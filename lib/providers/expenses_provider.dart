import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/expense.dart';
import '../services/data/expenses_repository.dart';
import '../services/cache/expenses_cache_service.dart';
import '../services/sync/sync_service.dart';
import '../services/sync/realtime_service.dart';
import '../utils/logger.dart';
import 'providers.dart';

/// State class for expenses data
class ExpensesState {
  final List<Expense> expenses;
  final bool isLoading;
  final String? error;
  final bool isOnline;
  final DateTime? lastSyncTime;
  final Map<String, double> categoryTotals;
  final double totalAmount;

  const ExpensesState({
    this.expenses = const [],
    this.isLoading = false,
    this.error,
    this.isOnline = true,
    this.lastSyncTime,
    this.categoryTotals = const {},
    this.totalAmount = 0.0,
  });

  ExpensesState copyWith({
    List<Expense>? expenses,
    bool? isLoading,
    String? error,
    bool? isOnline,
    DateTime? lastSyncTime,
    Map<String, double>? categoryTotals,
    double? totalAmount,
  }) {
    return ExpensesState(
      expenses: expenses ?? this.expenses,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isOnline: isOnline ?? this.isOnline,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      categoryTotals: categoryTotals ?? this.categoryTotals,
      totalAmount: totalAmount ?? this.totalAmount,
    );
  }
}

/// Expenses provider that manages expense data with automatic syncing
class ExpensesNotifier extends StateNotifier<ExpensesState> {
  final ExpensesRepository _repository;
  final ExpensesCacheService _cacheService;
  final SyncService _syncService;
  final RealtimeService _realtimeService;
  final Ref _ref;

  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  StreamSubscription<Map<String, dynamic>>? _syncEventSubscription;
  Timer? _autoSyncTimer;
  String? _currentUserId;
  bool _isDisposed = false;

  static const Duration _autoSyncInterval = Duration(minutes: 2);

  ExpensesNotifier(
    this._repository,
    this._cacheService,
    this._syncService,
    this._realtimeService,
    this._ref,
  ) : super(const ExpensesState()) {
    _initialize();
  }

  /// Initialize the provider
  Future<void> _initialize() async {
    try {
      Logger.info('Initializing ExpensesProvider');

      // Listen to auth state changes
      _ref.listen(currentUserProvider, (previous, next) {
        if (next?.id != _currentUserId) {
          _currentUserId = next?.id;
          if (_currentUserId != null) {
            _setupRealtimeSubscription();
            _startAutoSync();
            loadExpenses();
          } else {
            _cleanup();
          }
        }
      });

      // Listen to connectivity changes
      _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
        (connectivity) {
          final isOnline = connectivity != ConnectivityResult.none;
          state = state.copyWith(isOnline: isOnline);
          
          if (isOnline && _currentUserId != null) {
            // Sync when coming back online
            _syncExpenses();
          }
        },
      );

      // Listen to sync events
      _syncEventSubscription = _syncService.syncEventStream.listen(
        (event) {
          if (event['table'] == 'expenses') {
            _handleSyncEvent(event);
          }
        },
      );

      // Load initial data if user is authenticated
      final currentUser = _ref.read(currentUserProvider);
      if (currentUser != null) {
        _currentUserId = currentUser.id;
        await _setupRealtimeSubscription();
        _startAutoSync();
        await loadExpenses();
      }

      Logger.info('ExpensesProvider initialized successfully');
    } catch (e) {
      Logger.error('Failed to initialize ExpensesProvider: $e');
      state = state.copyWith(error: 'Failed to initialize: $e');
    }
  }

  /// Load expenses from repository or cache
  Future<void> loadExpenses({bool forceRefresh = false}) async {
    if (_isDisposed || _currentUserId == null) return;

    try {
      state = state.copyWith(isLoading: true, error: null);
      Logger.info('Loading expenses');

      List<Expense> expenses;

      if (state.isOnline && (forceRefresh || await _shouldRefreshFromServer())) {
        // Load from server
        expenses = await _repository.getAll();
        
        // Cache the data
        await _cacheService.cacheExpenses(
          expenses.map((expense) => expense.toJson()).toList(),
        );
        
        Logger.info('Loaded ${expenses.length} expenses from server');
      } else {
        // Load from cache
        final cachedData = await _cacheService.getCachedExpenses(userId: _currentUserId);
        expenses = cachedData.map((json) => Expense.fromJson(json)).toList();
        
        Logger.info('Loaded ${expenses.length} expenses from cache');
      }

      // Calculate totals
      final categoryTotals = _calculateCategoryTotals(expenses);
      final totalAmount = expenses.fold<double>(0.0, (sum, expense) => sum + expense.amount);

      state = state.copyWith(
        expenses: expenses,
        isLoading: false,
        lastSyncTime: DateTime.now(),
        categoryTotals: categoryTotals,
        totalAmount: totalAmount,
      );
    } catch (e) {
      Logger.error('Failed to load expenses: $e');
      
      // Try to load from cache as fallback
      try {
        final cachedData = await _cacheService.getCachedExpenses(userId: _currentUserId);
        final expenses = cachedData.map((json) => Expense.fromJson(json)).toList();
        final categoryTotals = _calculateCategoryTotals(expenses);
        final totalAmount = expenses.fold<double>(0.0, (sum, expense) => sum + expense.amount);
        
        state = state.copyWith(
          expenses: expenses,
          isLoading: false,
          error: 'Using cached data: $e',
          categoryTotals: categoryTotals,
          totalAmount: totalAmount,
        );
      } catch (cacheError) {
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to load expenses: $e',
        );
      }
    }
  }

  /// Create a new expense
  Future<void> createExpense({
    required String item,
    required double amount,
    required String category,
    DateTime? date,
  }) async {
    if (_isDisposed || _currentUserId == null) return;

    try {
      Logger.info('Creating new expense: $item - \$${amount.toStringAsFixed(2)}');

      final newExpense = Expense(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: _currentUserId!,
        item: item,
        amount: amount,
        category: category,
        date: date ?? DateTime.now(),
        createdAt: DateTime.now(),
      );

      if (state.isOnline) {
        // Create on server
        final createdExpense = await _repository.create(newExpense);
        
        // Update local state
        final updatedExpenses = [...state.expenses, createdExpense];
        final categoryTotals = _calculateCategoryTotals(updatedExpenses);
        final totalAmount = updatedExpenses.fold<double>(0.0, (sum, expense) => sum + expense.amount);
        
        state = state.copyWith(
          expenses: updatedExpenses,
          categoryTotals: categoryTotals,
          totalAmount: totalAmount,
        );
        
        // Cache the new expense
        await _cacheService.cacheExpense(createdExpense.toJson());
      } else {
        // Add to local state and queue for sync
        final updatedExpenses = [...state.expenses, newExpense];
        final categoryTotals = _calculateCategoryTotals(updatedExpenses);
        final totalAmount = updatedExpenses.fold<double>(0.0, (sum, expense) => sum + expense.amount);
        
        state = state.copyWith(
          expenses: updatedExpenses,
          categoryTotals: categoryTotals,
          totalAmount: totalAmount,
        );
        
        // Cache with unsynced flag
        await _cacheService.cacheExpense({
          ...newExpense.toJson(),
          'synced': 0,
        });
        
        // Queue for sync
        await _syncService.queueOperation(
          table: 'expenses',
          operation: SyncOperation.create,
          data: newExpense.toJson(),
        );
      }

      Logger.info('Expense created successfully');
    } catch (e) {
      Logger.error('Failed to create expense: $e');
      state = state.copyWith(error: 'Failed to create expense: $e');
    }
  }

  /// Update an existing expense
  Future<void> updateExpense(String expenseId, Map<String, dynamic> updates) async {
    if (_isDisposed || _currentUserId == null) return;

    try {
      Logger.info('Updating expense: $expenseId');

      final expenseIndex = state.expenses.indexWhere((expense) => expense.id == expenseId);
      if (expenseIndex == -1) {
        throw Exception('Expense not found');
      }

      final currentExpense = state.expenses[expenseIndex];

      if (state.isOnline) {
        // Update on server
        final updatedExpense = await _repository.update(expenseId, updates);
        
        // Update local state
        final updatedExpenses = [...state.expenses];
        updatedExpenses[expenseIndex] = updatedExpense;
        final categoryTotals = _calculateCategoryTotals(updatedExpenses);
        final totalAmount = updatedExpenses.fold<double>(0.0, (sum, expense) => sum + expense.amount);
        
        state = state.copyWith(
          expenses: updatedExpenses,
          categoryTotals: categoryTotals,
          totalAmount: totalAmount,
        );
        
        // Update cache
        await _cacheService.updateCachedExpense(expenseId, updatedExpense.toJson());
      } else {
        // Update local state
        final updatedExpense = currentExpense.copyWith(
          item: updates['item'] ?? currentExpense.item,
          amount: updates['amount'] ?? currentExpense.amount,
          category: updates['category'] ?? currentExpense.category,
          date: updates['date'] != null 
              ? DateTime.parse(updates['date']) 
              : currentExpense.date,
        );
        
        final updatedExpenses = [...state.expenses];
        updatedExpenses[expenseIndex] = updatedExpense;
        final categoryTotals = _calculateCategoryTotals(updatedExpenses);
        final totalAmount = updatedExpenses.fold<double>(0.0, (sum, expense) => sum + expense.amount);
        
        state = state.copyWith(
          expenses: updatedExpenses,
          categoryTotals: categoryTotals,
          totalAmount: totalAmount,
        );
        
        // Update cache with unsynced flag
        await _cacheService.updateCachedExpense(expenseId, {
          ...updatedExpense.toJson(),
          'synced': 0,
        });
        
        // Queue for sync
        await _syncService.queueOperation(
          table: 'expenses',
          operation: SyncOperation.update,
          data: updates,
          recordId: expenseId,
        );
      }

      Logger.info('Expense updated successfully');
    } catch (e) {
      Logger.error('Failed to update expense: $e');
      state = state.copyWith(error: 'Failed to update expense: $e');
    }
  }

  /// Delete an expense
  Future<void> deleteExpense(String expenseId) async {
    if (_isDisposed || _currentUserId == null) return;

    try {
      Logger.info('Deleting expense: $expenseId');

      if (state.isOnline) {
        // Delete from server
        await _repository.delete(expenseId);
        
        // Update local state
        final updatedExpenses = state.expenses.where((expense) => expense.id != expenseId).toList();
        final categoryTotals = _calculateCategoryTotals(updatedExpenses);
        final totalAmount = updatedExpenses.fold<double>(0.0, (sum, expense) => sum + expense.amount);
        
        state = state.copyWith(
          expenses: updatedExpenses,
          categoryTotals: categoryTotals,
          totalAmount: totalAmount,
        );
        
        // Remove from cache
        await _cacheService.deleteCachedExpense(expenseId);
      } else {
        // Update local state
        final updatedExpenses = state.expenses.where((expense) => expense.id != expenseId).toList();
        final categoryTotals = _calculateCategoryTotals(updatedExpenses);
        final totalAmount = updatedExpenses.fold<double>(0.0, (sum, expense) => sum + expense.amount);
        
        state = state.copyWith(
          expenses: updatedExpenses,
          categoryTotals: categoryTotals,
          totalAmount: totalAmount,
        );
        
        // Remove from cache
        await _cacheService.deleteCachedExpense(expenseId);
        
        // Queue for sync
        await _syncService.queueOperation(
          table: 'expenses',
          operation: SyncOperation.delete,
          data: {},
          recordId: expenseId,
        );
      }

      Logger.info('Expense deleted successfully');
    } catch (e) {
      Logger.error('Failed to delete expense: $e');
      state = state.copyWith(error: 'Failed to delete expense: $e');
    }
  }

  /// Get expenses by category
  List<Expense> getExpensesByCategory(String category) {
    return state.expenses.where((expense) => expense.category == category).toList();
  }

  /// Get expenses by date range
  List<Expense> getExpensesByDateRange(DateTime startDate, DateTime endDate) {
    return state.expenses.where((expense) {
      return expense.date.isAfter(startDate.subtract(const Duration(days: 1))) &&
             expense.date.isBefore(endDate.add(const Duration(days: 1)));
    }).toList();
  }

  /// Get today's expenses
  List<Expense> getTodaysExpenses() {
    return state.expenses.where((expense) => expense.isToday).toList();
  }

  /// Get this week's expenses
  List<Expense> getThisWeeksExpenses() {
    return state.expenses.where((expense) => expense.isThisWeek).toList();
  }

  /// Get this month's expenses
  List<Expense> getThisMonthsExpenses() {
    return state.expenses.where((expense) => expense.isThisMonth).toList();
  }

  /// Get unique categories
  List<String> getCategories() {
    return state.expenses.map((expense) => expense.category).toSet().toList()..sort();
  }



  /// Create expense from AI action
  Future<void> createExpenseFromAI(Map<String, dynamic> actionData) async {
    try {
      final item = actionData['item'] as String? ?? '';
      final amount = (actionData['amount'] as num?)?.toDouble() ?? 0.0;
      final category = actionData['category'] as String? ?? 'Other';
      final dateStr = actionData['date'] as String?;

      DateTime? date;
      if (dateStr != null) {
        try {
          date = DateTime.parse(dateStr);
        } catch (e) {
          Logger.warning('Invalid date from AI: $dateStr');
        }
      }

      await createExpense(
        item: item,
        amount: amount,
        category: category,
        date: date,
      );

      Logger.info('Expense created from AI: $item - \$${amount.toStringAsFixed(2)}');
    } catch (e) {
      Logger.error('Failed to create expense from AI: $e');
      throw Exception('Failed to create expense from AI: $e');
    }
  }

  /// Update expense from AI action
  Future<void> updateExpenseFromAI(Map<String, dynamic> actionData) async {
    try {
      final expenseId = actionData['expense_id'] as String?;
      if (expenseId == null) {
        throw Exception('Expense ID is required for update');
      }

      final updates = <String, dynamic>{};
      
      if (actionData.containsKey('item')) {
        updates['item'] = actionData['item'];
      }
      
      if (actionData.containsKey('amount')) {
        final amount = (actionData['amount'] as num?)?.toDouble();
        if (amount != null) {
          updates['amount'] = amount;
        }
      }
      
      if (actionData.containsKey('category')) {
        updates['category'] = actionData['category'];
      }
      
      if (actionData.containsKey('date')) {
        final dateStr = actionData['date'] as String?;
        if (dateStr != null) {
          try {
            updates['date'] = DateTime.parse(dateStr).toIso8601String();
          } catch (e) {
            Logger.warning('Invalid date from AI: $dateStr');
          }
        }
      }

      if (updates.isNotEmpty) {
        await updateExpense(expenseId, updates);
        Logger.info('Expense updated from AI: $expenseId');
      }
    } catch (e) {
      Logger.error('Failed to update expense from AI: $e');
      throw Exception('Failed to update expense from AI: $e');
    }
  }

  /// Setup realtime subscription for expenses
  Future<void> _setupRealtimeSubscription() async {
    if (_currentUserId == null) return;

    try {
      await _realtimeService.subscribe(
        subscriptionId: 'expenses_$_currentUserId',
        config: SubscriptionConfig(
          table: 'expenses',
          filter: 'user_id=eq.$_currentUserId',
          onInsert: (payload) => _handleRealtimeInsert(payload),
          onUpdate: (payload) => _handleRealtimeUpdate(payload),
          onDelete: (payload) => _handleRealtimeDelete(payload),
        ),
      );
      
      Logger.info('Realtime subscription setup for expenses');
    } catch (e) {
      Logger.error('Failed to setup realtime subscription: $e');
    }
  }

  /// Start automatic syncing
  void _startAutoSync() {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = Timer.periodic(_autoSyncInterval, (_) {
      if (state.isOnline && _currentUserId != null) {
        _syncExpenses();
      }
    });
    
    Logger.info('Auto-sync started for expenses');
  }

  /// Handle realtime insert events
  void _handleRealtimeInsert(Map<String, dynamic> payload) {
    try {
      final newExpense = Expense.fromJson(payload);
      
      // Check if expense already exists (avoid duplicates)
      if (!state.expenses.any((expense) => expense.id == newExpense.id)) {
        final updatedExpenses = [...state.expenses, newExpense];
        final categoryTotals = _calculateCategoryTotals(updatedExpenses);
        final totalAmount = updatedExpenses.fold<double>(0.0, (sum, expense) => sum + expense.amount);
        
        state = state.copyWith(
          expenses: updatedExpenses,
          categoryTotals: categoryTotals,
          totalAmount: totalAmount,
        );
        
        // Cache the new expense
        _cacheService.cacheExpense(newExpense.toJson());
        
        Logger.debug('Added new expense from realtime: ${newExpense.id}');
      }
    } catch (e) {
      Logger.error('Failed to handle realtime insert: $e');
    }
  }

  /// Handle realtime update events
  void _handleRealtimeUpdate(Map<String, dynamic> payload) {
    try {
      final updatedExpense = Expense.fromJson(payload);
      final expenseIndex = state.expenses.indexWhere((expense) => expense.id == updatedExpense.id);
      
      if (expenseIndex != -1) {
        final updatedExpenses = [...state.expenses];
        updatedExpenses[expenseIndex] = updatedExpense;
        final categoryTotals = _calculateCategoryTotals(updatedExpenses);
        final totalAmount = updatedExpenses.fold<double>(0.0, (sum, expense) => sum + expense.amount);
        
        state = state.copyWith(
          expenses: updatedExpenses,
          categoryTotals: categoryTotals,
          totalAmount: totalAmount,
        );
        
        // Update cache
        _cacheService.updateCachedExpense(updatedExpense.id, updatedExpense.toJson());
        
        Logger.debug('Updated expense from realtime: ${updatedExpense.id}');
      }
    } catch (e) {
      Logger.error('Failed to handle realtime update: $e');
    }
  }

  /// Handle realtime delete events
  void _handleRealtimeDelete(Map<String, dynamic> payload) {
    try {
      final expenseId = payload['id'] as String;
      
      final updatedExpenses = state.expenses.where((expense) => expense.id != expenseId).toList();
      final categoryTotals = _calculateCategoryTotals(updatedExpenses);
      final totalAmount = updatedExpenses.fold<double>(0.0, (sum, expense) => sum + expense.amount);
      
      state = state.copyWith(
        expenses: updatedExpenses,
        categoryTotals: categoryTotals,
        totalAmount: totalAmount,
      );
      
      // Remove from cache
      _cacheService.deleteCachedExpense(expenseId);
      
      Logger.debug('Deleted expense from realtime: $expenseId');
    } catch (e) {
      Logger.error('Failed to handle realtime delete: $e');
    }
  }

  /// Handle sync events
  void _handleSyncEvent(Map<String, dynamic> event) {
    final eventType = event['type'] as String;
    
    switch (eventType) {
      case 'sync_completed':
        state = state.copyWith(lastSyncTime: DateTime.now());
        break;
      case 'cache_update_required':
        if (event['table'] == 'expenses') {
          // Reload expenses when cache update is required
          loadExpenses();
        }
        break;
    }
  }

  /// Sync expenses with server
  Future<void> _syncExpenses() async {
    if (!state.isOnline || _currentUserId == null) return;

    try {
      Logger.debug('Auto-syncing expenses with server');
      await _syncService.sync();
    } catch (e) {
      Logger.error('Failed to auto-sync expenses: $e');
    }
  }

  /// Check if we should refresh from server
  Future<bool> _shouldRefreshFromServer() async {
    const maxAge = Duration(minutes: 3);
    return await _cacheService.isDataStale(maxAge);
  }

  /// Calculate category totals
  Map<String, double> _calculateCategoryTotals(List<Expense> expenses) {
    final Map<String, double> totals = {};
    
    for (final expense in expenses) {
      totals[expense.category] = (totals[expense.category] ?? 0.0) + expense.amount;
    }
    
    return totals;
  }

  /// Cleanup resources
  void _cleanup() {
    state = const ExpensesState();
    
    _autoSyncTimer?.cancel();
    _autoSyncTimer = null;
    
    if (_currentUserId != null) {
      _realtimeService.unsubscribe('expenses_$_currentUserId');
    }
  }

  @override
  void dispose() {
    Logger.info('Disposing ExpensesProvider');
    _isDisposed = true;
    
    _connectivitySubscription?.cancel();
    _syncEventSubscription?.cancel();
    _autoSyncTimer?.cancel();
    
    if (_currentUserId != null) {
      _realtimeService.unsubscribe('expenses_$_currentUserId');
    }
    
    super.dispose();
  }
}

/// Provider for expenses repository
final expensesRepositoryProvider = Provider<ExpensesRepository>((ref) {
  return ExpensesRepository();
});

/// Provider for expenses cache service
final expensesCacheServiceProvider = Provider<ExpensesCacheService>((ref) {
  return ExpensesCacheService();
});

/// Main expenses provider
final expensesProvider = StateNotifierProvider<ExpensesNotifier, ExpensesState>((ref) {
  return ExpensesNotifier(
    ref.watch(expensesRepositoryProvider),
    ref.watch(expensesCacheServiceProvider),
    SyncService.instance,
    RealtimeService.instance,
    ref,
  );
});

/// Convenience providers for specific expense queries
final todaysExpensesProvider = Provider<List<Expense>>((ref) {
  final expensesState = ref.watch(expensesProvider);
  return expensesState.expenses.where((expense) => expense.isToday).toList();
});

final thisWeeksExpensesProvider = Provider<List<Expense>>((ref) {
  final expensesState = ref.watch(expensesProvider);
  return expensesState.expenses.where((expense) => expense.isThisWeek).toList();
});

final thisMonthsExpensesProvider = Provider<List<Expense>>((ref) {
  final expensesState = ref.watch(expensesProvider);
  return expensesState.expenses.where((expense) => expense.isThisMonth).toList();
});

final expenseCategoriesProvider = Provider<List<String>>((ref) {
  final expensesState = ref.watch(expensesProvider);
  return expensesState.expenses.map((expense) => expense.category).toSet().toList()..sort();
});

final categoryTotalsProvider = Provider<Map<String, double>>((ref) {
  final expensesState = ref.watch(expensesProvider);
  return expensesState.categoryTotals;
});

final totalExpensesProvider = Provider<double>((ref) {
  final expensesState = ref.watch(expensesProvider);
  return expensesState.totalAmount;
});

final expensesLoadingProvider = Provider<bool>((ref) {
  final expensesState = ref.watch(expensesProvider);
  return expensesState.isLoading;
});

final expensesErrorProvider = Provider<String?>((ref) {
  final expensesState = ref.watch(expensesProvider);
  return expensesState.error;
});
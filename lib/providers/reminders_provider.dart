import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/reminder.dart';
import '../services/data/reminders_repository.dart';
import '../services/cache/reminders_cache_service.dart';
import '../services/sync/sync_service.dart';
import '../services/sync/realtime_service.dart';
import '../services/notifications/notification_service.dart';
import '../utils/logger.dart';
import 'providers.dart';

/// State class for reminders data
class RemindersState {
  final List<Reminder> reminders;
  final bool isLoading;
  final String? error;
  final bool isOnline;
  final DateTime? lastSyncTime;
  final List<Reminder> upcomingReminders;
  final List<Reminder> overdueReminders;
  final bool notificationsEnabled;

  const RemindersState({
    this.reminders = const [],
    this.isLoading = false,
    this.error,
    this.isOnline = true,
    this.lastSyncTime,
    this.upcomingReminders = const [],
    this.overdueReminders = const [],
    this.notificationsEnabled = false,
  });

  RemindersState copyWith({
    List<Reminder>? reminders,
    bool? isLoading,
    String? error,
    bool? isOnline,
    DateTime? lastSyncTime,
    List<Reminder>? upcomingReminders,
    List<Reminder>? overdueReminders,
    bool? notificationsEnabled,
  }) {
    return RemindersState(
      reminders: reminders ?? this.reminders,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isOnline: isOnline ?? this.isOnline,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      upcomingReminders: upcomingReminders ?? this.upcomingReminders,
      overdueReminders: overdueReminders ?? this.overdueReminders,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    );
  }
}

/// Reminders provider that manages reminder data with notification scheduling
class RemindersNotifier extends StateNotifier<RemindersState> {
  final RemindersRepository _repository;
  final RemindersCacheService _cacheService;
  final SyncService _syncService;
  final RealtimeService _realtimeService;
  final NotificationService _notificationService;
  final Ref _ref;

  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  StreamSubscription<Map<String, dynamic>>? _syncEventSubscription;
  Timer? _notificationCheckTimer;
  String? _currentUserId;
  bool _isDisposed = false;

  static const Duration _notificationCheckInterval = Duration(minutes: 1);

  RemindersNotifier(
    this._repository,
    this._cacheService,
    this._syncService,
    this._realtimeService,
    this._notificationService,
    this._ref,
  ) : super(const RemindersState()) {
    _initialize();
  }

  /// Initialize the provider
  Future<void> _initialize() async {
    try {
      Logger.info('Initializing RemindersProvider');

      // Initialize notification service
      final notificationsEnabled = await _notificationService.initialize();
      state = state.copyWith(notificationsEnabled: notificationsEnabled);

      // Listen to auth state changes
      _ref.listen(currentUserProvider, (previous, next) {
        if (next?.id != _currentUserId) {
          _currentUserId = next?.id;
          if (_currentUserId != null) {
            _setupRealtimeSubscription();
            _startNotificationChecking();
            loadReminders();
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
            _syncReminders();
          }
        },
      );

      // Listen to sync events
      _syncEventSubscription = _syncService.syncEventStream.listen(
        (event) {
          if (event['table'] == 'reminders') {
            _handleSyncEvent(event);
          }
        },
      );

      // Load initial data if user is authenticated
      final currentUser = _ref.read(currentUserProvider);
      if (currentUser != null) {
        _currentUserId = currentUser.id;
        await _setupRealtimeSubscription();
        _startNotificationChecking();
        await loadReminders();
      }

      Logger.info('RemindersProvider initialized successfully');
    } catch (e) {
      Logger.error('Failed to initialize RemindersProvider: $e');
      state = state.copyWith(error: 'Failed to initialize: $e');
    }
  }

  /// Load reminders from repository or cache
  Future<void> loadReminders({bool forceRefresh = false}) async {
    if (_isDisposed || _currentUserId == null) return;

    try {
      state = state.copyWith(isLoading: true, error: null);
      Logger.info('Loading reminders');

      List<Reminder> reminders;

      if (state.isOnline && (forceRefresh || await _shouldRefreshFromServer())) {
        // Load from server
        reminders = await _repository.getAll();
        
        // Cache the data
        await _cacheService.cacheReminders(
          reminders.map((reminder) => reminder.toJson()).toList(),
        );
        
        Logger.info('Loaded ${reminders.length} reminders from server');
      } else {
        // Load from cache
        final cachedData = await _cacheService.getCachedReminders(userId: _currentUserId);
        reminders = cachedData.map((json) => Reminder.fromJson(json)).toList();
        
        Logger.info('Loaded ${reminders.length} reminders from cache');
      }

      // Calculate derived lists
      final upcomingReminders = reminders.where((r) => r.isUpcoming).toList();
      final overdueReminders = reminders.where((r) => r.isOverdue).toList();

      state = state.copyWith(
        reminders: reminders,
        isLoading: false,
        lastSyncTime: DateTime.now(),
        upcomingReminders: upcomingReminders,
        overdueReminders: overdueReminders,
      );

      // Schedule notifications for upcoming reminders
      await _scheduleNotifications();
    } catch (e) {
      Logger.error('Failed to load reminders: $e');
      
      // Try to load from cache as fallback
      try {
        final cachedData = await _cacheService.getCachedReminders(userId: _currentUserId);
        final reminders = cachedData.map((json) => Reminder.fromJson(json)).toList();
        final upcomingReminders = reminders.where((r) => r.isUpcoming).toList();
        final overdueReminders = reminders.where((r) => r.isOverdue).toList();
        
        state = state.copyWith(
          reminders: reminders,
          isLoading: false,
          error: 'Using cached data: $e',
          upcomingReminders: upcomingReminders,
          overdueReminders: overdueReminders,
        );
      } catch (cacheError) {
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to load reminders: $e',
        );
      }
    }
  }

  /// Create a new reminder
  Future<void> createReminder({
    required String title,
    String? description,
    required DateTime scheduledTime,
  }) async {
    if (_isDisposed || _currentUserId == null) return;

    try {
      Logger.info('Creating new reminder: $title');

      final newReminder = Reminder(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: _currentUserId!,
        title: title,
        description: description,
        scheduledTime: scheduledTime,
        completed: false,
        createdAt: DateTime.now(),
      );

      if (state.isOnline) {
        // Create on server
        final createdReminder = await _repository.create(newReminder);
        
        // Update local state
        final updatedReminders = [...state.reminders, createdReminder];
        final upcomingReminders = updatedReminders.where((r) => r.isUpcoming).toList();
        final overdueReminders = updatedReminders.where((r) => r.isOverdue).toList();
        
        state = state.copyWith(
          reminders: updatedReminders,
          upcomingReminders: upcomingReminders,
          overdueReminders: overdueReminders,
        );
        
        // Cache the new reminder
        await _cacheService.cacheReminder(createdReminder.toJson());
        
        // Schedule notification
        await _scheduleNotificationForReminder(createdReminder);
      } else {
        // Add to local state and queue for sync
        final updatedReminders = [...state.reminders, newReminder];
        final upcomingReminders = updatedReminders.where((r) => r.isUpcoming).toList();
        final overdueReminders = updatedReminders.where((r) => r.isOverdue).toList();
        
        state = state.copyWith(
          reminders: updatedReminders,
          upcomingReminders: upcomingReminders,
          overdueReminders: overdueReminders,
        );
        
        // Cache with unsynced flag
        await _cacheService.cacheReminder({
          ...newReminder.toJson(),
          'synced': 0,
        });
        
        // Schedule notification
        await _scheduleNotificationForReminder(newReminder);
        
        // Queue for sync
        await _syncService.queueOperation(
          table: 'reminders',
          operation: SyncOperation.create,
          data: newReminder.toJson(),
        );
      }

      Logger.info('Reminder created successfully');
    } catch (e) {
      Logger.error('Failed to create reminder: $e');
      state = state.copyWith(error: 'Failed to create reminder: $e');
    }
  }

  /// Update an existing reminder
  Future<void> updateReminder(String reminderId, Map<String, dynamic> updates) async {
    if (_isDisposed || _currentUserId == null) return;

    try {
      Logger.info('Updating reminder: $reminderId');

      final reminderIndex = state.reminders.indexWhere((reminder) => reminder.id == reminderId);
      if (reminderIndex == -1) {
        throw Exception('Reminder not found');
      }

      final currentReminder = state.reminders[reminderIndex];

      if (state.isOnline) {
        // Update on server
        final updatedReminder = await _repository.update(reminderId, updates);
        
        // Update local state
        final updatedReminders = [...state.reminders];
        updatedReminders[reminderIndex] = updatedReminder;
        final upcomingReminders = updatedReminders.where((r) => r.isUpcoming).toList();
        final overdueReminders = updatedReminders.where((r) => r.isOverdue).toList();
        
        state = state.copyWith(
          reminders: updatedReminders,
          upcomingReminders: upcomingReminders,
          overdueReminders: overdueReminders,
        );
        
        // Update cache
        await _cacheService.updateCachedReminder(reminderId, updatedReminder.toJson());
        
        // Reschedule notification if time changed
        if (updates.containsKey('scheduled_time')) {
          await _cancelNotificationForReminder(reminderId);
          await _scheduleNotificationForReminder(updatedReminder);
        }
      } else {
        // Update local state
        final updatedReminder = currentReminder.copyWith(
          title: updates['title'] ?? currentReminder.title,
          description: updates['description'] ?? currentReminder.description,
          scheduledTime: updates['scheduled_time'] != null 
              ? DateTime.parse(updates['scheduled_time']) 
              : currentReminder.scheduledTime,
          completed: updates['completed'] ?? currentReminder.completed,
        );
        
        final updatedReminders = [...state.reminders];
        updatedReminders[reminderIndex] = updatedReminder;
        final upcomingReminders = updatedReminders.where((r) => r.isUpcoming).toList();
        final overdueReminders = updatedReminders.where((r) => r.isOverdue).toList();
        
        state = state.copyWith(
          reminders: updatedReminders,
          upcomingReminders: upcomingReminders,
          overdueReminders: overdueReminders,
        );
        
        // Update cache with unsynced flag
        await _cacheService.updateCachedReminder(reminderId, {
          ...updatedReminder.toJson(),
          'synced': 0,
        });
        
        // Reschedule notification if time changed
        if (updates.containsKey('scheduled_time')) {
          await _cancelNotificationForReminder(reminderId);
          await _scheduleNotificationForReminder(updatedReminder);
        }
        
        // Queue for sync
        await _syncService.queueOperation(
          table: 'reminders',
          operation: SyncOperation.update,
          data: updates,
          recordId: reminderId,
        );
      }

      Logger.info('Reminder updated successfully');
    } catch (e) {
      Logger.error('Failed to update reminder: $e');
      state = state.copyWith(error: 'Failed to update reminder: $e');
    }
  }

  /// Delete a reminder
  Future<void> deleteReminder(String reminderId) async {
    if (_isDisposed || _currentUserId == null) return;

    try {
      Logger.info('Deleting reminder: $reminderId');

      // Cancel notification first
      await _cancelNotificationForReminder(reminderId);

      if (state.isOnline) {
        // Delete from server
        await _repository.delete(reminderId);
        
        // Update local state
        final updatedReminders = state.reminders.where((reminder) => reminder.id != reminderId).toList();
        final upcomingReminders = updatedReminders.where((r) => r.isUpcoming).toList();
        final overdueReminders = updatedReminders.where((r) => r.isOverdue).toList();
        
        state = state.copyWith(
          reminders: updatedReminders,
          upcomingReminders: upcomingReminders,
          overdueReminders: overdueReminders,
        );
        
        // Remove from cache
        await _cacheService.deleteCachedReminder(reminderId);
      } else {
        // Update local state
        final updatedReminders = state.reminders.where((reminder) => reminder.id != reminderId).toList();
        final upcomingReminders = updatedReminders.where((r) => r.isUpcoming).toList();
        final overdueReminders = updatedReminders.where((r) => r.isOverdue).toList();
        
        state = state.copyWith(
          reminders: updatedReminders,
          upcomingReminders: upcomingReminders,
          overdueReminders: overdueReminders,
        );
        
        // Remove from cache
        await _cacheService.deleteCachedReminder(reminderId);
        
        // Queue for sync
        await _syncService.queueOperation(
          table: 'reminders',
          operation: SyncOperation.delete,
          data: {},
          recordId: reminderId,
        );
      }

      Logger.info('Reminder deleted successfully');
    } catch (e) {
      Logger.error('Failed to delete reminder: $e');
      state = state.copyWith(error: 'Failed to delete reminder: $e');
    }
  }

  /// Mark reminder as completed
  Future<void> markReminderCompleted(String reminderId) async {
    await updateReminder(reminderId, {'completed': true});
    await _cancelNotificationForReminder(reminderId);
  }

  /// Snooze reminder for specified duration
  Future<void> snoozeReminder(String reminderId, Duration snoozeDuration) async {
    final newScheduledTime = DateTime.now().add(snoozeDuration);
    
    await updateReminder(reminderId, {
      'scheduled_time': newScheduledTime.toIso8601String(),
    });
  }

  /// Get reminders by completion status
  List<Reminder> getRemindersByCompletion(bool completed) {
    return state.reminders.where((reminder) => reminder.completed == completed).toList();
  }

  /// Get reminders due today
  List<Reminder> getRemindersDueToday() {
    return state.reminders.where((reminder) => reminder.isDueToday).toList();
  }

  /// Get reminders due soon (within 24 hours)
  List<Reminder> getRemindersDueSoon() {
    return state.reminders.where((reminder) => reminder.isDueSoon).toList();
  }

  /// Create reminder from AI action
  Future<void> createReminderFromAI(Map<String, dynamic> actionData) async {
    try {
      final title = actionData['title'] as String? ?? '';
      final description = actionData['description'] as String?;
      final scheduledTimeStr = actionData['scheduled_time'] as String?;

      if (scheduledTimeStr == null) {
        throw Exception('Scheduled time is required for reminder');
      }

      DateTime scheduledTime;
      try {
        scheduledTime = DateTime.parse(scheduledTimeStr);
      } catch (e) {
        throw Exception('Invalid scheduled time format: $scheduledTimeStr');
      }

      await createReminder(
        title: title,
        description: description,
        scheduledTime: scheduledTime,
      );

      Logger.info('Reminder created from AI: $title');
    } catch (e) {
      Logger.error('Failed to create reminder from AI: $e');
      throw Exception('Failed to create reminder from AI: $e');
    }
  }

  /// Update reminder from AI action
  Future<void> updateReminderFromAI(Map<String, dynamic> actionData) async {
    try {
      final reminderId = actionData['reminder_id'] as String?;
      if (reminderId == null) {
        throw Exception('Reminder ID is required for update');
      }

      final updates = <String, dynamic>{};
      
      if (actionData.containsKey('title')) {
        updates['title'] = actionData['title'];
      }
      
      if (actionData.containsKey('description')) {
        updates['description'] = actionData['description'];
      }
      
      if (actionData.containsKey('scheduled_time')) {
        final scheduledTimeStr = actionData['scheduled_time'] as String?;
        if (scheduledTimeStr != null) {
          try {
            updates['scheduled_time'] = DateTime.parse(scheduledTimeStr).toIso8601String();
          } catch (e) {
            Logger.warning('Invalid scheduled time from AI: $scheduledTimeStr');
          }
        }
      }
      
      if (actionData.containsKey('completed')) {
        updates['completed'] = actionData['completed'] as bool;
      }

      if (updates.isNotEmpty) {
        await updateReminder(reminderId, updates);
        Logger.info('Reminder updated from AI: $reminderId');
      }
    } catch (e) {
      Logger.error('Failed to update reminder from AI: $e');
      throw Exception('Failed to update reminder from AI: $e');
    }
  }

  /// Request notification permissions
  Future<void> requestNotificationPermissions() async {
    try {
      final granted = await _notificationService.requestPermissions();
      state = state.copyWith(notificationsEnabled: granted);
      
      if (granted) {
        // Reschedule all notifications
        await _scheduleNotifications();
      }
    } catch (e) {
      Logger.error('Failed to request notification permissions: $e');
    }
  }

  /// Setup realtime subscription for reminders
  Future<void> _setupRealtimeSubscription() async {
    if (_currentUserId == null) return;

    try {
      await _realtimeService.subscribe(
        subscriptionId: 'reminders_$_currentUserId',
        config: SubscriptionConfig(
          table: 'reminders',
          filter: 'user_id=eq.$_currentUserId',
          onInsert: (payload) => _handleRealtimeInsert(payload),
          onUpdate: (payload) => _handleRealtimeUpdate(payload),
          onDelete: (payload) => _handleRealtimeDelete(payload),
        ),
      );
      
      Logger.info('Realtime subscription setup for reminders');
    } catch (e) {
      Logger.error('Failed to setup realtime subscription: $e');
    }
  }

  /// Start periodic notification checking
  void _startNotificationChecking() {
    _notificationCheckTimer?.cancel();
    _notificationCheckTimer = Timer.periodic(_notificationCheckInterval, (_) {
      _checkAndTriggerNotifications();
    });
    
    Logger.info('Notification checking started for reminders');
  }

  /// Check for reminders that need notifications
  Future<void> _checkAndTriggerNotifications() async {
    if (!state.notificationsEnabled || _currentUserId == null) return;

    try {
      final now = DateTime.now();
      final remindersToNotify = state.reminders.where((reminder) {
        return !reminder.completed &&
               reminder.scheduledTime.isBefore(now.add(const Duration(minutes: 1))) &&
               reminder.scheduledTime.isAfter(now.subtract(const Duration(minutes: 1)));
      }).toList();

      for (final reminder in remindersToNotify) {
        await _notificationService.showNotification(
          id: reminder.id.hashCode,
          title: 'Reminder: ${reminder.title}',
          body: reminder.description ?? 'You have a reminder due now',
          payload: reminder.id,
        );
        
        Logger.info('Triggered notification for reminder: ${reminder.id}');
      }
    } catch (e) {
      Logger.error('Failed to check and trigger notifications: $e');
    }
  }

  /// Schedule notifications for all upcoming reminders
  Future<void> _scheduleNotifications() async {
    if (!state.notificationsEnabled) return;

    try {
      // Cancel all existing notifications
      await _notificationService.cancelAllNotifications();
      
      // Schedule notifications for upcoming reminders
      for (final reminder in state.upcomingReminders) {
        await _scheduleNotificationForReminder(reminder);
      }
      
      Logger.info('Scheduled notifications for ${state.upcomingReminders.length} reminders');
    } catch (e) {
      Logger.error('Failed to schedule notifications: $e');
    }
  }

  /// Schedule notification for a specific reminder
  Future<void> _scheduleNotificationForReminder(Reminder reminder) async {
    if (!state.notificationsEnabled || reminder.completed) return;

    try {
      // Schedule both local and push notifications
      await _notificationService.scheduleNotification(
        id: reminder.id.hashCode,
        title: 'Reminder: ${reminder.title}',
        body: reminder.description ?? 'You have a reminder due now',
        scheduledDate: reminder.scheduledTime,
        payload: reminder.id,
        reminderId: reminder.id,
      );
      
      // Also schedule push notification specifically
      await _notificationService.schedulePushNotification(
        title: 'Reminder: ${reminder.title}',
        body: reminder.description ?? 'You have a reminder due now',
        scheduledTime: reminder.scheduledTime,
        reminderId: reminder.id,
        data: {
          'reminder_id': reminder.id,
          'title': reminder.title,
          'description': reminder.description,
        },
      );
      
      Logger.debug('Scheduled notifications for reminder: ${reminder.id}');
    } catch (e) {
      Logger.error('Failed to schedule notification for reminder ${reminder.id}: $e');
    }
  }

  /// Cancel notification for a specific reminder
  Future<void> _cancelNotificationForReminder(String reminderId) async {
    try {
      // Cancel local notification
      await _notificationService.cancelNotification(reminderId.hashCode);
      
      // Cancel push notification
      await _notificationService.cancelPushNotification(reminderId: reminderId);
      
      Logger.debug('Cancelled notifications for reminder: $reminderId');
    } catch (e) {
      Logger.error('Failed to cancel notification for reminder $reminderId: $e');
    }
  }

  /// Handle realtime insert events
  void _handleRealtimeInsert(Map<String, dynamic> payload) {
    try {
      final newReminder = Reminder.fromJson(payload);
      
      // Check if reminder already exists (avoid duplicates)
      if (!state.reminders.any((reminder) => reminder.id == newReminder.id)) {
        final updatedReminders = [...state.reminders, newReminder];
        final upcomingReminders = updatedReminders.where((r) => r.isUpcoming).toList();
        final overdueReminders = updatedReminders.where((r) => r.isOverdue).toList();
        
        state = state.copyWith(
          reminders: updatedReminders,
          upcomingReminders: upcomingReminders,
          overdueReminders: overdueReminders,
        );
        
        // Cache the new reminder
        _cacheService.cacheReminder(newReminder.toJson());
        
        // Schedule notification
        _scheduleNotificationForReminder(newReminder);
        
        Logger.debug('Added new reminder from realtime: ${newReminder.id}');
      }
    } catch (e) {
      Logger.error('Failed to handle realtime insert: $e');
    }
  }

  /// Handle realtime update events
  void _handleRealtimeUpdate(Map<String, dynamic> payload) {
    try {
      final updatedReminder = Reminder.fromJson(payload);
      final reminderIndex = state.reminders.indexWhere((reminder) => reminder.id == updatedReminder.id);
      
      if (reminderIndex != -1) {
        final oldReminder = state.reminders[reminderIndex];
        final updatedReminders = [...state.reminders];
        updatedReminders[reminderIndex] = updatedReminder;
        final upcomingReminders = updatedReminders.where((r) => r.isUpcoming).toList();
        final overdueReminders = updatedReminders.where((r) => r.isOverdue).toList();
        
        state = state.copyWith(
          reminders: updatedReminders,
          upcomingReminders: upcomingReminders,
          overdueReminders: overdueReminders,
        );
        
        // Update cache
        _cacheService.updateCachedReminder(updatedReminder.id, updatedReminder.toJson());
        
        // Reschedule notification if time changed or completed status changed
        if (oldReminder.scheduledTime != updatedReminder.scheduledTime || 
            oldReminder.completed != updatedReminder.completed) {
          _cancelNotificationForReminder(updatedReminder.id);
          if (!updatedReminder.completed) {
            _scheduleNotificationForReminder(updatedReminder);
          }
        }
        
        Logger.debug('Updated reminder from realtime: ${updatedReminder.id}');
      }
    } catch (e) {
      Logger.error('Failed to handle realtime update: $e');
    }
  }

  /// Handle realtime delete events
  void _handleRealtimeDelete(Map<String, dynamic> payload) {
    try {
      final reminderId = payload['id'] as String;
      
      // Cancel notification
      _cancelNotificationForReminder(reminderId);
      
      final updatedReminders = state.reminders.where((reminder) => reminder.id != reminderId).toList();
      final upcomingReminders = updatedReminders.where((r) => r.isUpcoming).toList();
      final overdueReminders = updatedReminders.where((r) => r.isOverdue).toList();
      
      state = state.copyWith(
        reminders: updatedReminders,
        upcomingReminders: upcomingReminders,
        overdueReminders: overdueReminders,
      );
      
      // Remove from cache
      _cacheService.deleteCachedReminder(reminderId);
      
      Logger.debug('Deleted reminder from realtime: $reminderId');
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
        if (event['table'] == 'reminders') {
          // Reload reminders when cache update is required
          loadReminders();
        }
        break;
    }
  }

  /// Sync reminders with server
  Future<void> _syncReminders() async {
    if (!state.isOnline || _currentUserId == null) return;

    try {
      Logger.debug('Syncing reminders with server');
      await _syncService.sync();
    } catch (e) {
      Logger.error('Failed to sync reminders: $e');
    }
  }

  /// Check if we should refresh from server
  Future<bool> _shouldRefreshFromServer() async {
    const maxAge = Duration(minutes: 5);
    return await _cacheService.isDataStale(maxAge);
  }

  /// Cleanup resources
  void _cleanup() {
    state = const RemindersState();
    
    _notificationCheckTimer?.cancel();
    _notificationCheckTimer = null;
    
    if (_currentUserId != null) {
      _realtimeService.unsubscribe('reminders_$_currentUserId');
    }
  }

  @override
  void dispose() {
    Logger.info('Disposing RemindersProvider');
    _isDisposed = true;
    
    _connectivitySubscription?.cancel();
    _syncEventSubscription?.cancel();
    _notificationCheckTimer?.cancel();
    
    if (_currentUserId != null) {
      _realtimeService.unsubscribe('reminders_$_currentUserId');
    }
    
    super.dispose();
  }
}

/// Provider for reminders repository
final remindersRepositoryProvider = Provider<RemindersRepository>((ref) {
  return RemindersRepository();
});

/// Provider for reminders cache service
final remindersCacheServiceProvider = Provider<RemindersCacheService>((ref) {
  return RemindersCacheService();
});

/// Provider for notification service
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService.instance;
});

/// Main reminders provider
final remindersProvider = StateNotifierProvider<RemindersNotifier, RemindersState>((ref) {
  return RemindersNotifier(
    ref.watch(remindersRepositoryProvider),
    ref.watch(remindersCacheServiceProvider),
    SyncService.instance,
    RealtimeService.instance,
    ref.watch(notificationServiceProvider),
    ref,
  );
});

/// Convenience providers for specific reminder queries
final upcomingRemindersProvider = Provider<List<Reminder>>((ref) {
  final remindersState = ref.watch(remindersProvider);
  return remindersState.upcomingReminders;
});

final overdueRemindersProvider = Provider<List<Reminder>>((ref) {
  final remindersState = ref.watch(remindersProvider);
  return remindersState.overdueReminders;
});

final completedRemindersProvider = Provider<List<Reminder>>((ref) {
  final remindersState = ref.watch(remindersProvider);
  return remindersState.reminders.where((reminder) => reminder.completed).toList();
});

final remindersDueTodayProvider = Provider<List<Reminder>>((ref) {
  final remindersState = ref.watch(remindersProvider);
  return remindersState.reminders.where((reminder) => reminder.isDueToday).toList();
});

final remindersDueSoonProvider = Provider<List<Reminder>>((ref) {
  final remindersState = ref.watch(remindersProvider);
  return remindersState.reminders.where((reminder) => reminder.isDueSoon).toList();
});

final notificationsEnabledProvider = Provider<bool>((ref) {
  final remindersState = ref.watch(remindersProvider);
  return remindersState.notificationsEnabled;
});

final remindersLoadingProvider = Provider<bool>((ref) {
  final remindersState = ref.watch(remindersProvider);
  return remindersState.isLoading;
});

final remindersErrorProvider = Provider<String?>((ref) {
  final remindersState = ref.watch(remindersProvider);
  return remindersState.error;
});
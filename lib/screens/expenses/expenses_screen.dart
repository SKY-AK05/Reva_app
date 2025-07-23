import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/expense.dart';
import '../../providers/expenses_provider.dart';
import '../../widgets/expenses/expense_list_item.dart';
import '../../widgets/expenses/expense_summary_card.dart';
import '../../widgets/expenses/expense_filter_chip.dart';
import '../../widgets/expenses/expense_search_bar.dart';

import 'add_expense_screen.dart';
import 'expense_detail_screen.dart';

class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  String? _selectedCategory;
  DateTimeRange? _selectedDateRange;
  bool _isSearchVisible = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    
    // Load expenses when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(expensesProvider.notifier).loadExpenses();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final expensesState = ref.watch(expensesProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text(
          'Expenses',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        actions: [
          IconButton(
            icon: Icon(_isSearchVisible ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearchVisible = !_isSearchVisible;
                if (!_isSearchVisible) {
                  _searchQuery = '';
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(expensesProvider.notifier).loadExpenses(forceRefresh: true);
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(_isSearchVisible ? 120 : 48),
          child: Column(
            children: [
              if (_isSearchVisible)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ExpenseSearchBar(
                    onSearchChanged: (query) {
                      setState(() {
                        _searchQuery = query;
                      });
                    },
                  ),
                ),
              TabBar(
                controller: _tabController,
                labelColor: theme.colorScheme.primary,
                unselectedLabelColor: theme.colorScheme.onSurface.withOpacity(0.6),
                indicatorColor: theme.colorScheme.primary,
                tabs: const [
                  Tab(text: 'All'),
                  Tab(text: 'Today'),
                  Tab(text: 'Week'),
                  Tab(text: 'Month'),
                ],
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          // Summary Cards
          if (!expensesState.isLoading && expensesState.expenses.isNotEmpty)
            _buildSummarySection(),
          
          // Active Filters
          if (_hasActiveFilters())
            _buildActiveFilters(),
          
          // Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildExpensesList(expensesState.expenses),
                _buildExpensesList(ref.watch(todaysExpensesProvider)),
                _buildExpensesList(ref.watch(thisWeeksExpensesProvider)),
                _buildExpensesList(ref.watch(thisMonthsExpensesProvider)),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToAddExpense(),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSummarySection() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: ExpenseSummaryCard(
                  title: 'Total',
                  amount: ref.watch(totalExpensesProvider),
                  icon: Icons.account_balance_wallet,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ExpenseSummaryCard(
                  title: 'This Month',
                  amount: ref.watch(thisMonthsExpensesProvider)
                      .fold<double>(0.0, (sum, expense) => sum + expense.amount),
                  icon: Icons.calendar_month,
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ExpenseSummaryCard(
                  title: 'This Week',
                  amount: ref.watch(thisWeeksExpensesProvider)
                      .fold<double>(0.0, (sum, expense) => sum + expense.amount),
                  icon: Icons.date_range,
                  color: Theme.of(context).colorScheme.tertiary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ExpenseSummaryCard(
                  title: 'Today',
                  amount: ref.watch(todaysExpensesProvider)
                      .fold<double>(0.0, (sum, expense) => sum + expense.amount),
                  icon: Icons.today,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActiveFilters() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 8,
        children: [
          if (_selectedCategory != null)
            ExpenseFilterChip(
              label: 'Category: $_selectedCategory',
              onDeleted: () {
                setState(() {
                  _selectedCategory = null;
                });
              },
            ),
          if (_selectedDateRange != null)
            ExpenseFilterChip(
              label: 'Date: ${DateFormat('MMM d').format(_selectedDateRange!.start)} - ${DateFormat('MMM d').format(_selectedDateRange!.end)}',
              onDeleted: () {
                setState(() {
                  _selectedDateRange = null;
                });
              },
            ),
          if (_searchQuery.isNotEmpty)
            ExpenseFilterChip(
              label: 'Search: $_searchQuery',
              onDeleted: () {
                setState(() {
                  _searchQuery = '';
                });
              },
            ),
        ],
      ),
    );
  }

  Widget _buildExpensesList(List<Expense> expenses) {
    final expensesState = ref.watch(expensesProvider);
    
    if (expensesState.isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (expensesState.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Error loading expenses',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              expensesState.error!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                ref.read(expensesProvider.notifier).loadExpenses(forceRefresh: true);
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    // Filter expenses based on search and filters
    final filteredExpenses = _filterExpenses(expenses);

    if (filteredExpenses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              _hasActiveFilters() ? 'No expenses match your filters' : 'No expenses yet',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _hasActiveFilters() 
                  ? 'Try adjusting your search or filters'
                  : 'Start tracking your expenses by tapping the + button',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Group expenses by category
    final groupedExpenses = _groupExpensesByCategory(filteredExpenses);

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(expensesProvider.notifier).loadExpenses(forceRefresh: true);
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: groupedExpenses.length,
        itemBuilder: (context, index) {
          final category = groupedExpenses.keys.elementAt(index);
          final categoryExpenses = groupedExpenses[category]!;
          final categoryTotal = categoryExpenses.fold<double>(
            0.0, 
            (sum, expense) => sum + expense.amount,
          );

          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        category,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '\$${categoryTotal.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Category Expenses
                ...categoryExpenses.map((expense) => ExpenseListItem(
                  expense: expense,
                  onTap: () => _navigateToExpenseDetail(expense),
                )),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Expense> _filterExpenses(List<Expense> expenses) {
    var filtered = expenses;

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((expense) {
        return expense.item.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               expense.category.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }

    // Apply category filter
    if (_selectedCategory != null) {
      filtered = filtered.where((expense) => expense.category == _selectedCategory).toList();
    }

    // Apply date range filter
    if (_selectedDateRange != null) {
      filtered = filtered.where((expense) {
        return expense.date.isAfter(_selectedDateRange!.start.subtract(const Duration(days: 1))) &&
               expense.date.isBefore(_selectedDateRange!.end.add(const Duration(days: 1)));
      }).toList();
    }

    return filtered;
  }

  Map<String, List<Expense>> _groupExpensesByCategory(List<Expense> expenses) {
    final Map<String, List<Expense>> grouped = {};
    
    for (final expense in expenses) {
      if (!grouped.containsKey(expense.category)) {
        grouped[expense.category] = [];
      }
      grouped[expense.category]!.add(expense);
    }

    // Sort expenses within each category by date (newest first)
    for (final category in grouped.keys) {
      grouped[category]!.sort((a, b) => b.date.compareTo(a.date));
    }

    // Sort categories by total amount (highest first)
    final sortedEntries = grouped.entries.toList()
      ..sort((a, b) {
        final totalA = a.value.fold<double>(0.0, (sum, expense) => sum + expense.amount);
        final totalB = b.value.fold<double>(0.0, (sum, expense) => sum + expense.amount);
        return totalB.compareTo(totalA);
      });

    return Map.fromEntries(sortedEntries);
  }

  bool _hasActiveFilters() {
    return _searchQuery.isNotEmpty || 
           _selectedCategory != null || 
           _selectedDateRange != null;
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (context, scrollController) => _buildFilterSheet(scrollController),
      ),
    );
  }

  Widget _buildFilterSheet(ScrollController scrollController) {
    final categories = ref.watch(expenseCategoriesProvider);
    
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Title
          Text(
            'Filter Expenses',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 24),
          
          Expanded(
            child: ListView(
              controller: scrollController,
              children: [
                // Category Filter
                Text(
                  'Category',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilterChip(
                      label: const Text('All Categories'),
                      selected: _selectedCategory == null,
                      onSelected: (selected) {
                        setState(() {
                          _selectedCategory = null;
                        });
                        Navigator.pop(context);
                      },
                    ),
                    ...categories.map((category) => FilterChip(
                      label: Text(category),
                      selected: _selectedCategory == category,
                      onSelected: (selected) {
                        setState(() {
                          _selectedCategory = selected ? category : null;
                        });
                        Navigator.pop(context);
                      },
                    )),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Date Range Filter
                Text(
                  'Date Range',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.date_range),
                  title: Text(_selectedDateRange == null 
                      ? 'Select date range' 
                      : '${DateFormat('MMM d, y').format(_selectedDateRange!.start)} - ${DateFormat('MMM d, y').format(_selectedDateRange!.end)}'),
                  trailing: _selectedDateRange != null 
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            setState(() {
                              _selectedDateRange = null;
                            });
                          },
                        )
                      : const Icon(Icons.chevron_right),
                  onTap: () async {
                    final dateRange = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                      initialDateRange: _selectedDateRange,
                    );
                    
                    if (dateRange != null) {
                      setState(() {
                        _selectedDateRange = dateRange;
                      });
                    }
                  },
                ),
                const SizedBox(height: 24),
                
                // Clear All Filters
                if (_hasActiveFilters())
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _selectedCategory = null;
                          _selectedDateRange = null;
                          _searchQuery = '';
                        });
                        Navigator.pop(context);
                      },
                      child: const Text('Clear All Filters'),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToAddExpense() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AddExpenseScreen(),
      ),
    );
  }

  void _navigateToExpenseDetail(Expense expense) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ExpenseDetailScreen(expense: expense),
      ),
    );
  }
}
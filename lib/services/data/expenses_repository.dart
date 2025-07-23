import '../../models/expense.dart';
import '../../utils/logger.dart';
import 'base_repository.dart';

class ExpensesRepository extends BaseRepository<Expense> {
  @override
  String get tableName => 'expenses';

  @override
  Expense fromJson(Map<String, dynamic> json) => Expense.fromJson(json);

  @override
  Map<String, dynamic> toJson(Expense item) => item.toJson();

  /// Get expenses by category
  Future<List<Expense>> getByCategory(String category) async {
    try {
      ensureAuthenticated();
      
      Logger.info('Fetching expenses for category: $category');
      
      final response = await supabase
          .from(tableName)
          .select()
          .eq('user_id', currentUserId!)
          .eq('category', category)
          .order('date', ascending: false);
      
      final expenses = (response as List<dynamic>)
          .map((json) => fromJson(json as Map<String, dynamic>))
          .toList();
      
      Logger.info('Fetched ${expenses.length} expenses for category: $category');
      return expenses;
    } catch (e) {
      Logger.error('Failed to fetch expenses by category: $e');
      throw handleError(e);
    }
  }

  /// Get expenses within date range
  Future<List<Expense>> getByDateRange(DateTime startDate, DateTime endDate) async {
    try {
      ensureAuthenticated();
      
      Logger.info('Fetching expenses from ${startDate.toIso8601String()} to ${endDate.toIso8601String()}');
      
      final response = await supabase
          .from(tableName)
          .select()
          .eq('user_id', currentUserId!)
          .gte('date', startDate.toIso8601String())
          .lte('date', endDate.toIso8601String())
          .order('date', ascending: false);
      
      final expenses = (response as List<dynamic>)
          .map((json) => fromJson(json as Map<String, dynamic>))
          .toList();
      
      Logger.info('Fetched ${expenses.length} expenses in date range');
      return expenses;
    } catch (e) {
      Logger.error('Failed to fetch expenses by date range: $e');
      throw handleError(e);
    }
  }

  /// Get expenses for today
  Future<List<Expense>> getToday() async {
    try {
      ensureAuthenticated();
      
      Logger.info('Fetching today\'s expenses');
      
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);
      
      return await getByDateRange(startOfDay, endOfDay);
    } catch (e) {
      Logger.error('Failed to fetch today\'s expenses: $e');
      throw handleError(e);
    }
  }

  /// Get expenses for this week
  Future<List<Expense>> getThisWeek() async {
    try {
      ensureAuthenticated();
      
      Logger.info('Fetching this week\'s expenses');
      
      final now = DateTime.now();
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      final endOfWeek = startOfWeek.add(const Duration(days: 6));
      
      return await getByDateRange(
        DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day),
        DateTime(endOfWeek.year, endOfWeek.month, endOfWeek.day, 23, 59, 59),
      );
    } catch (e) {
      Logger.error('Failed to fetch this week\'s expenses: $e');
      throw handleError(e);
    }
  }

  /// Get expenses for this month
  Future<List<Expense>> getThisMonth() async {
    try {
      ensureAuthenticated();
      
      Logger.info('Fetching this month\'s expenses');
      
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
      
      return await getByDateRange(startOfMonth, endOfMonth);
    } catch (e) {
      Logger.error('Failed to fetch this month\'s expenses: $e');
      throw handleError(e);
    }
  }

  /// Get total amount spent
  Future<double> getTotalAmount({
    String? category,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      ensureAuthenticated();
      
      Logger.info('Calculating total amount spent');
      
      var query = supabase
          .from(tableName)
          .select('amount')
          .eq('user_id', currentUserId!);
      
      if (category != null) {
        query = query.eq('category', category);
      }
      
      if (startDate != null) {
        query = query.gte('date', startDate.toIso8601String());
      }
      
      if (endDate != null) {
        query = query.lte('date', endDate.toIso8601String());
      }
      
      final response = await query;
      
      double total = 0.0;
      for (final row in response as List<dynamic>) {
        total += (row['amount'] as num).toDouble();
      }
      
      Logger.info('Total amount spent: \$${total.toStringAsFixed(2)}');
      return total;
    } catch (e) {
      Logger.error('Failed to calculate total amount: $e');
      throw handleError(e);
    }
  }

  /// Get spending by category
  Future<Map<String, double>> getSpendingByCategory({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      ensureAuthenticated();
      
      Logger.info('Fetching spending by category');
      
      var query = supabase
          .from(tableName)
          .select('category, amount')
          .eq('user_id', currentUserId!);
      
      if (startDate != null) {
        query = query.gte('date', startDate.toIso8601String());
      }
      
      if (endDate != null) {
        query = query.lte('date', endDate.toIso8601String());
      }
      
      final response = await query;
      
      final Map<String, double> categoryTotals = {};
      
      for (final row in response as List<dynamic>) {
        final category = row['category'] as String;
        final amount = (row['amount'] as num).toDouble();
        
        categoryTotals[category] = (categoryTotals[category] ?? 0.0) + amount;
      }
      
      Logger.info('Spending by category: $categoryTotals');
      return categoryTotals;
    } catch (e) {
      Logger.error('Failed to fetch spending by category: $e');
      throw handleError(e);
    }
  }

  /// Get all unique categories
  Future<List<String>> getCategories() async {
    try {
      ensureAuthenticated();
      
      Logger.info('Fetching all expense categories');
      
      final response = await supabase
          .from(tableName)
          .select('category')
          .eq('user_id', currentUserId!)
          .order('category');
      
      final categories = (response as List<dynamic>)
          .map((row) => row['category'] as String)
          .toSet()
          .toList();
      
      Logger.info('Found ${categories.length} unique categories');
      return categories;
    } catch (e) {
      Logger.error('Failed to fetch categories: $e');
      throw handleError(e);
    }
  }

  /// Search expenses by item name
  Future<List<Expense>> searchByItem(String query) async {
    try {
      ensureAuthenticated();
      
      Logger.info('Searching expenses with query: $query');
      
      final response = await supabase
          .from(tableName)
          .select()
          .eq('user_id', currentUserId!)
          .ilike('item', '%$query%')
          .order('date', ascending: false);
      
      final expenses = (response as List<dynamic>)
          .map((json) => fromJson(json as Map<String, dynamic>))
          .toList();
      
      Logger.info('Found ${expenses.length} expenses matching query: $query');
      return expenses;
    } catch (e) {
      Logger.error('Failed to search expenses: $e');
      throw handleError(e);
    }
  }

  /// Get expenses above certain amount
  Future<List<Expense>> getAboveAmount(double amount) async {
    try {
      ensureAuthenticated();
      
      Logger.info('Fetching expenses above \$${amount.toStringAsFixed(2)}');
      
      final response = await supabase
          .from(tableName)
          .select()
          .eq('user_id', currentUserId!)
          .gt('amount', amount)
          .order('amount', ascending: false);
      
      final expenses = (response as List<dynamic>)
          .map((json) => fromJson(json as Map<String, dynamic>))
          .toList();
      
      Logger.info('Found ${expenses.length} expenses above \$${amount.toStringAsFixed(2)}');
      return expenses;
    } catch (e) {
      Logger.error('Failed to fetch expenses above amount: $e');
      throw handleError(e);
    }
  }

  /// Get expense statistics
  Future<Map<String, dynamic>> getStatistics() async {
    try {
      ensureAuthenticated();
      
      Logger.info('Fetching expense statistics');
      
      // Get all expenses for the user
      final allExpenses = await getAll();
      
      if (allExpenses.isEmpty) {
        return {
          'total_count': 0,
          'total_amount': 0.0,
          'average_amount': 0.0,
          'highest_amount': 0.0,
          'lowest_amount': 0.0,
          'categories_count': 0,
          'this_month_total': 0.0,
          'this_week_total': 0.0,
          'today_total': 0.0,
        };
      }
      
      final amounts = allExpenses.map((e) => e.amount).toList();
      amounts.sort();
      
      final totalAmount = amounts.reduce((a, b) => a + b);
      final averageAmount = totalAmount / amounts.length;
      final categories = allExpenses.map((e) => e.category).toSet();
      
      // Get period totals
      final thisMonthTotal = await getTotalAmount(
        startDate: DateTime(DateTime.now().year, DateTime.now().month, 1),
        endDate: DateTime.now(),
      );
      
      final thisWeekTotal = await getTotalAmount(
        startDate: DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1)),
        endDate: DateTime.now(),
      );
      
      final todayTotal = await getTotalAmount(
        startDate: DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day),
        endDate: DateTime.now(),
      );
      
      final stats = {
        'total_count': allExpenses.length,
        'total_amount': totalAmount,
        'average_amount': averageAmount,
        'highest_amount': amounts.last,
        'lowest_amount': amounts.first,
        'categories_count': categories.length,
        'this_month_total': thisMonthTotal,
        'this_week_total': thisWeekTotal,
        'today_total': todayTotal,
      };
      
      Logger.info('Expense statistics: $stats');
      return stats;
    } catch (e) {
      Logger.error('Failed to fetch expense statistics: $e');
      throw handleError(e);
    }
  }
}
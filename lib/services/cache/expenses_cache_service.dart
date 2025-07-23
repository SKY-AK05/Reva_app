import 'package:sqflite/sqflite.dart';
import 'database_helper.dart';

class ExpensesCacheService {
  static const String _cacheKey = 'expenses';

  Future<void> cacheExpenses(List<Map<String, dynamic>> expenses) async {
    final db = await DatabaseHelper.database;
    
    // Clear existing expenses
    await db.delete(DatabaseHelper.expensesTable);
    
    // Insert new expenses
    for (final expense in expenses) {
      await db.insert(
        DatabaseHelper.expensesTable,
        {
          ...expense,
          'synced': 1, // Mark as synced since we're caching from server
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    
    // Update cache metadata
    await _updateCacheMetadata();
  }

  Future<List<Map<String, dynamic>>> getCachedExpenses({String? userId}) async {
    final db = await DatabaseHelper.database;
    
    String whereClause = '';
    List<dynamic> whereArgs = [];
    
    if (userId != null) {
      whereClause = 'user_id = ?';
      whereArgs = [userId];
    }
    
    final result = await db.query(
      DatabaseHelper.expensesTable,
      where: whereClause.isEmpty ? null : whereClause,
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'date DESC',
    );
    
    return result;
  }

  Future<void> cacheExpense(Map<String, dynamic> expense) async {
    final db = await DatabaseHelper.database;
    
    await db.insert(
      DatabaseHelper.expensesTable,
      {
        ...expense,
        'synced': 1,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    
    await _updateCacheMetadata();
  }

  Future<void> updateCachedExpense(String expenseId, Map<String, dynamic> updates) async {
    final db = await DatabaseHelper.database;
    
    await db.update(
      DatabaseHelper.expensesTable,
      {
        ...updates,
        'synced': 1,
      },
      where: 'id = ?',
      whereArgs: [expenseId],
    );
    
    await _updateCacheMetadata();
  }

  Future<void> deleteCachedExpense(String expenseId) async {
    final db = await DatabaseHelper.database;
    
    await db.delete(
      DatabaseHelper.expensesTable,
      where: 'id = ?',
      whereArgs: [expenseId],
    );
    
    await _updateCacheMetadata();
  }

  Future<Map<String, dynamic>?> getCachedExpense(String expenseId) async {
    final db = await DatabaseHelper.database;
    
    final result = await db.query(
      DatabaseHelper.expensesTable,
      where: 'id = ?',
      whereArgs: [expenseId],
      limit: 1,
    );
    
    return result.isNotEmpty ? result.first : null;
  }

  Future<List<Map<String, dynamic>>> getExpensesByCategory(String category, {String? userId}) async {
    final db = await DatabaseHelper.database;
    
    String whereClause = 'category = ?';
    List<dynamic> whereArgs = [category];
    
    if (userId != null) {
      whereClause += ' AND user_id = ?';
      whereArgs.add(userId);
    }
    
    final result = await db.query(
      DatabaseHelper.expensesTable,
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'date DESC',
    );
    
    return result;
  }

  Future<List<Map<String, dynamic>>> getExpensesByDateRange(
    DateTime startDate,
    DateTime endDate, {
    String? userId,
  }) async {
    final db = await DatabaseHelper.database;
    
    String whereClause = 'date >= ? AND date <= ?';
    List<dynamic> whereArgs = [
      startDate.toIso8601String().split('T')[0], // Date only
      endDate.toIso8601String().split('T')[0],
    ];
    
    if (userId != null) {
      whereClause += ' AND user_id = ?';
      whereArgs.add(userId);
    }
    
    final result = await db.query(
      DatabaseHelper.expensesTable,
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'date DESC',
    );
    
    return result;
  }

  Future<double> getTotalExpenses({String? userId, String? category}) async {
    final db = await DatabaseHelper.database;
    
    String whereClause = '';
    List<dynamic> whereArgs = [];
    
    if (userId != null) {
      whereClause = 'user_id = ?';
      whereArgs.add(userId);
    }
    
    if (category != null) {
      if (whereClause.isNotEmpty) {
        whereClause += ' AND ';
      }
      whereClause += 'category = ?';
      whereArgs.add(category);
    }
    
    final result = await db.rawQuery(
      'SELECT SUM(amount) as total FROM ${DatabaseHelper.expensesTable}' +
      (whereClause.isNotEmpty ? ' WHERE $whereClause' : ''),
      whereArgs.isNotEmpty ? whereArgs : null,
    );
    
    return (result.first['total'] as double?) ?? 0.0;
  }

  Future<List<Map<String, dynamic>>> getUnsyncedExpenses() async {
    final db = await DatabaseHelper.database;
    
    final result = await db.query(
      DatabaseHelper.expensesTable,
      where: 'synced = ?',
      whereArgs: [0],
    );
    
    return result;
  }

  Future<void> markExpenseAsSynced(String expenseId) async {
    final db = await DatabaseHelper.database;
    
    await db.update(
      DatabaseHelper.expensesTable,
      {'synced': 1},
      where: 'id = ?',
      whereArgs: [expenseId],
    );
  }

  Future<void> markExpenseAsUnsynced(String expenseId) async {
    final db = await DatabaseHelper.database;
    
    await db.update(
      DatabaseHelper.expensesTable,
      {'synced': 0},
      where: 'id = ?',
      whereArgs: [expenseId],
    );
  }

  Future<bool> isDataStale(Duration maxAge) async {
    final db = await DatabaseHelper.database;
    
    final result = await db.query(
      DatabaseHelper.cacheMetadataTable,
      where: 'key = ?',
      whereArgs: ['cache_$_cacheKey'],
      limit: 1,
    );
    
    if (result.isEmpty) return true;
    
    final lastUpdatedStr = result.first['last_updated'] as String;
    final lastUpdated = DateTime.parse(lastUpdatedStr);
    final now = DateTime.now();
    
    return now.difference(lastUpdated) > maxAge;
  }

  Future<void> clearCache() async {
    final db = await DatabaseHelper.database;
    
    await db.delete(DatabaseHelper.expensesTable);
    await db.delete(
      DatabaseHelper.cacheMetadataTable,
      where: 'key = ?',
      whereArgs: ['cache_$_cacheKey'],
    );
  }

  Future<void> _updateCacheMetadata() async {
    final db = await DatabaseHelper.database;
    
    await db.insert(
      DatabaseHelper.cacheMetadataTable,
      {
        'key': 'cache_$_cacheKey',
        'last_updated': DateTime.now().toIso8601String(),
        'expires_at': null,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
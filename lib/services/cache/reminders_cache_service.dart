import 'package:sqflite/sqflite.dart';
import 'database_helper.dart';

class RemindersCacheService {
  static const String _cacheKey = 'reminders';

  Future<void> cacheReminders(List<Map<String, dynamic>> reminders) async {
    final db = await DatabaseHelper.database;
    
    // Clear existing reminders
    await db.delete(DatabaseHelper.remindersTable);
    
    // Insert new reminders
    for (final reminder in reminders) {
      await db.insert(
        DatabaseHelper.remindersTable,
        {
          ...reminder,
          'synced': 1, // Mark as synced since we're caching from server
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    
    // Update cache metadata
    await _updateCacheMetadata();
  }

  Future<List<Map<String, dynamic>>> getCachedReminders({String? userId}) async {
    final db = await DatabaseHelper.database;
    
    String whereClause = '';
    List<dynamic> whereArgs = [];
    
    if (userId != null) {
      whereClause = 'user_id = ?';
      whereArgs = [userId];
    }
    
    final result = await db.query(
      DatabaseHelper.remindersTable,
      where: whereClause.isEmpty ? null : whereClause,
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'scheduled_time ASC',
    );
    
    return result;
  }

  Future<void> cacheReminder(Map<String, dynamic> reminder) async {
    final db = await DatabaseHelper.database;
    
    await db.insert(
      DatabaseHelper.remindersTable,
      {
        ...reminder,
        'synced': 1,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    
    await _updateCacheMetadata();
  }

  Future<void> updateCachedReminder(String reminderId, Map<String, dynamic> updates) async {
    final db = await DatabaseHelper.database;
    
    await db.update(
      DatabaseHelper.remindersTable,
      {
        ...updates,
        'synced': 1,
      },
      where: 'id = ?',
      whereArgs: [reminderId],
    );
    
    await _updateCacheMetadata();
  }

  Future<void> deleteCachedReminder(String reminderId) async {
    final db = await DatabaseHelper.database;
    
    await db.delete(
      DatabaseHelper.remindersTable,
      where: 'id = ?',
      whereArgs: [reminderId],
    );
    
    await _updateCacheMetadata();
  }

  Future<Map<String, dynamic>?> getCachedReminder(String reminderId) async {
    final db = await DatabaseHelper.database;
    
    final result = await db.query(
      DatabaseHelper.remindersTable,
      where: 'id = ?',
      whereArgs: [reminderId],
      limit: 1,
    );
    
    return result.isNotEmpty ? result.first : null;
  }

  Future<List<Map<String, dynamic>>> getUpcomingReminders({String? userId}) async {
    final db = await DatabaseHelper.database;
    
    String whereClause = 'scheduled_time > ? AND completed = 0';
    List<dynamic> whereArgs = [DateTime.now().toIso8601String()];
    
    if (userId != null) {
      whereClause += ' AND user_id = ?';
      whereArgs.add(userId);
    }
    
    final result = await db.query(
      DatabaseHelper.remindersTable,
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'scheduled_time ASC',
    );
    
    return result;
  }

  Future<List<Map<String, dynamic>>> getPastReminders({String? userId}) async {
    final db = await DatabaseHelper.database;
    
    String whereClause = 'scheduled_time <= ?';
    List<dynamic> whereArgs = [DateTime.now().toIso8601String()];
    
    if (userId != null) {
      whereClause += ' AND user_id = ?';
      whereArgs.add(userId);
    }
    
    final result = await db.query(
      DatabaseHelper.remindersTable,
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'scheduled_time DESC',
    );
    
    return result;
  }

  Future<List<Map<String, dynamic>>> getCompletedReminders({String? userId}) async {
    final db = await DatabaseHelper.database;
    
    String whereClause = 'completed = 1';
    List<dynamic> whereArgs = [];
    
    if (userId != null) {
      whereClause += ' AND user_id = ?';
      whereArgs.add(userId);
    }
    
    final result = await db.query(
      DatabaseHelper.remindersTable,
      where: whereClause,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'scheduled_time DESC',
    );
    
    return result;
  }

  Future<List<Map<String, dynamic>>> getRemindersDueWithin(
    Duration duration, {
    String? userId,
  }) async {
    final db = await DatabaseHelper.database;
    
    final now = DateTime.now();
    final dueTime = now.add(duration);
    
    String whereClause = 'scheduled_time > ? AND scheduled_time <= ? AND completed = 0';
    List<dynamic> whereArgs = [
      now.toIso8601String(),
      dueTime.toIso8601String(),
    ];
    
    if (userId != null) {
      whereClause += ' AND user_id = ?';
      whereArgs.add(userId);
    }
    
    final result = await db.query(
      DatabaseHelper.remindersTable,
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'scheduled_time ASC',
    );
    
    return result;
  }

  Future<void> markReminderAsCompleted(String reminderId) async {
    final db = await DatabaseHelper.database;
    
    await db.update(
      DatabaseHelper.remindersTable,
      {
        'completed': 1,
        'synced': 0, // Mark as unsynced since we're making a local change
      },
      where: 'id = ?',
      whereArgs: [reminderId],
    );
    
    await _updateCacheMetadata();
  }

  Future<List<Map<String, dynamic>>> getUnsyncedReminders() async {
    final db = await DatabaseHelper.database;
    
    final result = await db.query(
      DatabaseHelper.remindersTable,
      where: 'synced = ?',
      whereArgs: [0],
    );
    
    return result;
  }

  Future<void> markReminderAsSynced(String reminderId) async {
    final db = await DatabaseHelper.database;
    
    await db.update(
      DatabaseHelper.remindersTable,
      {'synced': 1},
      where: 'id = ?',
      whereArgs: [reminderId],
    );
  }

  Future<void> markReminderAsUnsynced(String reminderId) async {
    final db = await DatabaseHelper.database;
    
    await db.update(
      DatabaseHelper.remindersTable,
      {'synced': 0},
      where: 'id = ?',
      whereArgs: [reminderId],
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
    
    await db.delete(DatabaseHelper.remindersTable);
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
import 'package:sqflite/sqflite.dart';
import 'database_helper.dart';

class TasksCacheService {
  static const String _cacheKey = 'tasks';

  Future<void> cacheTasks(List<Map<String, dynamic>> tasks) async {
    final db = await DatabaseHelper.database;
    
    // Clear existing tasks
    await db.delete(DatabaseHelper.tasksTable);
    
    // Insert new tasks
    for (final task in tasks) {
      await db.insert(
        DatabaseHelper.tasksTable,
        {
          ...task,
          'synced': 1, // Mark as synced since we're caching from server
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    
    // Update cache metadata
    await _updateCacheMetadata();
  }

  Future<List<Map<String, dynamic>>> getCachedTasks({String? userId}) async {
    final db = await DatabaseHelper.database;
    
    String whereClause = '';
    List<dynamic> whereArgs = [];
    
    if (userId != null) {
      whereClause = 'user_id = ?';
      whereArgs = [userId];
    }
    
    final result = await db.query(
      DatabaseHelper.tasksTable,
      where: whereClause.isEmpty ? null : whereClause,
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'created_at DESC',
    );
    
    return result;
  }

  Future<void> cacheTask(Map<String, dynamic> task) async {
    final db = await DatabaseHelper.database;
    
    await db.insert(
      DatabaseHelper.tasksTable,
      {
        ...task,
        'synced': 1,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    
    await _updateCacheMetadata();
  }

  Future<void> updateCachedTask(String taskId, Map<String, dynamic> updates) async {
    final db = await DatabaseHelper.database;
    
    await db.update(
      DatabaseHelper.tasksTable,
      {
        ...updates,
        'updated_at': DateTime.now().toIso8601String(),
        'synced': 1,
      },
      where: 'id = ?',
      whereArgs: [taskId],
    );
    
    await _updateCacheMetadata();
  }

  Future<void> deleteCachedTask(String taskId) async {
    final db = await DatabaseHelper.database;
    
    await db.delete(
      DatabaseHelper.tasksTable,
      where: 'id = ?',
      whereArgs: [taskId],
    );
    
    await _updateCacheMetadata();
  }

  Future<Map<String, dynamic>?> getCachedTask(String taskId) async {
    final db = await DatabaseHelper.database;
    
    final result = await db.query(
      DatabaseHelper.tasksTable,
      where: 'id = ?',
      whereArgs: [taskId],
      limit: 1,
    );
    
    return result.isNotEmpty ? result.first : null;
  }

  Future<List<Map<String, dynamic>>> getUnsyncedTasks() async {
    final db = await DatabaseHelper.database;
    
    final result = await db.query(
      DatabaseHelper.tasksTable,
      where: 'synced = ?',
      whereArgs: [0],
    );
    
    return result;
  }

  Future<void> markTaskAsSynced(String taskId) async {
    final db = await DatabaseHelper.database;
    
    await db.update(
      DatabaseHelper.tasksTable,
      {'synced': 1},
      where: 'id = ?',
      whereArgs: [taskId],
    );
  }

  Future<void> markTaskAsUnsynced(String taskId) async {
    final db = await DatabaseHelper.database;
    
    await db.update(
      DatabaseHelper.tasksTable,
      {'synced': 0},
      where: 'id = ?',
      whereArgs: [taskId],
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
    
    await db.delete(DatabaseHelper.tasksTable);
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
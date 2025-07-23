import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'database_helper.dart';

class ChatCacheService {
  static const String _cacheKey = 'chat_messages';

  Future<void> cacheChatMessages(List<Map<String, dynamic>> messages) async {
    final db = await DatabaseHelper.database;
    
    // Clear existing messages
    await db.delete(DatabaseHelper.chatMessagesTable);
    
    // Insert new messages
    for (final message in messages) {
      await db.insert(
        DatabaseHelper.chatMessagesTable,
        {
          ...message,
          'metadata': message['metadata'] != null 
              ? jsonEncode(message['metadata']) 
              : null,
          'synced': 1, // Mark as synced since we're caching from server
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    
    // Update cache metadata
    await _updateCacheMetadata();
  }

  Future<List<Map<String, dynamic>>> getCachedChatMessages({
    int? limit,
    int? offset,
  }) async {
    final db = await DatabaseHelper.database;
    
    final result = await db.query(
      DatabaseHelper.chatMessagesTable,
      orderBy: 'timestamp DESC',
      limit: limit,
      offset: offset,
    );
    
    // Parse metadata back to Map
    return result.map((message) {
      final metadata = message['metadata'] as String?;
      return {
        ...message,
        'metadata': metadata != null ? jsonDecode(metadata) : null,
      };
    }).toList();
  }

  Future<void> cacheChatMessage(Map<String, dynamic> message) async {
    final db = await DatabaseHelper.database;
    
    await db.insert(
      DatabaseHelper.chatMessagesTable,
      {
        ...message,
        'metadata': message['metadata'] != null 
            ? jsonEncode(message['metadata']) 
            : null,
        'synced': 1,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    
    await _updateCacheMetadata();
  }

  Future<void> addUnsyncedMessage(Map<String, dynamic> message) async {
    final db = await DatabaseHelper.database;
    
    await db.insert(
      DatabaseHelper.chatMessagesTable,
      {
        ...message,
        'metadata': message['metadata'] != null 
            ? jsonEncode(message['metadata']) 
            : null,
        'synced': 0, // Mark as unsynced since it's a local message
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    
    await _updateCacheMetadata();
  }

  Future<void> updateCachedMessage(String messageId, Map<String, dynamic> updates) async {
    final db = await DatabaseHelper.database;
    
    final updateData = {...updates};
    if (updateData['metadata'] != null) {
      updateData['metadata'] = jsonEncode(updateData['metadata']);
    }
    
    await db.update(
      DatabaseHelper.chatMessagesTable,
      updateData,
      where: 'id = ?',
      whereArgs: [messageId],
    );
    
    await _updateCacheMetadata();
  }

  Future<void> deleteCachedMessage(String messageId) async {
    final db = await DatabaseHelper.database;
    
    await db.delete(
      DatabaseHelper.chatMessagesTable,
      where: 'id = ?',
      whereArgs: [messageId],
    );
    
    await _updateCacheMetadata();
  }

  Future<Map<String, dynamic>?> getCachedMessage(String messageId) async {
    final db = await DatabaseHelper.database;
    
    final result = await db.query(
      DatabaseHelper.chatMessagesTable,
      where: 'id = ?',
      whereArgs: [messageId],
      limit: 1,
    );
    
    if (result.isEmpty) return null;
    
    final message = result.first;
    final metadata = message['metadata'] as String?;
    
    return {
      ...message,
      'metadata': metadata != null ? jsonDecode(metadata) : null,
    };
  }

  Future<List<Map<String, dynamic>>> getMessagesByType(String type) async {
    final db = await DatabaseHelper.database;
    
    final result = await db.query(
      DatabaseHelper.chatMessagesTable,
      where: 'type = ?',
      whereArgs: [type],
      orderBy: 'timestamp DESC',
    );
    
    return result.map((message) {
      final metadata = message['metadata'] as String?;
      return {
        ...message,
        'metadata': metadata != null ? jsonDecode(metadata) : null,
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> getMessagesAfter(DateTime timestamp) async {
    final db = await DatabaseHelper.database;
    
    final result = await db.query(
      DatabaseHelper.chatMessagesTable,
      where: 'timestamp > ?',
      whereArgs: [timestamp.toIso8601String()],
      orderBy: 'timestamp ASC',
    );
    
    return result.map((message) {
      final metadata = message['metadata'] as String?;
      return {
        ...message,
        'metadata': metadata != null ? jsonDecode(metadata) : null,
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> getMessagesBefore(DateTime timestamp, {int? limit}) async {
    final db = await DatabaseHelper.database;
    
    final result = await db.query(
      DatabaseHelper.chatMessagesTable,
      where: 'timestamp < ?',
      whereArgs: [timestamp.toIso8601String()],
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    
    return result.map((message) {
      final metadata = message['metadata'] as String?;
      return {
        ...message,
        'metadata': metadata != null ? jsonDecode(metadata) : null,
      };
    }).toList();
  }

  Future<int> getMessageCount() async {
    final db = await DatabaseHelper.database;
    
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM ${DatabaseHelper.chatMessagesTable}'
    );
    
    return result.first['count'] as int;
  }

  Future<List<Map<String, dynamic>>> getUnsyncedMessages() async {
    final db = await DatabaseHelper.database;
    
    final result = await db.query(
      DatabaseHelper.chatMessagesTable,
      where: 'synced = ?',
      whereArgs: [0],
      orderBy: 'timestamp ASC',
    );
    
    return result.map((message) {
      final metadata = message['metadata'] as String?;
      return {
        ...message,
        'metadata': metadata != null ? jsonDecode(metadata) : null,
      };
    }).toList();
  }

  Future<void> markMessageAsSynced(String messageId) async {
    final db = await DatabaseHelper.database;
    
    await db.update(
      DatabaseHelper.chatMessagesTable,
      {'synced': 1},
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }

  Future<void> markMessageAsUnsynced(String messageId) async {
    final db = await DatabaseHelper.database;
    
    await db.update(
      DatabaseHelper.chatMessagesTable,
      {'synced': 0},
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }

  Future<void> clearOldMessages({int? keepCount, Duration? keepDuration}) async {
    final db = await DatabaseHelper.database;
    
    if (keepCount != null) {
      // Keep only the most recent N messages
      final result = await db.query(
        DatabaseHelper.chatMessagesTable,
        columns: ['id'],
        orderBy: 'timestamp DESC',
        limit: keepCount,
      );
      
      if (result.isNotEmpty) {
        final keepIds = result.map((row) => "'${row['id']}'").join(',');
        await db.rawDelete(
          'DELETE FROM ${DatabaseHelper.chatMessagesTable} WHERE id NOT IN ($keepIds)'
        );
      }
    } else if (keepDuration != null) {
      // Keep only messages newer than the specified duration
      final cutoffTime = DateTime.now().subtract(keepDuration);
      await db.delete(
        DatabaseHelper.chatMessagesTable,
        where: 'timestamp < ?',
        whereArgs: [cutoffTime.toIso8601String()],
      );
    }
    
    await _updateCacheMetadata();
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
    
    await db.delete(DatabaseHelper.chatMessagesTable);
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
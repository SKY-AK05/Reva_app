import 'dart:convert';
import 'dart:typed_data';
import 'package:sqflite/sqflite.dart';
import 'database_helper.dart';

/// Cache statistics for monitoring cache performance
class CacheStats {
  final String key;
  final DateTime lastUpdated;
  final DateTime? expiresAt;
  final int sizeBytes;
  final int accessCount;
  final DateTime lastAccessed;

  const CacheStats({
    required this.key,
    required this.lastUpdated,
    this.expiresAt,
    required this.sizeBytes,
    required this.accessCount,
    required this.lastAccessed,
  });

  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);
  bool isStale(Duration maxAge) => DateTime.now().difference(lastUpdated) > maxAge;
}

abstract class CacheService {
  Future<void> cacheData<T>(String key, List<T> data);
  Future<List<T>?> getCachedData<T>(String key);
  Future<void> clearCache();
  Future<bool> isDataStale(String key, Duration maxAge);
  Future<void> updateCacheMetadata(String key, {DateTime? expiresAt});
  Future<void> deleteCacheEntry(String key);
  
  // Cache eviction and management
  Future<void> evictLeastRecentlyUsed(int maxEntries);
  Future<void> evictOldestEntries(int maxEntries);
  Future<int> getCacheSize();
  Future<void> enforceStorageLimit(int maxSizeBytes);
  Future<void> refreshStaleData(String key, Duration maxAge);
  Future<Map<String, CacheStats>> getCacheStats();
}

class CacheServiceImpl implements CacheService {
  static const String _cachePrefix = 'cache_';

  @override
  Future<void> cacheData<T>(String key, List<T> data) async {
    final db = await DatabaseHelper.database;
    
    // Convert data to JSON string for storage
    final jsonData = data.map((item) {
      if (item is Map<String, dynamic>) {
        return item;
      } else if (item.toString().contains('toJson')) {
        // Assume the object has a toJson method
        return (item as dynamic).toJson();
      } else {
        throw ArgumentError('Data type must implement toJson() method');
      }
    }).toList();
    
    final jsonString = jsonEncode(jsonData);
    
    // Store in a generic cache table or use the key to determine storage
    await db.insert(
      DatabaseHelper.cacheMetadataTable,
      {
        'key': '$_cachePrefix$key',
        'last_updated': DateTime.now().toIso8601String(),
        'expires_at': null,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    
    // For now, we'll store the actual data in a simple key-value approach
    // In a more complex implementation, we might use separate tables
    await _storeCacheData(key, jsonString);
  }

  @override
  Future<List<T>?> getCachedData<T>(String key) async {
    try {
      final jsonString = await _retrieveCacheData(key);
      if (jsonString == null) return null;
      
      final List<dynamic> jsonList = jsonDecode(jsonString);
      
      // Note: This is a simplified approach. In practice, you'd need
      // proper deserialization based on the type T
      return jsonList.cast<T>();
    } catch (e) {
      // If there's an error retrieving or parsing data, return null
      return null;
    }
  }

  @override
  Future<void> clearCache() async {
    final db = await DatabaseHelper.database;
    await db.delete(DatabaseHelper.cacheMetadataTable);
    // Also clear any additional cache storage
    await _clearAllCacheData();
  }

  @override
  Future<bool> isDataStale(String key, Duration maxAge) async {
    final db = await DatabaseHelper.database;
    
    final result = await db.query(
      DatabaseHelper.cacheMetadataTable,
      where: 'key = ?',
      whereArgs: ['$_cachePrefix$key'],
      limit: 1,
    );
    
    if (result.isEmpty) return true;
    
    final lastUpdatedStr = result.first['last_updated'] as String;
    final lastUpdated = DateTime.parse(lastUpdatedStr);
    final now = DateTime.now();
    
    return now.difference(lastUpdated) > maxAge;
  }

  @override
  Future<void> updateCacheMetadata(String key, {DateTime? expiresAt}) async {
    final db = await DatabaseHelper.database;
    
    await db.update(
      DatabaseHelper.cacheMetadataTable,
      {
        'last_updated': DateTime.now().toIso8601String(),
        'expires_at': expiresAt?.toIso8601String(),
      },
      where: 'key = ?',
      whereArgs: ['$_cachePrefix$key'],
    );
  }

  @override
  Future<void> deleteCacheEntry(String key) async {
    final db = await DatabaseHelper.database;
    
    await db.delete(
      DatabaseHelper.cacheMetadataTable,
      where: 'key = ?',
      whereArgs: ['$_cachePrefix$key'],
    );
    
    await _deleteCacheData(key);
  }

  // Helper methods for storing actual cache data
  Future<void> _storeCacheData(String key, String data) async {
    final db = await DatabaseHelper.database;
    
    // Store in a dedicated cache_data table
    await db.insert(
      DatabaseHelper.cacheDataTable,
      {
        'key': key,
        'data': data,
        'created_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> _retrieveCacheData(String key) async {
    final db = await DatabaseHelper.database;
    
    final result = await db.query(
      DatabaseHelper.cacheDataTable,
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    
    if (result.isEmpty) return null;
    return result.first['data'] as String;
  }

  Future<void> _clearAllCacheData() async {
    final db = await DatabaseHelper.database;
    await db.delete(DatabaseHelper.cacheDataTable);
  }

  Future<void> _deleteCacheData(String key) async {
    final db = await DatabaseHelper.database;
    await db.delete(
      DatabaseHelper.cacheDataTable,
      where: 'key = ?',
      whereArgs: [key],
    );
  }

  // Utility methods for cache management
  
  Future<List<String>> getCacheKeys() async {
    final db = await DatabaseHelper.database;
    
    final result = await db.query(
      DatabaseHelper.cacheMetadataTable,
      columns: ['key'],
    );
    
    return result
        .map((row) => row['key'] as String)
        .where((key) => key.startsWith(_cachePrefix))
        .map((key) => key.substring(_cachePrefix.length))
        .toList();
  }

  Future<DateTime?> getLastUpdated(String key) async {
    final db = await DatabaseHelper.database;
    
    final result = await db.query(
      DatabaseHelper.cacheMetadataTable,
      where: 'key = ?',
      whereArgs: ['$_cachePrefix$key'],
      limit: 1,
    );
    
    if (result.isEmpty) return null;
    
    final lastUpdatedStr = result.first['last_updated'] as String;
    return DateTime.parse(lastUpdatedStr);
  }

  Future<bool> hasExpired(String key) async {
    final db = await DatabaseHelper.database;
    
    final result = await db.query(
      DatabaseHelper.cacheMetadataTable,
      where: 'key = ?',
      whereArgs: ['$_cachePrefix$key'],
      limit: 1,
    );
    
    if (result.isEmpty) return true;
    
    final expiresAtStr = result.first['expires_at'] as String?;
    if (expiresAtStr == null) return false;
    
    final expiresAt = DateTime.parse(expiresAtStr);
    return DateTime.now().isAfter(expiresAt);
  }

  Future<void> cleanupExpiredCache() async {
    final db = await DatabaseHelper.database;
    
    // Get all expired cache entries
    final expiredEntries = await db.query(
      DatabaseHelper.cacheMetadataTable,
      where: 'expires_at IS NOT NULL AND expires_at < ?',
      whereArgs: [DateTime.now().toIso8601String()],
    );
    
    // Delete expired entries
    for (final entry in expiredEntries) {
      final key = entry['key'] as String;
      await db.delete(
        DatabaseHelper.cacheMetadataTable,
        where: 'key = ?',
        whereArgs: [key],
      );
      
      // Also delete the associated cache data
      final cacheKey = key.startsWith(_cachePrefix) 
          ? key.substring(_cachePrefix.length) 
          : key;
      await _deleteCacheData(cacheKey);
    }
  }

  // Cache eviction and management implementations
  
  @override
  Future<void> evictLeastRecentlyUsed(int maxEntries) async {
    final db = await DatabaseHelper.database;
    
    // Get cache entries ordered by last access time (oldest first)
    final entries = await db.rawQuery('''
      SELECT m.key, m.last_updated, d.created_at
      FROM ${DatabaseHelper.cacheMetadataTable} m
      LEFT JOIN ${DatabaseHelper.cacheDataTable} d ON SUBSTR(m.key, ${_cachePrefix.length + 1}) = d.key
      WHERE m.key LIKE '$_cachePrefix%'
      ORDER BY COALESCE(d.created_at, m.last_updated) ASC
    ''');
    
    if (entries.length <= maxEntries) return;
    
    final entriesToEvict = entries.take(entries.length - maxEntries);
    
    for (final entry in entriesToEvict) {
      final key = entry['key'] as String;
      final cacheKey = key.substring(_cachePrefix.length);
      await deleteCacheEntry(cacheKey);
    }
  }

  @override
  Future<void> evictOldestEntries(int maxEntries) async {
    final db = await DatabaseHelper.database;
    
    // Get cache entries ordered by creation time (oldest first)
    final entries = await db.query(
      DatabaseHelper.cacheMetadataTable,
      where: 'key LIKE ?',
      whereArgs: ['$_cachePrefix%'],
      orderBy: 'last_updated ASC',
    );
    
    if (entries.length <= maxEntries) return;
    
    final entriesToEvict = entries.take(entries.length - maxEntries);
    
    for (final entry in entriesToEvict) {
      final key = entry['key'] as String;
      final cacheKey = key.substring(_cachePrefix.length);
      await deleteCacheEntry(cacheKey);
    }
  }

  @override
  Future<int> getCacheSize() async {
    final db = await DatabaseHelper.database;
    
    final result = await db.rawQuery('''
      SELECT COUNT(*) as count
      FROM ${DatabaseHelper.cacheMetadataTable}
      WHERE key LIKE '$_cachePrefix%'
    ''');
    
    return Sqflite.firstIntValue(result) ?? 0;
  }

  @override
  Future<void> enforceStorageLimit(int maxSizeBytes) async {
    final db = await DatabaseHelper.database;
    
    // Calculate current storage size
    final sizeResult = await db.rawQuery('''
      SELECT SUM(LENGTH(d.data)) as total_size
      FROM ${DatabaseHelper.cacheDataTable} d
      INNER JOIN ${DatabaseHelper.cacheMetadataTable} m 
      ON d.key = SUBSTR(m.key, ${_cachePrefix.length + 1})
      WHERE m.key LIKE '$_cachePrefix%'
    ''');
    
    final currentSize = Sqflite.firstIntValue(sizeResult) ?? 0;
    
    if (currentSize <= maxSizeBytes) return;
    
    // Get entries ordered by size (largest first) and last access (oldest first)
    final entries = await db.rawQuery('''
      SELECT m.key, LENGTH(d.data) as size, m.last_updated
      FROM ${DatabaseHelper.cacheMetadataTable} m
      INNER JOIN ${DatabaseHelper.cacheDataTable} d ON SUBSTR(m.key, ${_cachePrefix.length + 1}) = d.key
      WHERE m.key LIKE '$_cachePrefix%'
      ORDER BY LENGTH(d.data) DESC, m.last_updated ASC
    ''');
    
    int sizeToFree = currentSize - maxSizeBytes;
    int freedSize = 0;
    
    for (final entry in entries) {
      if (freedSize >= sizeToFree) break;
      
      final key = entry['key'] as String;
      final entrySize = entry['size'] as int;
      final cacheKey = key.substring(_cachePrefix.length);
      
      await deleteCacheEntry(cacheKey);
      freedSize += entrySize;
    }
  }

  @override
  Future<void> refreshStaleData(String key, Duration maxAge) async {
    final isStale = await isDataStale(key, maxAge);
    if (isStale) {
      // Mark for refresh by updating metadata
      await updateCacheMetadata(key);
    }
  }

  @override
  Future<Map<String, CacheStats>> getCacheStats() async {
    final db = await DatabaseHelper.database;
    
    final entries = await db.rawQuery('''
      SELECT 
        m.key,
        m.last_updated,
        m.expires_at,
        LENGTH(d.data) as size_bytes,
        d.created_at
      FROM ${DatabaseHelper.cacheMetadataTable} m
      LEFT JOIN ${DatabaseHelper.cacheDataTable} d ON SUBSTR(m.key, ${_cachePrefix.length + 1}) = d.key
      WHERE m.key LIKE '$_cachePrefix%'
    ''');
    
    final Map<String, CacheStats> stats = {};
    
    for (final entry in entries) {
      final key = (entry['key'] as String).substring(_cachePrefix.length);
      final lastUpdatedStr = entry['last_updated'] as String;
      final expiresAtStr = entry['expires_at'] as String?;
      final sizeBytes = entry['size_bytes'] as int? ?? 0;
      final createdAtStr = entry['created_at'] as String?;
      
      stats[key] = CacheStats(
        key: key,
        lastUpdated: DateTime.parse(lastUpdatedStr),
        expiresAt: expiresAtStr != null ? DateTime.parse(expiresAtStr) : null,
        sizeBytes: sizeBytes,
        accessCount: 1, // Simplified - would need separate tracking for real access count
        lastAccessed: createdAtStr != null 
            ? DateTime.parse(createdAtStr) 
            : DateTime.parse(lastUpdatedStr),
      );
    }
    
    return stats;
  }

  // Additional utility methods for offline data management
  
  Future<void> performMaintenanceTasks() async {
    // Clean up expired cache entries
    await cleanupExpiredCache();
    
    // Enforce reasonable cache size limits (100 entries max)
    await evictOldestEntries(100);
    
    // Enforce storage limit (10MB max)
    await enforceStorageLimit(10 * 1024 * 1024);
  }

  Future<List<String>> getStaleDataKeys(Duration maxAge) async {
    final db = await DatabaseHelper.database;
    
    final staleEntries = await db.query(
      DatabaseHelper.cacheMetadataTable,
      where: 'key LIKE ? AND last_updated < ?',
      whereArgs: [
        '$_cachePrefix%',
        DateTime.now().subtract(maxAge).toIso8601String(),
      ],
    );
    
    return staleEntries
        .map((entry) => (entry['key'] as String).substring(_cachePrefix.length))
        .toList();
  }

  Future<void> markDataForRefresh(List<String> keys) async {
    for (final key in keys) {
      await updateCacheMetadata(key);
    }
  }
}
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:sqflite/sqflite.dart';
import 'package:reva_mobile_app/services/cache/cache_service.dart';
import 'package:reva_mobile_app/services/cache/database_helper.dart';

// Generate mocks
@GenerateMocks([Database])
import 'cache_service_test.mocks.dart';

void main() {
  group('CacheService Tests', () {
    late CacheServiceImpl cacheService;
    late MockDatabase mockDatabase;

    setUp(() {
      mockDatabase = MockDatabase();
      cacheService = CacheServiceImpl();
    });

    group('CacheStats', () {
      test('should create cache stats with correct properties', () {
        final now = DateTime.now();
        final expiresAt = now.add(const Duration(hours: 1));
        
        final stats = CacheStats(
          key: 'test_key',
          lastUpdated: now,
          expiresAt: expiresAt,
          sizeBytes: 1024,
          accessCount: 5,
          lastAccessed: now,
        );

        expect(stats.key, equals('test_key'));
        expect(stats.lastUpdated, equals(now));
        expect(stats.expiresAt, equals(expiresAt));
        expect(stats.sizeBytes, equals(1024));
        expect(stats.accessCount, equals(5));
        expect(stats.lastAccessed, equals(now));
      });

      test('should correctly identify expired cache', () {
        final now = DateTime.now();
        final pastExpiry = now.subtract(const Duration(hours: 1));
        final futureExpiry = now.add(const Duration(hours: 1));

        final expiredStats = CacheStats(
          key: 'expired',
          lastUpdated: now,
          expiresAt: pastExpiry,
          sizeBytes: 100,
          accessCount: 1,
          lastAccessed: now,
        );

        final validStats = CacheStats(
          key: 'valid',
          lastUpdated: now,
          expiresAt: futureExpiry,
          sizeBytes: 100,
          accessCount: 1,
          lastAccessed: now,
        );

        final noExpiryStats = CacheStats(
          key: 'no_expiry',
          lastUpdated: now,
          expiresAt: null,
          sizeBytes: 100,
          accessCount: 1,
          lastAccessed: now,
        );

        expect(expiredStats.isExpired, isTrue);
        expect(validStats.isExpired, isFalse);
        expect(noExpiryStats.isExpired, isFalse);
      });

      test('should correctly identify stale cache', () {
        final now = DateTime.now();
        final oldUpdate = now.subtract(const Duration(hours: 2));
        final recentUpdate = now.subtract(const Duration(minutes: 30));

        final staleStats = CacheStats(
          key: 'stale',
          lastUpdated: oldUpdate,
          sizeBytes: 100,
          accessCount: 1,
          lastAccessed: now,
        );

        final freshStats = CacheStats(
          key: 'fresh',
          lastUpdated: recentUpdate,
          sizeBytes: 100,
          accessCount: 1,
          lastAccessed: now,
        );

        final maxAge = const Duration(hours: 1);
        expect(staleStats.isStale(maxAge), isTrue);
        expect(freshStats.isStale(maxAge), isFalse);
      });
    });

    group('Cache Data Operations', () {
      test('should cache data successfully', () async {
        // Mock database operations
        when(mockDatabase.insert(
          DatabaseHelper.cacheMetadataTable,
          any,
          conflictAlgorithm: anyNamed('conflictAlgorithm'),
        )).thenAnswer((_) async => 1);

        when(mockDatabase.insert(
          DatabaseHelper.cacheDataTable,
          any,
          conflictAlgorithm: anyNamed('conflictAlgorithm'),
        )).thenAnswer((_) async => 1);

        final testData = [
          {'id': '1', 'name': 'Item 1'},
          {'id': '2', 'name': 'Item 2'},
        ];

        await cacheService.cacheData('test_key', testData);

        verify(mockDatabase.insert(
          DatabaseHelper.cacheMetadataTable,
          any,
          conflictAlgorithm: ConflictAlgorithm.replace,
        )).called(1);

        verify(mockDatabase.insert(
          DatabaseHelper.cacheDataTable,
          any,
          conflictAlgorithm: ConflictAlgorithm.replace,
        )).called(1);
      });

      test('should retrieve cached data successfully', () async {
        final testDataJson = '[{"id":"1","name":"Item 1"},{"id":"2","name":"Item 2"}]';

        when(mockDatabase.query(
          DatabaseHelper.cacheDataTable,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
          limit: anyNamed('limit'),
        )).thenAnswer((_) async => [
          {'key': 'test_key', 'data': testDataJson}
        ]);

        final result = await cacheService.getCachedData<Map<String, dynamic>>('test_key');

        expect(result, isNotNull);
        expect(result, hasLength(2));
        expect(result![0]['id'], equals('1'));
        expect(result[1]['name'], equals('Item 2'));
      });

      test('should return null for non-existent cache key', () async {
        when(mockDatabase.query(
          DatabaseHelper.cacheDataTable,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
          limit: anyNamed('limit'),
        )).thenAnswer((_) async => []);

        final result = await cacheService.getCachedData<Map<String, dynamic>>('non_existent');

        expect(result, isNull);
      });

      test('should handle JSON parsing errors gracefully', () async {
        when(mockDatabase.query(
          DatabaseHelper.cacheDataTable,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
          limit: anyNamed('limit'),
        )).thenAnswer((_) async => [
          {'key': 'test_key', 'data': 'invalid json'}
        ]);

        final result = await cacheService.getCachedData<Map<String, dynamic>>('test_key');

        expect(result, isNull);
      });
    });

    group('Cache Metadata Operations', () {
      test('should check if data is stale correctly', () async {
        final oldTimestamp = DateTime.now().subtract(const Duration(hours: 2));

        when(mockDatabase.query(
          DatabaseHelper.cacheMetadataTable,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
          limit: anyNamed('limit'),
        )).thenAnswer((_) async => [
          {
            'key': 'cache_test_key',
            'last_updated': oldTimestamp.toIso8601String(),
          }
        ]);

        final isStale = await cacheService.isDataStale(
          'test_key',
          const Duration(hours: 1),
        );

        expect(isStale, isTrue);
      });

      test('should return true for non-existent cache metadata', () async {
        when(mockDatabase.query(
          DatabaseHelper.cacheMetadataTable,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
          limit: anyNamed('limit'),
        )).thenAnswer((_) async => []);

        final isStale = await cacheService.isDataStale(
          'non_existent',
          const Duration(hours: 1),
        );

        expect(isStale, isTrue);
      });

      test('should update cache metadata', () async {
        when(mockDatabase.update(
          DatabaseHelper.cacheMetadataTable,
          any,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        )).thenAnswer((_) async => 1);

        final expiresAt = DateTime.now().add(const Duration(hours: 1));

        await cacheService.updateCacheMetadata('test_key', expiresAt: expiresAt);

        verify(mockDatabase.update(
          DatabaseHelper.cacheMetadataTable,
          any,
          where: 'key = ?',
          whereArgs: ['cache_test_key'],
        )).called(1);
      });
    });

    group('Cache Cleanup Operations', () {
      test('should clear all cache', () async {
        when(mockDatabase.delete(DatabaseHelper.cacheMetadataTable))
            .thenAnswer((_) async => 5);
        when(mockDatabase.delete(DatabaseHelper.cacheDataTable))
            .thenAnswer((_) async => 5);

        await cacheService.clearCache();

        verify(mockDatabase.delete(DatabaseHelper.cacheMetadataTable)).called(1);
        verify(mockDatabase.delete(DatabaseHelper.cacheDataTable)).called(1);
      });

      test('should delete specific cache entry', () async {
        when(mockDatabase.delete(
          DatabaseHelper.cacheMetadataTable,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        )).thenAnswer((_) async => 1);

        when(mockDatabase.delete(
          DatabaseHelper.cacheDataTable,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        )).thenAnswer((_) async => 1);

        await cacheService.deleteCacheEntry('test_key');

        verify(mockDatabase.delete(
          DatabaseHelper.cacheMetadataTable,
          where: 'key = ?',
          whereArgs: ['cache_test_key'],
        )).called(1);

        verify(mockDatabase.delete(
          DatabaseHelper.cacheDataTable,
          where: 'key = ?',
          whereArgs: ['test_key'],
        )).called(1);
      });
    });

    group('Cache Eviction Policies', () {
      test('should evict least recently used entries', () async {
        final entries = [
          {
            'key': 'cache_old_key',
            'last_updated': DateTime.now().subtract(const Duration(hours: 3)).toIso8601String(),
            'created_at': DateTime.now().subtract(const Duration(hours: 3)).toIso8601String(),
          },
          {
            'key': 'cache_new_key',
            'last_updated': DateTime.now().subtract(const Duration(hours: 1)).toIso8601String(),
            'created_at': DateTime.now().subtract(const Duration(hours: 1)).toIso8601String(),
          },
        ];

        when(mockDatabase.rawQuery(any)).thenAnswer((_) async => entries);
        when(mockDatabase.delete(
          DatabaseHelper.cacheMetadataTable,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        )).thenAnswer((_) async => 1);
        when(mockDatabase.delete(
          DatabaseHelper.cacheDataTable,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        )).thenAnswer((_) async => 1);

        await cacheService.evictLeastRecentlyUsed(1);

        // Should delete the older entry
        verify(mockDatabase.delete(
          DatabaseHelper.cacheMetadataTable,
          where: 'key = ?',
          whereArgs: ['cache_old_key'],
        )).called(1);
      });

      test('should evict oldest entries', () async {
        final entries = [
          {
            'key': 'cache_oldest',
            'last_updated': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
          },
          {
            'key': 'cache_newer',
            'last_updated': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
          },
        ];

        when(mockDatabase.query(
          DatabaseHelper.cacheMetadataTable,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
          orderBy: anyNamed('orderBy'),
        )).thenAnswer((_) async => entries);

        when(mockDatabase.delete(
          DatabaseHelper.cacheMetadataTable,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        )).thenAnswer((_) async => 1);
        when(mockDatabase.delete(
          DatabaseHelper.cacheDataTable,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        )).thenAnswer((_) async => 1);

        await cacheService.evictOldestEntries(1);

        verify(mockDatabase.delete(
          DatabaseHelper.cacheMetadataTable,
          where: 'key = ?',
          whereArgs: ['cache_oldest'],
        )).called(1);
      });

      test('should get cache size', () async {
        when(mockDatabase.rawQuery(any))
            .thenAnswer((_) async => [{'count': 42}]);

        final size = await cacheService.getCacheSize();

        expect(size, equals(42));
      });

      test('should enforce storage limit', () async {
        // Mock current size query
        when(mockDatabase.rawQuery(any))
            .thenAnswer((_) async => [{'total_size': 2000000}]); // 2MB

        // Mock entries query for eviction
        final entries = [
          {
            'key': 'cache_large_entry',
            'size': 1000000,
            'last_updated': DateTime.now().subtract(const Duration(hours: 1)).toIso8601String(),
          },
        ];

        when(mockDatabase.rawQuery(any))
            .thenAnswer((_) async => entries);

        when(mockDatabase.delete(
          DatabaseHelper.cacheMetadataTable,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        )).thenAnswer((_) async => 1);
        when(mockDatabase.delete(
          DatabaseHelper.cacheDataTable,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        )).thenAnswer((_) async => 1);

        await cacheService.enforceStorageLimit(1500000); // 1.5MB limit

        // Should evict the large entry
        verify(mockDatabase.delete(
          DatabaseHelper.cacheMetadataTable,
          where: 'key = ?',
          whereArgs: ['cache_large_entry'],
        )).called(1);
      });
    });

    group('Cache Statistics', () {
      test('should get cache statistics', () async {
        final entries = [
          {
            'key': 'cache_test_key',
            'last_updated': DateTime.now().toIso8601String(),
            'expires_at': DateTime.now().add(const Duration(hours: 1)).toIso8601String(),
            'size_bytes': 1024,
            'created_at': DateTime.now().toIso8601String(),
          },
        ];

        when(mockDatabase.rawQuery(any)).thenAnswer((_) async => entries);

        final stats = await cacheService.getCacheStats();

        expect(stats, hasLength(1));
        expect(stats['test_key'], isNotNull);
        expect(stats['test_key']!.sizeBytes, equals(1024));
      });

      test('should handle null values in cache statistics', () async {
        final entries = [
          {
            'key': 'cache_test_key',
            'last_updated': DateTime.now().toIso8601String(),
            'expires_at': null,
            'size_bytes': null,
            'created_at': null,
          },
        ];

        when(mockDatabase.rawQuery(any)).thenAnswer((_) async => entries);

        final stats = await cacheService.getCacheStats();

        expect(stats, hasLength(1));
        expect(stats['test_key'], isNotNull);
        expect(stats['test_key']!.sizeBytes, equals(0));
        expect(stats['test_key']!.expiresAt, isNull);
      });
    });

    group('Maintenance Operations', () {
      test('should perform maintenance tasks', () async {
        // Mock expired entries cleanup
        when(mockDatabase.query(
          DatabaseHelper.cacheMetadataTable,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        )).thenAnswer((_) async => []);

        // Mock eviction operations
        when(mockDatabase.query(
          DatabaseHelper.cacheMetadataTable,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
          orderBy: anyNamed('orderBy'),
        )).thenAnswer((_) async => []);

        // Mock storage size check
        when(mockDatabase.rawQuery(any))
            .thenAnswer((_) async => [{'total_size': 1000}]);

        await cacheService.performMaintenanceTasks();

        // Should complete without errors
        expect(true, isTrue);
      });

      test('should get stale data keys', () async {
        final staleEntries = [
          {
            'key': 'cache_stale_key1',
            'last_updated': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
          },
          {
            'key': 'cache_stale_key2',
            'last_updated': DateTime.now().subtract(const Duration(hours: 3)).toIso8601String(),
          },
        ];

        when(mockDatabase.query(
          DatabaseHelper.cacheMetadataTable,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        )).thenAnswer((_) async => staleEntries);

        final staleKeys = await cacheService.getStaleDataKeys(
          const Duration(hours: 1),
        );

        expect(staleKeys, hasLength(2));
        expect(staleKeys, contains('stale_key1'));
        expect(staleKeys, contains('stale_key2'));
      });

      test('should mark data for refresh', () async {
        when(mockDatabase.update(
          DatabaseHelper.cacheMetadataTable,
          any,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        )).thenAnswer((_) async => 1);

        await cacheService.markDataForRefresh(['key1', 'key2']);

        verify(mockDatabase.update(
          DatabaseHelper.cacheMetadataTable,
          any,
          where: 'key = ?',
          whereArgs: ['cache_key1'],
        )).called(1);

        verify(mockDatabase.update(
          DatabaseHelper.cacheMetadataTable,
          any,
          where: 'key = ?',
          whereArgs: ['cache_key2'],
        )).called(1);
      });
    });

    group('Error Handling', () {
      test('should handle database errors gracefully', () async {
        when(mockDatabase.insert(any, any, conflictAlgorithm: anyNamed('conflictAlgorithm')))
            .thenThrow(DatabaseException('Database error'));

        expect(
          () => cacheService.cacheData('test_key', [{'test': 'data'}]),
          throwsA(isA<DatabaseException>()),
        );
      });

      test('should handle invalid data types', () async {
        // Test with data that doesn't have toJson method
        expect(
          () => cacheService.cacheData('test_key', ['string_data']),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('Utility Methods', () {
      test('should get cache keys', () async {
        final entries = [
          {'key': 'cache_key1'},
          {'key': 'cache_key2'},
          {'key': 'other_key'}, // Should be filtered out
        ];

        when(mockDatabase.query(
          DatabaseHelper.cacheMetadataTable,
          columns: anyNamed('columns'),
        )).thenAnswer((_) async => entries);

        final keys = await cacheService.getCacheKeys();

        expect(keys, hasLength(2));
        expect(keys, contains('key1'));
        expect(keys, contains('key2'));
        expect(keys, isNot(contains('other_key')));
      });

      test('should get last updated timestamp', () async {
        final timestamp = DateTime.now();
        when(mockDatabase.query(
          DatabaseHelper.cacheMetadataTable,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
          limit: anyNamed('limit'),
        )).thenAnswer((_) async => [
          {
            'last_updated': timestamp.toIso8601String(),
          }
        ]);

        final lastUpdated = await cacheService.getLastUpdated('test_key');

        expect(lastUpdated, equals(timestamp));
      });

      test('should return null for non-existent last updated', () async {
        when(mockDatabase.query(
          DatabaseHelper.cacheMetadataTable,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
          limit: anyNamed('limit'),
        )).thenAnswer((_) async => []);

        final lastUpdated = await cacheService.getLastUpdated('non_existent');

        expect(lastUpdated, isNull);
      });

      test('should check if cache has expired', () async {
        final expiredTime = DateTime.now().subtract(const Duration(hours: 1));
        when(mockDatabase.query(
          DatabaseHelper.cacheMetadataTable,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
          limit: anyNamed('limit'),
        )).thenAnswer((_) async => [
          {
            'expires_at': expiredTime.toIso8601String(),
          }
        ]);

        final hasExpired = await cacheService.hasExpired('test_key');

        expect(hasExpired, isTrue);
      });

      test('should return false for cache without expiry', () async {
        when(mockDatabase.query(
          DatabaseHelper.cacheMetadataTable,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
          limit: anyNamed('limit'),
        )).thenAnswer((_) async => [
          {
            'expires_at': null,
          }
        ]);

        final hasExpired = await cacheService.hasExpired('test_key');

        expect(hasExpired, isFalse);
      });
    });
  });
}
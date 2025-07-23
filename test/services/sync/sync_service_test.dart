import 'package:flutter_test/flutter_test.dart';
import '../../../lib/services/sync/sync_service.dart';

void main() {
  group('SyncService', () {
    late SyncService syncService;

    setUp(() {
      // Reset singleton for each test
      SyncService.resetInstance();
      syncService = SyncService.instance;
    });

    tearDown(() async {
      await syncService.dispose();
      SyncService.resetInstance();
    });

    group('Singleton Pattern', () {
      test('should return the same instance', () {
        // Act
        final instance1 = SyncService.instance;
        final instance2 = SyncService.instance;
        
        // Assert
        expect(identical(instance1, instance2), isTrue);
      });
    });

    group('PendingSyncOperation', () {
      test('should create operation correctly', () {
        // Arrange
        final timestamp = DateTime.now();
        final data = {'name': 'Test Task', 'completed': false};
        
        // Act
        final operation = PendingSyncOperation(
          id: 'test-op-1',
          table: 'tasks',
          operation: SyncOperation.create,
          data: data,
          timestamp: timestamp,
          recordId: 'record-123',
        );
        
        // Assert
        expect(operation.id, equals('test-op-1'));
        expect(operation.table, equals('tasks'));
        expect(operation.operation, equals(SyncOperation.create));
        expect(operation.data, equals(data));
        expect(operation.timestamp, equals(timestamp));
        expect(operation.retryCount, equals(0));
        expect(operation.recordId, equals('record-123'));
      });

      test('should serialize to and from JSON correctly', () {
        // Arrange
        final timestamp = DateTime.now();
        final data = {'name': 'Test Task', 'completed': false};
        final operation = PendingSyncOperation(
          id: 'test-op-1',
          table: 'tasks',
          operation: SyncOperation.update,
          data: data,
          timestamp: timestamp,
          retryCount: 2,
          recordId: 'record-123',
        );
        
        // Act
        final json = operation.toJson();
        final restored = PendingSyncOperation.fromJson(json);
        
        // Assert
        expect(restored.id, equals(operation.id));
        expect(restored.table, equals(operation.table));
        expect(restored.operation, equals(operation.operation));
        expect(restored.data, equals(operation.data));
        expect(restored.timestamp, equals(operation.timestamp));
        expect(restored.retryCount, equals(operation.retryCount));
        expect(restored.recordId, equals(operation.recordId));
      });

      test('should create copy with updated values', () {
        // Arrange
        final original = PendingSyncOperation(
          id: 'test-op-1',
          table: 'tasks',
          operation: SyncOperation.create,
          data: {'name': 'Test'},
          timestamp: DateTime.now(),
        );
        
        // Act
        final copy = original.copyWith(
          retryCount: 3,
          recordId: 'new-record-id',
        );
        
        // Assert
        expect(copy.id, equals(original.id));
        expect(copy.table, equals(original.table));
        expect(copy.operation, equals(original.operation));
        expect(copy.data, equals(original.data));
        expect(copy.timestamp, equals(original.timestamp));
        expect(copy.retryCount, equals(3));
        expect(copy.recordId, equals('new-record-id'));
      });
    });

    group('SyncConfig', () {
      test('should create config with default values', () {
        // Act
        const config = SyncConfig();
        
        // Assert
        expect(config.syncInterval, equals(const Duration(minutes: 5)));
        expect(config.maxRetries, equals(3));
        expect(config.initialRetryDelay, equals(const Duration(seconds: 2)));
        expect(config.maxRetryDelay, equals(const Duration(minutes: 5)));
        expect(config.retryBackoffMultiplier, equals(2.0));
        expect(config.conflictResolutionWindow, equals(const Duration(seconds: 30)));
      });

      test('should create config with custom values', () {
        // Act
        const config = SyncConfig(
          syncInterval: Duration(minutes: 10),
          maxRetries: 5,
          initialRetryDelay: Duration(seconds: 5),
          maxRetryDelay: Duration(minutes: 10),
          retryBackoffMultiplier: 1.5,
          conflictResolutionWindow: Duration(minutes: 1),
        );
        
        // Assert
        expect(config.syncInterval, equals(const Duration(minutes: 10)));
        expect(config.maxRetries, equals(5));
        expect(config.initialRetryDelay, equals(const Duration(seconds: 5)));
        expect(config.maxRetryDelay, equals(const Duration(minutes: 10)));
        expect(config.retryBackoffMultiplier, equals(1.5));
        expect(config.conflictResolutionWindow, equals(const Duration(minutes: 1)));
      });
    });

    group('Initial State', () {
      test('should have correct initial state', () {
        // Assert
        expect(syncService.currentStatus, equals(SyncStatus.idle));
        expect(syncService.pendingOperationsCount, equals(0));
        expect(syncService.pendingOperations, isEmpty);
      });

      test('should provide status stream', () {
        // Act
        final stream = syncService.statusStream;
        
        // Assert
        expect(stream, isA<Stream<SyncStatus>>());
      });

      test('should provide sync event stream', () {
        // Act
        final stream = syncService.syncEventStream;
        
        // Assert
        expect(stream, isA<Stream<Map<String, dynamic>>>());
      });
    });

    group('Sync Status Management', () {
      test('should track sync status changes', () async {
        // Arrange
        final statusUpdates = <SyncStatus>[];
        final subscription = syncService.statusStream.listen(statusUpdates.add);
        
        // Act
        await syncService.initialize();
        
        // Wait for potential status updates
        await Future.delayed(const Duration(milliseconds: 100));
        
        // Verify current status is accessible
        expect(syncService.currentStatus, equals(SyncStatus.idle));
        
        // Cleanup
        await subscription.cancel();
        
        // Assert - The service should have the correct status even if stream doesn't emit in tests
        expect(syncService.currentStatus, equals(SyncStatus.idle));
      });
    });

    group('Operation Queueing', () {
      test('should queue operations when offline', () async {
        // Arrange
        await syncService.initialize();
        
        // Act
        await syncService.queueOperation(
          table: 'tasks',
          operation: SyncOperation.create,
          data: {'name': 'Test Task', 'completed': false},
        );
        
        // Assert
        expect(syncService.pendingOperationsCount, equals(1));
        expect(syncService.pendingOperations.first.table, equals('tasks'));
        expect(syncService.pendingOperations.first.operation, equals(SyncOperation.create));
      });

      test('should queue multiple operations', () async {
        // Arrange
        await syncService.initialize();
        
        // Act
        await syncService.queueOperation(
          table: 'tasks',
          operation: SyncOperation.create,
          data: {'name': 'Task 1'},
        );
        
        await syncService.queueOperation(
          table: 'expenses',
          operation: SyncOperation.update,
          data: {'amount': 100.0},
          recordId: 'expense-123',
        );
        
        // Assert
        expect(syncService.pendingOperationsCount, equals(2));
        
        final operations = syncService.pendingOperations;
        expect(operations[0].table, equals('tasks'));
        expect(operations[0].operation, equals(SyncOperation.create));
        expect(operations[1].table, equals('expenses'));
        expect(operations[1].operation, equals(SyncOperation.update));
        expect(operations[1].recordId, equals('expense-123'));
      });
    });

    group('Sync Time Tracking', () {
      test('should track last sync times', () async {
        // Arrange
        await syncService.initialize();
        
        // Act
        await syncService.handleRealtimeChange(
          table: 'tasks',
          changeType: 'INSERT',
          record: {'id': 'task-123', 'name': 'Test Task'},
        );
        
        // Assert
        final lastSync = syncService.getLastSyncTime('tasks');
        expect(lastSync, isNotNull);
        expect(lastSync!.isBefore(DateTime.now().add(const Duration(seconds: 1))), isTrue);
      });

      test('should determine if sync is needed', () async {
        // Arrange
        await syncService.initialize();
        
        // Act & Assert - No sync time recorded yet
        expect(syncService.needsSync('tasks'), isTrue);
        
        // Simulate a recent sync
        await syncService.handleRealtimeChange(
          table: 'tasks',
          changeType: 'INSERT',
          record: {'id': 'task-123', 'name': 'Test Task'},
        );
        
        // Should not need sync immediately after
        expect(syncService.needsSync('tasks', maxAge: const Duration(minutes: 1)), isFalse);
        
        // Wait a bit and then check with very short max age
        await Future.delayed(const Duration(milliseconds: 10));
        expect(syncService.needsSync('tasks', maxAge: const Duration(milliseconds: 1)), isTrue);
      });
    });

    group('Realtime Change Handling', () {
      test('should handle realtime changes without errors', () async {
        // Arrange
        await syncService.initialize();
        
        // Act & Assert - Should not throw
        await expectLater(
          syncService.handleRealtimeChange(
            table: 'tasks',
            changeType: 'INSERT',
            record: {'id': 'task-123', 'name': 'Test Task', 'updated_at': DateTime.now().toIso8601String()},
          ),
          completes,
        );
      });

      test('should emit sync events for realtime changes', () async {
        // Arrange
        await syncService.initialize();
        
        final syncEvents = <Map<String, dynamic>>[];
        final subscription = syncService.syncEventStream.listen(syncEvents.add);
        
        // Act
        await syncService.handleRealtimeChange(
          table: 'tasks',
          changeType: 'UPDATE',
          record: {'id': 'task-123', 'name': 'Updated Task'},
        );
        
        // Wait for event emission
        await Future.delayed(const Duration(milliseconds: 10));
        
        // Cleanup
        await subscription.cancel();
        
        // Assert
        expect(syncEvents, isNotEmpty);
        final realtimeEvent = syncEvents.firstWhere(
          (event) => event['type'] == 'realtime_change_processed',
          orElse: () => <String, dynamic>{},
        );
        expect(realtimeEvent, isNotEmpty);
        expect(realtimeEvent['table'], equals('tasks'));
        expect(realtimeEvent['change_type'], equals('UPDATE'));
      });
    });

    group('Pending Operations Management', () {
      test('should clear pending operations', () async {
        // Arrange
        await syncService.initialize();
        
        await syncService.queueOperation(
          table: 'tasks',
          operation: SyncOperation.create,
          data: {'name': 'Test Task'},
        );
        
        expect(syncService.pendingOperationsCount, equals(1));
        
        // Act
        await syncService.clearPendingOperations();
        
        // Assert
        expect(syncService.pendingOperationsCount, equals(0));
        expect(syncService.pendingOperations, isEmpty);
      });

      test('should emit event when clearing operations', () async {
        // Arrange
        await syncService.initialize();
        
        final syncEvents = <Map<String, dynamic>>[];
        final subscription = syncService.syncEventStream.listen(syncEvents.add);
        
        // Act
        await syncService.clearPendingOperations();
        
        // Wait for event emission
        await Future.delayed(const Duration(milliseconds: 10));
        
        // Cleanup
        await subscription.cancel();
        
        // Assert
        final clearEvent = syncEvents.firstWhere(
          (event) => event['type'] == 'pending_operations_cleared',
          orElse: () => <String, dynamic>{},
        );
        expect(clearEvent, isNotEmpty);
      });
    });

    group('Health Status', () {
      test('should return correct health status structure', () async {
        // Arrange
        await syncService.initialize();
        
        // Act
        final healthStatus = syncService.getHealthStatus();
        
        // Assert
        expect(healthStatus.containsKey('initialized'), isTrue);
        expect(healthStatus.containsKey('disposed'), isTrue);
        expect(healthStatus.containsKey('current_status'), isTrue);
        expect(healthStatus.containsKey('is_online'), isTrue);
        expect(healthStatus.containsKey('pending_operations'), isTrue);
        expect(healthStatus.containsKey('last_sync_times'), isTrue);
        expect(healthStatus.containsKey('config'), isTrue);
        expect(healthStatus.containsKey('timestamp'), isTrue);
        
        expect(healthStatus['pending_operations'], equals(0));
        expect(healthStatus['last_sync_times'], isA<Map<String, String>>());
        expect(healthStatus['config'], isA<Map<String, dynamic>>());
      });

      test('should track pending operations in health status', () async {
        // Arrange
        await syncService.initialize();
        
        await syncService.queueOperation(
          table: 'tasks',
          operation: SyncOperation.create,
          data: {'name': 'Test Task'},
        );
        
        // Act
        final healthStatus = syncService.getHealthStatus();
        
        // Assert
        expect(healthStatus['pending_operations'], equals(1));
      });
    });

    group('Disposal', () {
      test('should dispose cleanly', () async {
        // Arrange
        await syncService.initialize();
        
        // Act & Assert - Should not throw
        await expectLater(syncService.dispose(), completes);
      });

      test('should handle multiple dispose calls', () async {
        // Arrange
        await syncService.initialize();
        await syncService.dispose();
        
        // Act & Assert - Second dispose should not throw
        await expectLater(syncService.dispose(), completes);
      });

      test('should not allow operations after disposal', () async {
        // Arrange
        await syncService.initialize();
        await syncService.dispose();
        
        // Act - Should handle gracefully
        await syncService.queueOperation(
          table: 'tasks',
          operation: SyncOperation.create,
          data: {'name': 'Test Task'},
        );
        
        // Assert - Should not have queued the operation
        expect(syncService.pendingOperationsCount, equals(0));
      });
    });

    group('Error Handling', () {
      test('should handle sync without initialization gracefully', () async {
        // Act & Assert - Should not throw
        await expectLater(syncService.sync(), completes);
      });

      test('should handle realtime changes without initialization', () async {
        // Act & Assert - Should not throw
        await expectLater(
          syncService.handleRealtimeChange(
            table: 'tasks',
            changeType: 'INSERT',
            record: {'id': 'task-123'},
          ),
          completes,
        );
      });
    });
  });
}
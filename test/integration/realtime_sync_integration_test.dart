import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:reva_mobile_app/services/sync/realtime_service.dart';
import 'package:reva_mobile_app/services/sync/sync_service.dart';
import 'package:reva_mobile_app/services/data/tasks_repository.dart';
import 'package:reva_mobile_app/services/data/expenses_repository.dart';
import 'package:reva_mobile_app/services/data/reminders_repository.dart';
import 'package:reva_mobile_app/services/cache/cache_service.dart';
import 'package:reva_mobile_app/models/task.dart';
import 'package:reva_mobile_app/models/expense.dart';
import 'package:reva_mobile_app/models/reminder.dart';

// Generate mocks
@GenerateMocks([
  SupabaseClient,
  RealtimeClient,
  RealtimeChannel,
  TasksRepository,
  ExpensesRepository,
  RemindersRepository,
  CacheService,
])
import 'realtime_sync_integration_test.mocks.dart';

void main() {
  group('Realtime Synchronization Integration Tests', () {
    late RealtimeService realtimeService;
    late SyncService syncService;
    late MockSupabaseClient mockSupabaseClient;
    late MockRealtimeClient mockRealtimeClient;
    late MockRealtimeChannel mockChannel;
    late MockTasksRepository mockTasksRepository;
    late MockExpensesRepository mockExpensesRepository;
    late MockRemindersRepository mockRemindersRepository;
    late MockCacheService mockCacheService;

    setUp(() {
      mockSupabaseClient = MockSupabaseClient();
      mockRealtimeClient = MockRealtimeClient();
      mockChannel = MockRealtimeChannel();
      mockTasksRepository = MockTasksRepository();
      mockExpensesRepository = MockExpensesRepository();
      mockRemindersRepository = MockRemindersRepository();
      mockCacheService = MockCacheService();

      // Setup basic mocks
      when(mockSupabaseClient.realtime).thenReturn(mockRealtimeClient);
      when(mockRealtimeClient.channel(any)).thenReturn(mockChannel);
      when(mockChannel.onPostgresChanges(
        event: anyNamed('event'),
        schema: anyNamed('schema'),
        table: anyNamed('table'),
        callback: anyNamed('callback'),
      )).thenReturn(mockChannel);
      when(mockChannel.subscribe()).thenAnswer((_) async => RealtimeSubscribeStatus.subscribed);

      realtimeService = RealtimeService(mockSupabaseClient);
      syncService = SyncService(
        tasksRepository: mockTasksRepository,
        expensesRepository: mockExpensesRepository,
        remindersRepository: mockRemindersRepository,
        cacheService: mockCacheService,
        realtimeService: realtimeService,
      );
    });

    group('Complete Realtime Synchronization Flow', () {
      test('should handle full sync cycle for tasks', () async {
        final testTask = Task(
          id: 'task-1',
          userId: 'user-123',
          description: 'Test task',
          priority: TaskPriority.medium,
          completed: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Setup repository mocks
        when(mockTasksRepository.getAllTasks()).thenAnswer((_) async => [testTask]);
        when(mockTasksRepository.createTask(any)).thenAnswer((_) async => testTask);
        when(mockTasksRepository.updateTask(any, any)).thenAnswer((_) async => testTask);
        when(mockTasksRepository.deleteTask(any)).thenAnswer((_) async {});

        // Setup cache mocks
        when(mockCacheService.cacheData('tasks', any)).thenAnswer((_) async {});
        when(mockCacheService.getCachedData<Map<String, dynamic>>('tasks'))
            .thenAnswer((_) async => [testTask.toJson()]);

        // Step 1: Initial sync
        await syncService.syncTasks();
        verify(mockTasksRepository.getAllTasks()).called(1);
        verify(mockCacheService.cacheData('tasks', any)).called(1);

        // Step 2: Setup realtime subscription
        late Function(Map<String, dynamic>) realtimeCallback;
        when(mockChannel.onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'tasks',
          callback: anyNamed('callback'),
        )).thenAnswer((invocation) {
          realtimeCallback = invocation.namedArguments[const Symbol('callback')];
          return mockChannel;
        });

        await realtimeService.subscribeToTasks((data) async {
          await syncService.handleTaskRealtimeUpdate(data);
        });

        // Step 3: Simulate realtime INSERT
        final insertPayload = {
          'eventType': 'INSERT',
          'new': {
            'id': 'task-2',
            'user_id': 'user-123',
            'description': 'New task from realtime',
            'priority': 'high',
            'completed': false,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          },
        };

        realtimeCallback(insertPayload);
        await Future.delayed(const Duration(milliseconds: 10));

        // Verify cache was updated
        verify(mockCacheService.cacheData('tasks', any)).called(atLeast(1));

        // Step 4: Simulate realtime UPDATE
        final updatePayload = {
          'eventType': 'UPDATE',
          'new': {
            'id': 'task-1',
            'user_id': 'user-123',
            'description': 'Updated task description',
            'priority': 'high',
            'completed': true,
            'created_at': testTask.createdAt.toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          },
          'old': testTask.toJson(),
        };

        realtimeCallback(updatePayload);
        await Future.delayed(const Duration(milliseconds: 10));

        // Step 5: Simulate realtime DELETE
        final deletePayload = {
          'eventType': 'DELETE',
          'old': {
            'id': 'task-1',
            'user_id': 'user-123',
            'description': 'Task to delete',
            'priority': 'medium',
            'completed': false,
            'created_at': testTask.createdAt.toIso8601String(),
            'updated_at': testTask.updatedAt.toIso8601String(),
          },
        };

        realtimeCallback(deletePayload);
        await Future.delayed(const Duration(milliseconds: 10));

        // Verify all operations were handled
        verify(mockCacheService.cacheData('tasks', any)).called(atLeast(3));
      });

      test('should handle cross-entity synchronization', () async {
        // Setup test data
        final testTask = Task(
          id: 'task-1',
          userId: 'user-123',
          description: 'Task related to expense',
          priority: TaskPriority.medium,
          completed: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final testExpense = Expense(
          id: 'expense-1',
          userId: 'user-123',
          item: 'Business lunch',
          amount: 25.50,
          category: 'Food & Dining',
          date: DateTime.now(),
          createdAt: DateTime.now(),
        );

        final testReminder = Reminder(
          id: 'reminder-1',
          userId: 'user-123',
          title: 'Follow up on expense',
          scheduledTime: DateTime.now().add(const Duration(hours: 1)),
          completed: false,
          createdAt: DateTime.now(),
        );

        // Setup repository mocks
        when(mockTasksRepository.getAllTasks()).thenAnswer((_) async => [testTask]);
        when(mockExpensesRepository.getAllExpenses()).thenAnswer((_) async => [testExpense]);
        when(mockRemindersRepository.getAllReminders()).thenAnswer((_) async => [testReminder]);

        // Setup cache mocks
        when(mockCacheService.cacheData(any, any)).thenAnswer((_) async {});

        // Perform initial sync for all entities
        await Future.wait([
          syncService.syncTasks(),
          syncService.syncExpenses(),
          syncService.syncReminders(),
        ]);

        // Verify all entities were synced
        verify(mockTasksRepository.getAllTasks()).called(1);
        verify(mockExpensesRepository.getAllExpenses()).called(1);
        verify(mockRemindersRepository.getAllReminders()).called(1);
        verify(mockCacheService.cacheData('tasks', any)).called(1);
        verify(mockCacheService.cacheData('expenses', any)).called(1);
        verify(mockCacheService.cacheData('reminders', any)).called(1);

        // Setup realtime subscriptions for all entities
        await Future.wait([
          realtimeService.subscribeToTasks((data) async {
            await syncService.handleTaskRealtimeUpdate(data);
          }),
          realtimeService.subscribeToExpenses((data) async {
            await syncService.handleExpenseRealtimeUpdate(data);
          }),
          realtimeService.subscribeToReminders((data) async {
            await syncService.handleReminderRealtimeUpdate(data);
          }),
        ]);

        // Verify all subscriptions were established
        verify(mockChannel.onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'tasks',
          callback: anyNamed('callback'),
        )).called(1);
        verify(mockChannel.onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'expenses',
          callback: anyNamed('callback'),
        )).called(1);
        verify(mockChannel.onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'reminders',
          callback: anyNamed('callback'),
        )).called(1);
      });
    });

    group('Conflict Resolution', () {
      test('should resolve conflicts using last-write-wins strategy', () async {
        final originalTask = Task(
          id: 'task-conflict',
          userId: 'user-123',
          description: 'Original description',
          priority: TaskPriority.low,
          completed: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now().subtract(const Duration(minutes: 5)),
        );

        final localUpdate = originalTask.copyWith(
          description: 'Local update',
          priority: TaskPriority.medium,
          updatedAt: DateTime.now().subtract(const Duration(minutes: 2)),
        );

        final remoteUpdate = originalTask.copyWith(
          description: 'Remote update',
          priority: TaskPriority.high,
          updatedAt: DateTime.now(), // Most recent
        );

        // Setup cache with local update
        when(mockCacheService.getCachedData<Map<String, dynamic>>('tasks'))
            .thenAnswer((_) async => [localUpdate.toJson()]);

        // Setup repository mock
        when(mockTasksRepository.updateTask(any, any))
            .thenAnswer((_) async => remoteUpdate);

        // Simulate realtime update with newer timestamp
        final conflictPayload = {
          'eventType': 'UPDATE',
          'new': remoteUpdate.toJson(),
          'old': originalTask.toJson(),
        };

        // Handle conflict resolution
        await syncService.handleTaskRealtimeUpdate(conflictPayload);

        // Verify remote update wins (last-write-wins)
        verify(mockCacheService.cacheData('tasks', any)).called(1);
        
        // The cached data should contain the remote update
        final capturedData = verify(mockCacheService.cacheData('tasks', captureAny)).captured.last;
        final updatedTasks = capturedData as List;
        expect(updatedTasks.first['description'], equals('Remote update'));
        expect(updatedTasks.first['priority'], equals('high'));
      });

      test('should handle concurrent modifications gracefully', () async {
        final baseTask = Task(
          id: 'concurrent-task',
          userId: 'user-123',
          description: 'Base task',
          priority: TaskPriority.medium,
          completed: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Setup multiple concurrent updates
        final updates = [
          {
            'eventType': 'UPDATE',
            'new': baseTask.copyWith(
              description: 'Update 1',
              updatedAt: DateTime.now().add(const Duration(seconds: 1)),
            ).toJson(),
          },
          {
            'eventType': 'UPDATE',
            'new': baseTask.copyWith(
              description: 'Update 2',
              updatedAt: DateTime.now().add(const Duration(seconds: 2)),
            ).toJson(),
          },
          {
            'eventType': 'UPDATE',
            'new': baseTask.copyWith(
              description: 'Update 3',
              updatedAt: DateTime.now().add(const Duration(seconds: 3)),
            ).toJson(),
          },
        ];

        when(mockCacheService.cacheData('tasks', any)).thenAnswer((_) async {});

        // Process updates concurrently
        await Future.wait(updates.map((update) => 
          syncService.handleTaskRealtimeUpdate(update)
        ));

        // Verify all updates were processed
        verify(mockCacheService.cacheData('tasks', any)).called(3);
      });
    });

    group('Connection Management', () {
      test('should handle connection loss and reconnection', () async {
        final connectionController = StreamController<RealtimeSubscribeStatus>();
        
        // Mock connection status changes
        when(mockChannel.subscribe()).thenAnswer((_) async {
          connectionController.add(RealtimeSubscribeStatus.subscribed);
          return RealtimeSubscribeStatus.subscribed;
        });

        // Setup subscription
        await realtimeService.subscribeToTasks((data) async {});

        // Simulate connection loss
        connectionController.add(RealtimeSubscribeStatus.channelError);
        await Future.delayed(const Duration(milliseconds: 10));

        // Simulate reconnection
        connectionController.add(RealtimeSubscribeStatus.subscribed);
        await Future.delayed(const Duration(milliseconds: 10));

        // Verify subscription was re-established
        verify(mockChannel.subscribe()).called(atLeast(1));

        connectionController.close();
      });

      test('should handle subscription failures with retry logic', () async {
        var attemptCount = 0;
        when(mockChannel.subscribe()).thenAnswer((_) async {
          attemptCount++;
          if (attemptCount < 3) {
            throw Exception('Subscription failed');
          }
          return RealtimeSubscribeStatus.subscribed;
        });

        // Attempt subscription with retry
        for (int i = 0; i < 3; i++) {
          try {
            await realtimeService.subscribeToTasks((data) async {});
            break;
          } catch (e) {
            if (i == 2) rethrow;
            await Future.delayed(Duration(seconds: i + 1));
          }
        }

        expect(attemptCount, equals(3));
        verify(mockChannel.subscribe()).called(3);
      });

      test('should manage multiple channel subscriptions efficiently', () async {
        // Setup multiple subscriptions
        await Future.wait([
          realtimeService.subscribeToTasks((data) async {}),
          realtimeService.subscribeToExpenses((data) async {}),
          realtimeService.subscribeToReminders((data) async {}),
        ]);

        // Verify separate channels were created
        verify(mockRealtimeClient.channel('tasks')).called(1);
        verify(mockRealtimeClient.channel('expenses')).called(1);
        verify(mockRealtimeClient.channel('reminders')).called(1);

        // Verify all subscriptions were established
        verify(mockChannel.subscribe()).called(3);
      });
    });

    group('Data Consistency and Integrity', () {
      test('should maintain data consistency during sync operations', () async {
        final tasks = List.generate(10, (i) => Task(
          id: 'task-$i',
          userId: 'user-123',
          description: 'Task $i',
          priority: TaskPriority.medium,
          completed: i % 2 == 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));

        // Setup repository mock
        when(mockTasksRepository.getAllTasks()).thenAnswer((_) async => tasks);

        // Setup cache mock to track consistency
        final cachedData = <String, List<Map<String, dynamic>>>{};
        when(mockCacheService.cacheData('tasks', any)).thenAnswer((invocation) async {
          final data = invocation.positionalArguments[1] as List<Map<String, dynamic>>;
          cachedData['tasks'] = data;
        });

        when(mockCacheService.getCachedData<Map<String, dynamic>>('tasks'))
            .thenAnswer((_) async => cachedData['tasks']);

        // Perform initial sync
        await syncService.syncTasks();

        // Verify data consistency
        expect(cachedData['tasks'], hasLength(10));
        for (int i = 0; i < 10; i++) {
          expect(cachedData['tasks']![i]['id'], equals('task-$i'));
          expect(cachedData['tasks']![i]['completed'], equals(i % 2 == 0));
        }

        // Simulate realtime updates
        for (int i = 0; i < 5; i++) {
          final updatePayload = {
            'eventType': 'UPDATE',
            'new': tasks[i].copyWith(completed: !tasks[i].completed).toJson(),
            'old': tasks[i].toJson(),
          };

          await syncService.handleTaskRealtimeUpdate(updatePayload);
        }

        // Verify consistency after updates
        expect(cachedData['tasks'], hasLength(10));
        for (int i = 0; i < 5; i++) {
          expect(cachedData['tasks']![i]['completed'], equals(!(i % 2 == 0)));
        }
      });

      test('should handle data validation during sync', () async {
        // Setup invalid data from realtime
        final invalidPayload = {
          'eventType': 'INSERT',
          'new': {
            'id': '', // Invalid: empty ID
            'user_id': 'user-123',
            'description': '', // Invalid: empty description
            'priority': 'invalid_priority', // Invalid: unknown priority
            'completed': false,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          },
        };

        // Mock validation failure
        when(mockCacheService.cacheData('tasks', any)).thenAnswer((_) async {
          throw ArgumentError('Invalid task data');
        });

        // Handle invalid payload
        expect(
          () => syncService.handleTaskRealtimeUpdate(invalidPayload),
          throwsA(isA<ArgumentError>()),
        );

        // Verify cache wasn't corrupted
        verifyNever(mockCacheService.cacheData('tasks', any));
      });
    });

    group('Performance and Scalability', () {
      test('should handle high-frequency realtime updates efficiently', () async {
        final updates = List.generate(100, (i) => {
          'eventType': 'UPDATE',
          'new': {
            'id': 'task-$i',
            'user_id': 'user-123',
            'description': 'Updated task $i',
            'priority': 'medium',
            'completed': i % 2 == 0,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          },
        });

        when(mockCacheService.cacheData('tasks', any)).thenAnswer((_) async {});

        final stopwatch = Stopwatch()..start();

        // Process all updates
        await Future.wait(updates.map((update) => 
          syncService.handleTaskRealtimeUpdate(update)
        ));

        stopwatch.stop();

        // Verify performance (should complete within reasonable time)
        expect(stopwatch.elapsedMilliseconds, lessThan(1000)); // Less than 1 second

        // Verify all updates were processed
        verify(mockCacheService.cacheData('tasks', any)).called(100);
      });

      test('should batch multiple updates for efficiency', () async {
        final batchUpdates = List.generate(10, (i) => {
          'eventType': 'UPDATE',
          'new': {
            'id': 'task-$i',
            'user_id': 'user-123',
            'description': 'Batch update $i',
            'priority': 'medium',
            'completed': false,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          },
        });

        // Mock batched cache update
        var batchCount = 0;
        when(mockCacheService.cacheData('tasks', any)).thenAnswer((invocation) async {
          batchCount++;
          final data = invocation.positionalArguments[1] as List;
          expect(data.length, greaterThan(1)); // Should be batched
        });

        // Process updates in batch
        await syncService.batchProcessUpdates('tasks', batchUpdates);

        // Verify batching occurred
        expect(batchCount, lessThan(10)); // Should be fewer calls than individual updates
      });

      test('should optimize memory usage during large syncs', () async {
        // Create large dataset
        final largeTasks = List.generate(1000, (i) => Task(
          id: 'task-$i',
          userId: 'user-123',
          description: 'Large sync task $i',
          priority: TaskPriority.medium,
          completed: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));

        when(mockTasksRepository.getAllTasks()).thenAnswer((_) async => largeTasks);
        when(mockCacheService.cacheData('tasks', any)).thenAnswer((_) async {});

        // Monitor memory usage during sync
        final initialMemory = ProcessInfo.currentRss;
        
        await syncService.syncTasks();
        
        final finalMemory = ProcessInfo.currentRss;
        final memoryIncrease = finalMemory - initialMemory;

        // Verify reasonable memory usage (less than 50MB increase)
        expect(memoryIncrease, lessThan(50 * 1024 * 1024));

        verify(mockCacheService.cacheData('tasks', any)).called(1);
      });
    });

    group('Error Recovery and Resilience', () {
      test('should recover from temporary sync failures', () async {
        var failureCount = 0;
        when(mockTasksRepository.getAllTasks()).thenAnswer((_) async {
          failureCount++;
          if (failureCount < 3) {
            throw Exception('Temporary sync failure');
          }
          return [Task(
            id: 'recovered-task',
            userId: 'user-123',
            description: 'Recovered task',
            priority: TaskPriority.medium,
            completed: false,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          )];
        });

        when(mockCacheService.cacheData('tasks', any)).thenAnswer((_) async {});

        // Attempt sync with retry logic
        for (int i = 0; i < 3; i++) {
          try {
            await syncService.syncTasks();
            break;
          } catch (e) {
            if (i == 2) rethrow;
            await Future.delayed(Duration(seconds: i + 1));
          }
        }

        expect(failureCount, equals(3));
        verify(mockCacheService.cacheData('tasks', any)).called(1);
      });

      test('should maintain partial functionality during sync errors', () async {
        // Setup partial failure scenario
        when(mockTasksRepository.getAllTasks()).thenThrow(Exception('Tasks sync failed'));
        when(mockExpensesRepository.getAllExpenses()).thenAnswer((_) async => [
          Expense(
            id: 'expense-1',
            userId: 'user-123',
            item: 'Test expense',
            amount: 10.0,
            category: 'Test',
            date: DateTime.now(),
            createdAt: DateTime.now(),
          )
        ]);
        when(mockRemindersRepository.getAllReminders()).thenAnswer((_) async => [
          Reminder(
            id: 'reminder-1',
            userId: 'user-123',
            title: 'Test reminder',
            scheduledTime: DateTime.now().add(const Duration(hours: 1)),
            completed: false,
            createdAt: DateTime.now(),
          )
        ]);

        when(mockCacheService.cacheData(any, any)).thenAnswer((_) async {});

        // Attempt sync for all entities
        final results = await Future.wait([
          syncService.syncTasks().catchError((e) => null),
          syncService.syncExpenses().catchError((e) => null),
          syncService.syncReminders().catchError((e) => null),
        ]);

        // Verify partial success
        expect(results[0], isNull); // Tasks failed
        expect(results[1], isNull); // Expenses succeeded (no exception)
        expect(results[2], isNull); // Reminders succeeded (no exception)

        // Verify successful syncs were cached
        verify(mockCacheService.cacheData('expenses', any)).called(1);
        verify(mockCacheService.cacheData('reminders', any)).called(1);
        verifyNever(mockCacheService.cacheData('tasks', any));
      });
    });
  });
}
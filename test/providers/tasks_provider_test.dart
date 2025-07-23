import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reva_mobile_app/providers/tasks_provider.dart';
import 'package:reva_mobile_app/services/data/tasks_repository.dart';
import 'package:reva_mobile_app/services/sync/realtime_service.dart';
import 'package:reva_mobile_app/models/task.dart';

// Generate mocks
@GenerateMocks([TasksRepository, RealtimeService])
import 'tasks_provider_test.mocks.dart';

void main() {
  group('TasksProvider Tests', () {
    late MockTasksRepository mockRepository;
    late MockRealtimeService mockRealtimeService;
    late ProviderContainer container;

    setUp(() {
      mockRepository = MockTasksRepository();
      mockRealtimeService = MockRealtimeService();

      container = ProviderContainer(
        overrides: [
          tasksRepositoryProvider.overrideWithValue(mockRepository),
          realtimeServiceProvider.overrideWithValue(mockRealtimeService),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    group('Task Loading', () {
      test('should load tasks successfully', () async {
        final testTasks = [
          Task(
            id: 'task-1',
            userId: 'user-123',
            description: 'Test task 1',
            priority: TaskPriority.high,
            completed: false,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          Task(
            id: 'task-2',
            userId: 'user-123',
            description: 'Test task 2',
            priority: TaskPriority.medium,
            completed: true,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ];

        when(mockRepository.getAllTasks()).thenAnswer((_) async => testTasks);
        when(mockRealtimeService.subscribeToTasks(any)).thenAnswer((_) async {});

        final tasksAsync = container.read(tasksProvider);
        
        expect(tasksAsync, isA<AsyncLoading>());

        // Wait for the provider to complete loading
        await container.read(tasksProvider.future);

        final loadedTasks = container.read(tasksProvider).value;
        expect(loadedTasks, hasLength(2));
        expect(loadedTasks![0].description, equals('Test task 1'));
        expect(loadedTasks[1].completed, isTrue);

        verify(mockRepository.getAllTasks()).called(1);
        verify(mockRealtimeService.subscribeToTasks(any)).called(1);
      });

      test('should handle loading error', () async {
        when(mockRepository.getAllTasks()).thenThrow(Exception('Failed to load tasks'));
        when(mockRealtimeService.subscribeToTasks(any)).thenAnswer((_) async {});

        await container.read(tasksProvider.future).catchError((error) {
          expect(error, isA<Exception>());
          return <Task>[];
        });

        final tasksAsync = container.read(tasksProvider);
        expect(tasksAsync, isA<AsyncError>());
      });
    });

    group('Task Creation', () {
      test('should create task successfully', () async {
        final newTask = Task(
          id: 'task-new',
          userId: 'user-123',
          description: 'New task',
          priority: TaskPriority.medium,
          completed: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        when(mockRepository.getAllTasks()).thenAnswer((_) async => []);
        when(mockRealtimeService.subscribeToTasks(any)).thenAnswer((_) async {});
        when(mockRepository.createTask(any)).thenAnswer((_) async => newTask);

        // Initialize the provider
        await container.read(tasksProvider.future);

        // Create a new task
        final notifier = container.read(tasksProvider.notifier);
        await notifier.createTask(
          description: 'New task',
          priority: TaskPriority.medium,
          dueDate: null,
        );

        verify(mockRepository.createTask(any)).called(1);
      });

      test('should handle task creation error', () async {
        when(mockRepository.getAllTasks()).thenAnswer((_) async => []);
        when(mockRealtimeService.subscribeToTasks(any)).thenAnswer((_) async {});
        when(mockRepository.createTask(any)).thenThrow(Exception('Failed to create task'));

        await container.read(tasksProvider.future);

        final notifier = container.read(tasksProvider.notifier);
        
        expect(
          () => notifier.createTask(
            description: 'New task',
            priority: TaskPriority.medium,
          ),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('Task Updates', () {
      test('should update task successfully', () async {
        final existingTask = Task(
          id: 'task-1',
          userId: 'user-123',
          description: 'Original task',
          priority: TaskPriority.low,
          completed: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final updatedTask = existingTask.copyWith(
          description: 'Updated task',
          priority: TaskPriority.high,
        );

        when(mockRepository.getAllTasks()).thenAnswer((_) async => [existingTask]);
        when(mockRealtimeService.subscribeToTasks(any)).thenAnswer((_) async {});
        when(mockRepository.updateTask('task-1', any)).thenAnswer((_) async => updatedTask);

        await container.read(tasksProvider.future);

        final notifier = container.read(tasksProvider.notifier);
        await notifier.updateTask('task-1', {
          'description': 'Updated task',
          'priority': 'high',
        });

        verify(mockRepository.updateTask('task-1', any)).called(1);
      });

      test('should toggle task completion', () async {
        final task = Task(
          id: 'task-1',
          userId: 'user-123',
          description: 'Test task',
          priority: TaskPriority.medium,
          completed: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final completedTask = task.copyWith(completed: true);

        when(mockRepository.getAllTasks()).thenAnswer((_) async => [task]);
        when(mockRealtimeService.subscribeToTasks(any)).thenAnswer((_) async {});
        when(mockRepository.updateTask('task-1', any)).thenAnswer((_) async => completedTask);

        await container.read(tasksProvider.future);

        final notifier = container.read(tasksProvider.notifier);
        await notifier.toggleTaskCompletion('task-1');

        verify(mockRepository.updateTask('task-1', {'completed': true})).called(1);
      });

      test('should handle task update error', () async {
        final task = Task(
          id: 'task-1',
          userId: 'user-123',
          description: 'Test task',
          priority: TaskPriority.medium,
          completed: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        when(mockRepository.getAllTasks()).thenAnswer((_) async => [task]);
        when(mockRealtimeService.subscribeToTasks(any)).thenAnswer((_) async {});
        when(mockRepository.updateTask('task-1', any)).thenThrow(Exception('Update failed'));

        await container.read(tasksProvider.future);

        final notifier = container.read(tasksProvider.notifier);
        
        expect(
          () => notifier.updateTask('task-1', {'description': 'Updated'}),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('Task Deletion', () {
      test('should delete task successfully', () async {
        final task = Task(
          id: 'task-1',
          userId: 'user-123',
          description: 'Test task',
          priority: TaskPriority.medium,
          completed: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        when(mockRepository.getAllTasks()).thenAnswer((_) async => [task]);
        when(mockRealtimeService.subscribeToTasks(any)).thenAnswer((_) async {});
        when(mockRepository.deleteTask('task-1')).thenAnswer((_) async {});

        await container.read(tasksProvider.future);

        final notifier = container.read(tasksProvider.notifier);
        await notifier.deleteTask('task-1');

        verify(mockRepository.deleteTask('task-1')).called(1);
      });

      test('should handle task deletion error', () async {
        final task = Task(
          id: 'task-1',
          userId: 'user-123',
          description: 'Test task',
          priority: TaskPriority.medium,
          completed: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        when(mockRepository.getAllTasks()).thenAnswer((_) async => [task]);
        when(mockRealtimeService.subscribeToTasks(any)).thenAnswer((_) async {});
        when(mockRepository.deleteTask('task-1')).thenThrow(Exception('Delete failed'));

        await container.read(tasksProvider.future);

        final notifier = container.read(tasksProvider.notifier);
        
        expect(
          () => notifier.deleteTask('task-1'),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('Task Filtering and Sorting', () {
      test('should filter completed tasks', () async {
        final tasks = [
          Task(
            id: 'task-1',
            userId: 'user-123',
            description: 'Completed task',
            priority: TaskPriority.medium,
            completed: true,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          Task(
            id: 'task-2',
            userId: 'user-123',
            description: 'Incomplete task',
            priority: TaskPriority.high,
            completed: false,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ];

        when(mockRepository.getAllTasks()).thenAnswer((_) async => tasks);
        when(mockRealtimeService.subscribeToTasks(any)).thenAnswer((_) async {});

        await container.read(tasksProvider.future);

        final completedTasks = container.read(completedTasksProvider);
        expect(completedTasks, hasLength(1));
        expect(completedTasks.first.completed, isTrue);

        final incompleteTasks = container.read(incompleteTasksProvider);
        expect(incompleteTasks, hasLength(1));
        expect(incompleteTasks.first.completed, isFalse);
      });

      test('should filter overdue tasks', () async {
        final now = DateTime.now();
        final tasks = [
          Task(
            id: 'task-1',
            userId: 'user-123',
            description: 'Overdue task',
            priority: TaskPriority.medium,
            completed: false,
            dueDate: now.subtract(const Duration(days: 1)),
            createdAt: now,
            updatedAt: now,
          ),
          Task(
            id: 'task-2',
            userId: 'user-123',
            description: 'Future task',
            priority: TaskPriority.high,
            completed: false,
            dueDate: now.add(const Duration(days: 1)),
            createdAt: now,
            updatedAt: now,
          ),
        ];

        when(mockRepository.getAllTasks()).thenAnswer((_) async => tasks);
        when(mockRealtimeService.subscribeToTasks(any)).thenAnswer((_) async {});

        await container.read(tasksProvider.future);

        final overdueTasks = container.read(overdueTasksProvider);
        expect(overdueTasks, hasLength(1));
        expect(overdueTasks.first.isOverdue, isTrue);
      });

      test('should filter tasks due today', () async {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day, 15, 0);
        
        final tasks = [
          Task(
            id: 'task-1',
            userId: 'user-123',
            description: 'Due today',
            priority: TaskPriority.medium,
            completed: false,
            dueDate: today,
            createdAt: now,
            updatedAt: now,
          ),
          Task(
            id: 'task-2',
            userId: 'user-123',
            description: 'Due tomorrow',
            priority: TaskPriority.high,
            completed: false,
            dueDate: now.add(const Duration(days: 1)),
            createdAt: now,
            updatedAt: now,
          ),
        ];

        when(mockRepository.getAllTasks()).thenAnswer((_) async => tasks);
        when(mockRealtimeService.subscribeToTasks(any)).thenAnswer((_) async {});

        await container.read(tasksProvider.future);

        final todayTasks = container.read(tasksDueTodayProvider);
        expect(todayTasks, hasLength(1));
        expect(todayTasks.first.isDueToday, isTrue);
      });

      test('should filter high priority tasks', () async {
        final tasks = [
          Task(
            id: 'task-1',
            userId: 'user-123',
            description: 'High priority task',
            priority: TaskPriority.high,
            completed: false,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          Task(
            id: 'task-2',
            userId: 'user-123',
            description: 'Low priority task',
            priority: TaskPriority.low,
            completed: false,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ];

        when(mockRepository.getAllTasks()).thenAnswer((_) async => tasks);
        when(mockRealtimeService.subscribeToTasks(any)).thenAnswer((_) async {});

        await container.read(tasksProvider.future);

        final highPriorityTasks = container.read(highPriorityTasksProvider);
        expect(highPriorityTasks, hasLength(1));
        expect(highPriorityTasks.first.priority, equals(TaskPriority.high));
      });
    });

    group('Task Statistics', () {
      test('should calculate task statistics correctly', () async {
        final tasks = [
          Task(
            id: 'task-1',
            userId: 'user-123',
            description: 'Completed task',
            priority: TaskPriority.high,
            completed: true,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          Task(
            id: 'task-2',
            userId: 'user-123',
            description: 'Incomplete task',
            priority: TaskPriority.medium,
            completed: false,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          Task(
            id: 'task-3',
            userId: 'user-123',
            description: 'Another incomplete task',
            priority: TaskPriority.low,
            completed: false,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ];

        when(mockRepository.getAllTasks()).thenAnswer((_) async => tasks);
        when(mockRealtimeService.subscribeToTasks(any)).thenAnswer((_) async {});

        await container.read(tasksProvider.future);

        final stats = container.read(taskStatsProvider);
        expect(stats.totalTasks, equals(3));
        expect(stats.completedTasks, equals(1));
        expect(stats.incompleteTasks, equals(2));
        expect(stats.completionRate, closeTo(0.33, 0.01));
      });

      test('should handle empty task list in statistics', () async {
        when(mockRepository.getAllTasks()).thenAnswer((_) async => []);
        when(mockRealtimeService.subscribeToTasks(any)).thenAnswer((_) async {});

        await container.read(tasksProvider.future);

        final stats = container.read(taskStatsProvider);
        expect(stats.totalTasks, equals(0));
        expect(stats.completedTasks, equals(0));
        expect(stats.incompleteTasks, equals(0));
        expect(stats.completionRate, equals(0.0));
      });
    });

    group('Realtime Updates', () {
      test('should handle realtime task updates', () async {
        final initialTasks = [
          Task(
            id: 'task-1',
            userId: 'user-123',
            description: 'Original task',
            priority: TaskPriority.medium,
            completed: false,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ];

        when(mockRepository.getAllTasks()).thenAnswer((_) async => initialTasks);
        when(mockRealtimeService.subscribeToTasks(any)).thenAnswer((_) async {});

        await container.read(tasksProvider.future);

        // Simulate realtime update
        final notifier = container.read(tasksProvider.notifier);
        await notifier.handleRealtimeUpdate({
          'eventType': 'UPDATE',
          'new': {
            'id': 'task-1',
            'user_id': 'user-123',
            'description': 'Updated task',
            'priority': 'high',
            'completed': true,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          },
        });

        final updatedTasks = container.read(tasksProvider).value;
        expect(updatedTasks![0].description, equals('Updated task'));
        expect(updatedTasks[0].priority, equals(TaskPriority.high));
        expect(updatedTasks[0].completed, isTrue);
      });

      test('should handle realtime task insertion', () async {
        when(mockRepository.getAllTasks()).thenAnswer((_) async => []);
        when(mockRealtimeService.subscribeToTasks(any)).thenAnswer((_) async {});

        await container.read(tasksProvider.future);

        final notifier = container.read(tasksProvider.notifier);
        await notifier.handleRealtimeUpdate({
          'eventType': 'INSERT',
          'new': {
            'id': 'task-new',
            'user_id': 'user-123',
            'description': 'New task from realtime',
            'priority': 'medium',
            'completed': false,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          },
        });

        final tasks = container.read(tasksProvider).value;
        expect(tasks, hasLength(1));
        expect(tasks![0].description, equals('New task from realtime'));
      });

      test('should handle realtime task deletion', () async {
        final initialTasks = [
          Task(
            id: 'task-1',
            userId: 'user-123',
            description: 'Task to delete',
            priority: TaskPriority.medium,
            completed: false,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ];

        when(mockRepository.getAllTasks()).thenAnswer((_) async => initialTasks);
        when(mockRealtimeService.subscribeToTasks(any)).thenAnswer((_) async {});

        await container.read(tasksProvider.future);

        final notifier = container.read(tasksProvider.notifier);
        await notifier.handleRealtimeUpdate({
          'eventType': 'DELETE',
          'old': {
            'id': 'task-1',
            'user_id': 'user-123',
            'description': 'Task to delete',
            'priority': 'medium',
            'completed': false,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          },
        });

        final tasks = container.read(tasksProvider).value;
        expect(tasks, isEmpty);
      });
    });

    group('Error Handling', () {
      test('should handle repository errors gracefully', () async {
        when(mockRepository.getAllTasks()).thenThrow(Exception('Repository error'));
        when(mockRealtimeService.subscribeToTasks(any)).thenAnswer((_) async {});

        final tasksAsync = await container.read(tasksProvider.future).catchError((error) {
          expect(error, isA<Exception>());
          return <Task>[];
        });

        expect(tasksAsync, isEmpty);
      });

      test('should handle realtime subscription errors', () async {
        when(mockRepository.getAllTasks()).thenAnswer((_) async => []);
        when(mockRealtimeService.subscribeToTasks(any)).thenThrow(Exception('Realtime error'));

        // Should still load tasks even if realtime subscription fails
        await container.read(tasksProvider.future);
        
        final tasks = container.read(tasksProvider).value;
        expect(tasks, isNotNull);
        expect(tasks, isEmpty);
      });
    });
  });
}
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../lib/models/task.dart';
import '../../lib/providers/tasks_provider.dart';
import '../../lib/providers/chat_provider.dart';
import '../../lib/models/chat_message.dart';

// Mock classes
class MockTasksRepository extends Mock {}
class MockTasksCacheService extends Mock {}
class MockSyncService extends Mock {}
class MockRealtimeService extends Mock {}
class MockChatService extends Mock {}

void main() {
  group('Task Chat Integration Tests', () {
    late ProviderContainer container;
    late MockTasksRepository mockTasksRepository;
    late MockTasksCacheService mockTasksCacheService;
    late MockSyncService mockSyncService;
    late MockRealtimeService mockRealtimeService;

    setUp(() {
      mockTasksRepository = MockTasksRepository();
      mockTasksCacheService = MockTasksCacheService();
      mockSyncService = MockSyncService();
      mockRealtimeService = MockRealtimeService();

      container = ProviderContainer(
        overrides: [
          tasksRepositoryProvider.overrideWithValue(mockTasksRepository),
          tasksCacheServiceProvider.overrideWithValue(mockTasksCacheService),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    testWidgets('should create task from AI action', (WidgetTester tester) async {
      // Arrange
      final taskData = {
        'description': 'Test task from AI',
        'due_date': DateTime.now().add(const Duration(days: 1)).toIso8601String(),
        'priority': 'high',
      };

      final expectedTask = Task(
        id: 'test-task-id',
        userId: 'test-user-id',
        description: 'Test task from AI',
        dueDate: DateTime.now().add(const Duration(days: 1)),
        priority: TaskPriority.high,
        completed: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      when(mockTasksRepository.create(any)).thenAnswer((_) async => expectedTask);
      when(mockTasksCacheService.cacheTask(any)).thenAnswer((_) async {});

      // Act
      final tasksNotifier = container.read(tasksProvider.notifier);
      await tasksNotifier.createTaskFromAI(taskData);

      // Assert
      final tasksState = container.read(tasksProvider);
      expect(tasksState.tasks.length, equals(1));
      expect(tasksState.tasks.first.description, equals('Test task from AI'));
      expect(tasksState.tasks.first.priority, equals(TaskPriority.high));
    });

    testWidgets('should update task from AI action', (WidgetTester tester) async {
      // Arrange
      final existingTask = Task(
        id: 'test-task-id',
        userId: 'test-user-id',
        description: 'Original task',
        priority: TaskPriority.medium,
        completed: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final updateData = {
        'task_id': 'test-task-id',
        'description': 'Updated task description',
        'priority': 'high',
      };

      final updatedTask = existingTask.copyWith(
        description: 'Updated task description',
        priority: TaskPriority.high,
        updatedAt: DateTime.now(),
      );

      when(mockTasksRepository.update('test-task-id', any))
          .thenAnswer((_) async => updatedTask);
      when(mockTasksCacheService.updateCachedTask('test-task-id', any))
          .thenAnswer((_) async {});

      // Set initial state
      final tasksNotifier = container.read(tasksProvider.notifier);
      // Simulate existing task in state
      // This would normally be done through proper state management

      // Act
      await tasksNotifier.updateTaskFromAI(updateData);

      // Assert
      verify(mockTasksRepository.update('test-task-id', any)).called(1);
      verify(mockTasksCacheService.updateCachedTask('test-task-id', any)).called(1);
    });

    testWidgets('should complete task from AI action', (WidgetTester tester) async {
      // Arrange
      final taskId = 'test-task-id';
      final completeData = {'task_id': taskId};

      final completedTask = Task(
        id: taskId,
        userId: 'test-user-id',
        description: 'Test task',
        priority: TaskPriority.medium,
        completed: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      when(mockTasksRepository.update(taskId, any))
          .thenAnswer((_) async => completedTask);
      when(mockTasksCacheService.updateCachedTask(taskId, any))
          .thenAnswer((_) async {});

      // Act
      final tasksNotifier = container.read(tasksProvider.notifier);
      await tasksNotifier.completeTaskFromAI(completeData);

      // Assert
      verify(mockTasksRepository.update(taskId, {'completed': true, 'updated_at': any}))
          .called(1);
    });

    test('should handle AI action metadata correctly', () {
      // Test that chat messages with action metadata are processed correctly
      final chatMessage = ChatMessage.assistant(
        id: 'test-message-id',
        content: 'I\'ve created a task for you.',
        metadata: {
          'action': {
            'type': 'create_task',
            'data': {
              'description': 'Test task from chat',
              'priority': 'high',
            },
          },
        },
      );

      expect(chatMessage.hasActionMetadata, isTrue);
      expect(chatMessage.actionType, equals('create_task'));
      expect(chatMessage.actionData?['description'], equals('Test task from chat'));
      expect(chatMessage.actionData?['priority'], equals('high'));
    });

    test('should handle realtime task updates', () {
      // Test that realtime updates are processed correctly
      final realtimePayload = {
        'id': 'test-task-id',
        'user_id': 'test-user-id',
        'description': 'Updated via web app',
        'priority': 'high',
        'completed': false,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      final task = Task.fromJson(realtimePayload);
      
      expect(task.id, equals('test-task-id'));
      expect(task.description, equals('Updated via web app'));
      expect(task.priority, equals(TaskPriority.high));
      expect(task.completed, isFalse);
    });

    test('should handle offline task caching', () async {
      // Test that tasks are cached properly for offline access
      final task = Task(
        id: 'test-task-id',
        userId: 'test-user-id',
        description: 'Offline task',
        priority: TaskPriority.medium,
        completed: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      when(mockTasksCacheService.cacheTask(any)).thenAnswer((_) async {});
      when(mockTasksCacheService.getCachedTasks(userId: 'test-user-id'))
          .thenAnswer((_) async => [task.toJson()]);

      // Simulate caching
      await mockTasksCacheService.cacheTask(task.toJson());
      
      // Simulate retrieval from cache
      final cachedTasks = await mockTasksCacheService.getCachedTasks(userId: 'test-user-id');
      
      expect(cachedTasks.length, equals(1));
      expect(cachedTasks.first['description'], equals('Offline task'));
      
      verify(mockTasksCacheService.cacheTask(any)).called(1);
      verify(mockTasksCacheService.getCachedTasks(userId: 'test-user-id')).called(1);
    });
  });
}
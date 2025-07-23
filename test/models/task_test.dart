import 'package:flutter_test/flutter_test.dart';
import 'package:reva_mobile_app/models/task.dart';

void main() {
  group('Task Model Tests', () {
    late Task testTask;
    late DateTime testDate;

    setUp(() {
      testDate = DateTime(2024, 1, 15, 10, 30);
      testTask = Task(
        id: 'test-task-1',
        userId: 'user-123',
        description: 'Test task description',
        dueDate: testDate,
        priority: TaskPriority.medium,
        completed: false,
        createdAt: DateTime(2024, 1, 10),
        updatedAt: DateTime(2024, 1, 12),
      );
    });

    group('Task Creation', () {
      test('should create task with all properties', () {
        expect(testTask.id, equals('test-task-1'));
        expect(testTask.userId, equals('user-123'));
        expect(testTask.description, equals('Test task description'));
        expect(testTask.dueDate, equals(testDate));
        expect(testTask.priority, equals(TaskPriority.medium));
        expect(testTask.completed, isFalse);
        expect(testTask.createdAt, equals(DateTime(2024, 1, 10)));
        expect(testTask.updatedAt, equals(DateTime(2024, 1, 12)));
      });

      test('should create task without due date', () {
        final taskWithoutDueDate = Task(
          id: 'test-task-2',
          userId: 'user-123',
          description: 'Task without due date',
          priority: TaskPriority.low,
          completed: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        expect(taskWithoutDueDate.dueDate, isNull);
      });
    });

    group('JSON Serialization', () {
      test('should serialize to JSON correctly', () {
        final json = testTask.toJson();

        expect(json['id'], equals('test-task-1'));
        expect(json['user_id'], equals('user-123'));
        expect(json['description'], equals('Test task description'));
        expect(json['due_date'], equals(testDate.toIso8601String()));
        expect(json['priority'], equals('medium'));
        expect(json['completed'], isFalse);
        expect(json['created_at'], equals(DateTime(2024, 1, 10).toIso8601String()));
        expect(json['updated_at'], equals(DateTime(2024, 1, 12).toIso8601String()));
      });

      test('should deserialize from JSON correctly', () {
        final json = {
          'id': 'test-task-1',
          'user_id': 'user-123',
          'description': 'Test task description',
          'due_date': testDate.toIso8601String(),
          'priority': 'medium',
          'completed': false,
          'created_at': DateTime(2024, 1, 10).toIso8601String(),
          'updated_at': DateTime(2024, 1, 12).toIso8601String(),
        };

        final task = Task.fromJson(json);

        expect(task.id, equals('test-task-1'));
        expect(task.userId, equals('user-123'));
        expect(task.description, equals('Test task description'));
        expect(task.dueDate, equals(testDate));
        expect(task.priority, equals(TaskPriority.medium));
        expect(task.completed, isFalse);
        expect(task.createdAt, equals(DateTime(2024, 1, 10)));
        expect(task.updatedAt, equals(DateTime(2024, 1, 12)));
      });

      test('should handle null due date in JSON', () {
        final json = {
          'id': 'test-task-2',
          'user_id': 'user-123',
          'description': 'Task without due date',
          'due_date': null,
          'priority': 'low',
          'completed': false,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        };

        final task = Task.fromJson(json);
        expect(task.dueDate, isNull);
      });
    });

    group('Business Logic', () {
      test('isOverdue should return true for overdue incomplete tasks', () {
        final overdueTask = testTask.copyWith(
          dueDate: DateTime.now().subtract(const Duration(days: 1)),
          completed: false,
        );

        expect(overdueTask.isOverdue, isTrue);
      });

      test('isOverdue should return false for completed tasks', () {
        final completedOverdueTask = testTask.copyWith(
          dueDate: DateTime.now().subtract(const Duration(days: 1)),
          completed: true,
        );

        expect(completedOverdueTask.isOverdue, isFalse);
      });

      test('isOverdue should return false for tasks without due date', () {
        final taskWithoutDueDate = Task(
          id: 'test-task-no-due',
          userId: 'user-123',
          description: 'Task without due date',
          dueDate: null,
          priority: TaskPriority.medium,
          completed: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        expect(taskWithoutDueDate.isOverdue, isFalse);
      });

      test('isDueToday should return true for tasks due today', () {
        final todayTask = testTask.copyWith(dueDate: DateTime.now());
        expect(todayTask.isDueToday, isTrue);
      });

      test('isDueToday should return false for tasks due tomorrow', () {
        final tomorrowTask = testTask.copyWith(
          dueDate: DateTime.now().add(const Duration(days: 1)),
        );
        expect(tomorrowTask.isDueToday, isFalse);
      });

      test('isDueSoon should return true for tasks due within 3 days', () {
        final soonTask = testTask.copyWith(
          dueDate: DateTime.now().add(const Duration(days: 2)),
          completed: false,
        );
        expect(soonTask.isDueSoon, isTrue);
      });

      test('isDueSoon should return false for completed tasks', () {
        final completedSoonTask = testTask.copyWith(
          dueDate: DateTime.now().add(const Duration(days: 2)),
          completed: true,
        );
        expect(completedSoonTask.isDueSoon, isFalse);
      });

      test('priorityDisplayName should return correct display names', () {
        expect(testTask.copyWith(priority: TaskPriority.high).priorityDisplayName, equals('High'));
        expect(testTask.copyWith(priority: TaskPriority.medium).priorityDisplayName, equals('Medium'));
        expect(testTask.copyWith(priority: TaskPriority.low).priorityDisplayName, equals('Low'));
      });
    });

    group('Validation', () {
      test('isValid should return true for valid task', () {
        expect(testTask.isValid(), isTrue);
      });

      test('isValid should return false for empty description', () {
        final invalidTask = testTask.copyWith(description: '');
        expect(invalidTask.isValid(), isFalse);
      });

      test('isValid should return false for empty user ID', () {
        final invalidTask = testTask.copyWith(userId: '');
        expect(invalidTask.isValid(), isFalse);
      });

      test('isValid should return false for empty task ID', () {
        final invalidTask = testTask.copyWith(id: '');
        expect(invalidTask.isValid(), isFalse);
      });

      test('getValidationErrors should return empty list for valid task', () {
        final errors = testTask.getValidationErrors();
        expect(errors, isEmpty);
      });

      test('getValidationErrors should return appropriate errors', () {
        final invalidTask = Task(
          id: '',
          userId: '',
          description: '',
          priority: TaskPriority.medium,
          completed: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final errors = invalidTask.getValidationErrors();
        expect(errors, contains('Task ID cannot be empty'));
        expect(errors, contains('User ID cannot be empty'));
        expect(errors, contains('Task description cannot be empty'));
      });

      test('getValidationErrors should check description length', () {
        final longDescriptionTask = testTask.copyWith(
          description: 'a' * 501, // 501 characters
        );

        final errors = longDescriptionTask.getValidationErrors();
        expect(errors, contains('Task description cannot exceed 500 characters'));
      });
    });

    group('Equality and CopyWith', () {
      test('should support equality comparison', () {
        final task1 = testTask;
        final task2 = Task(
          id: 'test-task-1',
          userId: 'user-123',
          description: 'Test task description',
          dueDate: testDate,
          priority: TaskPriority.medium,
          completed: false,
          createdAt: DateTime(2024, 1, 10),
          updatedAt: DateTime(2024, 1, 12),
        );

        expect(task1, equals(task2));
      });

      test('should support copyWith method', () {
        final updatedTask = testTask.copyWith(
          description: 'Updated description',
          completed: true,
        );

        expect(updatedTask.id, equals(testTask.id));
        expect(updatedTask.description, equals('Updated description'));
        expect(updatedTask.completed, isTrue);
        expect(updatedTask.userId, equals(testTask.userId));
      });

      test('should have proper toString implementation', () {
        final taskString = testTask.toString();
        expect(taskString, contains('Task('));
        expect(taskString, contains('test-task-1'));
        expect(taskString, contains('Test task description'));
        expect(taskString, contains('medium'));
        expect(taskString, contains('false'));
      });
    });

    group('TaskPriority Enum', () {
      test('should serialize priority enum correctly', () {
        expect(TaskPriority.high.name, equals('high'));
        expect(TaskPriority.medium.name, equals('medium'));
        expect(TaskPriority.low.name, equals('low'));
      });

      test('should handle all priority values', () {
        final priorities = TaskPriority.values;
        expect(priorities, hasLength(3));
        expect(priorities, contains(TaskPriority.high));
        expect(priorities, contains(TaskPriority.medium));
        expect(priorities, contains(TaskPriority.low));
      });
    });
  });
}
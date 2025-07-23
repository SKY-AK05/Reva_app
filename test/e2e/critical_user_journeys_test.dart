import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:reva_mobile_app/main.dart';
import 'package:reva_mobile_app/services/auth/auth_service.dart';
import 'package:reva_mobile_app/services/chat/chat_service.dart';
import 'package:reva_mobile_app/services/data/tasks_repository.dart';
import 'package:reva_mobile_app/services/data/expenses_repository.dart';
import 'package:reva_mobile_app/services/data/reminders_repository.dart';
import 'package:reva_mobile_app/services/connectivity/connectivity_service.dart';
import 'package:reva_mobile_app/models/task.dart';
import 'package:reva_mobile_app/models/expense.dart';
import 'package:reva_mobile_app/models/reminder.dart';
import 'package:reva_mobile_app/models/chat_message.dart';
import 'package:reva_mobile_app/providers/auth_provider.dart';
import 'package:reva_mobile_app/providers/chat_provider.dart';
import 'package:reva_mobile_app/providers/tasks_provider.dart';
import 'package:reva_mobile_app/providers/expenses_provider.dart';
import 'package:reva_mobile_app/providers/reminders_provider.dart';

// Generate mocks
@GenerateMocks([
  AuthService,
  ChatService,
  TasksRepository,
  ExpensesRepository,
  RemindersRepository,
  ConnectivityService,
])
import 'critical_user_journeys_test.mocks.dart';

void main() {
  group('Critical User Journeys E2E Tests', () {
    late MockAuthService mockAuthService;
    late MockChatService mockChatService;
    late MockTasksRepository mockTasksRepository;
    late MockExpensesRepository mockExpensesRepository;
    late MockRemindersRepository mockRemindersRepository;
    late MockConnectivityService mockConnectivityService;

    setUp(() {
      mockAuthService = MockAuthService();
      mockChatService = MockChatService();
      mockTasksRepository = MockTasksRepository();
      mockExpensesRepository = MockExpensesRepository();
      mockRemindersRepository = MockRemindersRepository();
      mockConnectivityService = MockConnectivityService();

      // Setup default mocks
      when(mockAuthService.isAuthenticated).thenReturn(true);
      when(mockAuthService.currentUser).thenReturn(null);
      when(mockAuthService.authStateChanges).thenAnswer((_) => Stream.empty());
      when(mockConnectivityService.isConnected).thenReturn(true);
      when(mockConnectivityService.connectionStream).thenAnswer((_) => Stream.value(true));
    });

    group('Complete User Onboarding Journey', () {
      testWidgets('should complete full onboarding flow from login to first task creation', 
          (WidgetTester tester) async {
        // Step 1: Start with unauthenticated state
        when(mockAuthService.isAuthenticated).thenReturn(false);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authServiceProvider.overrideWithValue(mockAuthService),
              chatServiceProvider.overrideWithValue(mockChatService),
              tasksRepositoryProvider.overrideWithValue(mockTasksRepository),
              connectivityServiceProvider.overrideWithValue(mockConnectivityService),
            ],
            child: const RevaApp(),
          ),
        );

        await tester.pumpAndSettle();

        // Should show login screen
        expect(find.text('Sign In'), findsOneWidget);
        expect(find.text('Email'), findsOneWidget);
        expect(find.text('Password'), findsOneWidget);

        // Step 2: Perform login
        await tester.enterText(find.byType(TextField).first, 'test@example.com');
        await tester.enterText(find.byType(TextField).last, 'password123');

        // Mock successful login
        when(mockAuthService.signInWithEmailPassword(
          email: 'test@example.com',
          password: 'password123',
        )).thenAnswer((_) async => AuthResponse(user: null, session: null));

        when(mockAuthService.isAuthenticated).thenReturn(true);

        await tester.tap(find.text('Sign In'));
        await tester.pumpAndSettle();

        // Step 3: Should navigate to main app (chat screen)
        expect(find.text('Reva'), findsOneWidget); // App bar title
        expect(find.byType(TextField), findsOneWidget); // Chat input
        expect(find.text('Start a conversation'), findsOneWidget); // Empty state

        // Step 4: Send first message to create a task
        const taskMessage = 'Create a task to buy groceries';
        
        // Mock chat response
        when(mockChatService.sendMessage(
          message: taskMessage,
          history: any,
          contextItem: any,
        )).thenAnswer((_) async => ChatResponse(
          aiResponseText: 'I\'ve created a task for you to buy groceries.',
          actionMetadata: {
            'type': 'create_task',
            'data': {'description': 'Buy groceries', 'priority': 'medium'}
          },
          contextItemId: 'task-123',
          contextItemType: 'task',
        ));

        // Mock task creation
        final createdTask = Task(
          id: 'task-123',
          userId: 'user-123',
          description: 'Buy groceries',
          priority: TaskPriority.medium,
          completed: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        when(mockTasksRepository.getAllTasks()).thenAnswer((_) async => [createdTask]);
        when(mockChatService.saveMessage(any)).thenAnswer((_) async {});

        // Send the message
        await tester.enterText(find.byType(TextField), taskMessage);
        await tester.tap(find.byIcon(Icons.send));
        await tester.pumpAndSettle();

        // Step 5: Verify chat response is displayed
        expect(find.textContaining('I\'ve created a task'), findsOneWidget);
        expect(find.textContaining('Buy groceries'), findsOneWidget);

        // Step 6: Navigate to tasks screen to verify task was created
        await tester.tap(find.text('Tasks'));
        await tester.pumpAndSettle();

        // Should show the created task
        expect(find.text('Buy groceries'), findsOneWidget);
        expect(find.byIcon(Icons.circle_outlined), findsOneWidget); // Incomplete task icon

        // Step 7: Complete the task
        await tester.tap(find.byIcon(Icons.circle_outlined));
        await tester.pumpAndSettle();

        // Task should be marked as completed
        expect(find.byIcon(Icons.check_circle), findsOneWidget);

        // Verify the complete onboarding journey was successful
        verify(mockAuthService.signInWithEmailPassword(
          email: 'test@example.com',
          password: 'password123',
        )).called(1);
        verify(mockChatService.sendMessage(
          message: taskMessage,
          history: any,
          contextItem: any,
        )).called(1);
        verify(mockTasksRepository.getAllTasks()).called(atLeast(1));
      });
    });

    group('Task Management Journey', () {
      testWidgets('should complete full task lifecycle from creation to completion', 
          (WidgetTester tester) async {
        // Setup authenticated state
        when(mockTasksRepository.getAllTasks()).thenAnswer((_) async => []);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authServiceProvider.overrideWithValue(mockAuthService),
              tasksRepositoryProvider.overrideWithValue(mockTasksRepository),
              connectivityServiceProvider.overrideWithValue(mockConnectivityService),
            ],
            child: const RevaApp(),
          ),
        );

        await tester.pumpAndSettle();

        // Navigate to tasks screen
        await tester.tap(find.text('Tasks'));
        await tester.pumpAndSettle();

        // Should show empty state
        expect(find.text('No tasks yet'), findsOneWidget);

        // Step 1: Create a new task manually
        await tester.tap(find.byIcon(Icons.add));
        await tester.pumpAndSettle();

        // Should open add task screen
        expect(find.text('Add Task'), findsOneWidget);

        // Fill in task details
        await tester.enterText(
          find.widgetWithText(TextField, 'Task description'),
          'Complete project proposal',
        );

        // Set priority to high
        await tester.tap(find.text('Priority'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('High'));
        await tester.pumpAndSettle();

        // Set due date
        await tester.tap(find.text('Due Date'));
        await tester.pumpAndSettle();
        
        // Select tomorrow's date
        final tomorrow = DateTime.now().add(const Duration(days: 1));
        await tester.tap(find.text(tomorrow.day.toString()));
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();

        // Mock task creation
        final newTask = Task(
          id: 'task-new',
          userId: 'user-123',
          description: 'Complete project proposal',
          priority: TaskPriority.high,
          completed: false,
          dueDate: tomorrow,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        when(mockTasksRepository.createTask(any)).thenAnswer((_) async => newTask);
        when(mockTasksRepository.getAllTasks()).thenAnswer((_) async => [newTask]);

        // Save the task
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();

        // Step 2: Verify task appears in list
        expect(find.text('Complete project proposal'), findsOneWidget);
        expect(find.byIcon(Icons.priority_high), findsOneWidget); // High priority indicator

        // Step 3: Edit the task
        await tester.tap(find.text('Complete project proposal'));
        await tester.pumpAndSettle();

        // Should open task detail/edit screen
        expect(find.text('Edit Task'), findsOneWidget);

        // Update description
        await tester.enterText(
          find.widgetWithText(TextField, 'Complete project proposal'),
          'Complete and submit project proposal',
        );

        // Mock task update
        final updatedTask = newTask.copyWith(
          description: 'Complete and submit project proposal',
          updatedAt: DateTime.now(),
        );

        when(mockTasksRepository.updateTask(any, any)).thenAnswer((_) async => updatedTask);
        when(mockTasksRepository.getAllTasks()).thenAnswer((_) async => [updatedTask]);

        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();

        // Step 4: Verify updated task
        expect(find.text('Complete and submit project proposal'), findsOneWidget);

        // Step 5: Mark task as completed
        await tester.tap(find.byIcon(Icons.circle_outlined));
        await tester.pumpAndSettle();

        // Mock task completion
        final completedTask = updatedTask.copyWith(
          completed: true,
          updatedAt: DateTime.now(),
        );

        when(mockTasksRepository.updateTask(any, any)).thenAnswer((_) async => completedTask);
        when(mockTasksRepository.getAllTasks()).thenAnswer((_) async => [completedTask]);

        // Verify task is marked as completed
        expect(find.byIcon(Icons.check_circle), findsOneWidget);

        // Step 6: Filter to show only completed tasks
        await tester.tap(find.text('Filter'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Completed'));
        await tester.pumpAndSettle();

        // Should show the completed task
        expect(find.text('Complete and submit project proposal'), findsOneWidget);

        // Verify all operations were called
        verify(mockTasksRepository.createTask(any)).called(1);
        verify(mockTasksRepository.updateTask(any, any)).called(atLeast(2));
        verify(mockTasksRepository.getAllTasks()).called(atLeast(3));
      });
    });

    group('Expense Tracking Journey', () {
      testWidgets('should complete expense logging and categorization flow', 
          (WidgetTester tester) async {
        when(mockExpensesRepository.getAllExpenses()).thenAnswer((_) async => []);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authServiceProvider.overrideWithValue(mockAuthService),
              expensesRepositoryProvider.overrideWithValue(mockExpensesRepository),
              connectivityServiceProvider.overrideWithValue(mockConnectivityService),
            ],
            child: const RevaApp(),
          ),
        );

        await tester.pumpAndSettle();

        // Navigate to expenses screen
        await tester.tap(find.text('Expenses'));
        await tester.pumpAndSettle();

        // Step 1: Add first expense
        await tester.tap(find.byIcon(Icons.add));
        await tester.pumpAndSettle();

        // Fill expense details
        await tester.enterText(find.widgetWithText(TextField, 'Item'), 'Business lunch');
        await tester.enterText(find.widgetWithText(TextField, 'Amount'), '25.50');

        // Select category
        await tester.tap(find.text('Category'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Food & Dining'));
        await tester.pumpAndSettle();

        // Mock expense creation
        final expense1 = Expense(
          id: 'expense-1',
          userId: 'user-123',
          item: 'Business lunch',
          amount: 25.50,
          category: 'Food & Dining',
          date: DateTime.now(),
          createdAt: DateTime.now(),
        );

        when(mockExpensesRepository.createExpense(any)).thenAnswer((_) async => expense1);
        when(mockExpensesRepository.getAllExpenses()).thenAnswer((_) async => [expense1]);

        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();

        // Step 2: Add second expense
        await tester.tap(find.byIcon(Icons.add));
        await tester.pumpAndSettle();

        await tester.enterText(find.widgetWithText(TextField, 'Item'), 'Uber ride');
        await tester.enterText(find.widgetWithText(TextField, 'Amount'), '15.75');

        await tester.tap(find.text('Category'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Transportation'));
        await tester.pumpAndSettle();

        final expense2 = Expense(
          id: 'expense-2',
          userId: 'user-123',
          item: 'Uber ride',
          amount: 15.75,
          category: 'Transportation',
          date: DateTime.now(),
          createdAt: DateTime.now(),
        );

        when(mockExpensesRepository.createExpense(any)).thenAnswer((_) async => expense2);
        when(mockExpensesRepository.getAllExpenses()).thenAnswer((_) async => [expense1, expense2]);

        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();

        // Step 3: Verify both expenses are displayed
        expect(find.text('Business lunch'), findsOneWidget);
        expect(find.text('Uber ride'), findsOneWidget);
        expect(find.text('\$25.50'), findsOneWidget);
        expect(find.text('\$15.75'), findsOneWidget);

        // Step 4: View expense summary
        await tester.tap(find.text('Summary'));
        await tester.pumpAndSettle();

        // Should show total and category breakdown
        expect(find.text('\$41.25'), findsOneWidget); // Total
        expect(find.text('Food & Dining: \$25.50'), findsOneWidget);
        expect(find.text('Transportation: \$15.75'), findsOneWidget);

        // Step 5: Filter by category
        await tester.tap(find.text('Filter'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Food & Dining'));
        await tester.pumpAndSettle();

        // Should show only food expenses
        expect(find.text('Business lunch'), findsOneWidget);
        expect(find.text('Uber ride'), findsNothing);

        verify(mockExpensesRepository.createExpense(any)).called(2);
        verify(mockExpensesRepository.getAllExpenses()).called(atLeast(2));
      });
    });

    group('Chat-Driven Task Creation Journey', () {
      testWidgets('should create tasks through natural language conversation', 
          (WidgetTester tester) async {
        // Setup empty initial state
        when(mockTasksRepository.getAllTasks()).thenAnswer((_) async => []);
        when(mockChatService.getMessageHistory()).thenAnswer((_) async => []);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authServiceProvider.overrideWithValue(mockAuthService),
              chatServiceProvider.overrideWithValue(mockChatService),
              tasksRepositoryProvider.overrideWithValue(mockTasksRepository),
              connectivityServiceProvider.overrideWithValue(mockConnectivityService),
            ],
            child: const RevaApp(),
          ),
        );

        await tester.pumpAndSettle();

        // Should start on chat screen
        expect(find.text('Start a conversation'), findsOneWidget);

        // Step 1: Send natural language request
        const userMessage = 'I need to remember to call my dentist tomorrow at 2 PM';

        // Mock AI response that creates both a task and a reminder
        when(mockChatService.sendMessage(
          message: userMessage,
          history: any,
          contextItem: any,
        )).thenAnswer((_) async => ChatResponse(
          aiResponseText: 'I\'ve created a task to call your dentist and set a reminder for tomorrow at 2 PM.',
          actionMetadata: {
            'type': 'create_task_and_reminder',
            'data': {
              'task': {'description': 'Call dentist', 'priority': 'medium'},
              'reminder': {'title': 'Call dentist', 'time': '14:00'}
            }
          },
        ));

        // Mock data creation
        final createdTask = Task(
          id: 'task-dentist',
          userId: 'user-123',
          description: 'Call dentist',
          priority: TaskPriority.medium,
          completed: false,
          dueDate: DateTime.now().add(const Duration(days: 1)),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final createdReminder = Reminder(
          id: 'reminder-dentist',
          userId: 'user-123',
          title: 'Call dentist',
          scheduledTime: DateTime.now().add(const Duration(days: 1, hours: 14)),
          completed: false,
          createdAt: DateTime.now(),
        );

        when(mockTasksRepository.getAllTasks()).thenAnswer((_) async => [createdTask]);
        when(mockRemindersRepository.getAllReminders()).thenAnswer((_) async => [createdReminder]);
        when(mockChatService.saveMessage(any)).thenAnswer((_) async {});

        // Send the message
        await tester.enterText(find.byType(TextField), userMessage);
        await tester.tap(find.byIcon(Icons.send));
        await tester.pumpAndSettle();

        // Step 2: Verify AI response
        expect(find.textContaining('I\'ve created a task'), findsOneWidget);
        expect(find.textContaining('call your dentist'), findsOneWidget);

        // Step 3: Verify task was created by navigating to tasks
        await tester.tap(find.text('Tasks'));
        await tester.pumpAndSettle();

        expect(find.text('Call dentist'), findsOneWidget);

        // Step 4: Verify reminder was created
        await tester.tap(find.text('Reminders'));
        await tester.pumpAndSettle();

        expect(find.text('Call dentist'), findsOneWidget);
        expect(find.textContaining('2:00 PM'), findsOneWidget);

        // Step 5: Continue conversation to modify the task
        await tester.tap(find.text('Chat'));
        await tester.pumpAndSettle();

        const followUpMessage = 'Actually, make that high priority';

        when(mockChatService.sendMessage(
          message: followUpMessage,
          history: any,
          contextItem: any,
        )).thenAnswer((_) async => ChatResponse(
          aiResponseText: 'I\'ve updated the task priority to high.',
          actionMetadata: {
            'type': 'update_task',
            'data': {'id': 'task-dentist', 'priority': 'high'}
          },
        ));

        final updatedTask = createdTask.copyWith(
          priority: TaskPriority.high,
          updatedAt: DateTime.now(),
        );

        when(mockTasksRepository.getAllTasks()).thenAnswer((_) async => [updatedTask]);

        await tester.enterText(find.byType(TextField), followUpMessage);
        await tester.tap(find.byIcon(Icons.send));
        await tester.pumpAndSettle();

        // Step 6: Verify task was updated
        await tester.tap(find.text('Tasks'));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.priority_high), findsOneWidget);

        // Verify all interactions
        verify(mockChatService.sendMessage(message: userMessage, history: any, contextItem: any)).called(1);
        verify(mockChatService.sendMessage(message: followUpMessage, history: any, contextItem: any)).called(1);
        verify(mockTasksRepository.getAllTasks()).called(atLeast(2));
        verify(mockRemindersRepository.getAllReminders()).called(atLeast(1));
      });
    });

    group('Offline-to-Online Sync Journey', () {
      testWidgets('should handle offline operations and sync when online', 
          (WidgetTester tester) async {
        // Start offline
        when(mockConnectivityService.isConnected).thenReturn(false);
        when(mockConnectivityService.connectionStream).thenAnswer((_) => Stream.value(false));

        when(mockTasksRepository.getAllTasks()).thenAnswer((_) async => []);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authServiceProvider.overrideWithValue(mockAuthService),
              tasksRepositoryProvider.overrideWithValue(mockTasksRepository),
              connectivityServiceProvider.overrideWithValue(mockConnectivityService),
            ],
            child: const RevaApp(),
          ),
        );

        await tester.pumpAndSettle();

        // Step 1: Verify offline status is shown
        expect(find.text('Offline'), findsOneWidget);
        expect(find.byIcon(Icons.cloud_off), findsOneWidget);

        // Step 2: Try to create a task while offline
        await tester.tap(find.text('Tasks'));
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.add));
        await tester.pumpAndSettle();

        // Should show offline warning
        expect(find.textContaining('offline'), findsOneWidget);

        // Create task anyway (should be cached locally)
        await tester.enterText(
          find.widgetWithText(TextField, 'Task description'),
          'Offline task',
        );

        // Mock local storage
        final offlineTask = Task(
          id: 'offline-task',
          userId: 'user-123',
          description: 'Offline task',
          priority: TaskPriority.medium,
          completed: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        when(mockTasksRepository.createTask(any)).thenAnswer((_) async => offlineTask);
        when(mockTasksRepository.getAllTasks()).thenAnswer((_) async => [offlineTask]);

        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();

        // Task should be created locally
        expect(find.text('Offline task'), findsOneWidget);
        expect(find.byIcon(Icons.sync_disabled), findsOneWidget); // Unsynced indicator

        // Step 3: Go back online
        when(mockConnectivityService.isConnected).thenReturn(true);
        
        // Simulate connectivity change
        final connectivityController = StreamController<bool>();
        when(mockConnectivityService.connectionStream)
            .thenAnswer((_) => connectivityController.stream);

        connectivityController.add(true);
        await tester.pumpAndSettle();

        // Step 4: Verify online status and sync
        expect(find.text('Online'), findsOneWidget);
        expect(find.byIcon(Icons.cloud_done), findsOneWidget);

        // Sync should happen automatically
        expect(find.byIcon(Icons.sync), findsOneWidget); // Synced indicator

        // Step 5: Verify data is now synced
        await tester.pump(const Duration(seconds: 2)); // Wait for sync
        expect(find.byIcon(Icons.sync_disabled), findsNothing); // No more unsynced items

        connectivityController.close();

        verify(mockTasksRepository.createTask(any)).called(1);
        verify(mockTasksRepository.getAllTasks()).called(atLeast(2));
      });
    });

    group('Multi-Screen Data Consistency Journey', () {
      testWidgets('should maintain data consistency across all screens', 
          (WidgetTester tester) async {
        // Setup initial data
        final initialTask = Task(
          id: 'consistent-task',
          userId: 'user-123',
          description: 'Consistent task',
          priority: TaskPriority.medium,
          completed: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        when(mockTasksRepository.getAllTasks()).thenAnswer((_) async => [initialTask]);
        when(mockChatService.getMessageHistory()).thenAnswer((_) async => [
          ChatMessage.assistant(
            id: 'msg-1',
            content: 'I created a task for you: Consistent task',
            metadata: {
              'contextItemId': 'consistent-task',
              'contextItemType': 'task',
            },
          ),
        ]);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authServiceProvider.overrideWithValue(mockAuthService),
              chatServiceProvider.overrideWithValue(mockChatService),
              tasksRepositoryProvider.overrideWithValue(mockTasksRepository),
              connectivityServiceProvider.overrideWithValue(mockConnectivityService),
            ],
            child: const RevaApp(),
          ),
        );

        await tester.pumpAndSettle();

        // Step 1: Verify task reference in chat
        expect(find.textContaining('Consistent task'), findsOneWidget);

        // Step 2: Navigate to tasks and verify task exists
        await tester.tap(find.text('Tasks'));
        await tester.pumpAndSettle();

        expect(find.text('Consistent task'), findsOneWidget);
        expect(find.byIcon(Icons.circle_outlined), findsOneWidget); // Incomplete

        // Step 3: Complete the task
        final completedTask = initialTask.copyWith(
          completed: true,
          updatedAt: DateTime.now(),
        );

        when(mockTasksRepository.updateTask(any, any)).thenAnswer((_) async => completedTask);
        when(mockTasksRepository.getAllTasks()).thenAnswer((_) async => [completedTask]);

        await tester.tap(find.byIcon(Icons.circle_outlined));
        await tester.pumpAndSettle();

        // Verify task is completed
        expect(find.byIcon(Icons.check_circle), findsOneWidget);

        // Step 4: Navigate back to chat
        await tester.tap(find.text('Chat'));
        await tester.pumpAndSettle();

        // The chat message should still reference the same task
        expect(find.textContaining('Consistent task'), findsOneWidget);

        // Step 5: Navigate to a different screen and back
        await tester.tap(find.text('Expenses'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Tasks'));
        await tester.pumpAndSettle();

        // Task should still be completed
        expect(find.byIcon(Icons.check_circle), findsOneWidget);

        // Verify consistency was maintained
        verify(mockTasksRepository.updateTask(any, any)).called(1);
        verify(mockTasksRepository.getAllTasks()).called(atLeast(3));
      });
    });

    group('Error Recovery Journey', () {
      testWidgets('should recover gracefully from errors and continue functioning', 
          (WidgetTester tester) async {
        when(mockTasksRepository.getAllTasks()).thenAnswer((_) async => []);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authServiceProvider.overrideWithValue(mockAuthService),
              tasksRepositoryProvider.overrideWithValue(mockTasksRepository),
              connectivityServiceProvider.overrideWithValue(mockConnectivityService),
            ],
            child: const RevaApp(),
          ),
        );

        await tester.pumpAndSettle();

        // Step 1: Navigate to tasks
        await tester.tap(find.text('Tasks'));
        await tester.pumpAndSettle();

        // Step 2: Try to create a task that fails
        await tester.tap(find.byIcon(Icons.add));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(TextField, 'Task description'),
          'Task that will fail',
        );

        // Mock creation failure
        when(mockTasksRepository.createTask(any))
            .thenThrow(Exception('Network error'));

        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();

        // Step 3: Should show error message
        expect(find.textContaining('error'), findsOneWidget);
        expect(find.text('Retry'), findsOneWidget);

        // Step 4: Retry the operation
        when(mockTasksRepository.createTask(any)).thenAnswer((_) async => Task(
          id: 'recovered-task',
          userId: 'user-123',
          description: 'Task that will fail',
          priority: TaskPriority.medium,
          completed: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));

        when(mockTasksRepository.getAllTasks()).thenAnswer((_) async => [
          Task(
            id: 'recovered-task',
            userId: 'user-123',
            description: 'Task that will fail',
            priority: TaskPriority.medium,
            completed: false,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ]);

        await tester.tap(find.text('Retry'));
        await tester.pumpAndSettle();

        // Step 5: Should succeed and show the task
        expect(find.text('Task that will fail'), findsOneWidget);
        expect(find.textContaining('error'), findsNothing);

        // Step 6: Verify app continues to function normally
        await tester.tap(find.text('Chat'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Tasks'));
        await tester.pumpAndSettle();

        // Task should still be there
        expect(find.text('Task that will fail'), findsOneWidget);

        verify(mockTasksRepository.createTask(any)).called(2); // Failed once, succeeded once
      });
    });
  });
}
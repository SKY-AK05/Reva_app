import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/providers.dart';

import '../../screens/auth/login_screen.dart';
import '../../screens/auth/signup_screen.dart';
import '../../screens/chat/chat_screen.dart';
import '../../screens/settings/settings_screen.dart';
import '../../screens/tasks/tasks_screen.dart';
import '../../screens/tasks/add_task_screen.dart';
import '../../screens/expenses/expenses_screen.dart';
import '../../screens/expenses/add_expense_screen.dart';
import '../../screens/reminders/reminders_screen.dart';
import '../../screens/reminders/add_reminder_screen.dart';
import 'app_shell.dart';
import 'route_wrappers.dart';

// Route names for easy reference
class AppRoutes {
  static const String login = '/login';
  static const String signup = '/signup';
  static const String chat = '/';
  static const String settings = '/settings';
  static const String tasks = '/tasks';
  static const String addTask = '/tasks/add';
  static const String editTask = '/tasks/edit';
  static const String taskDetail = '/tasks/detail';
  static const String expenses = '/expenses';
  static const String addExpense = '/expenses/add';
  static const String editExpense = '/expenses/edit';
  static const String expenseDetail = '/expenses/detail';
  static const String reminders = '/reminders';
  static const String addReminder = '/reminders/add';
  static const String editReminder = '/reminders/edit';
  static const String reminderDetail = '/reminders/detail';
}

// Router provider
final routerProvider = Provider<GoRouter>((ref) {
  final isAuthenticated = ref.watch(isAuthenticatedProvider);
  final authLoading = ref.watch(authLoadingProvider);

  return GoRouter(
    initialLocation: AppRoutes.chat,
    redirect: (context, state) {
      // Don't redirect while auth is loading
      if (authLoading) return null;

      final isAuthRoute = state.matchedLocation == AppRoutes.login || 
                         state.matchedLocation == AppRoutes.signup;

      // If not authenticated and not on auth route, redirect to login
      if (!isAuthenticated && !isAuthRoute) {
        return AppRoutes.login;
      }

      // If authenticated and on auth route, redirect to chat
      if (isAuthenticated && isAuthRoute) {
        return AppRoutes.chat;
      }

      return null;
    },
    routes: [
      // Authentication routes (no shell)
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.signup,
        name: 'signup',
        builder: (context, state) => const SignUpScreen(),
      ),

      // Main app routes with shell navigation
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          // Chat (Home) route
          GoRoute(
            path: AppRoutes.chat,
            name: 'chat',
            builder: (context, state) {
              // Handle query parameters for deep linking
              final contextId = state.uri.queryParameters['contextId'];
              final message = state.uri.queryParameters['message'];
              
              return ChatScreen(
                initialContextId: contextId,
                initialMessage: message,
              );
            },
          ),

          // Settings route
          GoRoute(
            path: AppRoutes.settings,
            name: 'settings',
            builder: (context, state) => const SettingsScreen(),
          ),

          // Tasks routes
          GoRoute(
            path: AppRoutes.tasks,
            name: 'tasks',
            builder: (context, state) => const TasksScreen(),
            routes: [
              GoRoute(
                path: 'add',
                name: 'add-task',
                builder: (context, state) => const AddTaskScreen(),
              ),
              GoRoute(
                path: 'edit/:id',
                name: 'edit-task',
                builder: (context, state) {
                  final taskId = state.pathParameters['id']!;
                  return EditTaskWrapper(taskId: taskId);
                },
              ),
              GoRoute(
                path: 'detail/:id',
                name: 'task-detail',
                builder: (context, state) {
                  final taskId = state.pathParameters['id']!;
                  return TaskDetailWrapper(taskId: taskId);
                },
              ),
            ],
          ),

          // Expenses routes
          GoRoute(
            path: AppRoutes.expenses,
            name: 'expenses',
            builder: (context, state) => const ExpensesScreen(),
            routes: [
              GoRoute(
                path: 'add',
                name: 'add-expense',
                builder: (context, state) => const AddExpenseScreen(),
              ),
              GoRoute(
                path: 'edit/:id',
                name: 'edit-expense',
                builder: (context, state) {
                  final expenseId = state.pathParameters['id']!;
                  return EditExpenseWrapper(expenseId: expenseId);
                },
              ),
              GoRoute(
                path: 'detail/:id',
                name: 'expense-detail',
                builder: (context, state) {
                  final expenseId = state.pathParameters['id']!;
                  return ExpenseDetailWrapper(expenseId: expenseId);
                },
              ),
            ],
          ),

          // Reminders routes
          GoRoute(
            path: AppRoutes.reminders,
            name: 'reminders',
            builder: (context, state) => const RemindersScreen(),
            routes: [
              GoRoute(
                path: 'add',
                name: 'add-reminder',
                builder: (context, state) => const AddReminderScreen(),
              ),
              GoRoute(
                path: 'edit/:id',
                name: 'edit-reminder',
                builder: (context, state) {
                  final reminderId = state.pathParameters['id']!;
                  return EditReminderWrapper(reminderId: reminderId);
                },
              ),
              GoRoute(
                path: 'detail/:id',
                name: 'reminder-detail',
                builder: (context, state) {
                  final reminderId = state.pathParameters['id']!;
                  return ReminderDetailWrapper(reminderId: reminderId);
                },
              ),
            ],
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              'Page not found',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'The page you are looking for does not exist.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go(AppRoutes.chat),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    ),
  );
});
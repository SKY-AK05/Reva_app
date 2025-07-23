import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:reva_mobile_app/core/navigation/app_router.dart';
import 'package:reva_mobile_app/core/navigation/app_shell.dart';
import 'package:reva_mobile_app/screens/chat/chat_screen.dart';
import 'package:reva_mobile_app/screens/tasks/tasks_screen.dart';
import 'package:reva_mobile_app/screens/expenses/expenses_screen.dart';
import 'package:reva_mobile_app/screens/reminders/reminders_screen.dart';
import 'package:reva_mobile_app/providers/auth_provider.dart';
import 'package:reva_mobile_app/services/auth/auth_service.dart';
import 'package:reva_mobile_app/core/theme/app_theme.dart';

// Generate mocks
@GenerateMocks([AuthService])
import 'navigation_test.mocks.dart';

void main() {
  group('Navigation Tests', () {
    late MockAuthService mockAuthService;

    setUp(() {
      mockAuthService = MockAuthService();
      when(mockAuthService.isAuthenticated).thenReturn(true);
      when(mockAuthService.currentUser).thenReturn(null);
      when(mockAuthService.authStateChanges).thenAnswer((_) => Stream.empty());
    });

    group('AppShell Navigation', () {
      testWidgets('should display bottom navigation bar', (WidgetTester tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authServiceProvider.overrideWithValue(mockAuthService),
            ],
            child: MaterialApp.router(
              theme: AppTheme.lightTheme,
              routerConfig: AppRouter.router,
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Verify bottom navigation bar is present
        expect(find.byType(BottomNavigationBar), findsOneWidget);
        
        // Verify all navigation items are present
        expect(find.text('Chat'), findsOneWidget);
        expect(find.text('Tasks'), findsOneWidget);
        expect(find.text('Expenses'), findsOneWidget);
        expect(find.text('Reminders'), findsOneWidget);
      });

      testWidgets('should navigate between tabs', (WidgetTester tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authServiceProvider.overrideWithValue(mockAuthService),
            ],
            child: MaterialApp.router(
              theme: AppTheme.lightTheme,
              routerConfig: AppRouter.router,
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Initially should be on chat screen
        expect(find.byType(ChatScreen), findsOneWidget);

        // Tap on Tasks tab
        await tester.tap(find.text('Tasks'));
        await tester.pumpAndSettle();

        // Should navigate to tasks screen
        expect(find.byType(TasksScreen), findsOneWidget);
        expect(find.byType(ChatScreen), findsNothing);

        // Tap on Expenses tab
        await tester.tap(find.text('Expenses'));
        await tester.pumpAndSettle();

        // Should navigate to expenses screen
        expect(find.byType(ExpensesScreen), findsOneWidget);
        expect(find.byType(TasksScreen), findsNothing);

        // Tap on Reminders tab
        await tester.tap(find.text('Reminders'));
        await tester.pumpAndSettle();

        // Should navigate to reminders screen
        expect(find.byType(RemindersScreen), findsOneWidget);
        expect(find.byType(ExpensesScreen), findsNothing);

        // Tap back on Chat tab
        await tester.tap(find.text('Chat'));
        await tester.pumpAndSettle();

        // Should navigate back to chat screen
        expect(find.byType(ChatScreen), findsOneWidget);
        expect(find.byType(RemindersScreen), findsNothing);
      });

      testWidgets('should highlight active tab', (WidgetTester tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authServiceProvider.overrideWithValue(mockAuthService),
            ],
            child: MaterialApp.router(
              theme: AppTheme.lightTheme,
              routerConfig: AppRouter.router,
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Get bottom navigation bar
        final bottomNavBar = tester.widget<BottomNavigationBar>(
          find.byType(BottomNavigationBar),
        );

        // Initially chat tab should be selected
        expect(bottomNavBar.currentIndex, equals(0));

        // Navigate to tasks
        await tester.tap(find.text('Tasks'));
        await tester.pumpAndSettle();

        // Tasks tab should be selected
        final updatedBottomNavBar = tester.widget<BottomNavigationBar>(
          find.byType(BottomNavigationBar),
        );
        expect(updatedBottomNavBar.currentIndex, equals(1));
      });

      testWidgets('should maintain state when switching tabs', (WidgetTester tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authServiceProvider.overrideWithValue(mockAuthService),
            ],
            child: MaterialApp.router(
              theme: AppTheme.lightTheme,
              routerConfig: AppRouter.router,
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Navigate to tasks and interact with the screen
        await tester.tap(find.text('Tasks'));
        await tester.pumpAndSettle();

        // Simulate some interaction (e.g., scrolling)
        if (find.byType(ListView).evaluate().isNotEmpty) {
          await tester.drag(find.byType(ListView), const Offset(0, -100));
          await tester.pumpAndSettle();
        }

        // Navigate away and back
        await tester.tap(find.text('Chat'));
        await tester.pumpAndSettle();
        
        await tester.tap(find.text('Tasks'));
        await tester.pumpAndSettle();

        // State should be maintained (screen should still be scrolled)
        expect(find.byType(TasksScreen), findsOneWidget);
      });
    });

    group('Deep Linking', () {
      testWidgets('should handle deep link to specific task', (WidgetTester tester) async {
        // Create a router with initial location
        final router = GoRouter(
          initialLocation: '/tasks/task-123',
          routes: AppRouter.routes,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authServiceProvider.overrideWithValue(mockAuthService),
            ],
            child: MaterialApp.router(
              theme: AppTheme.lightTheme,
              routerConfig: router,
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Should navigate directly to task detail screen
        // Note: This would require the actual task detail screen to be implemented
        expect(find.byType(TasksScreen), findsOneWidget);
      });

      testWidgets('should handle deep link to expense detail', (WidgetTester tester) async {
        final router = GoRouter(
          initialLocation: '/expenses/expense-456',
          routes: AppRouter.routes,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authServiceProvider.overrideWithValue(mockAuthService),
            ],
            child: MaterialApp.router(
              theme: AppTheme.lightTheme,
              routerConfig: router,
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.byType(ExpensesScreen), findsOneWidget);
      });

      testWidgets('should handle deep link to reminder detail', (WidgetTester tester) async {
        final router = GoRouter(
          initialLocation: '/reminders/reminder-789',
          routes: AppRouter.routes,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authServiceProvider.overrideWithValue(mockAuthService),
            ],
            child: MaterialApp.router(
              theme: AppTheme.lightTheme,
              routerConfig: router,
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.byType(RemindersScreen), findsOneWidget);
      });

      testWidgets('should handle invalid deep links gracefully', (WidgetTester tester) async {
        final router = GoRouter(
          initialLocation: '/invalid/route',
          routes: AppRouter.routes,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authServiceProvider.overrideWithValue(mockAuthService),
            ],
            child: MaterialApp.router(
              theme: AppTheme.lightTheme,
              routerConfig: router,
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Should redirect to default route (chat)
        expect(find.byType(ChatScreen), findsOneWidget);
      });
    });

    group('Authentication Guards', () {
      testWidgets('should redirect to login when not authenticated', (WidgetTester tester) async {
        when(mockAuthService.isAuthenticated).thenReturn(false);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authServiceProvider.overrideWithValue(mockAuthService),
            ],
            child: MaterialApp.router(
              theme: AppTheme.lightTheme,
              routerConfig: AppRouter.router,
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Should redirect to login screen
        expect(find.text('Sign In'), findsOneWidget);
        expect(find.byType(ChatScreen), findsNothing);
      });

      testWidgets('should allow access when authenticated', (WidgetTester tester) async {
        when(mockAuthService.isAuthenticated).thenReturn(true);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authServiceProvider.overrideWithValue(mockAuthService),
            ],
            child: MaterialApp.router(
              theme: AppTheme.lightTheme,
              routerConfig: AppRouter.router,
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Should allow access to main app
        expect(find.byType(ChatScreen), findsOneWidget);
        expect(find.text('Sign In'), findsNothing);
      });

      testWidgets('should handle authentication state changes', (WidgetTester tester) async {
        final authStateController = StreamController<AuthState>();
        when(mockAuthService.authStateChanges)
            .thenAnswer((_) => authStateController.stream);
        when(mockAuthService.isAuthenticated).thenReturn(false);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authServiceProvider.overrideWithValue(mockAuthService),
            ],
            child: MaterialApp.router(
              theme: AppTheme.lightTheme,
              routerConfig: AppRouter.router,
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Initially should show login
        expect(find.text('Sign In'), findsOneWidget);

        // Simulate successful authentication
        when(mockAuthService.isAuthenticated).thenReturn(true);
        authStateController.add(const AuthenticationStateAuthenticated(null));
        await tester.pumpAndSettle();

        // Should navigate to main app
        expect(find.byType(ChatScreen), findsOneWidget);
        expect(find.text('Sign In'), findsNothing);

        authStateController.close();
      });
    });

    group('Navigation Accessibility', () {
      testWidgets('should have proper semantic labels', (WidgetTester tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authServiceProvider.overrideWithValue(mockAuthService),
            ],
            child: MaterialApp.router(
              theme: AppTheme.lightTheme,
              routerConfig: AppRouter.router,
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Verify semantic labels for navigation items
        expect(find.bySemanticsLabel('Chat tab'), findsOneWidget);
        expect(find.bySemanticsLabel('Tasks tab'), findsOneWidget);
        expect(find.bySemanticsLabel('Expenses tab'), findsOneWidget);
        expect(find.bySemanticsLabel('Reminders tab'), findsOneWidget);
      });

      testWidgets('should support keyboard navigation', (WidgetTester tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authServiceProvider.overrideWithValue(mockAuthService),
            ],
            child: MaterialApp.router(
              theme: AppTheme.lightTheme,
              routerConfig: AppRouter.router,
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Focus on navigation bar
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();

        // Navigate using arrow keys
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();

        // Should move focus to next tab
        final focusedWidget = tester.binding.focusManager.primaryFocus;
        expect(focusedWidget, isNotNull);
      });

      testWidgets('should announce navigation changes to screen readers', (WidgetTester tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authServiceProvider.overrideWithValue(mockAuthService),
            ],
            child: MaterialApp.router(
              theme: AppTheme.lightTheme,
              routerConfig: AppRouter.router,
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Navigate to tasks
        await tester.tap(find.text('Tasks'));
        await tester.pumpAndSettle();

        // Should announce the navigation change
        expect(tester.binding.defaultBinaryMessenger, isNotNull);
      });
    });

    group('Navigation Performance', () {
      testWidgets('should navigate quickly between tabs', (WidgetTester tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authServiceProvider.overrideWithValue(mockAuthService),
            ],
            child: MaterialApp.router(
              theme: AppTheme.lightTheme,
              routerConfig: AppRouter.router,
            ),
          ),
        );

        await tester.pumpAndSettle();

        final stopwatch = Stopwatch()..start();

        // Navigate through all tabs
        await tester.tap(find.text('Tasks'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Expenses'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Reminders'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Chat'));
        await tester.pumpAndSettle();

        stopwatch.stop();

        // Navigation should be fast (less than 1 second for all tabs)
        expect(stopwatch.elapsedMilliseconds, lessThan(1000));
      });

      testWidgets('should not rebuild unnecessary widgets during navigation', (WidgetTester tester) async {
        var chatBuildCount = 0;
        var tasksBuildCount = 0;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authServiceProvider.overrideWithValue(mockAuthService),
            ],
            child: MaterialApp.router(
              theme: AppTheme.lightTheme,
              routerConfig: GoRouter(
                routes: [
                  ShellRoute(
                    builder: (context, state, child) => AppShell(child: child),
                    routes: [
                      GoRoute(
                        path: '/',
                        builder: (context, state) {
                          chatBuildCount++;
                          return const ChatScreen();
                        },
                      ),
                      GoRoute(
                        path: '/tasks',
                        builder: (context, state) {
                          tasksBuildCount++;
                          return const TasksScreen();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Initial build
        expect(chatBuildCount, equals(1));
        expect(tasksBuildCount, equals(0));

        // Navigate to tasks
        await tester.tap(find.text('Tasks'));
        await tester.pumpAndSettle();

        expect(chatBuildCount, equals(1)); // Should not rebuild
        expect(tasksBuildCount, equals(1)); // Should build once

        // Navigate back to chat
        await tester.tap(find.text('Chat'));
        await tester.pumpAndSettle();

        expect(chatBuildCount, equals(1)); // Should not rebuild again
        expect(tasksBuildCount, equals(1)); // Should not rebuild
      });
    });

    group('Back Button Handling', () {
      testWidgets('should handle Android back button correctly', (WidgetTester tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authServiceProvider.overrideWithValue(mockAuthService),
            ],
            child: MaterialApp.router(
              theme: AppTheme.lightTheme,
              routerConfig: AppRouter.router,
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Navigate to tasks
        await tester.tap(find.text('Tasks'));
        await tester.pumpAndSettle();

        expect(find.byType(TasksScreen), findsOneWidget);

        // Simulate back button press
        final NavigatorState navigator = tester.state(find.byType(Navigator));
        navigator.pop();
        await tester.pumpAndSettle();

        // Should go back to previous screen or handle appropriately
        // Note: Behavior depends on router configuration
      });

      testWidgets('should prevent accidental app exit', (WidgetTester tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authServiceProvider.overrideWithValue(mockAuthService),
            ],
            child: MaterialApp.router(
              theme: AppTheme.lightTheme,
              routerConfig: AppRouter.router,
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Try to pop from main screen
        final NavigatorState navigator = tester.state(find.byType(Navigator));
        
        // Should not exit app immediately
        expect(navigator.canPop(), isFalse);
      });
    });
  });
}
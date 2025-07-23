import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/providers.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/logout_button.dart';
import '../animations/app_animations.dart';
import '../accessibility/accessibility_utils.dart';
import '../responsive/responsive_utils.dart';
import 'app_router.dart';

class AppShell extends ConsumerStatefulWidget {
  final Widget child;

  const AppShell({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  // Removed bottom navigation - chat is the main interface

  // Removed navigation logic since we only have chat as main interface

  bool _canPop() {
    // Allow popping for all screens except chat (main screen)
    final location = GoRouterState.of(context).matchedLocation;
    
    // If we're on chat screen, don't allow popping (will exit app)
    if (location == AppRoutes.chat) {
      return false;
    }
    
    // Allow popping for all other screens
    return true;
  }

  void _onPopInvoked(bool didPop, Object? result) {
    if (!didPop) {
      final location = GoRouterState.of(context).matchedLocation;
      
      // If we're on chat screen and user pressed back, show exit confirmation
      if (location == AppRoutes.chat) {
        _handleMainScreenBackPress();
      }
    }
  }

  void _handleMainScreenBackPress() {
    // Show exit confirmation when on chat screen
    showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exit App'),
        content: const Text('Are you sure you want to exit Reva?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(true);
              SystemNavigator.pop(); // Exit the app
            },
            child: const Text('Exit'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _canPop(),
      onPopInvokedWithResult: _onPopInvoked,
      child: Scaffold(
        appBar: _buildAppBar(context),
        body: _buildBody(context),
        bottomNavigationBar: _buildBottomNavigationBar(context),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    
    // Show different app bars based on location
    if (location == AppRoutes.settings) {
      return AppBar(
        title: const Text('Settings'),
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
      );
    }
    
    // For chat screen - clean minimal app bar
    return AppBar(
      title: const Text('Reva'),
      elevation: 0,
      backgroundColor: Theme.of(context).colorScheme.surface,
      foregroundColor: Theme.of(context).colorScheme.onSurface,
      actions: [
        Builder(
          builder: (context) {
            final user = ref.watch(currentUserStateProvider);
            String? avatarUrl = user?.userMetadata?['avatar_url'] as String?;
            String? fullName = user?.userMetadata?['full_name'] as String?;
            String? email = user?.email;
            String initials = '';
            if (fullName != null && fullName.trim().isNotEmpty) {
              var parts = fullName.trim().split(' ');
              initials = parts.length > 1
                  ? (parts[0][0] + parts[1][0])
                  : parts[0][0];
            } else if (email != null && email.isNotEmpty) {
              initials = email[0].toUpperCase();
            } else {
              initials = '?';
            }
            return IconButton(
              onPressed: () => context.push(AppRoutes.settings),
              tooltip: 'Profile & Settings',
              icon: avatarUrl != null && avatarUrl.isNotEmpty
                  ? CircleAvatar(
                      backgroundImage: NetworkImage(avatarUrl),
                      radius: 16,
                    )
                  : CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      radius: 16,
                      child: Text(
                        initials,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context) {
    // Simple body without navigation transitions
    return widget.child;
  }

  Widget? _buildBottomNavigationBar(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    
    // Don't show bottom navigation on settings screen to keep it clean
    if (location == AppRoutes.settings) {
      return null;
    }
    
    // Determine current index based on location
    int currentIndex = 0;
    if (location == AppRoutes.chat) {
      currentIndex = 0;
    } else if (location.startsWith('/tasks')) {
      currentIndex = 1;
    } else if (location.startsWith('/expenses')) {
      currentIndex = 2;
    } else if (location.startsWith('/reminders')) {
      currentIndex = 3;
    }
    
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      currentIndex: currentIndex,
      onTap: (index) => _onBottomNavTap(context, index),
      selectedItemColor: Theme.of(context).colorScheme.primary,
      unselectedItemColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
      backgroundColor: Theme.of(context).colorScheme.surface,
      elevation: 8,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.chat_outlined),
          activeIcon: Icon(Icons.chat),
          label: 'Chat',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.task_outlined),
          activeIcon: Icon(Icons.task),
          label: 'Tasks',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.receipt_outlined),
          activeIcon: Icon(Icons.receipt),
          label: 'Expenses',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.notifications_outlined),
          activeIcon: Icon(Icons.notifications),
          label: 'Reminders',
        ),
      ],
    );
  }

  void _onBottomNavTap(BuildContext context, int index) {
    // Provide haptic feedback
    HapticFeedback.lightImpact();
    
    switch (index) {
      case 0:
        context.go(AppRoutes.chat);
        break;
      case 1:
        context.go(AppRoutes.tasks);
        break;
      case 2:
        context.go(AppRoutes.expenses);
        break;
      case 3:
        context.go(AppRoutes.reminders);
        break;
    }
  }
}
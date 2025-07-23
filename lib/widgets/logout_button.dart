import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../utils/logger.dart';

class LogoutButton extends ConsumerWidget {
  final bool showText;
  final IconData? icon;
  
  const LogoutButton({
    super.key,
    this.showText = true,
    this.icon,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authNotifier = ref.read(authNotifierProvider.notifier);
    final isLoading = ref.watch(authLoadingStateProvider);
    
    void handleLogout() async {
      try {
        // Show confirmation dialog
        final shouldLogout = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Sign Out'),
            content: const Text('Are you sure you want to sign out?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Sign Out'),
              ),
            ],
          ),
        );
        
        if (shouldLogout == true) {
          await authNotifier.signOut();
          Logger.info('User signed out successfully');
        }
      } catch (e) {
        Logger.error('Logout error: $e');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to sign out. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
    
    if (showText) {
      return TextButton.icon(
        onPressed: isLoading ? null : handleLogout,
        icon: Icon(icon ?? Icons.logout),
        label: const Text('Sign Out'),
      );
    } else {
      return IconButton(
        onPressed: isLoading ? null : handleLogout,
        icon: Icon(icon ?? Icons.logout),
        tooltip: 'Sign Out',
      );
    }
  }
}
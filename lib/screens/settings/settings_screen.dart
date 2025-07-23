import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/providers.dart';
import '../../providers/chat_provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/animations/app_animations.dart';
import '../../core/accessibility/accessibility_utils.dart';
import '../../widgets/logout_button.dart';
import '../../widgets/debug/database_health_widget.dart';
import '../../utils/logger.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDarkMode = ref.watch(themeModeProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // App Information Section
          _buildSection(
            context,
            title: 'App',
            children: [
              _buildListTile(
                context,
                icon: Icons.info_outline,
                title: 'About Reva',
                subtitle: 'AI-powered productivity assistant',
                onTap: () {
                  _showAboutDialog(context);
                },
              ),
              _buildListTile(
                context,
                icon: Icons.article_outlined,
                title: 'Privacy Policy',
                onTap: () {
                  // TODO: Navigate to privacy policy
                },
              ),
              _buildListTile(
                context,
                icon: Icons.description_outlined,
                title: 'Terms of Service',
                onTap: () {
                  // TODO: Navigate to terms of service
                },
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Appearance Section
          _buildSection(
            context,
            title: 'Appearance',
            children: [
              _buildListTile(
                context,
                icon: isDarkMode ? Icons.dark_mode : Icons.light_mode,
                title: 'Theme',
                subtitle: isDarkMode ? 'Dark Mode' : 'Light Mode',
                trailing: Switch(
                  value: isDarkMode,
                  onChanged: (value) {
                    AccessibilityUtils.provideFeedback(HapticFeedbackType.lightImpact);
                    ref.read(themeModeProvider.notifier).state = value;
                    
                    // Announce theme change
                    AccessibilityUtils.announceToScreenReader(
                      context,
                      value ? 'Switched to dark mode' : 'Switched to light mode',
                    );
                  },
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Chat Section
          _buildSection(
            context,
            title: 'Chat',
            children: [
              Consumer(
                builder: (context, ref, child) {
                  final chatState = ref.watch(chatProvider);
                  return _buildListTile(
                    context,
                    icon: Icons.refresh,
                    title: 'Refresh Messages',
                    subtitle: 'Sync latest messages from server',
                    onTap: chatState.isLoading ? null : () {
                      ref.read(chatProvider.notifier).refreshMessages();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Messages refreshed')),
                      );
                    },
                  );
                },
              ),
              Consumer(
                builder: (context, ref, child) {
                  final chatState = ref.watch(chatProvider);
                  return _buildListTile(
                    context,
                    icon: chatState.isOffline ? Icons.cloud_off : Icons.cloud_done,
                    title: 'Sync Status',
                    subtitle: chatState.isOffline 
                        ? 'Offline - ${chatState.unsyncedMessages.length} messages pending'
                        : chatState.unsyncedMessages.isNotEmpty
                            ? '${chatState.unsyncedMessages.length} messages syncing'
                            : 'All messages synced',
                    onTap: () {
                      _showSyncStatusDialog(context, ref);
                    },
                  );
                },
              ),
              _buildListTile(
                context,
                icon: Icons.delete_outline,
                title: 'Clear Chat History',
                subtitle: 'Remove all chat messages',
                titleColor: Colors.orange,
                onTap: () {
                  _showClearChatHistoryDialog(context, ref);
                },
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Account Section
          _buildSection(
            context,
            title: 'Account',
            children: [
              _buildListTile(
                context,
                icon: Icons.person_outline,
                title: 'Profile',
                subtitle: 'Manage your account',
                onTap: () {
                  _showProfileDialog(context, ref);
                },
              ),
              _buildListTile(
                context,
                icon: Icons.notifications_outlined,
                title: 'Notifications',
                subtitle: 'Configure push notifications',
                onTap: () {
                  _showNotificationSettingsDialog(context, ref);
                },
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Data & Storage Section
          _buildSection(
            context,
            title: 'Data & Storage',
            children: [
              _buildListTile(
                context,
                icon: Icons.delete_outline,
                title: 'Clear Cache',
                subtitle: 'Free up storage space',
                onTap: () {
                  _showClearCacheDialog(context, ref);
                },
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Database Health (Debug Section)
          const DatabaseHealthWidget(),
          
          const SizedBox(height: 24),
          
          // Support Section
          _buildSection(
            context,
            title: 'Support',
            children: [
              _buildListTile(
                context,
                icon: Icons.help_outline,
                title: 'Help & FAQ',
                onTap: () {
                  // TODO: Navigate to help screen
                },
              ),
              _buildListTile(
                context,
                icon: Icons.feedback_outlined,
                title: 'Send Feedback',
                onTap: () {
                  // TODO: Open feedback form
                },
              ),
              _buildListTile(
                context,
                icon: Icons.bug_report_outlined,
                title: 'Report a Bug',
                onTap: () {
                  // TODO: Open bug report form
                },
              ),
            ],
          ),
          
          const SizedBox(height: 32),
          
          // Logout Section
          _buildSection(
            context,
            title: 'Account Actions',
            children: [
              _buildListTile(
                context,
                icon: Icons.logout,
                title: 'Sign Out',
                titleColor: Colors.red,
                onTap: () {
                  _showLogoutDialog(context, ref);
                },
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // App Version
          Center(
            child: Text(
              'Version 1.0.0',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Card(
          elevation: 0,
          color: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
            ),
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildListTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    Color? titleColor,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: titleColor ?? Theme.of(context).colorScheme.onSurface,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: titleColor ?? Theme.of(context).colorScheme.onSurface,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            )
          : null,
      trailing: trailing,
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About Reva'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reva is an AI-powered productivity assistant that helps you manage tasks, track expenses, and set reminders through natural conversation.',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),
            Text(
              'Features:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text('• Chat with AI assistant'),
            Text('• Task management'),
            Text('• Expense tracking'),
            Text('• Smart reminders'),
            Text('• Real-time sync'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showClearCacheDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cache'),
        content: const Text(
          'This will clear all cached data and free up storage space. Your data will be re-synced from the server.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: Implement cache clearing
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Cache cleared successfully')),
              );
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _showSyncStatusDialog(BuildContext context, WidgetRef ref) {
    final chatState = ref.read(chatProvider);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sync Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  chatState.isOffline ? Icons.cloud_off : Icons.cloud_done,
                  color: chatState.isOffline 
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  chatState.isOffline ? 'Offline Mode' : 'Online',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (chatState.unsyncedMessages.isNotEmpty) ...[
              Text('Pending Messages: ${chatState.unsyncedMessages.length}'),
              const SizedBox(height: 8),
              const Text(
                'These messages will be synced when connection is restored.',
                style: TextStyle(fontSize: 14),
              ),
            ] else if (!chatState.isOffline) ...[
              const Text('All messages are synced successfully.'),
            ],
            if (chatState.isOffline) ...[
              const SizedBox(height: 8),
              const Text(
                'You can continue using the app offline. Messages will sync when connection is restored.',
                style: TextStyle(fontSize: 14),
              ),
            ],
          ],
        ),
        actions: [
          if (!chatState.isOffline && !chatState.isLoading)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                ref.read(chatProvider.notifier).refreshMessages();
              },
              child: const Text('Refresh'),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showClearChatHistoryDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Chat History'),
        content: const Text(
          'Are you sure you want to clear all chat messages? This action cannot be undone and will remove all conversation history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              ref.read(chatProvider.notifier).clearHistory();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Chat history cleared')),
              );
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.orange,
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _showProfileDialog(BuildContext context, WidgetRef ref) {
    final authState = ref.read(authNotifierProvider);
    final user = authState is AuthenticationStateAuthenticated ? authState.user : null;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (user?.email != null) ...[
              const Text(
                'Email:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(user!.email!),
              const SizedBox(height: 16),
            ],
            if (user?.userMetadata?['full_name'] != null) ...[
              const Text(
                'Name:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(user!.userMetadata!['full_name']),
              const SizedBox(height: 16),
            ],
            const Text(
              'Account Status:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Row(
              children: [
                Icon(
                  Icons.verified_user,
                  color: Theme.of(context).colorScheme.primary,
                  size: 16,
                ),
                const SizedBox(width: 4),
                const Text('Active'),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showNotificationSettingsDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notification Settings'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Push notifications help you stay updated with:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Text('• Reminder alerts'),
            Text('• Task due dates'),
            Text('• AI response notifications'),
            Text('• Sync status updates'),
            SizedBox(height: 16),
            Text(
              'To manage notification settings, go to your device Settings > Apps > Reva > Notifications.',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text(
          'Are you sure you want to sign out? You will need to sign in again to access your data.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                await ref.read(authNotifierProvider.notifier).signOut();
                Logger.info('User signed out from settings');
              } catch (e) {
                Logger.error('Logout error from settings: $e');
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Failed to sign out. Please try again.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
} 
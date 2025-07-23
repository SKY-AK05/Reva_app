import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/chat_provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/navigation/app_router.dart';

class ChatAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final VoidCallback? onRefresh;
  final VoidCallback? onClearHistory;

  const ChatAppBar({
    super.key,
    this.onRefresh,
    this.onClearHistory,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatState = ref.watch(chatProvider);
    
    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Reva'),
          if (chatState.isOffline)
            Text(
              'Offline',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            )
          else if (chatState.isSending)
            Text(
              'Sending...',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            )
          else if (chatState.unsyncedMessages.isNotEmpty)
            Text(
              '${chatState.unsyncedMessages.length} pending',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
        ],
      ),
      actions: [
        // Show user avatar or initials
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
}
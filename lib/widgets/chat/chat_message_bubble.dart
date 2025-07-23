import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/chat_message.dart';
import 'action_card.dart';

class ChatMessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isUnsynced;
  final VoidCallback? onRetry;

  const ChatMessageBubble({
    super.key,
    required this.message,
    this.isUnsynced = false,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.isFromUser;
    final theme = Theme.of(context);
    
    return Row(
      mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isUser) _buildAvatar(context),
        if (!isUser) const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              _buildMessageBubble(context, theme, isUser),
              if (message.hasActionMetadata) ...[
                const SizedBox(height: 8),
                ActionCard(
                  actionType: message.actionType!,
                  actionData: message.actionData!,
                ),
              ],
              const SizedBox(height: 4),
              _buildMessageInfo(context, theme, isUser),
            ],
          ),
        ),
        if (isUser) const SizedBox(width: 8),
        if (isUser) _buildAvatar(context),
      ],
    );
  }

  Widget _buildAvatar(BuildContext context) {
    final isUser = message.isFromUser;
    
    return CircleAvatar(
      radius: 16,
      backgroundColor: isUser 
          ? Theme.of(context).colorScheme.primary
          : Theme.of(context).colorScheme.secondary,
      child: Icon(
        isUser ? Icons.person : Icons.smart_toy,
        size: 16,
        color: isUser 
            ? Theme.of(context).colorScheme.onPrimary
            : Theme.of(context).colorScheme.onSecondary,
      ),
    );
  }

  Widget _buildMessageBubble(BuildContext context, ThemeData theme, bool isUser) {
    final backgroundColor = isUser
        ? theme.colorScheme.primary
        : theme.colorScheme.surfaceVariant;
    
    final textColor = isUser
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onSurfaceVariant;

    return GestureDetector(
      onLongPress: () => _showMessageOptions(context),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(18).copyWith(
            bottomLeft: isUser ? const Radius.circular(18) : const Radius.circular(4),
            bottomRight: isUser ? const Radius.circular(4) : const Radius.circular(18),
          ),
          border: isUnsynced
              ? Border.all(
                  color: theme.colorScheme.error.withOpacity(0.5),
                  width: 1,
                )
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.content,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: textColor,
              ),
            ),
            if (isUnsynced) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 16,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Not sent',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: onRetry,
                    child: Text(
                      'Retry',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInfo(BuildContext context, ThemeData theme, bool isUser) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          message.formattedTimestamp,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
        if (message.hasContextItem) ...[
          const SizedBox(width: 4),
          Icon(
            Icons.link,
            size: 12,
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
        ],
      ],
    );
  }

  void _showMessageOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copy message'),
              onTap: () {
                Clipboard.setData(ClipboardData(text: message.content));
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Message copied to clipboard')),
                );
              },
            ),
            if (message.hasActionMetadata)
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('View action details'),
                onTap: () {
                  Navigator.of(context).pop();
                  _showActionDetails(context);
                },
              ),
            if (isUnsynced && onRetry != null)
              ListTile(
                leading: const Icon(Icons.refresh),
                title: const Text('Retry sending'),
                onTap: () {
                  Navigator.of(context).pop();
                  onRetry?.call();
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showActionDetails(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Action: ${message.actionType}'),
        content: SingleChildScrollView(
          child: Text(
            message.actionData.toString(),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
            ),
          ),
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
}
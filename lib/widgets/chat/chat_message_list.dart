import 'package:flutter/material.dart';
import '../../models/chat_message.dart';
import 'chat_message_bubble.dart';
import 'chat_loading_indicator.dart';

class ChatMessageList extends StatelessWidget {
  final List<ChatMessage> messages;
  final bool isLoading;
  final bool hasMoreMessages;
  final List<ChatMessage> unsyncedMessages;
  final ScrollController scrollController;
  final Function(String) onRetryMessage;
  final VoidCallback onLoadMore;

  const ChatMessageList({
    super.key,
    required this.messages,
    required this.isLoading,
    required this.hasMoreMessages,
    required this.unsyncedMessages,
    required this.scrollController,
    required this.onRetryMessage,
    required this.onLoadMore,
  });

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty && !isLoading) {
      return _buildEmptyState(context);
    }

    return RefreshIndicator(
      onRefresh: () async => onLoadMore(),
      child: ListView.builder(
        controller: scrollController,
        reverse: true, // Show newest messages at bottom
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: messages.length + (hasMoreMessages ? 1 : 0),
        itemBuilder: (context, index) {
          // Load more indicator at the top (index 0 when reversed)
          if (index == messages.length) {
            return _buildLoadMoreIndicator(context);
          }

          final message = messages[index];
          final isUnsynced = unsyncedMessages.any((m) => m.id == message.id);
          
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ChatMessageBubble(
              message: message,
              isUnsynced: isUnsynced,
              onRetry: () => onRetryMessage(message.id),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'Start a conversation with Reva',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ask me to help with tasks, expenses, or reminders',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          _buildSuggestionChips(context),
        ],
      ),
    );
  }

  Widget _buildSuggestionChips(BuildContext context) {
    final suggestions = [
      'Add a task',
      'Log an expense',
      'Set a reminder',
      'Show my tasks',
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: suggestions.map((suggestion) {
        return ActionChip(
          label: Text(suggestion),
          onPressed: () {
            // This would trigger sending the suggestion as a message
            // For now, we'll just show it as a placeholder
          },
        );
      }).toList(),
    );
  }

  Widget _buildLoadMoreIndicator(BuildContext context) {
    if (!hasMoreMessages) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: isLoading
            ? const ChatLoadingIndicator()
            : TextButton.icon(
                onPressed: onLoadMore,
                icon: const Icon(Icons.expand_more),
                label: const Text('Load more messages'),
              ),
      ),
    );
  }
}
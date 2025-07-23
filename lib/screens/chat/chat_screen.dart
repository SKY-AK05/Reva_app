import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/chat_provider.dart';
import '../../widgets/chat/chat_message_list.dart';
import '../../widgets/chat/chat_input_field.dart';
import '../../widgets/chat/offline_message_status.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String? initialContextId;
  final String? initialMessage;

  const ChatScreen({
    super.key,
    this.initialContextId,
    this.initialMessage,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _setupScrollListener();
    _handleDeepLinkParameters();
  }

  void _handleDeepLinkParameters() {
    // Handle initial message from deep link
    if (widget.initialMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _messageController.text = widget.initialMessage!;
        _messageFocusNode.requestFocus();
      });
    }

    // Handle initial context from deep link
    if (widget.initialContextId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Set context in chat provider if needed
        // This would depend on how the chat provider handles context
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _messageController.dispose();
    _messageFocusNode.dispose();
    super.dispose();
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      // Load more messages when scrolled to bottom
      if (_scrollController.position.pixels >= 
          _scrollController.position.maxScrollExtent - 200) {
        final chatState = ref.read(chatProvider);
        if (!chatState.isLoading && chatState.hasMoreMessages) {
          ref.read(chatProvider.notifier).loadMoreMessages();
        }
      }
    });
  }

  void _sendMessage() {
    final message = _messageController.text.trim();
    if (message.isNotEmpty) {
      ref.read(chatProvider.notifier).sendMessage(message);
      _messageController.clear();
      _scrollToTop();
    }
  }

  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _retryMessage(String messageId) {
    ref.read(chatProvider.notifier).retryMessage(messageId);
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);
    
    return Column(
      children: [
        // Offline banner
        if (chatState.isOffline)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Theme.of(context).colorScheme.errorContainer,
            child: Row(
              children: [
                Icon(
                  Icons.cloud_off,
                  color: Theme.of(context).colorScheme.onErrorContainer,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'You\'re offline. Messages will sync when connection is restored.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
              ],
            ),
          ),
        
        // Error banner
        if (chatState.hasError)
          _buildErrorBanner(context, chatState.error!),
        
        // Chat messages
        Expanded(
          child: Stack(
            children: [
              ChatMessageList(
                messages: chatState.messages,
                isLoading: chatState.isLoading,
                hasMoreMessages: chatState.hasMoreMessages,
                unsyncedMessages: chatState.unsyncedMessages,
                scrollController: _scrollController,
                onRetryMessage: _retryMessage,
                onLoadMore: () => ref.read(chatProvider.notifier).loadMoreMessages(),
              ),
              
              // Offline message status overlay
              if (chatState.unsyncedMessages.isNotEmpty)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: OfflineMessageStatus(),
                ),
            ],
          ),
        ),
        
        // Chat input
        ChatInputField(
          controller: _messageController,
          focusNode: _messageFocusNode,
          onSend: _sendMessage,
          isEnabled: !chatState.isSending,
          isSending: chatState.isSending,
          isOffline: chatState.isOffline,
        ),
      ],
    );
  }

  Widget _buildErrorBanner(BuildContext context, String error) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context).colorScheme.errorContainer,
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: Theme.of(context).colorScheme.onErrorContainer,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              error,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
          ),
          IconButton(
            onPressed: () => ref.read(chatProvider.notifier).clearError(),
            icon: Icon(
              Icons.close,
              color: Theme.of(context).colorScheme.onErrorContainer,
              size: 20,
            ),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }


}
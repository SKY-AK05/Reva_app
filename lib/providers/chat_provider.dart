import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/chat_message.dart';
import '../services/chat/chat_service.dart';
import '../services/chat/context_manager.dart';
import '../services/connectivity/connectivity_service.dart';
import '../services/auth/auth_service.dart';
import 'tasks_provider.dart';
import 'expenses_provider.dart';
import 'reminders_provider.dart';

/// Provider for chat service
final chatServiceProvider = Provider<ChatService>((ref) {
  final authService = AuthService();
  return ChatService(authService: authService);
});

/// Provider for context manager
final contextManagerProvider = Provider<ContextManager>((ref) => ContextManager());

/// Provider for chat state
final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  return ChatNotifier(
    chatService: ref.read(chatServiceProvider),
    contextManager: ref.read(contextManagerProvider),
    ref: ref,
  );
});

/// Chat state class
class ChatState {
  final List<ChatMessage> messages;
  final bool isLoading;
  final bool isSending;
  final String? error;
  final bool hasMoreMessages;
  final int currentPage;
  final bool isOffline;
  final List<ChatMessage> unsyncedMessages;

  const ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.isSending = false,
    this.error,
    this.hasMoreMessages = true,
    this.currentPage = 0,
    this.isOffline = false,
    this.unsyncedMessages = const [],
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    bool? isSending,
    String? error,
    bool? hasMoreMessages,
    int? currentPage,
    bool? isOffline,
    List<ChatMessage>? unsyncedMessages,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      error: error ?? this.error,
      hasMoreMessages: hasMoreMessages ?? this.hasMoreMessages,
      currentPage: currentPage ?? this.currentPage,
      isOffline: isOffline ?? this.isOffline,
      unsyncedMessages: unsyncedMessages ?? this.unsyncedMessages,
    );
  }

  bool get hasError => error != null;
  bool get isEmpty => messages.isEmpty;
  int get messageCount => messages.length;
  ChatMessage? get lastMessage => messages.isNotEmpty ? messages.first : null;
}

/// Chat state notifier
class ChatNotifier extends StateNotifier<ChatState> {
  final ChatService _chatService;
  final ContextManager _contextManager;
  final Ref _ref;
  final Uuid _uuid = const Uuid();
  
  StreamSubscription<bool>? _connectivitySubscription;
  Timer? _syncTimer;

  ChatNotifier({
    required ChatService chatService,
    required ContextManager contextManager,
    required Ref ref,
  }) : _chatService = chatService,
       _contextManager = contextManager,
       _ref = ref,
       super(const ChatState()) {
    _initializeChat();
    _setupConnectivityListener();
    _setupPeriodicSync();
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _syncTimer?.cancel();
    super.dispose();
  }

  /// Initialize chat by loading message history
  Future<void> _initializeChat() async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final messages = await _chatService.getMessageHistory(page: 0);
      final unsyncedMessages = await _chatService.getUnsyncedMessages();
      
      state = state.copyWith(
        messages: messages,
        unsyncedMessages: unsyncedMessages,
        isLoading: false,
        currentPage: 0,
        hasMoreMessages: messages.length >= 20, // Assuming page size of 20
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e is ChatException ? e.userFriendlyMessage : e.toString(),
      );
    }
  }

  /// Setup connectivity listener
  void _setupConnectivityListener() {
    final connectivityService = _ref.read(connectivityServiceProvider);
    _connectivitySubscription = connectivityService.connectivityStream.listen((isConnected) {
      state = state.copyWith(isOffline: !isConnected);
      
      if (isConnected && state.unsyncedMessages.isNotEmpty) {
        _syncUnsyncedMessages();
      }
    });
  }

  /// Setup periodic sync for unsynced messages
  void _setupPeriodicSync() {
    _syncTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!state.isOffline && state.unsyncedMessages.isNotEmpty) {
        _syncUnsyncedMessages();
      }
    });
  }

  /// Send a message
  Future<void> sendMessage(String content, {Map<String, dynamic>? contextItem}) async {
    if (content.trim().isEmpty) return;

    final userMessage = ChatMessage.user(
      id: _uuid.v4(),
      content: content.trim(),
    );

    // Add user message to state immediately
    state = state.copyWith(
      messages: [userMessage, ...state.messages],
      isSending: true,
      error: null,
    );

    try {
      if (state.isOffline) {
        // Save as unsynced message when offline
        await _chatService.saveUnsyncedMessage(userMessage);
        state = state.copyWith(
          unsyncedMessages: [userMessage, ...state.unsyncedMessages],
          isSending: false,
        );
        return;
      }

      // Build context for the AI
      final context = await _buildCurrentContext(contextItem);
      
      // Get recent messages for conversation history
      final recentMessages = state.messages.take(10).toList().reversed.toList();

      // Send message to API
      final response = await _chatService.sendMessage(
        message: content,
        history: recentMessages,
        contextItem: context,
      );

      // Create assistant message from response
      final assistantMessage = ChatMessage.assistant(
        id: _uuid.v4(),
        content: response.aiResponseText,
        metadata: {
          if (response.hasAction) 'action': response.actionMetadata,
          if (response.hasContextItem) ...{
            'contextItemId': response.contextItemId,
            'contextItemType': response.contextItemType,
          },
        },
      );

      // Save both messages
      await _chatService.saveMessage(userMessage);
      await _chatService.saveMessage(assistantMessage);

      // Update state with assistant response
      state = state.copyWith(
        messages: [assistantMessage, ...state.messages],
        isSending: false,
      );

      // Process any actions from the AI response
      if (response.hasAction) {
        await _processAIAction(response.actionMetadata!);
      }

    } catch (e) {
      // Handle error - mark user message as unsynced if it's a network error
      if (e is ChatException && e.type == ChatErrorType.networkError) {
        await _chatService.saveUnsyncedMessage(userMessage);
        state = state.copyWith(
          unsyncedMessages: [userMessage, ...state.unsyncedMessages],
          isSending: false,
          error: 'Message saved. Will send when online.',
        );
      } else {
        // Remove the user message from state on other errors
        final updatedMessages = state.messages.where((msg) => msg.id != userMessage.id).toList();
        state = state.copyWith(
          messages: updatedMessages,
          isSending: false,
          error: e is ChatException ? e.userFriendlyMessage : e.toString(),
        );
      }
    }
  }

  /// Load more messages (pagination)
  Future<void> loadMoreMessages() async {
    if (state.isLoading || !state.hasMoreMessages) return;

    state = state.copyWith(isLoading: true);

    try {
      final nextPage = state.currentPage + 1;
      final moreMessages = await _chatService.getMessageHistory(page: nextPage);

      if (moreMessages.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          hasMoreMessages: false,
        );
        return;
      }

      // Filter out duplicates
      final existingIds = state.messages.map((m) => m.id).toSet();
      final newMessages = moreMessages.where((m) => !existingIds.contains(m.id)).toList();

      state = state.copyWith(
        messages: [...state.messages, ...newMessages],
        isLoading: false,
        currentPage: nextPage,
        hasMoreMessages: moreMessages.length >= 20, // Assuming page size of 20
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e is ChatException ? e.userFriendlyMessage : e.toString(),
      );
    }
  }

  /// Refresh messages
  Future<void> refreshMessages() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final messages = await _chatService.getMessageHistory(page: 0, forceRefresh: true);
      
      state = state.copyWith(
        messages: messages,
        isLoading: false,
        currentPage: 0,
        hasMoreMessages: messages.length >= 20,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e is ChatException ? e.userFriendlyMessage : e.toString(),
      );
    }
  }

  /// Clear error state
  void clearError() {
    state = state.copyWith(error: null);
  }

  /// Clear chat history
  Future<void> clearHistory() async {
    try {
      await _chatService.clearHistory();
      state = const ChatState();
    } catch (e) {
      state = state.copyWith(
        error: e is ChatException ? e.userFriendlyMessage : e.toString(),
      );
    }
  }

  /// Retry sending a failed message
  Future<void> retryMessage(String messageId) async {
    final message = state.unsyncedMessages.firstWhere(
      (msg) => msg.id == messageId,
      orElse: () => throw Exception('Message not found'),
    );

    await sendMessage(message.content);
    
    // Remove from unsynced messages
    final updatedUnsynced = state.unsyncedMessages.where((msg) => msg.id != messageId).toList();
    state = state.copyWith(unsyncedMessages: updatedUnsynced);
  }

  /// Build current context for AI
  Future<Map<String, dynamic>> _buildCurrentContext(Map<String, dynamic>? contextItem) async {
    try {
      // Get recent data from other providers
      final tasksState = _ref.read(tasksProvider);
      final expensesState = _ref.read(expensesProvider);
      final remindersState = _ref.read(remindersProvider);

      return _contextManager.buildContext(
        recentMessages: state.messages.take(10).toList(),
        recentTasks: tasksState.tasks.take(5).toList(),
        recentExpenses: expensesState.expenses.take(5).toList(),
        recentReminders: remindersState.reminders.take(5).toList(),
        currentContextItem: contextItem,
      );
    } catch (e) {
      // Return minimal context if there's an error
      return _contextManager.buildContext(
        recentMessages: state.messages.take(10).toList(),
        currentContextItem: contextItem,
      );
    }
  }

  /// Process AI actions
  Future<void> _processAIAction(Map<String, dynamic> actionMetadata) async {
    try {
      final actionType = actionMetadata['type'] as String?;
      final actionData = actionMetadata['data'] as Map<String, dynamic>?;

      if (actionType == null || actionData == null) return;

      switch (actionType) {
        case 'create_task':
          await _ref.read(tasksProvider.notifier).createTaskFromAI(actionData);
          break;
        case 'update_task':
          await _ref.read(tasksProvider.notifier).updateTaskFromAI(actionData);
          break;
        case 'complete_task':
          await _ref.read(tasksProvider.notifier).completeTaskFromAI(actionData);
          break;
        case 'create_expense':
          await _ref.read(expensesProvider.notifier).createExpenseFromAI(actionData);
          break;
        case 'update_expense':
          await _ref.read(expensesProvider.notifier).updateExpenseFromAI(actionData);
          break;
        case 'create_reminder':
          await _ref.read(remindersProvider.notifier).createReminderFromAI(actionData);
          break;
        case 'update_reminder':
          await _ref.read(remindersProvider.notifier).updateReminderFromAI(actionData);
          break;
      }
    } catch (e) {
      // Log error but don't fail the chat interaction
      print('Error processing AI action: $e');
    }
  }

  /// Sync unsynced messages when connectivity returns
  Future<void> _syncUnsyncedMessages() async {
    if (state.unsyncedMessages.isEmpty) return;

    final messagesToSync = List<ChatMessage>.from(state.unsyncedMessages);
    
    for (final message in messagesToSync) {
      try {
        if (message.type == MessageType.user) {
          // Resend user messages
          final context = await _buildCurrentContext(null);
          final recentMessages = state.messages.take(10).toList().reversed.toList();
          
          final response = await _chatService.sendMessage(
            message: message.content,
            history: recentMessages,
            contextItem: context,
          );

          // Mark as synced
          await _chatService.markMessageAsSynced(message.id);

          // Create assistant response
          final assistantMessage = ChatMessage.assistant(
            id: _uuid.v4(),
            content: response.aiResponseText,
            metadata: {
              if (response.hasAction) 'action': response.actionMetadata,
              if (response.hasContextItem) ...{
                'contextItemId': response.contextItemId,
                'contextItemType': response.contextItemType,
              },
            },
          );

          await _chatService.saveMessage(assistantMessage);

          // Update state
          final updatedMessages = [assistantMessage, ...state.messages];
          final updatedUnsynced = state.unsyncedMessages.where((msg) => msg.id != message.id).toList();
          
          state = state.copyWith(
            messages: updatedMessages,
            unsyncedMessages: updatedUnsynced,
          );

          // Process AI actions
          if (response.hasAction) {
            await _processAIAction(response.actionMetadata!);
          }
        }
      } catch (e) {
        // Continue with other messages if one fails
        print('Failed to sync message ${message.id}: $e');
      }
    }
  }
}

/// Provider for connectivity service
final connectivityServiceProvider = Provider<ConnectivityService>((ref) => ConnectivityService());
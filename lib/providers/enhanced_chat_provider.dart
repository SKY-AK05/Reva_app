import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/chat_message.dart';
import '../services/chat/chat_service.dart';
import '../services/chat/context_manager.dart';
import '../services/chat/ai_fallback_service.dart';
import '../services/connectivity/connectivity_service.dart';
import '../services/data/tasks_repository.dart';
import '../services/data/expenses_repository.dart';
import '../services/data/reminders_repository.dart';
import '../core/error/error_handler.dart';
import '../utils/logger.dart';
import 'tasks_provider.dart';
import 'expenses_provider.dart';
import 'reminders_provider.dart';

/// Provider for AI fallback service
final aiFallbackServiceProvider = Provider<AIFallbackService>((ref) {
  return AIFallbackService(
    tasksRepository: ref.read(tasksRepositoryProvider),
    expensesRepository: ref.read(expensesRepositoryProvider),
    remindersRepository: ref.read(remindersRepositoryProvider),
  );
});

/// Enhanced chat provider with AI fallback capabilities
final enhancedChatProvider = StateNotifierProvider<EnhancedChatNotifier, EnhancedChatState>((ref) {
  return EnhancedChatNotifier(
    chatService: ref.read(chatServiceProvider),
    contextManager: ref.read(contextManagerProvider),
    fallbackService: ref.read(aiFallbackServiceProvider),
    ref: ref,
  );
});

/// Enhanced chat state with fallback support
class EnhancedChatState {
  final List<ChatMessage> messages;
  final bool isLoading;
  final bool isSending;
  final String? error;
  final bool hasMoreMessages;
  final int currentPage;
  final bool isOffline;
  final List<ChatMessage> unsyncedMessages;
  
  // Fallback-specific state
  final List<FallbackSuggestion> fallbackSuggestions;
  final bool showFallbackSuggestions;
  final String? fallbackHelpMessage;
  final bool isProcessingFallback;
  final String? lastFailedMessage;

  const EnhancedChatState({
    this.messages = const [],
    this.isLoading = false,
    this.isSending = false,
    this.error,
    this.hasMoreMessages = true,
    this.currentPage = 0,
    this.isOffline = false,
    this.unsyncedMessages = const [],
    this.fallbackSuggestions = const [],
    this.showFallbackSuggestions = false,
    this.fallbackHelpMessage,
    this.isProcessingFallback = false,
    this.lastFailedMessage,
  });

  EnhancedChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    bool? isSending,
    String? error,
    bool? hasMoreMessages,
    int? currentPage,
    bool? isOffline,
    List<ChatMessage>? unsyncedMessages,
    List<FallbackSuggestion>? fallbackSuggestions,
    bool? showFallbackSuggestions,
    String? fallbackHelpMessage,
    bool? isProcessingFallback,
    String? lastFailedMessage,
  }) {
    return EnhancedChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      error: error,
      hasMoreMessages: hasMoreMessages ?? this.hasMoreMessages,
      currentPage: currentPage ?? this.currentPage,
      isOffline: isOffline ?? this.isOffline,
      unsyncedMessages: unsyncedMessages ?? this.unsyncedMessages,
      fallbackSuggestions: fallbackSuggestions ?? this.fallbackSuggestions,
      showFallbackSuggestions: showFallbackSuggestions ?? this.showFallbackSuggestions,
      fallbackHelpMessage: fallbackHelpMessage,
      isProcessingFallback: isProcessingFallback ?? this.isProcessingFallback,
      lastFailedMessage: lastFailedMessage,
    );
  }

  bool get hasError => error != null;
  bool get isEmpty => messages.isEmpty;
  int get messageCount => messages.length;
  ChatMessage? get lastMessage => messages.isNotEmpty ? messages.first : null;
  bool get hasFallbackSuggestions => fallbackSuggestions.isNotEmpty;
}

/// Enhanced chat notifier with AI fallback capabilities
class EnhancedChatNotifier extends StateNotifier<EnhancedChatState> {
  final ChatService _chatService;
  final ContextManager _contextManager;
  final AIFallbackService _fallbackService;
  final Ref _ref;
  final Uuid _uuid = const Uuid();
  
  StreamSubscription<bool>? _connectivitySubscription;
  Timer? _syncTimer;

  EnhancedChatNotifier({
    required ChatService chatService,
    required ContextManager contextManager,
    required AIFallbackService fallbackService,
    required Ref ref,
  }) : _chatService = chatService,
       _contextManager = contextManager,
       _fallbackService = fallbackService,
       _ref = ref,
       super(const EnhancedChatState()) {
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
        hasMoreMessages: messages.length >= 20,
      );
    } catch (e) {
      final appError = ErrorHandler.handleError(e, StackTrace.current, context: 'Initialize chat');
      state = state.copyWith(
        isLoading: false,
        error: appError.userMessage,
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

  /// Send a message with enhanced error handling and fallback support
  Future<void> sendMessage(String content, {Map<String, dynamic>? contextItem}) async {
    if (content.trim().isEmpty) return;

    final userMessage = ChatMessage.user(
      id: _uuid.v4(),
      content: content.trim(),
    );

    // Clear any existing fallback state
    state = state.copyWith(
      showFallbackSuggestions: false,
      fallbackSuggestions: [],
      fallbackHelpMessage: null,
      lastFailedMessage: null,
    );

    // Add user message to state immediately
    state = state.copyWith(
      messages: [userMessage, ...state.messages],
      isSending: true,
      error: null,
    );

    try {
      if (state.isOffline) {
        await _handleOfflineMessage(userMessage);
        return;
      }

      await _sendMessageWithFallback(userMessage, contextItem);

    } catch (e) {
      Logger.error('Failed to send message: $e');
      await _handleMessageError(userMessage, e);
    }
  }

  /// Send message with fallback handling
  Future<void> _sendMessageWithFallback(ChatMessage userMessage, Map<String, dynamic>? contextItem) async {
    try {
      // Build context for the AI
      final context = await _buildCurrentContext(contextItem);
      
      // Get recent messages for conversation history
      final recentMessages = state.messages.take(10).toList().reversed.toList();

      // Send message to API with timeout
      final response = await _chatService.sendMessage(
        message: userMessage.content,
        history: recentMessages,
        contextItem: context,
      ).timeout(const Duration(seconds: 30));

      await _handleSuccessfulResponse(userMessage, response);

    } catch (e) {
      Logger.warning('AI request failed, triggering fallback: $e');
      await _triggerFallback(userMessage, e);
    }
  }

  /// Handle successful AI response
  Future<void> _handleSuccessfulResponse(ChatMessage userMessage, ChatResponse response) async {
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
  }

  /// Handle offline message
  Future<void> _handleOfflineMessage(ChatMessage userMessage) async {
    await _chatService.saveUnsyncedMessage(userMessage);
    state = state.copyWith(
      unsyncedMessages: [userMessage, ...state.unsyncedMessages],
      isSending: false,
      error: 'Message saved. Will send when online.',
    );
  }

  /// Handle message sending error
  Future<void> _handleMessageError(ChatMessage userMessage, Object error) async {
    final appError = ErrorHandler.handleError(error, StackTrace.current, context: 'Send message');
    
    if (appError.type == ErrorType.network) {
      // Save as unsynced for network errors
      await _chatService.saveUnsyncedMessage(userMessage);
      state = state.copyWith(
        unsyncedMessages: [userMessage, ...state.unsyncedMessages],
        isSending: false,
        error: 'Message saved. Will send when online.',
      );
    } else {
      // Remove user message and trigger fallback for other errors
      final updatedMessages = state.messages.where((msg) => msg.id != userMessage.id).toList();
      state = state.copyWith(
        messages: updatedMessages,
        isSending: false,
        error: appError.userMessage,
        lastFailedMessage: userMessage.content,
      );
      
      await _triggerFallback(userMessage, error);
    }
  }

  /// Trigger AI fallback when AI fails to process the message
  Future<void> _triggerFallback(ChatMessage userMessage, Object error) async {
    Logger.info('Triggering AI fallback for message: ${userMessage.content}');
    
    state = state.copyWith(isProcessingFallback: true);
    
    try {
      // Generate fallback suggestions
      final suggestions = await _fallbackService.analyzeFallbackSuggestions(userMessage.content);
      
      // Generate help message
      final helpMessage = _fallbackService.generateHelpMessage(userMessage.content);
      
      state = state.copyWith(
        fallbackSuggestions: suggestions,
        showFallbackSuggestions: suggestions.isNotEmpty,
        fallbackHelpMessage: helpMessage,
        isProcessingFallback: false,
        lastFailedMessage: userMessage.content,
      );
      
      Logger.info('Generated ${suggestions.length} fallback suggestions');
      
    } catch (e) {
      Logger.error('Failed to generate fallback suggestions: $e');
      state = state.copyWith(
        isProcessingFallback: false,
        fallbackHelpMessage: 'I couldn\'t understand your request. Please try using the manual input options or navigation tabs.',
      );
    }
  }

  /// Execute a fallback suggestion
  Future<void> executeFallbackSuggestion(FallbackSuggestion suggestion) async {
    Logger.info('Executing fallback suggestion: ${suggestion.title}');
    
    state = state.copyWith(isProcessingFallback: true);
    
    try {
      final result = await _fallbackService.executeFallbackSuggestion(suggestion);
      
      if (result.success) {
        // Add system message about the action
        final systemMessage = ChatMessage.system(
          id: _uuid.v4(),
          content: result.message,
          metadata: {
            'fallback_action': true,
            'suggestion_type': suggestion.type.name,
            if (result.data != null) 'action_data': result.data,
          },
        );
        
        await _chatService.saveMessage(systemMessage);
        
        state = state.copyWith(
          messages: [systemMessage, ...state.messages],
          showFallbackSuggestions: false,
          fallbackSuggestions: [],
          isProcessingFallback: false,
        );
        
        // Handle navigation if required
        if (result.requiresNavigation && result.navigationRoute != null) {
          // This would be handled by the UI layer
          Logger.info('Navigation required to: ${result.navigationRoute}');
        }
        
      } else {
        state = state.copyWith(
          isProcessingFallback: false,
          error: result.message,
        );
      }
      
    } catch (e) {
      Logger.error('Failed to execute fallback suggestion: $e');
      state = state.copyWith(
        isProcessingFallback: false,
        error: 'Failed to execute action: ${e.toString()}',
      );
    }
  }

  /// Dismiss fallback suggestions
  void dismissFallbackSuggestions() {
    state = state.copyWith(
      showFallbackSuggestions: false,
      fallbackSuggestions: [],
      fallbackHelpMessage: null,
    );
  }

  /// Retry the last failed message
  Future<void> retryLastFailedMessage() async {
    final lastFailed = state.lastFailedMessage;
    if (lastFailed != null) {
      await sendMessage(lastFailed);
    }
  }

  /// Get manual input alternatives for the last failed message
  List<String> getManualInputAlternatives() {
    final lastFailed = state.lastFailedMessage;
    if (lastFailed == null) return [];
    
    return [
      'Create Task',
      'Log Expense', 
      'Set Reminder',
    ];
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
        hasMoreMessages: moreMessages.length >= 20,
      );
    } catch (e) {
      final appError = ErrorHandler.handleError(e, StackTrace.current, context: 'Load more messages');
      state = state.copyWith(
        isLoading: false,
        error: appError.userMessage,
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
      final appError = ErrorHandler.handleError(e, StackTrace.current, context: 'Refresh messages');
      state = state.copyWith(
        isLoading: false,
        error: appError.userMessage,
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
      state = const EnhancedChatState();
    } catch (e) {
      final appError = ErrorHandler.handleError(e, StackTrace.current, context: 'Clear history');
      state = state.copyWith(error: appError.userMessage);
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
      Logger.warning('Failed to build full context, using minimal context: $e');
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
      Logger.error('Error processing AI action: $e');
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
        Logger.warning('Failed to sync message ${message.id}: $e');
      }
    }
  }
}

// Repository providers (these should be defined elsewhere, but included here for completeness)
final tasksRepositoryProvider = Provider<TasksRepository>((ref) => TasksRepository());
final expensesRepositoryProvider = Provider<ExpensesRepository>((ref) => ExpensesRepository());
final remindersRepositoryProvider = Provider<RemindersRepository>((ref) => RemindersRepository());

// Re-export existing providers for compatibility
final chatServiceProvider = Provider<ChatService>((ref) => ChatService());
final contextManagerProvider = Provider<ContextManager>((ref) => ContextManager());
final connectivityServiceProvider = Provider<ConnectivityService>((ref) => ConnectivityService());
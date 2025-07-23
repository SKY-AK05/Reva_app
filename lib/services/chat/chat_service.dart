import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../models/chat_message.dart';
import '../cache/chat_cache_service.dart';
import '../auth/auth_service.dart';
import '../auth/session_manager.dart';
import '../performance/performance_analytics.dart';

class ChatService {
  static const String _chatEndpoint = '/api/v1/chat';
  static const int _defaultPageSize = 20;
  static const Duration _requestTimeout = Duration(seconds: 30);
  
  final ChatCacheService _cacheService = ChatCacheService();
  final AuthService _authService;
  late final SessionManager _sessionManager;

  ChatService({required AuthService authService}) : _authService = authService {
    _sessionManager = SessionManager(_authService);
  }
  
  String get _baseUrl => dotenv.env['API_BASE_URL'] ?? 'https://reva-backend-8bcr.onrender.com/api/v1/chat';
  
  /// Send a message to the chat API and return the response
  Future<ChatResponse> sendMessage({
    required String message,
    List<ChatMessage>? history,
    Map<String, dynamic>? contextItem,
  }) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      final session = _authService.currentSession;
      if (session == null) {
        throw ChatException('User not authenticated', ChatErrorType.authentication);
      }

      final requestBody = {
        'message': message,
        'history': history?.map((msg) => msg.toJson()).toList() ?? [],
        if (contextItem != null) 'context_item': contextItem,
      };

      final response = await http.post(
        Uri.parse('$_baseUrl$_chatEndpoint'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.accessToken}',
        },
        body: jsonEncode(requestBody),
      ).timeout(_requestTimeout);

      stopwatch.stop();
      
      if (response.statusCode == 200) {
        // Record successful API call
        PerformanceAnalytics.recordAPICall(
          _chatEndpoint,
          stopwatch.elapsed,
          success: true,
        );
        
        final responseData = jsonDecode(response.body) as Map<String, dynamic>;
        return ChatResponse.fromJson(responseData);
      } else {
        // Record failed API call
        String errorMessage;
        if (response.statusCode == 401) {
          errorMessage = 'Authentication failed';
          throw ChatException(errorMessage, ChatErrorType.authentication);
        } else if (response.statusCode == 429) {
          errorMessage = 'Rate limit exceeded';
          throw ChatException(errorMessage, ChatErrorType.rateLimited);
        } else if (response.statusCode >= 500) {
          errorMessage = 'Server error';
          throw ChatException(errorMessage, ChatErrorType.serverError);
        } else {
          final errorData = jsonDecode(response.body) as Map<String, dynamic>?;
          errorMessage = errorData?['error'] ?? 'Unknown error occurred';
          throw ChatException(errorMessage, ChatErrorType.apiError);
        }
        
        PerformanceAnalytics.recordAPICall(
          _chatEndpoint,
          stopwatch.elapsed,
          success: false,
          errorMessage: errorMessage,
        );
      }
    } on SocketException {
      stopwatch.stop();
      PerformanceAnalytics.recordAPICall(
        _chatEndpoint,
        stopwatch.elapsed,
        success: false,
        errorMessage: 'No internet connection',
      );
      throw ChatException('No internet connection', ChatErrorType.networkError);
    } on http.ClientException {
      stopwatch.stop();
      PerformanceAnalytics.recordAPICall(
        _chatEndpoint,
        stopwatch.elapsed,
        success: false,
        errorMessage: 'Network request failed',
      );
      throw ChatException('Network request failed', ChatErrorType.networkError);
    } on FormatException {
      stopwatch.stop();
      PerformanceAnalytics.recordAPICall(
        _chatEndpoint,
        stopwatch.elapsed,
        success: false,
        errorMessage: 'Invalid response format',
      );
      throw ChatException('Invalid response format', ChatErrorType.parseError);
    } catch (e) {
      stopwatch.stop();
      if (e is ChatException) {
        PerformanceAnalytics.recordAPICall(
          _chatEndpoint,
          stopwatch.elapsed,
          success: false,
          errorMessage: e.message,
        );
        rethrow;
      }
      PerformanceAnalytics.recordAPICall(
        _chatEndpoint,
        stopwatch.elapsed,
        success: false,
        errorMessage: 'Unexpected error: ${e.toString()}',
      );
      throw ChatException('Unexpected error: ${e.toString()}', ChatErrorType.unknown);
    }
  }

  /// Get chat message history with pagination
  Future<List<ChatMessage>> getMessageHistory({
    int page = 0,
    int pageSize = _defaultPageSize,
    bool forceRefresh = false,
  }) async {
    try {
      // Check if we should use cached data
      if (!forceRefresh && !await _cacheService.isDataStale(const Duration(minutes: 5))) {
        final cachedMessages = await _cacheService.getCachedChatMessages(
          limit: pageSize,
          offset: page * pageSize,
        );
        
        if (cachedMessages.isNotEmpty) {
          return cachedMessages.map((json) => ChatMessage.fromJson(json)).toList();
        }
      }

      // Fetch from API
      final session = _authService.currentSession;
      if (session == null) {
        throw ChatException('User not authenticated', ChatErrorType.authentication);
      }

      final queryParams = {
        'page': page.toString(),
        'limit': pageSize.toString(),
      };

      final uri = Uri.parse('$_baseUrl$_chatEndpoint/history').replace(
        queryParameters: queryParams,
      );

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer ${session.accessToken}',
        },
      ).timeout(_requestTimeout);

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body) as Map<String, dynamic>;
        final messagesJson = responseData['messages'] as List<dynamic>;
        
        final messages = messagesJson
            .map((json) => ChatMessage.fromJson(json as Map<String, dynamic>))
            .toList();

        // Cache the messages if this is the first page
        if (page == 0) {
          await _cacheService.cacheChatMessages(
            messagesJson.cast<Map<String, dynamic>>(),
          );
        }

        return messages;
      } else if (response.statusCode == 401) {
        throw ChatException('Authentication failed', ChatErrorType.authentication);
      } else {
        throw ChatException('Failed to fetch message history', ChatErrorType.apiError);
      }
    } on SocketException {
      // Return cached data if available when offline
      final cachedMessages = await _cacheService.getCachedChatMessages(
        limit: pageSize,
        offset: page * pageSize,
      );
      
      if (cachedMessages.isNotEmpty) {
        return cachedMessages.map((json) => ChatMessage.fromJson(json)).toList();
      }
      
      throw ChatException('No internet connection', ChatErrorType.networkError);
    } catch (e) {
      if (e is ChatException) rethrow;
      throw ChatException('Failed to get message history: ${e.toString()}', ChatErrorType.unknown);
    }
  }

  /// Get messages before a specific timestamp for pagination
  Future<List<ChatMessage>> getMessagesBefore(
    DateTime timestamp, {
    int limit = _defaultPageSize,
  }) async {
    try {
      final cachedMessages = await _cacheService.getMessagesBefore(
        timestamp,
        limit: limit,
      );
      
      return cachedMessages.map((json) => ChatMessage.fromJson(json)).toList();
    } catch (e) {
      throw ChatException('Failed to get messages before timestamp: ${e.toString()}', ChatErrorType.unknown);
    }
  }

  /// Get messages after a specific timestamp
  Future<List<ChatMessage>> getMessagesAfter(DateTime timestamp) async {
    try {
      final cachedMessages = await _cacheService.getMessagesAfter(timestamp);
      return cachedMessages.map((json) => ChatMessage.fromJson(json)).toList();
    } catch (e) {
      throw ChatException('Failed to get messages after timestamp: ${e.toString()}', ChatErrorType.unknown);
    }
  }

  /// Save a message to local cache
  Future<void> saveMessage(ChatMessage message) async {
    try {
      await _cacheService.cacheChatMessage(message.toJson());
    } catch (e) {
      throw ChatException('Failed to save message: ${e.toString()}', ChatErrorType.cacheError);
    }
  }

  /// Save an unsynced message (for offline scenarios)
  Future<void> saveUnsyncedMessage(ChatMessage message) async {
    try {
      await _cacheService.addUnsyncedMessage(message.toJson());
    } catch (e) {
      throw ChatException('Failed to save unsynced message: ${e.toString()}', ChatErrorType.cacheError);
    }
  }

  /// Get unsynced messages that need to be sent when online
  Future<List<ChatMessage>> getUnsyncedMessages() async {
    try {
      final unsyncedMessages = await _cacheService.getUnsyncedMessages();
      return unsyncedMessages.map((json) => ChatMessage.fromJson(json)).toList();
    } catch (e) {
      throw ChatException('Failed to get unsynced messages: ${e.toString()}', ChatErrorType.cacheError);
    }
  }

  /// Mark a message as synced
  Future<void> markMessageAsSynced(String messageId) async {
    try {
      await _cacheService.markMessageAsSynced(messageId);
    } catch (e) {
      throw ChatException('Failed to mark message as synced: ${e.toString()}', ChatErrorType.cacheError);
    }
  }

  /// Update a message in cache
  Future<void> updateMessage(String messageId, Map<String, dynamic> updates) async {
    try {
      await _cacheService.updateCachedMessage(messageId, updates);
    } catch (e) {
      throw ChatException('Failed to update message: ${e.toString()}', ChatErrorType.cacheError);
    }
  }

  /// Delete a message from cache
  Future<void> deleteMessage(String messageId) async {
    try {
      await _cacheService.deleteCachedMessage(messageId);
    } catch (e) {
      throw ChatException('Failed to delete message: ${e.toString()}', ChatErrorType.cacheError);
    }
  }

  /// Clear all chat history
  Future<void> clearHistory() async {
    try {
      await _cacheService.clearCache();
    } catch (e) {
      throw ChatException('Failed to clear chat history: ${e.toString()}', ChatErrorType.cacheError);
    }
  }

  /// Get total message count
  Future<int> getMessageCount() async {
    try {
      return await _cacheService.getMessageCount();
    } catch (e) {
      throw ChatException('Failed to get message count: ${e.toString()}', ChatErrorType.cacheError);
    }
  }

  /// Clean up old messages to manage storage
  Future<void> cleanupOldMessages({
    int? keepCount = 1000,
    Duration? keepDuration,
  }) async {
    try {
      await _cacheService.clearOldMessages(
        keepCount: keepCount,
        keepDuration: keepDuration,
      );
    } catch (e) {
      throw ChatException('Failed to cleanup old messages: ${e.toString()}', ChatErrorType.cacheError);
    }
  }

  /// Build conversation context from recent messages
  Map<String, dynamic> buildConversationContext({
    List<ChatMessage>? recentMessages,
    int maxMessages = 10,
  }) {
    final messages = recentMessages ?? [];
    final contextMessages = messages.take(maxMessages).map((msg) => {
      'type': msg.type.name,
      'content': msg.content,
      'timestamp': msg.timestamp.toIso8601String(),
      if (msg.metadata != null) 'metadata': msg.metadata,
    }).toList();

    return {
      'recent_messages': contextMessages,
      'message_count': messages.length,
      'last_message_time': messages.isNotEmpty 
          ? messages.first.timestamp.toIso8601String()
          : null,
    };
  }

  /// Extract context items from message metadata
  List<Map<String, dynamic>> extractContextItems(List<ChatMessage> messages) {
    final contextItems = <Map<String, dynamic>>[];
    
    for (final message in messages) {
      if (message.hasContextItem) {
        contextItems.add({
          'id': message.contextItemId,
          'type': message.contextItemType,
          'message_id': message.id,
          'timestamp': message.timestamp.toIso8601String(),
        });
      }
    }
    
    return contextItems;
  }

  /// Check if the chat service is available (network connectivity)
  Future<bool> isServiceAvailable() async {
    try {
      final response = await http.head(
        Uri.parse('$_baseUrl/health'),
      ).timeout(const Duration(seconds: 5));
      
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}

/// Custom exception class for chat-related errors
class ChatException implements Exception {
  final String message;
  final ChatErrorType type;
  final dynamic originalError;

  const ChatException(this.message, this.type, [this.originalError]);

  @override
  String toString() => 'ChatException: $message (Type: ${type.name})';

  /// Get user-friendly error message
  String get userFriendlyMessage {
    switch (type) {
      case ChatErrorType.networkError:
        return 'Please check your internet connection and try again.';
      case ChatErrorType.authentication:
        return 'Please log in again to continue chatting.';
      case ChatErrorType.rateLimited:
        return 'You\'re sending messages too quickly. Please wait a moment.';
      case ChatErrorType.serverError:
        return 'Our servers are experiencing issues. Please try again later.';
      case ChatErrorType.apiError:
        return message.isNotEmpty ? message : 'Something went wrong. Please try again.';
      case ChatErrorType.parseError:
        return 'Received an unexpected response. Please try again.';
      case ChatErrorType.cacheError:
        return 'There was an issue saving your message locally.';
      case ChatErrorType.unknown:
        return 'An unexpected error occurred. Please try again.';
    }
  }

  /// Check if this error is recoverable
  bool get isRecoverable {
    switch (type) {
      case ChatErrorType.networkError:
      case ChatErrorType.rateLimited:
      case ChatErrorType.serverError:
        return true;
      case ChatErrorType.authentication:
      case ChatErrorType.apiError:
      case ChatErrorType.parseError:
      case ChatErrorType.cacheError:
      case ChatErrorType.unknown:
        return false;
    }
  }
}

/// Types of chat errors
enum ChatErrorType {
  networkError,
  authentication,
  rateLimited,
  serverError,
  apiError,
  parseError,
  cacheError,
  unknown,
}
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:reva_mobile_app/services/chat/chat_service.dart';
import 'package:reva_mobile_app/services/cache/chat_cache_service.dart';
import 'package:reva_mobile_app/services/auth/auth_service.dart';
import 'package:reva_mobile_app/models/chat_message.dart';

// Generate mocks
@GenerateMocks([
  http.Client,
  ChatCacheService,
  AuthService,
  Session,
])
import 'chat_service_test.mocks.dart';

void main() {
  group('ChatService Tests', () {
    late ChatService chatService;
    late MockClient mockHttpClient;
    late MockChatCacheService mockCacheService;
    late MockAuthService mockAuthService;
    late MockSession mockSession;

    setUp(() {
      mockHttpClient = MockClient();
      mockCacheService = MockChatCacheService();
      mockAuthService = MockAuthService();
      mockSession = MockSession();

      // Setup basic auth mock
      when(mockAuthService.currentSession).thenReturn(mockSession);
      when(mockSession.accessToken).thenReturn('test_access_token');

      chatService = ChatService(authService: mockAuthService);
    });

    group('ChatException', () {
      test('should create exception with correct properties', () {
        const exception = ChatException(
          'Test error',
          ChatErrorType.networkError,
          'Original error',
        );

        expect(exception.message, equals('Test error'));
        expect(exception.type, equals(ChatErrorType.networkError));
        expect(exception.originalError, equals('Original error'));
        expect(exception.toString(), contains('ChatException: Test error'));
      });

      test('should provide user-friendly error messages', () {
        const networkError = ChatException('Network failed', ChatErrorType.networkError);
        expect(networkError.userFriendlyMessage, 
          contains('check your internet connection'));

        const authError = ChatException('Auth failed', ChatErrorType.authentication);
        expect(authError.userFriendlyMessage, 
          contains('log in again'));

        const rateLimitError = ChatException('Rate limited', ChatErrorType.rateLimited);
        expect(rateLimitError.userFriendlyMessage, 
          contains('sending messages too quickly'));

        const serverError = ChatException('Server error', ChatErrorType.serverError);
        expect(serverError.userFriendlyMessage, 
          contains('servers are experiencing issues'));
      });

      test('should indicate if error is recoverable', () {
        const networkError = ChatException('Network failed', ChatErrorType.networkError);
        expect(networkError.isRecoverable, isTrue);

        const rateLimitError = ChatException('Rate limited', ChatErrorType.rateLimited);
        expect(rateLimitError.isRecoverable, isTrue);

        const authError = ChatException('Auth failed', ChatErrorType.authentication);
        expect(authError.isRecoverable, isFalse);

        const parseError = ChatException('Parse failed', ChatErrorType.parseError);
        expect(parseError.isRecoverable, isFalse);
      });
    });

    group('Send Message', () {
      test('should send message successfully', () async {
        final responseData = {
          'ai_response_text': 'Hello! How can I help you?',
          'action_metadata': null,
          'context_item_id': null,
          'context_item_type': null,
        };

        final response = http.Response(
          jsonEncode(responseData),
          200,
          headers: {'content-type': 'application/json'},
        );

        when(mockHttpClient.post(
          any,
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        )).thenAnswer((_) async => response);

        final result = await chatService.sendMessage(message: 'Hello');

        expect(result.aiResponseText, equals('Hello! How can I help you?'));
        expect(result.hasAction, isFalse);
        expect(result.hasContextItem, isFalse);
      });

      test('should send message with history and context', () async {
        final history = [
          ChatMessage.user(id: '1', content: 'Previous message'),
        ];

        final contextItem = {
          'type': 'task',
          'id': 'task-123',
          'data': {'description': 'Test task'},
        };

        final responseData = {
          'ai_response_text': 'I understand the context.',
          'action_metadata': {
            'type': 'create_task',
            'data': {'description': 'New task'},
          },
          'context_item_id': 'task-456',
          'context_item_type': 'task',
        };

        final response = http.Response(
          jsonEncode(responseData),
          200,
          headers: {'content-type': 'application/json'},
        );

        when(mockHttpClient.post(
          any,
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        )).thenAnswer((_) async => response);

        final result = await chatService.sendMessage(
          message: 'Create a task',
          history: history,
          contextItem: contextItem,
        );

        expect(result.aiResponseText, equals('I understand the context.'));
        expect(result.hasAction, isTrue);
        expect(result.hasContextItem, isTrue);
        expect(result.contextItemId, equals('task-456'));
        expect(result.contextItemType, equals('task'));
      });

      test('should throw ChatException for authentication error', () async {
        when(mockAuthService.currentSession).thenReturn(null);

        expect(
          () => chatService.sendMessage(message: 'Hello'),
          throwsA(isA<ChatException>().having(
            (e) => e.type,
            'type',
            ChatErrorType.authentication,
          )),
        );
      });

      test('should throw ChatException for HTTP errors', () async {
        // Test 401 Unauthorized
        when(mockHttpClient.post(any, headers: anyNamed('headers'), body: anyNamed('body')))
            .thenAnswer((_) async => http.Response('Unauthorized', 401));

        expect(
          () => chatService.sendMessage(message: 'Hello'),
          throwsA(isA<ChatException>().having(
            (e) => e.type,
            'type',
            ChatErrorType.authentication,
          )),
        );

        // Test 429 Rate Limited
        when(mockHttpClient.post(any, headers: anyNamed('headers'), body: anyNamed('body')))
            .thenAnswer((_) async => http.Response('Rate limited', 429));

        expect(
          () => chatService.sendMessage(message: 'Hello'),
          throwsA(isA<ChatException>().having(
            (e) => e.type,
            'type',
            ChatErrorType.rateLimited,
          )),
        );

        // Test 500 Server Error
        when(mockHttpClient.post(any, headers: anyNamed('headers'), body: anyNamed('body')))
            .thenAnswer((_) async => http.Response('Server error', 500));

        expect(
          () => chatService.sendMessage(message: 'Hello'),
          throwsA(isA<ChatException>().having(
            (e) => e.type,
            'type',
            ChatErrorType.serverError,
          )),
        );
      });

      test('should throw ChatException for network errors', () async {
        when(mockHttpClient.post(any, headers: anyNamed('headers'), body: anyNamed('body')))
            .thenThrow(const SocketException('No internet connection'));

        expect(
          () => chatService.sendMessage(message: 'Hello'),
          throwsA(isA<ChatException>().having(
            (e) => e.type,
            'type',
            ChatErrorType.networkError,
          )),
        );
      });

      test('should throw ChatException for invalid JSON response', () async {
        when(mockHttpClient.post(any, headers: anyNamed('headers'), body: anyNamed('body')))
            .thenAnswer((_) async => http.Response('Invalid JSON', 200));

        expect(
          () => chatService.sendMessage(message: 'Hello'),
          throwsA(isA<ChatException>().having(
            (e) => e.type,
            'type',
            ChatErrorType.parseError,
          )),
        );
      });
    });

    group('Message History', () {
      test('should get message history from cache when not stale', () async {
        final cachedMessages = [
          {
            'id': 'msg-1',
            'content': 'Hello',
            'type': 'user',
            'timestamp': DateTime.now().toIso8601String(),
          },
        ];

        when(mockCacheService.isDataStale(any)).thenAnswer((_) async => false);
        when(mockCacheService.getCachedChatMessages(
          limit: anyNamed('limit'),
          offset: anyNamed('offset'),
        )).thenAnswer((_) async => cachedMessages);

        final result = await chatService.getMessageHistory();

        expect(result, hasLength(1));
        expect(result.first.content, equals('Hello'));
        verify(mockCacheService.getCachedChatMessages(
          limit: 20,
          offset: 0,
        )).called(1);
      });

      test('should fetch message history from API when cache is stale', () async {
        final apiResponse = {
          'messages': [
            {
              'id': 'msg-1',
              'content': 'Hello from API',
              'type': 'user',
              'timestamp': DateTime.now().toIso8601String(),
            },
          ],
        };

        when(mockCacheService.isDataStale(any)).thenAnswer((_) async => true);
        when(mockCacheService.getCachedChatMessages(
          limit: anyNamed('limit'),
          offset: anyNamed('offset'),
        )).thenAnswer((_) async => []);

        when(mockHttpClient.get(
          any,
          headers: anyNamed('headers'),
        )).thenAnswer((_) async => http.Response(
          jsonEncode(apiResponse),
          200,
          headers: {'content-type': 'application/json'},
        ));

        when(mockCacheService.cacheChatMessages(any))
            .thenAnswer((_) async {});

        final result = await chatService.getMessageHistory();

        expect(result, hasLength(1));
        expect(result.first.content, equals('Hello from API'));
        verify(mockCacheService.cacheChatMessages(any)).called(1);
      });

      test('should return cached data when API fails and cache available', () async {
        final cachedMessages = [
          {
            'id': 'msg-1',
            'content': 'Cached message',
            'type': 'user',
            'timestamp': DateTime.now().toIso8601String(),
          },
        ];

        when(mockCacheService.getCachedChatMessages(
          limit: anyNamed('limit'),
          offset: anyNamed('offset'),
        )).thenAnswer((_) async => cachedMessages);

        when(mockHttpClient.get(any, headers: anyNamed('headers')))
            .thenThrow(const SocketException('No internet'));

        final result = await chatService.getMessageHistory();

        expect(result, hasLength(1));
        expect(result.first.content, equals('Cached message'));
      });

      test('should throw ChatException when both API and cache fail', () async {
        when(mockCacheService.getCachedChatMessages(
          limit: anyNamed('limit'),
          offset: anyNamed('offset'),
        )).thenAnswer((_) async => []);

        when(mockHttpClient.get(any, headers: anyNamed('headers')))
            .thenThrow(const SocketException('No internet'));

        expect(
          () => chatService.getMessageHistory(),
          throwsA(isA<ChatException>().having(
            (e) => e.type,
            'type',
            ChatErrorType.networkError,
          )),
        );
      });
    });

    group('Message Management', () {
      test('should save message to cache', () async {
        final message = ChatMessage.user(id: 'msg-1', content: 'Test message');

        when(mockCacheService.cacheChatMessage(any))
            .thenAnswer((_) async {});

        await chatService.saveMessage(message);

        verify(mockCacheService.cacheChatMessage(message.toJson())).called(1);
      });

      test('should save unsynced message', () async {
        final message = ChatMessage.user(id: 'msg-1', content: 'Unsynced message');

        when(mockCacheService.addUnsyncedMessage(any))
            .thenAnswer((_) async {});

        await chatService.saveUnsyncedMessage(message);

        verify(mockCacheService.addUnsyncedMessage(message.toJson())).called(1);
      });

      test('should get unsynced messages', () async {
        final unsyncedMessages = [
          {
            'id': 'msg-1',
            'content': 'Unsynced message',
            'type': 'user',
            'timestamp': DateTime.now().toIso8601String(),
          },
        ];

        when(mockCacheService.getUnsyncedMessages())
            .thenAnswer((_) async => unsyncedMessages);

        final result = await chatService.getUnsyncedMessages();

        expect(result, hasLength(1));
        expect(result.first.content, equals('Unsynced message'));
      });

      test('should mark message as synced', () async {
        when(mockCacheService.markMessageAsSynced('msg-1'))
            .thenAnswer((_) async {});

        await chatService.markMessageAsSynced('msg-1');

        verify(mockCacheService.markMessageAsSynced('msg-1')).called(1);
      });

      test('should update message', () async {
        final updates = {'content': 'Updated content'};

        when(mockCacheService.updateCachedMessage('msg-1', updates))
            .thenAnswer((_) async {});

        await chatService.updateMessage('msg-1', updates);

        verify(mockCacheService.updateCachedMessage('msg-1', updates)).called(1);
      });

      test('should delete message', () async {
        when(mockCacheService.deleteCachedMessage('msg-1'))
            .thenAnswer((_) async {});

        await chatService.deleteMessage('msg-1');

        verify(mockCacheService.deleteCachedMessage('msg-1')).called(1);
      });

      test('should clear chat history', () async {
        when(mockCacheService.clearCache()).thenAnswer((_) async {});

        await chatService.clearHistory();

        verify(mockCacheService.clearCache()).called(1);
      });

      test('should get message count', () async {
        when(mockCacheService.getMessageCount()).thenAnswer((_) async => 42);

        final count = await chatService.getMessageCount();

        expect(count, equals(42));
        verify(mockCacheService.getMessageCount()).called(1);
      });

      test('should cleanup old messages', () async {
        when(mockCacheService.clearOldMessages(
          keepCount: anyNamed('keepCount'),
          keepDuration: anyNamed('keepDuration'),
        )).thenAnswer((_) async {});

        await chatService.cleanupOldMessages(
          keepCount: 500,
          keepDuration: const Duration(days: 30),
        );

        verify(mockCacheService.clearOldMessages(
          keepCount: 500,
          keepDuration: const Duration(days: 30),
        )).called(1);
      });
    });

    group('Utility Methods', () {
      test('should build conversation context', () {
        final messages = [
          ChatMessage.user(id: '1', content: 'Hello'),
          ChatMessage.assistant(
            id: '2',
            content: 'Hi there!',
            metadata: {'action': 'greeting'},
          ),
        ];

        final context = chatService.buildConversationContext(
          recentMessages: messages,
          maxMessages: 5,
        );

        expect(context['recent_messages'], hasLength(2));
        expect(context['message_count'], equals(2));
        expect(context['last_message_time'], isNotNull);

        final firstMessage = context['recent_messages'][0];
        expect(firstMessage['type'], equals('user'));
        expect(firstMessage['content'], equals('Hello'));
      });

      test('should extract context items from messages', () {
        final messages = [
          ChatMessage.assistant(
            id: '1',
            content: 'Task created',
            metadata: {
              'contextItemId': 'task-123',
              'contextItemType': 'task',
            },
          ),
          ChatMessage.user(id: '2', content: 'Thanks'),
          ChatMessage.assistant(
            id: '3',
            content: 'Expense logged',
            metadata: {
              'contextItemId': 'expense-456',
              'contextItemType': 'expense',
            },
          ),
        ];

        final contextItems = chatService.extractContextItems(messages);

        expect(contextItems, hasLength(2));
        expect(contextItems[0]['id'], equals('task-123'));
        expect(contextItems[0]['type'], equals('task'));
        expect(contextItems[1]['id'], equals('expense-456'));
        expect(contextItems[1]['type'], equals('expense'));
      });

      test('should check service availability', () async {
        // Test service available
        when(mockHttpClient.head(any))
            .thenAnswer((_) async => http.Response('', 200));

        final isAvailable = await chatService.isServiceAvailable();
        expect(isAvailable, isTrue);

        // Test service unavailable
        when(mockHttpClient.head(any))
            .thenAnswer((_) async => http.Response('', 500));

        final isUnavailable = await chatService.isServiceAvailable();
        expect(isUnavailable, isFalse);

        // Test network error
        when(mockHttpClient.head(any))
            .thenThrow(const SocketException('No connection'));

        final isUnavailableNetwork = await chatService.isServiceAvailable();
        expect(isUnavailableNetwork, isFalse);
      });
    });

    group('Error Handling', () {
      test('should handle cache errors gracefully', () async {
        final message = ChatMessage.user(id: 'msg-1', content: 'Test');

        when(mockCacheService.cacheChatMessage(any))
            .thenThrow(Exception('Cache error'));

        expect(
          () => chatService.saveMessage(message),
          throwsA(isA<ChatException>().having(
            (e) => e.type,
            'type',
            ChatErrorType.cacheError,
          )),
        );
      });

      test('should handle timeout errors', () async {
        when(mockHttpClient.post(any, headers: anyNamed('headers'), body: anyNamed('body')))
            .thenAnswer((_) async {
          await Future.delayed(const Duration(seconds: 35)); // Longer than timeout
          return http.Response('{}', 200);
        });

        expect(
          () => chatService.sendMessage(message: 'Hello'),
          throwsA(isA<ChatException>()),
        );
      });
    });
  });
}
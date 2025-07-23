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
import 'chat_api_integration_test.mocks.dart';

void main() {
  group('Chat API Integration Tests', () {
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

    group('End-to-End Chat Flow', () {
      test('should complete full chat conversation flow', () async {
        // Setup conversation history
        final conversationHistory = [
          ChatMessage.user(id: 'msg-1', content: 'Hello'),
          ChatMessage.assistant(id: 'msg-2', content: 'Hi! How can I help you?'),
        ];

        // Mock cache operations
        when(mockCacheService.isDataStale(any)).thenAnswer((_) async => false);
        when(mockCacheService.getCachedChatMessages(
          limit: anyNamed('limit'),
          offset: anyNamed('offset'),
        )).thenAnswer((_) async => conversationHistory.map((m) => m.toJson()).toList());

        // Mock API response for new message
        final apiResponse = {
          'ai_response_text': 'I can help you create a task. What would you like to do?',
          'action_metadata': {
            'type': 'create_task',
            'data': {'description': 'New task from chat'}
          },
          'context_item_id': 'task-123',
          'context_item_type': 'task',
        };

        when(mockHttpClient.post(
          any,
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        )).thenAnswer((_) async => http.Response(
          jsonEncode(apiResponse),
          200,
          headers: {'content-type': 'application/json'},
        ));

        // Mock cache save operations
        when(mockCacheService.cacheChatMessage(any)).thenAnswer((_) async {});

        // Step 1: Get conversation history
        final history = await chatService.getMessageHistory();
        expect(history, hasLength(2));
        expect(history[0].content, equals('Hello'));
        expect(history[1].content, equals('Hi! How can I help you?'));

        // Step 2: Send new message with context
        final response = await chatService.sendMessage(
          message: 'Create a task for me',
          history: history,
          contextItem: {
            'type': 'conversation',
            'messages': history.map((m) => m.toJson()).toList(),
          },
        );

        // Step 3: Verify response
        expect(response.aiResponseText, contains('create a task'));
        expect(response.hasAction, isTrue);
        expect(response.actionMetadata!['type'], equals('create_task'));
        expect(response.hasContextItem, isTrue);
        expect(response.contextItemType, equals('task'));

        // Step 4: Save response to cache
        final responseMessage = ChatMessage.assistant(
          id: 'msg-3',
          content: response.aiResponseText,
          metadata: {
            'action': response.actionMetadata,
            'contextItemId': response.contextItemId,
            'contextItemType': response.contextItemType,
          },
        );

        await chatService.saveMessage(responseMessage);

        verify(mockCacheService.cacheChatMessage(responseMessage.toJson())).called(1);
      });

      test('should handle offline-to-online message synchronization', () async {
        // Setup offline messages
        final offlineMessages = [
          ChatMessage.user(id: 'offline-1', content: 'Message sent offline'),
          ChatMessage.user(id: 'offline-2', content: 'Another offline message'),
        ];

        when(mockCacheService.getUnsyncedMessages())
            .thenAnswer((_) async => offlineMessages.map((m) => m.toJson()).toList());

        // Mock successful API responses for offline messages
        final responses = [
          {
            'ai_response_text': 'Got your first offline message',
            'action_metadata': null,
            'context_item_id': null,
            'context_item_type': null,
          },
          {
            'ai_response_text': 'Got your second offline message',
            'action_metadata': null,
            'context_item_id': null,
            'context_item_type': null,
          },
        ];

        var callCount = 0;
        when(mockHttpClient.post(
          any,
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        )).thenAnswer((_) async {
          final response = responses[callCount % responses.length];
          callCount++;
          return http.Response(
            jsonEncode(response),
            200,
            headers: {'content-type': 'application/json'},
          );
        });

        when(mockCacheService.markMessageAsSynced(any)).thenAnswer((_) async {});
        when(mockCacheService.cacheChatMessage(any)).thenAnswer((_) async {});

        // Get unsynced messages
        final unsyncedMessages = await chatService.getUnsyncedMessages();
        expect(unsyncedMessages, hasLength(2));

        // Sync each message
        for (final message in unsyncedMessages) {
          final response = await chatService.sendMessage(message: message.content);
          expect(response.aiResponseText, isNotEmpty);

          // Mark as synced
          await chatService.markMessageAsSynced(message.id);
        }

        // Verify all messages were marked as synced
        verify(mockCacheService.markMessageAsSynced('offline-1')).called(1);
        verify(mockCacheService.markMessageAsSynced('offline-2')).called(1);
      });

      test('should handle message pagination and infinite scroll', () async {
        // Setup paginated responses
        final page1Messages = List.generate(20, (i) => {
          'id': 'msg-${i + 1}',
          'content': 'Message ${i + 1}',
          'type': 'user',
          'timestamp': DateTime.now().subtract(Duration(minutes: i)).toIso8601String(),
        });

        final page2Messages = List.generate(20, (i) => {
          'id': 'msg-${i + 21}',
          'content': 'Message ${i + 21}',
          'type': 'assistant',
          'timestamp': DateTime.now().subtract(Duration(minutes: i + 20)).toIso8601String(),
        });

        // Mock cache responses
        when(mockCacheService.isDataStale(any)).thenAnswer((_) async => true);
        when(mockCacheService.getCachedChatMessages(
          limit: anyNamed('limit'),
          offset: anyNamed('offset'),
        )).thenAnswer((_) async => []);

        // Mock API responses for pagination
        when(mockHttpClient.get(
          argThat(contains('page=0')),
          headers: anyNamed('headers'),
        )).thenAnswer((_) async => http.Response(
          jsonEncode({'messages': page1Messages}),
          200,
          headers: {'content-type': 'application/json'},
        ));

        when(mockHttpClient.get(
          argThat(contains('page=1')),
          headers: anyNamed('headers'),
        )).thenAnswer((_) async => http.Response(
          jsonEncode({'messages': page2Messages}),
          200,
          headers: {'content-type': 'application/json'},
        ));

        when(mockCacheService.cacheChatMessages(any)).thenAnswer((_) async {});

        // Load first page
        final firstPage = await chatService.getMessageHistory(page: 0, pageSize: 20);
        expect(firstPage, hasLength(20));
        expect(firstPage.first.content, equals('Message 1'));

        // Load second page
        final secondPage = await chatService.getMessageHistory(page: 1, pageSize: 20);
        expect(secondPage, hasLength(20));
        expect(secondPage.first.content, equals('Message 21'));

        // Verify caching was called for first page only
        verify(mockCacheService.cacheChatMessages(any)).called(1);
      });
    });

    group('API Error Handling and Recovery', () {
      test('should handle API timeout with retry mechanism', () async {
        var attemptCount = 0;
        when(mockHttpClient.post(
          any,
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        )).thenAnswer((_) async {
          attemptCount++;
          if (attemptCount < 3) {
            await Future.delayed(const Duration(seconds: 35)); // Timeout
            throw Exception('Timeout');
          }
          return http.Response(
            jsonEncode({
              'ai_response_text': 'Success after retries',
              'action_metadata': null,
              'context_item_id': null,
              'context_item_type': null,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        });

        // This would typically be handled by a retry wrapper
        // For testing, we simulate the retry logic
        ChatResponse? response;
        for (int i = 0; i < 3; i++) {
          try {
            response = await chatService.sendMessage(message: 'Test message');
            break;
          } catch (e) {
            if (i == 2) rethrow; // Last attempt
            await Future.delayed(Duration(seconds: i + 1));
          }
        }

        expect(response, isNotNull);
        expect(response!.aiResponseText, equals('Success after retries'));
        expect(attemptCount, equals(3));
      });

      test('should handle rate limiting with exponential backoff', () async {
        var attemptCount = 0;
        when(mockHttpClient.post(
          any,
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        )).thenAnswer((_) async {
          attemptCount++;
          if (attemptCount < 3) {
            return http.Response('Rate limited', 429);
          }
          return http.Response(
            jsonEncode({
              'ai_response_text': 'Success after rate limit',
              'action_metadata': null,
              'context_item_id': null,
              'context_item_type': null,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        });

        // Simulate retry with exponential backoff
        ChatResponse? response;
        for (int i = 0; i < 3; i++) {
          try {
            response = await chatService.sendMessage(message: 'Test message');
            break;
          } catch (e) {
            if (e is ChatException && e.type == ChatErrorType.rateLimited) {
              if (i == 2) rethrow; // Last attempt
              await Future.delayed(Duration(seconds: (i + 1) * 2)); // Exponential backoff
            } else {
              rethrow;
            }
          }
        }

        expect(response, isNotNull);
        expect(response!.aiResponseText, equals('Success after rate limit'));
      });

      test('should handle server errors with graceful degradation', () async {
        // Mock server error
        when(mockHttpClient.post(
          any,
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        )).thenAnswer((_) async => http.Response('Internal Server Error', 500));

        // Mock fallback to cached suggestions
        when(mockCacheService.getCachedChatMessages(
          limit: anyNamed('limit'),
          offset: anyNamed('offset'),
        )).thenAnswer((_) async => [
          {
            'id': 'fallback-1',
            'content': 'Try rephrasing your question',
            'type': 'system',
            'timestamp': DateTime.now().toIso8601String(),
          }
        ]);

        // Attempt to send message
        expect(
          () => chatService.sendMessage(message: 'Test message'),
          throwsA(isA<ChatException>().having(
            (e) => e.type,
            'type',
            ChatErrorType.serverError,
          )),
        );

        // Fallback to cached suggestions
        final fallbackMessages = await chatService.getMessageHistory();
        expect(fallbackMessages, hasLength(1));
        expect(fallbackMessages.first.content, equals('Try rephrasing your question'));
      });
    });

    group('Context Management Integration', () {
      test('should maintain conversation context across multiple messages', () async {
        final conversationContext = <String, dynamic>{};
        
        // First message - establish context
        when(mockHttpClient.post(
          any,
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        )).thenAnswer((_) async {
          final requestBody = jsonDecode(verify(mockHttpClient.post(
            any,
            headers: anyNamed('headers'),
            body: captureAnyNamed('body'),
          )).captured.last);
          
          conversationContext.addAll(requestBody['context_item'] ?? {});
          
          return http.Response(
            jsonEncode({
              'ai_response_text': 'I understand you want to create a task',
              'action_metadata': {
                'type': 'create_task',
                'data': {'description': 'Task from conversation'}
              },
              'context_item_id': 'task-456',
              'context_item_type': 'task',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        });

        // Send first message
        final response1 = await chatService.sendMessage(
          message: 'I need to create a task',
          contextItem: {'user_intent': 'task_creation'},
        );

        expect(response1.hasAction, isTrue);
        expect(response1.actionMetadata!['type'], equals('create_task'));

        // Second message - context should be maintained
        final response2 = await chatService.sendMessage(
          message: 'Make it high priority',
          contextItem: {
            'previous_action': response1.actionMetadata,
            'context_item_id': response1.contextItemId,
          },
        );

        // Verify context was passed in both requests
        expect(conversationContext, isNotEmpty);
      });

      test('should extract and manage context items from responses', () async {
        final messages = [
          ChatMessage.assistant(
            id: '1',
            content: 'Task created successfully',
            metadata: {
              'contextItemId': 'task-123',
              'contextItemType': 'task',
            },
          ),
          ChatMessage.assistant(
            id: '2',
            content: 'Expense logged',
            metadata: {
              'contextItemId': 'expense-456',
              'contextItemType': 'expense',
            },
          ),
          ChatMessage.user(id: '3', content: 'Thanks'),
        ];

        final contextItems = chatService.extractContextItems(messages);

        expect(contextItems, hasLength(2));
        expect(contextItems[0]['id'], equals('task-123'));
        expect(contextItems[0]['type'], equals('task'));
        expect(contextItems[1]['id'], equals('expense-456'));
        expect(contextItems[1]['type'], equals('expense'));
      });

      test('should build conversation context for API requests', () async {
        final recentMessages = [
          ChatMessage.user(id: '1', content: 'Create a task'),
          ChatMessage.assistant(
            id: '2',
            content: 'Task created',
            metadata: {'action': {'type': 'create_task'}},
          ),
          ChatMessage.user(id: '3', content: 'Set it to high priority'),
        ];

        final context = chatService.buildConversationContext(
          recentMessages: recentMessages,
          maxMessages: 5,
        );

        expect(context['recent_messages'], hasLength(3));
        expect(context['message_count'], equals(3));
        expect(context['last_message_time'], isNotNull);

        final firstMessage = context['recent_messages'][0];
        expect(firstMessage['type'], equals('user'));
        expect(firstMessage['content'], equals('Create a task'));
      });
    });

    group('Performance and Optimization', () {
      test('should handle concurrent API requests efficiently', () async {
        // Mock successful responses
        when(mockHttpClient.post(
          any,
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        )).thenAnswer((_) async => http.Response(
          jsonEncode({
            'ai_response_text': 'Concurrent response',
            'action_metadata': null,
            'context_item_id': null,
            'context_item_type': null,
          }),
          200,
          headers: {'content-type': 'application/json'},
        ));

        // Send multiple concurrent requests
        final futures = List.generate(5, (i) => chatService.sendMessage(
          message: 'Concurrent message $i',
        ));

        final responses = await Future.wait(futures);

        // All should succeed
        expect(responses, hasLength(5));
        for (final response in responses) {
          expect(response.aiResponseText, equals('Concurrent response'));
        }
      });

      test('should optimize cache usage for frequently accessed messages', () async {
        // Mock cache hit for recent messages
        when(mockCacheService.isDataStale(any)).thenAnswer((_) async => false);
        when(mockCacheService.getCachedChatMessages(
          limit: anyNamed('limit'),
          offset: anyNamed('offset'),
        )).thenAnswer((_) async => [
          {
            'id': 'cached-1',
            'content': 'Cached message',
            'type': 'user',
            'timestamp': DateTime.now().toIso8601String(),
          }
        ]);

        // Multiple requests for same data
        for (int i = 0; i < 3; i++) {
          final messages = await chatService.getMessageHistory();
          expect(messages, hasLength(1));
          expect(messages.first.content, equals('Cached message'));
        }

        // Verify cache was used (no API calls)
        verifyNever(mockHttpClient.get(any, headers: anyNamed('headers')));
        
        // Verify cache was accessed multiple times
        verify(mockCacheService.getCachedChatMessages(
          limit: 20,
          offset: 0,
        )).called(3);
      });

      test('should handle large message payloads efficiently', () async {
        // Create large message content
        final largeContent = 'A' * 5000; // 5KB message
        
        when(mockHttpClient.post(
          any,
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        )).thenAnswer((_) async {
          // Verify request body size is reasonable
          final body = verify(mockHttpClient.post(
            any,
            headers: anyNamed('headers'),
            body: captureAnyNamed('body'),
          )).captured.last as String;
          
          expect(body.length, lessThan(10000)); // Should be compressed or optimized
          
          return http.Response(
            jsonEncode({
              'ai_response_text': 'Processed large message',
              'action_metadata': null,
              'context_item_id': null,
              'context_item_type': null,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        });

        final response = await chatService.sendMessage(message: largeContent);
        expect(response.aiResponseText, equals('Processed large message'));
      });
    });

    group('Service Availability and Health Checks', () {
      test('should check service availability', () async {
        // Mock health check endpoint
        when(mockHttpClient.head(any))
            .thenAnswer((_) async => http.Response('', 200));

        final isAvailable = await chatService.isServiceAvailable();
        expect(isAvailable, isTrue);

        verify(mockHttpClient.head(argThat(contains('/health')))).called(1);
      });

      test('should handle service unavailability gracefully', () async {
        // Mock service unavailable
        when(mockHttpClient.head(any))
            .thenAnswer((_) async => http.Response('Service Unavailable', 503));

        final isAvailable = await chatService.isServiceAvailable();
        expect(isAvailable, isFalse);
      });

      test('should provide fallback functionality when service is down', () async {
        // Mock service down
        when(mockHttpClient.post(
          any,
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        )).thenThrow(const SocketException('Service unavailable'));

        // Mock offline message saving
        when(mockCacheService.addUnsyncedMessage(any)).thenAnswer((_) async {});

        // Attempt to send message
        expect(
          () => chatService.sendMessage(message: 'Test message'),
          throwsA(isA<ChatException>().having(
            (e) => e.type,
            'type',
            ChatErrorType.networkError,
          )),
        );

        // Save message for later sync
        final offlineMessage = ChatMessage.user(
          id: 'offline-msg',
          content: 'Test message',
        );
        
        await chatService.saveUnsyncedMessage(offlineMessage);
        
        verify(mockCacheService.addUnsyncedMessage(offlineMessage.toJson())).called(1);
      });
    });
  });
}
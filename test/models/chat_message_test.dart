import 'package:flutter_test/flutter_test.dart';
import 'package:reva_mobile_app/models/chat_message.dart';

void main() {
  group('ChatMessage Model Tests', () {
    late ChatMessage testMessage;
    late DateTime testTimestamp;

    setUp(() {
      testTimestamp = DateTime(2024, 1, 15, 14, 30);
      testMessage = ChatMessage(
        id: 'msg-1',
        content: 'Hello, how can I help you today?',
        type: MessageType.assistant,
        timestamp: testTimestamp,
        metadata: {
          'action': {
            'type': 'create_task',
            'data': {'description': 'Test task'}
          },
          'contextItemId': 'task-123',
          'contextItemType': 'task',
        },
      );
    });

    group('ChatMessage Creation', () {
      test('should create message with all properties', () {
        expect(testMessage.id, equals('msg-1'));
        expect(testMessage.content, equals('Hello, how can I help you today?'));
        expect(testMessage.type, equals(MessageType.assistant));
        expect(testMessage.timestamp, equals(testTimestamp));
        expect(testMessage.metadata, isNotNull);
        expect(testMessage.metadata!['contextItemId'], equals('task-123'));
      });

      test('should create message without metadata', () {
        final simpleMessage = ChatMessage(
          id: 'msg-2',
          content: 'Simple message',
          type: MessageType.user,
          timestamp: DateTime.now(),
        );

        expect(simpleMessage.metadata, isNull);
      });
    });

    group('Factory Constructors', () {
      test('should create user message with factory constructor', () {
        final userMessage = ChatMessage.user(
          id: 'user-msg-1',
          content: 'Hello AI',
        );

        expect(userMessage.type, equals(MessageType.user));
        expect(userMessage.content, equals('Hello AI'));
        expect(userMessage.id, equals('user-msg-1'));
      });

      test('should create assistant message with factory constructor', () {
        final assistantMessage = ChatMessage.assistant(
          id: 'ai-msg-1',
          content: 'Hello human',
          metadata: {'test': 'data'},
        );

        expect(assistantMessage.type, equals(MessageType.assistant));
        expect(assistantMessage.content, equals('Hello human'));
        expect(assistantMessage.metadata!['test'], equals('data'));
      });

      test('should create system message with factory constructor', () {
        final systemMessage = ChatMessage.system(
          id: 'sys-msg-1',
          content: 'System notification',
        );

        expect(systemMessage.type, equals(MessageType.system));
        expect(systemMessage.content, equals('System notification'));
      });
    });

    group('JSON Serialization', () {
      test('should serialize to JSON correctly', () {
        final json = testMessage.toJson();

        expect(json['id'], equals('msg-1'));
        expect(json['content'], equals('Hello, how can I help you today?'));
        expect(json['type'], equals('assistant'));
        expect(json['timestamp'], equals(testTimestamp.toIso8601String()));
        expect(json['metadata'], isNotNull);
        expect(json['metadata']['contextItemId'], equals('task-123'));
      });

      test('should deserialize from JSON correctly', () {
        final json = {
          'id': 'msg-1',
          'content': 'Hello, how can I help you today?',
          'type': 'assistant',
          'timestamp': testTimestamp.toIso8601String(),
          'metadata': {
            'action': {
              'type': 'create_task',
              'data': {'description': 'Test task'}
            },
            'contextItemId': 'task-123',
            'contextItemType': 'task',
          },
        };

        final message = ChatMessage.fromJson(json);

        expect(message.id, equals('msg-1'));
        expect(message.content, equals('Hello, how can I help you today?'));
        expect(message.type, equals(MessageType.assistant));
        expect(message.timestamp, equals(testTimestamp));
        expect(message.metadata!['contextItemId'], equals('task-123'));
      });

      test('should handle null metadata in JSON', () {
        final json = {
          'id': 'msg-2',
          'content': 'Simple message',
          'type': 'user',
          'timestamp': DateTime.now().toIso8601String(),
          'metadata': null,
        };

        final message = ChatMessage.fromJson(json);
        expect(message.metadata, isNull);
      });
    });

    group('Business Logic Properties', () {
      test('isFromUser should return correct values', () {
        final userMessage = testMessage.copyWith(type: MessageType.user);
        final assistantMessage = testMessage.copyWith(type: MessageType.assistant);
        final systemMessage = testMessage.copyWith(type: MessageType.system);

        expect(userMessage.isFromUser, isTrue);
        expect(assistantMessage.isFromUser, isFalse);
        expect(systemMessage.isFromUser, isFalse);
      });

      test('isFromAssistant should return correct values', () {
        final userMessage = testMessage.copyWith(type: MessageType.user);
        final assistantMessage = testMessage.copyWith(type: MessageType.assistant);
        final systemMessage = testMessage.copyWith(type: MessageType.system);

        expect(userMessage.isFromAssistant, isFalse);
        expect(assistantMessage.isFromAssistant, isTrue);
        expect(systemMessage.isFromAssistant, isFalse);
      });

      test('isSystemMessage should return correct values', () {
        final userMessage = testMessage.copyWith(type: MessageType.user);
        final assistantMessage = testMessage.copyWith(type: MessageType.assistant);
        final systemMessage = testMessage.copyWith(type: MessageType.system);

        expect(userMessage.isSystemMessage, isFalse);
        expect(assistantMessage.isSystemMessage, isFalse);
        expect(systemMessage.isSystemMessage, isTrue);
      });

      test('hasActionMetadata should return correct values', () {
        expect(testMessage.hasActionMetadata, isTrue);

        final messageWithoutAction = testMessage.copyWith(
          metadata: {'other': 'data'},
        );
        expect(messageWithoutAction.hasActionMetadata, isFalse);

        final messageWithoutMetadata = testMessage.copyWith(metadata: null);
        expect(messageWithoutMetadata.hasActionMetadata, isFalse);
      });

      test('actionType should return correct action type', () {
        expect(testMessage.actionType, equals('create_task'));

        final messageWithoutAction = testMessage.copyWith(
          metadata: {'other': 'data'},
        );
        expect(messageWithoutAction.actionType, isNull);
      });

      test('actionData should return correct action data', () {
        final actionData = testMessage.actionData;
        expect(actionData, isNotNull);
        expect(actionData!['description'], equals('Test task'));
      });

      test('hasContextItem should return correct values', () {
        expect(testMessage.hasContextItem, isTrue);

        final messageWithoutContext = testMessage.copyWith(
          metadata: {'action': 'data'},
        );
        expect(messageWithoutContext.hasContextItem, isFalse);
      });

      test('contextItemId and contextItemType should return correct values', () {
        expect(testMessage.contextItemId, equals('task-123'));
        expect(testMessage.contextItemType, equals('task'));
      });
    });

    group('Display Formatting', () {
      test('formattedTimestamp should show time only for today', () {
        final todayMessage = testMessage.copyWith(
          timestamp: DateTime(
            DateTime.now().year,
            DateTime.now().month,
            DateTime.now().day,
            14,
            30,
          ),
        );
        expect(todayMessage.formattedTimestamp, equals('14:30'));
      });

      test('formattedTimestamp should show month/day for this year', () {
        final thisYearMessage = testMessage.copyWith(
          timestamp: DateTime(DateTime.now().year, 3, 15, 14, 30),
        );
        expect(thisYearMessage.formattedTimestamp, equals('3/15'));
      });

      test('formattedTimestamp should show full date for other years', () {
        final otherYearMessage = testMessage.copyWith(
          timestamp: DateTime(2025, 3, 15, 14, 30),
        );
        expect(otherYearMessage.formattedTimestamp, equals('15/3/2025'));
      });

      test('typeDisplayName should return correct display names', () {
        final userMessage = testMessage.copyWith(type: MessageType.user);
        final assistantMessage = testMessage.copyWith(type: MessageType.assistant);
        final systemMessage = testMessage.copyWith(type: MessageType.system);

        expect(userMessage.typeDisplayName, equals('You'));
        expect(assistantMessage.typeDisplayName, equals('Reva'));
        expect(systemMessage.typeDisplayName, equals('System'));
      });
    });

    group('Validation', () {
      test('isValid should return true for valid message', () {
        expect(testMessage.isValid(), isTrue);
      });

      test('isValid should return false for empty content', () {
        final invalidMessage = testMessage.copyWith(content: '');
        expect(invalidMessage.isValid(), isFalse);
      });

      test('isValid should return false for empty ID', () {
        final invalidMessage = testMessage.copyWith(id: '');
        expect(invalidMessage.isValid(), isFalse);
      });

      test('getValidationErrors should return empty list for valid message', () {
        final errors = testMessage.getValidationErrors();
        expect(errors, isEmpty);
      });

      test('getValidationErrors should return appropriate errors', () {
        final invalidMessage = ChatMessage(
          id: '',
          content: '',
          type: MessageType.user,
          timestamp: DateTime.now().add(const Duration(hours: 1)),
        );

        final errors = invalidMessage.getValidationErrors();
        expect(errors, contains('Message ID cannot be empty'));
        expect(errors, contains('Message content cannot be empty'));
        expect(errors, contains('Message timestamp cannot be in the future'));
      });

      test('getValidationErrors should check content length', () {
        final longContentMessage = testMessage.copyWith(
          content: 'a' * 10001, // 10001 characters
        );

        final errors = longContentMessage.getValidationErrors();
        expect(errors, contains('Message content cannot exceed 10,000 characters'));
      });
    });

    group('Equality and CopyWith', () {
      test('should support equality comparison', () {
        final message1 = testMessage;
        final message2 = ChatMessage(
          id: 'msg-1',
          content: 'Hello, how can I help you today?',
          type: MessageType.assistant,
          timestamp: testTimestamp,
          metadata: {
            'action': {
              'type': 'create_task',
              'data': {'description': 'Test task'}
            },
            'contextItemId': 'task-123',
            'contextItemType': 'task',
          },
        );

        expect(message1, equals(message2));
      });

      test('should support copyWith method', () {
        final updatedMessage = testMessage.copyWith(
          content: 'Updated content',
          type: MessageType.user,
        );

        expect(updatedMessage.id, equals(testMessage.id));
        expect(updatedMessage.content, equals('Updated content'));
        expect(updatedMessage.type, equals(MessageType.user));
        expect(updatedMessage.timestamp, equals(testMessage.timestamp));
      });

      test('should have proper toString implementation', () {
        final messageString = testMessage.toString();
        expect(messageString, contains('ChatMessage('));
        expect(messageString, contains('msg-1'));
        expect(messageString, contains('assistant'));
      });

      test('should truncate long content in toString', () {
        final longMessage = testMessage.copyWith(
          content: 'a' * 100, // Long content
        );
        final messageString = longMessage.toString();
        expect(messageString, contains('...'));
      });
    });

    group('MessageType Enum', () {
      test('should serialize message type enum correctly', () {
        expect(MessageType.user.name, equals('user'));
        expect(MessageType.assistant.name, equals('assistant'));
        expect(MessageType.system.name, equals('system'));
      });

      test('should handle all message type values', () {
        final types = MessageType.values;
        expect(types, hasLength(3));
        expect(types, contains(MessageType.user));
        expect(types, contains(MessageType.assistant));
        expect(types, contains(MessageType.system));
      });
    });
  });

  group('ChatResponse Model Tests', () {
    late ChatResponse testResponse;

    setUp(() {
      testResponse = ChatResponse(
        aiResponseText: 'I can help you with that task.',
        actionMetadata: {
          'type': 'create_task',
          'data': {'description': 'New task'}
        },
        contextItemId: 'task-456',
        contextItemType: 'task',
      );
    });

    group('ChatResponse Creation', () {
      test('should create response with all properties', () {
        expect(testResponse.aiResponseText, equals('I can help you with that task.'));
        expect(testResponse.actionMetadata, isNotNull);
        expect(testResponse.contextItemId, equals('task-456'));
        expect(testResponse.contextItemType, equals('task'));
      });

      test('should create response with minimal properties', () {
        final simpleResponse = ChatResponse(
          aiResponseText: 'Simple response',
        );

        expect(simpleResponse.aiResponseText, equals('Simple response'));
        expect(simpleResponse.actionMetadata, isNull);
        expect(simpleResponse.contextItemId, isNull);
        expect(simpleResponse.contextItemType, isNull);
      });
    });

    group('JSON Serialization', () {
      test('should serialize to JSON correctly', () {
        final json = testResponse.toJson();

        expect(json['ai_response_text'], equals('I can help you with that task.'));
        expect(json['action_metadata'], isNotNull);
        expect(json['context_item_id'], equals('task-456'));
        expect(json['context_item_type'], equals('task'));
      });

      test('should deserialize from JSON correctly', () {
        final json = {
          'ai_response_text': 'I can help you with that task.',
          'action_metadata': {
            'type': 'create_task',
            'data': {'description': 'New task'}
          },
          'context_item_id': 'task-456',
          'context_item_type': 'task',
        };

        final response = ChatResponse.fromJson(json);

        expect(response.aiResponseText, equals('I can help you with that task.'));
        expect(response.actionMetadata, isNotNull);
        expect(response.contextItemId, equals('task-456'));
        expect(response.contextItemType, equals('task'));
      });
    });

    group('Business Logic Properties', () {
      test('hasAction should return correct values', () {
        expect(testResponse.hasAction, isTrue);

        final responseWithoutAction = ChatResponse(
          aiResponseText: 'Simple response',
          actionMetadata: null,
        );
        expect(responseWithoutAction.hasAction, isFalse);
      });

      test('hasContextItem should return correct values', () {
        expect(testResponse.hasContextItem, isTrue);

        final responseWithoutContext = ChatResponse(
          aiResponseText: 'Simple response',
          contextItemId: null,
          contextItemType: null,
        );
        expect(responseWithoutContext.hasContextItem, isFalse);

        final responseWithPartialContext = ChatResponse(
          aiResponseText: 'Simple response',
          contextItemId: 'task-123',
          contextItemType: null,
        );
        expect(responseWithPartialContext.hasContextItem, isFalse);
      });
    });

    group('Equality and CopyWith', () {
      test('should support equality comparison', () {
        final response1 = testResponse;
        final response2 = ChatResponse(
          aiResponseText: 'I can help you with that task.',
          actionMetadata: {
            'type': 'create_task',
            'data': {'description': 'New task'}
          },
          contextItemId: 'task-456',
          contextItemType: 'task',
        );

        expect(response1, equals(response2));
      });

      test('should support copyWith method', () {
        final updatedResponse = testResponse.copyWith(
          aiResponseText: 'Updated response',
          contextItemId: 'task-789',
        );

        expect(updatedResponse.aiResponseText, equals('Updated response'));
        expect(updatedResponse.contextItemId, equals('task-789'));
        expect(updatedResponse.actionMetadata, equals(testResponse.actionMetadata));
        expect(updatedResponse.contextItemType, equals(testResponse.contextItemType));
      });

      test('should have proper toString implementation', () {
        final responseString = testResponse.toString();
        expect(responseString, contains('ChatResponse('));
        expect(responseString, contains('hasAction: true'));
      });

      test('should truncate long response text in toString', () {
        final longResponse = testResponse.copyWith(
          aiResponseText: 'a' * 100, // Long response
        );
        final responseString = longResponse.toString();
        expect(responseString, contains('...'));
      });
    });
  });
}
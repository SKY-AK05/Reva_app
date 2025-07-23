import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:reva_mobile_app/widgets/chat/chat_message_bubble.dart';
import 'package:reva_mobile_app/widgets/chat/chat_message_list.dart';
import 'package:reva_mobile_app/widgets/chat/chat_input_field.dart';
import 'package:reva_mobile_app/widgets/chat/chat_app_bar.dart';
import 'package:reva_mobile_app/widgets/chat/action_card.dart';
import 'package:reva_mobile_app/widgets/chat/chat_loading_indicator.dart';
import 'package:reva_mobile_app/widgets/chat/connectivity_status.dart';
import 'package:reva_mobile_app/models/chat_message.dart';
import 'package:reva_mobile_app/providers/chat_provider.dart';
import 'package:reva_mobile_app/services/connectivity/connectivity_service.dart';
import 'package:reva_mobile_app/core/theme/app_theme.dart';

// Generate mocks
@GenerateMocks([ConnectivityService])
import 'chat_widgets_test.mocks.dart';

void main() {
  group('Chat Widget Tests', () {
    late MockConnectivityService mockConnectivityService;

    setUp(() {
      mockConnectivityService = MockConnectivityService();
      when(mockConnectivityService.isConnected).thenReturn(true);
      when(mockConnectivityService.connectionStream)
          .thenAnswer((_) => Stream.value(true));
    });

    group('ChatMessageBubble Widget', () {
      testWidgets('should display user message correctly', (WidgetTester tester) async {
        final userMessage = ChatMessage.user(
          id: 'msg-1',
          content: 'Hello, this is a user message',
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: ChatMessageBubble(message: userMessage),
            ),
          ),
        );

        // Verify message content is displayed
        expect(find.text('Hello, this is a user message'), findsOneWidget);
        
        // Verify user message styling
        final messageBubble = tester.widget<Container>(
          find.descendant(
            of: find.byType(ChatMessageBubble),
            matching: find.byType(Container),
          ).first,
        );
        
        expect(messageBubble.alignment, equals(Alignment.centerRight));
      });

      testWidgets('should display assistant message correctly', (WidgetTester tester) async {
        final assistantMessage = ChatMessage.assistant(
          id: 'msg-2',
          content: 'Hello! How can I help you today?',
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: ChatMessageBubble(message: assistantMessage),
            ),
          ),
        );

        // Verify message content is displayed
        expect(find.text('Hello! How can I help you today?'), findsOneWidget);
        
        // Verify assistant message styling
        final messageBubble = tester.widget<Container>(
          find.descendant(
            of: find.byType(ChatMessageBubble),
            matching: find.byType(Container),
          ).first,
        );
        
        expect(messageBubble.alignment, equals(Alignment.centerLeft));
      });

      testWidgets('should display timestamp', (WidgetTester tester) async {
        final message = ChatMessage.user(
          id: 'msg-1',
          content: 'Test message',
          timestamp: DateTime(2024, 1, 15, 14, 30),
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: ChatMessageBubble(message: message),
            ),
          ),
        );

        // Verify timestamp is displayed
        expect(find.textContaining('14:30'), findsOneWidget);
      });

      testWidgets('should handle long messages with proper wrapping', (WidgetTester tester) async {
        final longMessage = ChatMessage.user(
          id: 'msg-1',
          content: 'This is a very long message that should wrap properly across multiple lines to ensure good user experience and readability on mobile devices with various screen sizes.',
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: SizedBox(
                width: 300,
                child: ChatMessageBubble(message: longMessage),
              ),
            ),
          ),
        );

        // Verify message is displayed
        expect(find.textContaining('This is a very long message'), findsOneWidget);
        
        // Verify text wraps properly
        final textWidget = tester.widget<Text>(
          find.descendant(
            of: find.byType(ChatMessageBubble),
            matching: find.byType(Text),
          ).first,
        );
        
        expect(textWidget.overflow, isNull); // Should not overflow
      });

      testWidgets('should display action metadata when present', (WidgetTester tester) async {
        final messageWithAction = ChatMessage.assistant(
          id: 'msg-1',
          content: 'I created a task for you',
          metadata: {
            'action': {
              'type': 'create_task',
              'data': {'description': 'New task'}
            }
          },
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: ChatMessageBubble(message: messageWithAction),
            ),
          ),
        );

        // Verify message content
        expect(find.text('I created a task for you'), findsOneWidget);
        
        // Verify action indicator is present
        expect(find.byIcon(Icons.check_circle), findsOneWidget);
      });
    });

    group('ChatMessageList Widget', () {
      testWidgets('should display list of messages', (WidgetTester tester) async {
        final messages = [
          ChatMessage.user(id: '1', content: 'Hello'),
          ChatMessage.assistant(id: '2', content: 'Hi there!'),
          ChatMessage.user(id: '3', content: 'How are you?'),
        ];

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: ChatMessageList(messages: messages),
            ),
          ),
        );

        // Verify all messages are displayed
        expect(find.text('Hello'), findsOneWidget);
        expect(find.text('Hi there!'), findsOneWidget);
        expect(find.text('How are you?'), findsOneWidget);
        
        // Verify message bubbles are present
        expect(find.byType(ChatMessageBubble), findsNWidgets(3));
      });

      testWidgets('should handle empty message list', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: ChatMessageList(messages: []),
            ),
          ),
        );

        // Verify empty state
        expect(find.text('Start a conversation'), findsOneWidget);
        expect(find.byType(ChatMessageBubble), findsNothing);
      });

      testWidgets('should support pull-to-refresh', (WidgetTester tester) async {
        final messages = [
          ChatMessage.user(id: '1', content: 'Test message'),
        ];

        bool refreshCalled = false;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: ChatMessageList(
                messages: messages,
                onRefresh: () async {
                  refreshCalled = true;
                },
              ),
            ),
          ),
        );

        // Trigger pull-to-refresh
        await tester.fling(
          find.byType(ListView),
          const Offset(0, 300),
          1000,
        );
        await tester.pumpAndSettle();

        expect(refreshCalled, isTrue);
      });

      testWidgets('should handle scroll to load more messages', (WidgetTester tester) async {
        final messages = List.generate(50, (i) => 
          ChatMessage.user(id: '$i', content: 'Message $i')
        );

        bool loadMoreCalled = false;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: ChatMessageList(
                messages: messages,
                onLoadMore: () async {
                  loadMoreCalled = true;
                },
              ),
            ),
          ),
        );

        // Scroll to bottom to trigger load more
        await tester.fling(
          find.byType(ListView),
          const Offset(0, -1000),
          1000,
        );
        await tester.pumpAndSettle();

        expect(loadMoreCalled, isTrue);
      });
    });

    group('ChatInputField Widget', () {
      testWidgets('should allow text input', (WidgetTester tester) async {
        String? submittedText;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: ChatInputField(
                onSubmit: (text) {
                  submittedText = text;
                },
              ),
            ),
          ),
        );

        // Find the text field
        final textField = find.byType(TextField);
        expect(textField, findsOneWidget);

        // Enter text
        await tester.enterText(textField, 'Hello, AI!');
        expect(find.text('Hello, AI!'), findsOneWidget);

        // Submit by tapping send button
        final sendButton = find.byIcon(Icons.send);
        expect(sendButton, findsOneWidget);
        
        await tester.tap(sendButton);
        await tester.pumpAndSettle();

        expect(submittedText, equals('Hello, AI!'));
      });

      testWidgets('should disable send button when input is empty', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: ChatInputField(
                onSubmit: (text) {},
              ),
            ),
          ),
        );

        // Send button should be disabled initially
        final sendButton = find.byIcon(Icons.send);
        final iconButton = tester.widget<IconButton>(
          find.ancestor(
            of: sendButton,
            matching: find.byType(IconButton),
          ),
        );
        
        expect(iconButton.onPressed, isNull);
      });

      testWidgets('should enable send button when input has text', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: ChatInputField(
                onSubmit: (text) {},
              ),
            ),
          ),
        );

        // Enter text
        await tester.enterText(find.byType(TextField), 'Test message');
        await tester.pump();

        // Send button should be enabled
        final sendButton = find.byIcon(Icons.send);
        final iconButton = tester.widget<IconButton>(
          find.ancestor(
            of: sendButton,
            matching: find.byType(IconButton),
          ),
        );
        
        expect(iconButton.onPressed, isNotNull);
      });

      testWidgets('should clear input after sending', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: ChatInputField(
                onSubmit: (text) {},
              ),
            ),
          ),
        );

        // Enter text and send
        await tester.enterText(find.byType(TextField), 'Test message');
        await tester.tap(find.byIcon(Icons.send));
        await tester.pumpAndSettle();

        // Input should be cleared
        final textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.controller?.text, isEmpty);
      });

      testWidgets('should handle multiline input', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: ChatInputField(
                onSubmit: (text) {},
                maxLines: 4,
              ),
            ),
          ),
        );

        // Enter multiline text
        const multilineText = 'Line 1\nLine 2\nLine 3';
        await tester.enterText(find.byType(TextField), multilineText);
        
        expect(find.text(multilineText), findsOneWidget);
      });
    });

    group('ChatAppBar Widget', () {
      testWidgets('should display app title', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              appBar: ChatAppBar(),
            ),
          ),
        );

        expect(find.text('Reva'), findsOneWidget);
      });

      testWidgets('should show connection status', (WidgetTester tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              connectivityServiceProvider.overrideWithValue(mockConnectivityService),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: Scaffold(
                appBar: ChatAppBar(),
              ),
            ),
          ),
        );

        // Should show online status
        expect(find.byIcon(Icons.cloud_done), findsOneWidget);
      });

      testWidgets('should show offline status when disconnected', (WidgetTester tester) async {
        when(mockConnectivityService.isConnected).thenReturn(false);
        when(mockConnectivityService.connectionStream)
            .thenAnswer((_) => Stream.value(false));

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              connectivityServiceProvider.overrideWithValue(mockConnectivityService),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: Scaffold(
                appBar: ChatAppBar(),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Should show offline status
        expect(find.byIcon(Icons.cloud_off), findsOneWidget);
      });

      testWidgets('should have menu button', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              appBar: ChatAppBar(),
              drawer: const Drawer(),
            ),
          ),
        );

        expect(find.byIcon(Icons.menu), findsOneWidget);
      });
    });

    group('ActionCard Widget', () {
      testWidgets('should display action information', (WidgetTester tester) async {
        final actionData = {
          'type': 'create_task',
          'data': {
            'description': 'New task created',
            'priority': 'high',
          }
        };

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: ActionCard(
                actionType: 'create_task',
                actionData: actionData['data'] as Map<String, dynamic>,
              ),
            ),
          ),
        );

        // Verify action type is displayed
        expect(find.textContaining('Task Created'), findsOneWidget);
        
        // Verify action data is displayed
        expect(find.textContaining('New task created'), findsOneWidget);
        expect(find.textContaining('high'), findsOneWidget);
      });

      testWidgets('should handle different action types', (WidgetTester tester) async {
        final expenseActionData = {
          'item': 'Coffee',
          'amount': 4.50,
          'category': 'Food & Dining',
        };

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: ActionCard(
                actionType: 'log_expense',
                actionData: expenseActionData,
              ),
            ),
          ),
        );

        // Verify expense action is displayed
        expect(find.textContaining('Expense Logged'), findsOneWidget);
        expect(find.textContaining('Coffee'), findsOneWidget);
        expect(find.textContaining('\$4.50'), findsOneWidget);
      });

      testWidgets('should be tappable with callback', (WidgetTester tester) async {
        bool tapped = false;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: ActionCard(
                actionType: 'create_task',
                actionData: {'description': 'Test task'},
                onTap: () {
                  tapped = true;
                },
              ),
            ),
          ),
        );

        await tester.tap(find.byType(ActionCard));
        expect(tapped, isTrue);
      });
    });

    group('ChatLoadingIndicator Widget', () {
      testWidgets('should display loading animation', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: const Scaffold(
              body: ChatLoadingIndicator(),
            ),
          ),
        );

        // Verify loading indicator is present
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        
        // Verify loading text
        expect(find.text('Reva is thinking...'), findsOneWidget);
      });

      testWidgets('should animate dots in loading text', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: const Scaffold(
              body: ChatLoadingIndicator(),
            ),
          ),
        );

        // Initial state
        expect(find.text('Reva is thinking...'), findsOneWidget);

        // Wait for animation
        await tester.pump(const Duration(milliseconds: 500));
        
        // Animation should be running
        expect(find.byType(AnimatedBuilder), findsOneWidget);
      });

      testWidgets('should have proper accessibility labels', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: const Scaffold(
              body: ChatLoadingIndicator(),
            ),
          ),
        );

        // Verify semantic labels
        expect(find.bySemanticsLabel('AI is processing your message'), findsOneWidget);
      });
    });

    group('ConnectivityStatus Widget', () {
      testWidgets('should show online status', (WidgetTester tester) async {
        when(mockConnectivityService.isConnected).thenReturn(true);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              connectivityServiceProvider.overrideWithValue(mockConnectivityService),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const Scaffold(
                body: ConnectivityStatus(),
              ),
            ),
          ),
        );

        expect(find.byIcon(Icons.cloud_done), findsOneWidget);
        expect(find.text('Online'), findsOneWidget);
      });

      testWidgets('should show offline status', (WidgetTester tester) async {
        when(mockConnectivityService.isConnected).thenReturn(false);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              connectivityServiceProvider.overrideWithValue(mockConnectivityService),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const Scaffold(
                body: ConnectivityStatus(),
              ),
            ),
          ),
        );

        expect(find.byIcon(Icons.cloud_off), findsOneWidget);
        expect(find.text('Offline'), findsOneWidget);
      });

      testWidgets('should update when connectivity changes', (WidgetTester tester) async {
        final connectivityController = StreamController<bool>();
        
        when(mockConnectivityService.connectionStream)
            .thenAnswer((_) => connectivityController.stream);
        when(mockConnectivityService.isConnected).thenReturn(true);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              connectivityServiceProvider.overrideWithValue(mockConnectivityService),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const Scaffold(
                body: ConnectivityStatus(),
              ),
            ),
          ),
        );

        // Initially online
        expect(find.text('Online'), findsOneWidget);

        // Change to offline
        when(mockConnectivityService.isConnected).thenReturn(false);
        connectivityController.add(false);
        await tester.pumpAndSettle();

        expect(find.text('Offline'), findsOneWidget);

        connectivityController.close();
      });
    });

    group('Chat Widget Integration', () {
      testWidgets('should integrate all chat components properly', (WidgetTester tester) async {
        final messages = [
          ChatMessage.user(id: '1', content: 'Hello'),
          ChatMessage.assistant(id: '2', content: 'Hi! How can I help?'),
        ];

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              connectivityServiceProvider.overrideWithValue(mockConnectivityService),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: Scaffold(
                appBar: ChatAppBar(),
                body: Column(
                  children: [
                    const ConnectivityStatus(),
                    Expanded(
                      child: ChatMessageList(messages: messages),
                    ),
                    ChatInputField(onSubmit: (text) {}),
                  ],
                ),
              ),
            ),
          ),
        );

        // Verify all components are present
        expect(find.text('Reva'), findsOneWidget); // App bar
        expect(find.text('Online'), findsOneWidget); // Connectivity status
        expect(find.text('Hello'), findsOneWidget); // User message
        expect(find.text('Hi! How can I help?'), findsOneWidget); // Assistant message
        expect(find.byType(TextField), findsOneWidget); // Input field
        expect(find.byIcon(Icons.send), findsOneWidget); // Send button
      });

      testWidgets('should handle message sending flow', (WidgetTester tester) async {
        final messages = <ChatMessage>[];
        
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: Column(
                children: [
                  Expanded(
                    child: ChatMessageList(messages: messages),
                  ),
                  ChatInputField(
                    onSubmit: (text) {
                      messages.add(ChatMessage.user(
                        id: 'new-msg',
                        content: text,
                      ));
                    },
                  ),
                ],
              ),
            ),
          ),
        );

        // Initially no messages
        expect(find.text('Start a conversation'), findsOneWidget);

        // Send a message
        await tester.enterText(find.byType(TextField), 'Test message');
        await tester.tap(find.byIcon(Icons.send));
        await tester.pumpAndSettle();

        // Verify message was added
        expect(messages, hasLength(1));
        expect(messages.first.content, equals('Test message'));
      });
    });
  });
}
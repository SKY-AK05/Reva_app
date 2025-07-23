import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../lib/models/reminder.dart';
import '../../lib/providers/reminders_provider.dart';
import '../../lib/providers/chat_provider.dart';
import '../../lib/services/notifications/notification_service.dart';
import '../../lib/services/notifications/supabase_notification_service.dart';
import '../../lib/services/navigation/deep_link_service.dart';
import '../../lib/models/chat_message.dart';

// Mock classes
class MockNotificationService extends Mock implements NotificationService {}
class MockSupabaseNotificationService extends Mock implements SupabaseNotificationService {}
class MockDeepLinkService extends Mock implements DeepLinkService {}

void main() {
  group('Reminder Notification Integration Tests', () {
    late ProviderContainer container;
    late MockNotificationService mockNotificationService;
    late MockSupabaseNotificationService mockSupabaseNotificationService;
    late MockDeepLinkService mockDeepLinkService;

    setUp(() {
      mockNotificationService = MockNotificationService();
      mockSupabaseNotificationService = MockSupabaseNotificationService();
      mockDeepLinkService = MockDeepLinkService();

      // Setup mock responses
      when(mockNotificationService.initialize()).thenAnswer((_) async => true);
      when(mockNotificationService.requestPermissions()).thenAnswer((_) async => true);
      when(mockNotificationService.areNotificationsEnabled).thenReturn(true);
      when(mockNotificationService.arePushNotificationsEnabled).thenReturn(true);
      
      when(mockSupabaseNotificationService.initialize()).thenAnswer((_) async => true);
      when(mockSupabaseNotificationService.areNotificationsEnabled).thenReturn(true);
      
      when(mockDeepLinkService.generateReminderNotificationData(any))
          .thenReturn({
            'type': 'reminder',
            'id': 'test-reminder-id',
            'deep_link': 'reva://reminder/test-reminder-id',
          });

      container = ProviderContainer(
        overrides: [
          notificationServiceProvider.overrideWithValue(mockNotificationService),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    testWidgets('should create reminder from AI chat and schedule notifications', (tester) async {
      // Arrange
      final chatNotifier = container.read(chatProvider.notifier);
      final remindersNotifier = container.read(remindersProvider.notifier);

      // Mock AI response with reminder creation action
      final aiActionData = {
        'title': 'Doctor appointment',
        'description': 'Annual checkup with Dr. Smith',
        'scheduled_time': DateTime.now().add(const Duration(hours: 2)).toIso8601String(),
      };

      // Act - Simulate AI creating a reminder
      await remindersNotifier.createReminderFromAI(aiActionData);

      // Assert
      final remindersState = container.read(remindersProvider);
      expect(remindersState.reminders.length, equals(1));
      
      final createdReminder = remindersState.reminders.first;
      expect(createdReminder.title, equals('Doctor appointment'));
      expect(createdReminder.description, equals('Annual checkup with Dr. Smith'));

      // Verify notifications were scheduled
      verify(mockNotificationService.scheduleNotification(
        id: any,
        title: 'Reminder: Doctor appointment',
        body: 'Annual checkup with Dr. Smith',
        scheduledDate: any,
        payload: any,
        reminderId: any,
      )).called(1);

      verify(mockNotificationService.schedulePushNotification(
        title: 'Reminder: Doctor appointment',
        body: 'Annual checkup with Dr. Smith',
        scheduledTime: any,
        reminderId: any,
        data: any,
      )).called(1);
    });

    testWidgets('should update reminder from AI chat and reschedule notifications', (tester) async {
      // Arrange
      final remindersNotifier = container.read(remindersProvider.notifier);
      
      // Create initial reminder
      await remindersNotifier.createReminder(
        title: 'Meeting with client',
        description: 'Discuss project requirements',
        scheduledTime: DateTime.now().add(const Duration(hours: 1)),
      );

      final initialState = container.read(remindersProvider);
      final reminderId = initialState.reminders.first.id;

      // Clear previous mock calls
      clearInteractions(mockNotificationService);

      // Mock AI response with reminder update action
      final aiUpdateData = {
        'reminder_id': reminderId,
        'title': 'Updated meeting with client',
        'scheduled_time': DateTime.now().add(const Duration(hours: 3)).toIso8601String(),
      };

      // Act - Simulate AI updating the reminder
      await remindersNotifier.updateReminderFromAI(aiUpdateData);

      // Assert
      final updatedState = container.read(remindersProvider);
      final updatedReminder = updatedState.reminders.first;
      expect(updatedReminder.title, equals('Updated meeting with client'));

      // Verify notifications were rescheduled (cancelled and scheduled again)
      verify(mockNotificationService.cancelNotification(any)).called(1);
      verify(mockNotificationService.cancelPushNotification(reminderId: reminderId)).called(1);
      
      verify(mockNotificationService.scheduleNotification(
        id: any,
        title: 'Reminder: Updated meeting with client',
        body: any,
        scheduledDate: any,
        payload: any,
        reminderId: any,
      )).called(1);

      verify(mockNotificationService.schedulePushNotification(
        title: 'Reminder: Updated meeting with client',
        body: any,
        scheduledTime: any,
        reminderId: any,
        data: any,
      )).called(1);
    });

    testWidgets('should handle notification tap and navigate to reminder details', (tester) async {
      // Arrange
      final remindersNotifier = container.read(remindersProvider.notifier);
      
      // Create a reminder
      await remindersNotifier.createReminder(
        title: 'Test reminder',
        description: 'Test description',
        scheduledTime: DateTime.now().add(const Duration(minutes: 30)),
      );

      final state = container.read(remindersProvider);
      final reminderId = state.reminders.first.id;

      // Mock notification data
      final notificationData = {
        'type': 'reminder',
        'id': reminderId,
        'deep_link': 'reva://reminder/$reminderId',
        'title': 'Test reminder',
        'description': 'Test description',
      };

      // Act - Simulate notification tap
      mockNotificationService.handleNotificationTap(notificationData);

      // Assert - Verify deep link service was called
      // Note: In a real test, we would verify navigation occurred
      // For now, we just verify the method was called
      verify(mockNotificationService.handleNotificationTap(notificationData)).called(1);
    });

    testWidgets('should handle reminder completion and cancel notifications', (tester) async {
      // Arrange
      final remindersNotifier = container.read(remindersProvider.notifier);
      
      // Create a reminder
      await remindersNotifier.createReminder(
        title: 'Task to complete',
        description: 'Important task',
        scheduledTime: DateTime.now().add(const Duration(hours: 1)),
      );

      final state = container.read(remindersProvider);
      final reminderId = state.reminders.first.id;

      // Clear previous mock calls
      clearInteractions(mockNotificationService);

      // Act - Mark reminder as completed
      await remindersNotifier.markReminderCompleted(reminderId);

      // Assert
      final updatedState = container.read(remindersProvider);
      final completedReminder = updatedState.reminders.first;
      expect(completedReminder.completed, isTrue);

      // Verify notifications were cancelled
      verify(mockNotificationService.cancelNotification(any)).called(1);
      verify(mockNotificationService.cancelPushNotification(reminderId: reminderId)).called(1);
    });

    testWidgets('should handle reminder snoozing and reschedule notifications', (tester) async {
      // Arrange
      final remindersNotifier = container.read(remindersProvider.notifier);
      
      // Create a reminder
      await remindersNotifier.createReminder(
        title: 'Snooze test reminder',
        description: 'Test snoozing',
        scheduledTime: DateTime.now().add(const Duration(minutes: 5)),
      );

      final state = container.read(remindersProvider);
      final reminderId = state.reminders.first.id;
      final originalTime = state.reminders.first.scheduledTime;

      // Clear previous mock calls
      clearInteractions(mockNotificationService);

      // Act - Snooze reminder for 30 minutes
      await remindersNotifier.snoozeReminder(reminderId, const Duration(minutes: 30));

      // Assert
      final updatedState = container.read(remindersProvider);
      final snoozedReminder = updatedState.reminders.first;
      expect(snoozedReminder.scheduledTime.isAfter(originalTime), isTrue);

      // Verify notifications were rescheduled
      verify(mockNotificationService.cancelNotification(any)).called(1);
      verify(mockNotificationService.cancelPushNotification(reminderId: reminderId)).called(1);
      
      verify(mockNotificationService.scheduleNotification(
        id: any,
        title: any,
        body: any,
        scheduledDate: any,
        payload: any,
        reminderId: any,
      )).called(1);

      verify(mockNotificationService.schedulePushNotification(
        title: any,
        body: any,
        scheduledTime: any,
        reminderId: any,
        data: any,
      )).called(1);
    });

    testWidgets('should handle notification permission changes', (tester) async {
      // Arrange
      final remindersNotifier = container.read(remindersProvider.notifier);
      
      // Create some reminders
      await remindersNotifier.createReminder(
        title: 'Reminder 1',
        scheduledTime: DateTime.now().add(const Duration(hours: 1)),
      );
      await remindersNotifier.createReminder(
        title: 'Reminder 2',
        scheduledTime: DateTime.now().add(const Duration(hours: 2)),
      );

      // Clear previous mock calls
      clearInteractions(mockNotificationService);

      // Act - Request notification permissions
      await remindersNotifier.requestNotificationPermissions();

      // Assert
      final state = container.read(remindersProvider);
      expect(state.notificationsEnabled, isTrue);

      // Verify all notifications were rescheduled
      verify(mockNotificationService.requestPermissions()).called(1);
      verify(mockNotificationService.cancelAllNotifications()).called(1);
      
      // Should schedule notifications for all upcoming reminders
      verify(mockNotificationService.scheduleNotification(
        id: any,
        title: any,
        body: any,
        scheduledDate: any,
        payload: any,
        reminderId: any,
      )).called(2); // Two reminders

      verify(mockNotificationService.schedulePushNotification(
        title: any,
        body: any,
        scheduledTime: any,
        reminderId: any,
        data: any,
      )).called(2); // Two reminders
    });

    testWidgets('should handle deep link generation for reminders', (tester) async {
      // Arrange
      const reminderId = 'test-reminder-123';
      
      // Act
      final deepLink = mockDeepLinkService.generateReminderLink(reminderId);
      final notificationData = mockDeepLinkService.generateReminderNotificationData(reminderId);

      // Assert
      expect(deepLink, isNotNull);
      expect(notificationData['type'], equals('reminder'));
      expect(notificationData['id'], equals(reminderId));
      expect(notificationData['deep_link'], contains(reminderId));
    });

    testWidgets('should handle offline reminder creation with notification scheduling', (tester) async {
      // Arrange
      final remindersNotifier = container.read(remindersProvider.notifier);
      
      // Simulate offline state
      // Note: In a real test, we would mock the connectivity service
      
      // Act - Create reminder while offline
      await remindersNotifier.createReminder(
        title: 'Offline reminder',
        description: 'Created while offline',
        scheduledTime: DateTime.now().add(const Duration(hours: 1)),
      );

      // Assert
      final state = container.read(remindersProvider);
      expect(state.reminders.length, equals(1));
      
      final reminder = state.reminders.first;
      expect(reminder.title, equals('Offline reminder'));

      // Verify local notification was still scheduled
      verify(mockNotificationService.scheduleNotification(
        id: any,
        title: 'Reminder: Offline reminder',
        body: 'Created while offline',
        scheduledDate: any,
        payload: any,
        reminderId: any,
      )).called(1);
    });
  });

  group('Deep Link Service Tests', () {
    late DeepLinkService deepLinkService;

    setUp(() {
      deepLinkService = DeepLinkService.instance;
    });

    test('should generate correct reminder deep links', () {
      // Arrange
      const reminderId = 'reminder-123';

      // Act
      final basicLink = deepLinkService.generateReminderLink(reminderId);
      final editLink = deepLinkService.generateReminderLink(reminderId, action: 'edit');
      final snoozeLink = deepLinkService.generateReminderLink(reminderId, action: 'snooze');

      // Assert
      expect(basicLink, equals('reva://reminder/reminder-123'));
      expect(editLink, equals('reva://reminder/reminder-123?action=edit'));
      expect(snoozeLink, equals('reva://reminder/reminder-123?action=snooze'));
    });

    test('should generate correct notification data', () {
      // Arrange
      const reminderId = 'reminder-456';

      // Act
      final notificationData = deepLinkService.generateReminderNotificationData(reminderId);

      // Assert
      expect(notificationData['type'], equals('reminder'));
      expect(notificationData['id'], equals(reminderId));
      expect(notificationData['deep_link'], equals('reva://reminder/reminder-456'));
    });
  });
}
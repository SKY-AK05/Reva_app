import 'package:flutter_test/flutter_test.dart';
import 'package:reva_mobile_app/models/reminder.dart';

void main() {
  group('Reminder Model Tests', () {
    late Reminder testReminder;
    late DateTime testScheduledTime;

    setUp(() {
      testScheduledTime = DateTime.now().add(const Duration(days: 7)); // Future date
      testReminder = Reminder(
        id: 'reminder-1',
        userId: 'user-123',
        title: 'Doctor Appointment',
        description: 'Annual checkup with Dr. Smith',
        scheduledTime: testScheduledTime,
        completed: false,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      );
    });

    group('Reminder Creation', () {
      test('should create reminder with all properties', () {
        expect(testReminder.id, equals('reminder-1'));
        expect(testReminder.userId, equals('user-123'));
        expect(testReminder.title, equals('Doctor Appointment'));
        expect(testReminder.description, equals('Annual checkup with Dr. Smith'));
        expect(testReminder.scheduledTime, equals(testScheduledTime));
        expect(testReminder.completed, isFalse);
        expect(testReminder.createdAt, isA<DateTime>());
      });

      test('should create reminder without description', () {
        final reminderWithoutDescription = Reminder(
          id: 'reminder-2',
          userId: 'user-123',
          title: 'Simple Reminder',
          scheduledTime: DateTime.now().add(const Duration(hours: 1)),
          completed: false,
          createdAt: DateTime.now(),
        );

        expect(reminderWithoutDescription.description, isNull);
      });
    });

    group('JSON Serialization', () {
      test('should serialize to JSON correctly', () {
        final json = testReminder.toJson();

        expect(json['id'], equals('reminder-1'));
        expect(json['user_id'], equals('user-123'));
        expect(json['title'], equals('Doctor Appointment'));
        expect(json['description'], equals('Annual checkup with Dr. Smith'));
        expect(json['scheduled_time'], equals(testScheduledTime.toIso8601String()));
        expect(json['completed'], isFalse);
        expect(json['created_at'], equals(DateTime(2024, 1, 15, 10, 0).toIso8601String()));
      });

      test('should deserialize from JSON correctly', () {
        final json = {
          'id': 'reminder-1',
          'user_id': 'user-123',
          'title': 'Doctor Appointment',
          'description': 'Annual checkup with Dr. Smith',
          'scheduled_time': testScheduledTime.toIso8601String(),
          'completed': false,
          'created_at': DateTime(2024, 1, 15, 10, 0).toIso8601String(),
        };

        final reminder = Reminder.fromJson(json);

        expect(reminder.id, equals('reminder-1'));
        expect(reminder.userId, equals('user-123'));
        expect(reminder.title, equals('Doctor Appointment'));
        expect(reminder.description, equals('Annual checkup with Dr. Smith'));
        expect(reminder.scheduledTime, equals(testScheduledTime));
        expect(reminder.completed, isFalse);
        expect(reminder.createdAt, equals(DateTime(2024, 1, 15, 10, 0)));
      });

      test('should handle null description in JSON', () {
        final json = {
          'id': 'reminder-2',
          'user_id': 'user-123',
          'title': 'Simple Reminder',
          'description': null,
          'scheduled_time': DateTime.now().toIso8601String(),
          'completed': false,
          'created_at': DateTime.now().toIso8601String(),
        };

        final reminder = Reminder.fromJson(json);
        expect(reminder.description, isNull);
      });
    });

    group('Business Logic', () {
      test('isOverdue should return true for overdue incomplete reminders', () {
        final overdueReminder = testReminder.copyWith(
          scheduledTime: DateTime.now().subtract(const Duration(hours: 1)),
          completed: false,
        );

        expect(overdueReminder.isOverdue, isTrue);
      });

      test('isOverdue should return false for completed reminders', () {
        final completedOverdueReminder = testReminder.copyWith(
          scheduledTime: DateTime.now().subtract(const Duration(hours: 1)),
          completed: true,
        );

        expect(completedOverdueReminder.isOverdue, isFalse);
      });

      test('isDueToday should return true for reminders scheduled today', () {
        final todayReminder = testReminder.copyWith(scheduledTime: DateTime.now());
        expect(todayReminder.isDueToday, isTrue);
      });

      test('isDueToday should return false for reminders scheduled tomorrow', () {
        final tomorrowReminder = testReminder.copyWith(
          scheduledTime: DateTime.now().add(const Duration(days: 1)),
        );
        expect(tomorrowReminder.isDueToday, isFalse);
      });

      test('isDueSoon should return true for reminders due within 24 hours', () {
        final soonReminder = testReminder.copyWith(
          scheduledTime: DateTime.now().add(const Duration(hours: 12)),
          completed: false,
        );
        expect(soonReminder.isDueSoon, isTrue);
      });

      test('isDueSoon should return false for completed reminders', () {
        final completedSoonReminder = testReminder.copyWith(
          scheduledTime: DateTime.now().add(const Duration(hours: 12)),
          completed: true,
        );
        expect(completedSoonReminder.isDueSoon, isFalse);
      });

      test('isUpcoming should return true for future incomplete reminders', () {
        final upcomingReminder = testReminder.copyWith(
          scheduledTime: DateTime.now().add(const Duration(days: 1)),
          completed: false,
        );
        expect(upcomingReminder.isUpcoming, isTrue);
      });

      test('isUpcoming should return false for completed reminders', () {
        final completedUpcomingReminder = testReminder.copyWith(
          scheduledTime: DateTime.now().add(const Duration(days: 1)),
          completed: true,
        );
        expect(completedUpcomingReminder.isUpcoming, isFalse);
      });

      test('isPast should return true for past reminders', () {
        final pastReminder = testReminder.copyWith(
          scheduledTime: DateTime.now().subtract(const Duration(hours: 1)),
        );
        expect(pastReminder.isPast, isTrue);
      });

      test('isPast should return false for future reminders', () {
        final futureReminder = testReminder.copyWith(
          scheduledTime: DateTime.now().add(const Duration(hours: 1)),
        );
        expect(futureReminder.isPast, isFalse);
      });
    });

    group('Formatted Display', () {
      test('formattedScheduledTime should show time only for today', () {
        final todayReminder = testReminder.copyWith(
          scheduledTime: DateTime(
            DateTime.now().year,
            DateTime.now().month,
            DateTime.now().day,
            14,
            30,
          ),
        );
        expect(todayReminder.formattedScheduledTime, equals('14:30'));
      });

      test('formattedScheduledTime should show month/day and time for this year', () {
        final thisYearReminder = testReminder.copyWith(
          scheduledTime: DateTime(DateTime.now().year, 3, 15, 14, 30),
        );
        expect(thisYearReminder.formattedScheduledTime, equals('3/15 14:30'));
      });

      test('formattedScheduledTime should show full date for other years', () {
        final otherYearReminder = testReminder.copyWith(
          scheduledTime: DateTime(2025, 3, 15, 14, 30),
        );
        expect(otherYearReminder.formattedScheduledTime, equals('15/3/2025 14:30'));
      });

      test('timeUntilDue should return "Completed" for completed reminders', () {
        final completedReminder = testReminder.copyWith(completed: true);
        expect(completedReminder.timeUntilDue, equals('Completed'));
      });

      test('timeUntilDue should return overdue message for past reminders', () {
        final overdueReminder = testReminder.copyWith(
          scheduledTime: DateTime.now().subtract(const Duration(days: 2)),
          completed: false,
        );
        expect(overdueReminder.timeUntilDue, contains('Overdue by 2 days'));
      });

      test('timeUntilDue should return future time for upcoming reminders', () {
        final futureReminder = testReminder.copyWith(
          scheduledTime: DateTime.now().add(const Duration(days: 3)),
          completed: false,
        );
        expect(futureReminder.timeUntilDue, contains('In 3 days'));
      });

      test('timeUntilDue should handle hours and minutes', () {
        final hourReminder = testReminder.copyWith(
          scheduledTime: DateTime.now().add(const Duration(hours: 2)),
          completed: false,
        );
        expect(hourReminder.timeUntilDue, contains('In 2 hours'));

        final minuteReminder = testReminder.copyWith(
          scheduledTime: DateTime.now().add(const Duration(minutes: 30)),
          completed: false,
        );
        expect(minuteReminder.timeUntilDue, contains('In 30 minutes'));
      });

      test('timeUntilDue should return "Due now" for current time', () {
        final nowReminder = testReminder.copyWith(
          scheduledTime: DateTime.now(),
          completed: false,
        );
        expect(nowReminder.timeUntilDue, equals('Due now'));
      });
    });

    group('Validation', () {
      test('isValid should return true for valid reminder', () {
        expect(testReminder.isValid(), isTrue);
      });

      test('isValid should return false for empty title', () {
        final invalidReminder = testReminder.copyWith(title: '');
        expect(invalidReminder.isValid(), isFalse);
      });

      test('isValid should return false for empty user ID', () {
        final invalidReminder = testReminder.copyWith(userId: '');
        expect(invalidReminder.isValid(), isFalse);
      });

      test('isValid should return false for empty reminder ID', () {
        final invalidReminder = testReminder.copyWith(id: '');
        expect(invalidReminder.isValid(), isFalse);
      });

      test('getValidationErrors should return empty list for valid reminder', () {
        final errors = testReminder.getValidationErrors();
        expect(errors, isEmpty);
      });

      test('getValidationErrors should return appropriate errors', () {
        final invalidReminder = Reminder(
          id: '',
          userId: '',
          title: '',
          scheduledTime: DateTime.now(),
          completed: false,
          createdAt: DateTime.now(),
        );

        final errors = invalidReminder.getValidationErrors();
        expect(errors, contains('Reminder ID cannot be empty'));
        expect(errors, contains('User ID cannot be empty'));
        expect(errors, contains('Reminder title cannot be empty'));
      });

      test('getValidationErrors should check title length', () {
        final longTitleReminder = testReminder.copyWith(
          title: 'a' * 201, // 201 characters
        );

        final errors = longTitleReminder.getValidationErrors();
        expect(errors, contains('Reminder title cannot exceed 200 characters'));
      });

      test('getValidationErrors should check description length', () {
        final longDescriptionReminder = testReminder.copyWith(
          description: 'a' * 1001, // 1001 characters
        );

        final errors = longDescriptionReminder.getValidationErrors();
        expect(errors, contains('Reminder description cannot exceed 1000 characters'));
      });

      test('getValidationErrors should check scheduled time bounds', () {
        final veryOldReminder = testReminder.copyWith(
          scheduledTime: DateTime.now().subtract(const Duration(days: 400)),
        );

        final errors = veryOldReminder.getValidationErrors();
        expect(errors, contains('Scheduled time cannot be more than a year in the past'));

        final veryFutureReminder = testReminder.copyWith(
          scheduledTime: DateTime.now().add(const Duration(days: 365 * 11)),
        );

        final futureErrors = veryFutureReminder.getValidationErrors();
        expect(futureErrors, contains('Scheduled time cannot be more than 10 years in the future'));
      });
    });

    group('Equality and CopyWith', () {
      test('should support equality comparison', () {
        final reminder1 = testReminder;
        final reminder2 = Reminder(
          id: 'reminder-1',
          userId: 'user-123',
          title: 'Doctor Appointment',
          description: 'Annual checkup with Dr. Smith',
          scheduledTime: testScheduledTime,
          completed: false,
          createdAt: DateTime(2024, 1, 15, 10, 0),
        );

        expect(reminder1, equals(reminder2));
      });

      test('should support copyWith method', () {
        final updatedReminder = testReminder.copyWith(
          title: 'Updated Appointment',
          completed: true,
          description: 'Updated description',
        );

        expect(updatedReminder.id, equals(testReminder.id));
        expect(updatedReminder.title, equals('Updated Appointment'));
        expect(updatedReminder.completed, isTrue);
        expect(updatedReminder.description, equals('Updated description'));
        expect(updatedReminder.userId, equals(testReminder.userId));
      });

      test('should have proper toString implementation', () {
        final reminderString = testReminder.toString();
        expect(reminderString, contains('Reminder('));
        expect(reminderString, contains('reminder-1'));
        expect(reminderString, contains('Doctor Appointment'));
        expect(reminderString, contains('false'));
      });
    });

    group('Edge Cases', () {
      test('should handle whitespace in title and description', () {
        final whitespaceReminder = testReminder.copyWith(
          title: '  Doctor Appointment  ',
          description: '  Annual checkup  ',
        );
        
        // Validation should still pass as we check trim()
        expect(whitespaceReminder.isValid(), isTrue);
      });

      test('should handle very precise scheduled times', () {
        final preciseReminder = testReminder.copyWith(
          scheduledTime: DateTime(2024, 1, 20, 14, 30, 45, 123),
        );
        
        expect(preciseReminder.scheduledTime.second, equals(45));
        expect(preciseReminder.scheduledTime.millisecond, equals(123));
      });

      test('should handle leap year dates', () {
        final leapYearReminder = testReminder.copyWith(
          scheduledTime: DateTime(2024, 2, 29, 12, 0), // 2024 is a leap year
        );
        
        expect(leapYearReminder.scheduledTime.month, equals(2));
        expect(leapYearReminder.scheduledTime.day, equals(29));
      });
    });
  });
}
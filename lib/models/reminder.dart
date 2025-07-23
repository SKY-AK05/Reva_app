import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

part 'reminder.g.dart';

@JsonSerializable()
class Reminder extends Equatable {
  final String id;
  @JsonKey(name: 'user_id')
  final String userId;
  final String title;
  final String? description;
  @JsonKey(name: 'scheduled_time')
  final DateTime scheduledTime;
  final bool completed;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  const Reminder({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
    required this.scheduledTime,
    required this.completed,
    required this.createdAt,
  });

  factory Reminder.fromJson(Map<String, dynamic> json) => _$ReminderFromJson(json);
  Map<String, dynamic> toJson() => _$ReminderToJson(this);

  Reminder copyWith({
    String? id,
    String? userId,
    String? title,
    String? description,
    DateTime? scheduledTime,
    bool? completed,
    DateTime? createdAt,
  }) {
    return Reminder(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      completed: completed ?? this.completed,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // Business logic methods
  bool get isOverdue {
    if (completed) return false;
    return DateTime.now().isAfter(scheduledTime);
  }

  bool get isDueToday {
    final now = DateTime.now();
    final scheduled = scheduledTime;
    return now.year == scheduled.year && 
           now.month == scheduled.month && 
           now.day == scheduled.day;
  }

  bool get isDueSoon {
    if (completed) return false;
    final now = DateTime.now();
    final difference = scheduledTime.difference(now);
    return difference.inHours <= 24 && difference.inHours >= 0;
  }

  bool get isUpcoming {
    if (completed) return false;
    return scheduledTime.isAfter(DateTime.now());
  }

  bool get isPast {
    return scheduledTime.isBefore(DateTime.now());
  }

  String get formattedScheduledTime {
    final now = DateTime.now();
    final scheduled = scheduledTime;
    
    // If it's today, show time only
    if (now.year == scheduled.year && 
        now.month == scheduled.month && 
        now.day == scheduled.day) {
      return '${scheduled.hour.toString().padLeft(2, '0')}:${scheduled.minute.toString().padLeft(2, '0')}';
    }
    
    // If it's this year, show month/day and time
    if (now.year == scheduled.year) {
      return '${scheduled.month}/${scheduled.day} ${scheduled.hour.toString().padLeft(2, '0')}:${scheduled.minute.toString().padLeft(2, '0')}';
    }
    
    // Otherwise show full date and time
    return '${scheduled.day}/${scheduled.month}/${scheduled.year} ${scheduled.hour.toString().padLeft(2, '0')}:${scheduled.minute.toString().padLeft(2, '0')}';
  }

  String get timeUntilDue {
    if (completed) return 'Completed';
    
    final now = DateTime.now();
    final difference = scheduledTime.difference(now);
    
    if (difference.isNegative) {
      final overdue = now.difference(scheduledTime);
      if (overdue.inDays > 0) {
        return 'Overdue by ${overdue.inDays} day${overdue.inDays == 1 ? '' : 's'}';
      } else if (overdue.inHours > 0) {
        return 'Overdue by ${overdue.inHours} hour${overdue.inHours == 1 ? '' : 's'}';
      } else {
        return 'Overdue by ${overdue.inMinutes} minute${overdue.inMinutes == 1 ? '' : 's'}';
      }
    }
    
    if (difference.inDays > 0) {
      return 'In ${difference.inDays} day${difference.inDays == 1 ? '' : 's'}';
    } else if (difference.inHours > 0) {
      return 'In ${difference.inHours} hour${difference.inHours == 1 ? '' : 's'}';
    } else if (difference.inMinutes > 0) {
      return 'In ${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'}';
    } else {
      return 'Due now';
    }
  }

  // Validation methods
  bool isValid() {
    return title.trim().isNotEmpty && 
           userId.trim().isNotEmpty &&
           id.trim().isNotEmpty;
  }

  List<String> getValidationErrors() {
    final errors = <String>[];
    
    if (id.trim().isEmpty) {
      errors.add('Reminder ID cannot be empty');
    }
    
    if (userId.trim().isEmpty) {
      errors.add('User ID cannot be empty');
    }
    
    if (title.trim().isEmpty) {
      errors.add('Reminder title cannot be empty');
    }
    
    if (title.length > 200) {
      errors.add('Reminder title cannot exceed 200 characters');
    }
    
    if (description != null && description!.length > 1000) {
      errors.add('Reminder description cannot exceed 1000 characters');
    }
    
    if (scheduledTime.isBefore(DateTime.now().subtract(const Duration(days: 365)))) {
      errors.add('Scheduled time cannot be more than a year in the past');
    }
    
    if (scheduledTime.isAfter(DateTime.now().add(const Duration(days: 365 * 10)))) {
      errors.add('Scheduled time cannot be more than 10 years in the future');
    }
    
    return errors;
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        title,
        description,
        scheduledTime,
        completed,
        createdAt,
      ];

  @override
  String toString() {
    return 'Reminder(id: $id, title: $title, scheduledTime: $scheduledTime, completed: $completed)';
  }
}
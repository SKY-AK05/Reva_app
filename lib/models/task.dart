import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';
import '../utils/encryption_utils.dart';

part 'task.g.dart';

enum TaskPriority {
  @JsonValue('high')
  high,
  @JsonValue('medium')
  medium,
  @JsonValue('low')
  low,
}

@JsonSerializable()
class Task extends Equatable {
  final String id;
  @JsonKey(name: 'user_id')
  final String userId;
  final String description;
  @JsonKey(name: 'due_date')
  final DateTime? dueDate;
  final TaskPriority priority;
  final bool completed;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;

  const Task({
    required this.id,
    required this.userId,
    required this.description,
    this.dueDate,
    required this.priority,
    required this.completed,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Task.fromJson(Map<String, dynamic> json) => _$TaskFromJson(json);
  Map<String, dynamic> toJson() => _$TaskToJson(this);

  // Async encryption-aware serialization
  static Future<Task> fromEncryptedJson(Map<String, dynamic> json) async {
    final decryptedPriority = await EncryptionUtils.decryptField(json['priority'] as String);
    return Task(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      description: await EncryptionUtils.decryptField(json['description'] as String),
      dueDate: json['due_date'] != null && (json['due_date'] as String).isNotEmpty
          ? DateTime.parse(await EncryptionUtils.decryptField(json['due_date'] as String))
          : null,
      priority: TaskPriority.values.firstWhere(
        (e) => e.toString().split('.').last == decryptedPriority,
        orElse: () => TaskPriority.medium,
      ),
      completed: json['completed'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Future<Map<String, dynamic>> toEncryptedJson() async {
    return {
      'id': id,
      'user_id': userId,
      'description': await EncryptionUtils.encryptField(description),
      'due_date': dueDate != null ? await EncryptionUtils.encryptField(dueDate!.toIso8601String()) : '',
      'priority': await EncryptionUtils.encryptField(priority.toString().split('.').last),
      'completed': completed,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Task copyWith({
    String? id,
    String? userId,
    String? description,
    DateTime? dueDate,
    TaskPriority? priority,
    bool? completed,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Task(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      description: description ?? this.description,
      dueDate: dueDate ?? this.dueDate,
      priority: priority ?? this.priority,
      completed: completed ?? this.completed,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Business logic methods
  bool get isOverdue {
    if (dueDate == null || completed) return false;
    return DateTime.now().isAfter(dueDate!);
  }

  bool get isDueToday {
    if (dueDate == null) return false;
    final now = DateTime.now();
    final due = dueDate!;
    return now.year == due.year && 
           now.month == due.month && 
           now.day == due.day;
  }

  bool get isDueSoon {
    if (dueDate == null || completed) return false;
    final now = DateTime.now();
    final difference = dueDate!.difference(now);
    return difference.inDays <= 3 && difference.inDays >= 0;
  }

  String get priorityDisplayName {
    switch (priority) {
      case TaskPriority.high:
        return 'High';
      case TaskPriority.medium:
        return 'Medium';
      case TaskPriority.low:
        return 'Low';
    }
  }

  // Validation methods
  bool isValid() {
    return description.trim().isNotEmpty && 
           userId.trim().isNotEmpty &&
           id.trim().isNotEmpty;
  }

  List<String> getValidationErrors() {
    final errors = <String>[];
    
    if (id.trim().isEmpty) {
      errors.add('Task ID cannot be empty');
    }
    
    if (userId.trim().isEmpty) {
      errors.add('User ID cannot be empty');
    }
    
    if (description.trim().isEmpty) {
      errors.add('Task description cannot be empty');
    }
    
    if (description.length > 500) {
      errors.add('Task description cannot exceed 500 characters');
    }
    
    return errors;
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        description,
        dueDate,
        priority,
        completed,
        createdAt,
        updatedAt,
      ];

  @override
  String toString() {
    return 'Task(id: $id, description: $description, priority: $priority, completed: $completed)';
  }
}
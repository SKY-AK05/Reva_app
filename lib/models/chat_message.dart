import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

part 'chat_message.g.dart';

enum MessageType {
  @JsonValue('user')
  user,
  @JsonValue('assistant')
  assistant,
  @JsonValue('system')
  system,
}

@JsonSerializable()
class ChatMessage extends Equatable {
  final String id;
  final String content;
  final MessageType type;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  const ChatMessage({
    required this.id,
    required this.content,
    required this.type,
    required this.timestamp,
    this.metadata,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) => _$ChatMessageFromJson(json);
  Map<String, dynamic> toJson() => _$ChatMessageToJson(this);

  ChatMessage copyWith({
    String? id,
    String? content,
    MessageType? type,
    DateTime? timestamp,
    Map<String, dynamic>? metadata,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      content: content ?? this.content,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      metadata: metadata ?? this.metadata,
    );
  }

  // Business logic methods
  bool get isFromUser => type == MessageType.user;
  bool get isFromAssistant => type == MessageType.assistant;
  bool get isSystemMessage => type == MessageType.system;

  bool get hasActionMetadata => metadata != null && metadata!.containsKey('action');
  
  String? get actionType => metadata?['action']?['type'] as String?;
  Map<String, dynamic>? get actionData => metadata?['action']?['data'] as Map<String, dynamic>?;

  bool get hasContextItem => metadata != null && 
      (metadata!.containsKey('contextItemId') || metadata!.containsKey('contextItemType'));
  
  String? get contextItemId => metadata?['contextItemId'] as String?;
  String? get contextItemType => metadata?['contextItemType'] as String?;

  String get formattedTimestamp {
    final now = DateTime.now();
    final messageTime = timestamp;
    
    // If it's today, show time only
    if (now.year == messageTime.year && 
        now.month == messageTime.month && 
        now.day == messageTime.day) {
      return '${messageTime.hour.toString().padLeft(2, '0')}:${messageTime.minute.toString().padLeft(2, '0')}';
    }
    
    // If it's this year, show month/day
    if (now.year == messageTime.year) {
      return '${messageTime.month}/${messageTime.day}';
    }
    
    // Otherwise show full date
    return '${messageTime.day}/${messageTime.month}/${messageTime.year}';
  }

  String get typeDisplayName {
    switch (type) {
      case MessageType.user:
        return 'You';
      case MessageType.assistant:
        return 'Reva';
      case MessageType.system:
        return 'System';
    }
  }

  // Factory constructors for common message types
  factory ChatMessage.user({
    required String id,
    required String content,
    DateTime? timestamp,
    Map<String, dynamic>? metadata,
  }) {
    return ChatMessage(
      id: id,
      content: content,
      type: MessageType.user,
      timestamp: timestamp ?? DateTime.now(),
      metadata: metadata,
    );
  }

  factory ChatMessage.assistant({
    required String id,
    required String content,
    DateTime? timestamp,
    Map<String, dynamic>? metadata,
  }) {
    return ChatMessage(
      id: id,
      content: content,
      type: MessageType.assistant,
      timestamp: timestamp ?? DateTime.now(),
      metadata: metadata,
    );
  }

  factory ChatMessage.system({
    required String id,
    required String content,
    DateTime? timestamp,
    Map<String, dynamic>? metadata,
  }) {
    return ChatMessage(
      id: id,
      content: content,
      type: MessageType.system,
      timestamp: timestamp ?? DateTime.now(),
      metadata: metadata,
    );
  }

  // Validation methods
  bool isValid() {
    return content.trim().isNotEmpty && id.trim().isNotEmpty;
  }

  List<String> getValidationErrors() {
    final errors = <String>[];
    
    if (id.trim().isEmpty) {
      errors.add('Message ID cannot be empty');
    }
    
    if (content.trim().isEmpty) {
      errors.add('Message content cannot be empty');
    }
    
    if (content.length > 10000) {
      errors.add('Message content cannot exceed 10,000 characters');
    }
    
    if (timestamp.isAfter(DateTime.now().add(const Duration(minutes: 5)))) {
      errors.add('Message timestamp cannot be in the future');
    }
    
    return errors;
  }

  @override
  List<Object?> get props => [
        id,
        content,
        type,
        timestamp,
        metadata,
      ];

  @override
  String toString() {
    return 'ChatMessage(id: $id, type: $type, content: ${content.length > 50 ? '${content.substring(0, 50)}...' : content})';
  }
}

@JsonSerializable()
class ChatResponse extends Equatable {
  @JsonKey(name: 'ai_response_text')
  final String aiResponseText;
  @JsonKey(name: 'action_metadata')
  final Map<String, dynamic>? actionMetadata;
  @JsonKey(name: 'context_item_id')
  final String? contextItemId;
  @JsonKey(name: 'context_item_type')
  final String? contextItemType;

  const ChatResponse({
    required this.aiResponseText,
    this.actionMetadata,
    this.contextItemId,
    this.contextItemType,
  });

  factory ChatResponse.fromJson(Map<String, dynamic> json) => _$ChatResponseFromJson(json);
  Map<String, dynamic> toJson() => _$ChatResponseToJson(this);

  ChatResponse copyWith({
    String? aiResponseText,
    Map<String, dynamic>? actionMetadata,
    String? contextItemId,
    String? contextItemType,
  }) {
    return ChatResponse(
      aiResponseText: aiResponseText ?? this.aiResponseText,
      actionMetadata: actionMetadata ?? this.actionMetadata,
      contextItemId: contextItemId ?? this.contextItemId,
      contextItemType: contextItemType ?? this.contextItemType,
    );
  }

  bool get hasAction => actionMetadata != null;
  bool get hasContextItem => contextItemId != null && contextItemType != null;

  @override
  List<Object?> get props => [
        aiResponseText,
        actionMetadata,
        contextItemId,
        contextItemType,
      ];

  @override
  String toString() {
    return 'ChatResponse(aiResponseText: ${aiResponseText.length > 50 ? '${aiResponseText.substring(0, 50)}...' : aiResponseText}, hasAction: $hasAction)';
  }
}
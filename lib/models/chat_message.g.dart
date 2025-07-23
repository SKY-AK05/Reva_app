// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_message.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ChatMessage _$ChatMessageFromJson(Map<String, dynamic> json) => ChatMessage(
  id: json['id'] as String,
  content: json['content'] as String,
  type: $enumDecode(_$MessageTypeEnumMap, json['type']),
  timestamp: DateTime.parse(json['timestamp'] as String),
  metadata: json['metadata'] as Map<String, dynamic>?,
);

Map<String, dynamic> _$ChatMessageToJson(ChatMessage instance) =>
    <String, dynamic>{
      'id': instance.id,
      'content': instance.content,
      'type': _$MessageTypeEnumMap[instance.type]!,
      'timestamp': instance.timestamp.toIso8601String(),
      'metadata': instance.metadata,
    };

const _$MessageTypeEnumMap = {
  MessageType.user: 'user',
  MessageType.assistant: 'assistant',
  MessageType.system: 'system',
};

ChatResponse _$ChatResponseFromJson(Map<String, dynamic> json) => ChatResponse(
  aiResponseText: json['ai_response_text'] as String,
  actionMetadata: json['action_metadata'] as Map<String, dynamic>?,
  contextItemId: json['context_item_id'] as String?,
  contextItemType: json['context_item_type'] as String?,
);

Map<String, dynamic> _$ChatResponseToJson(ChatResponse instance) =>
    <String, dynamic>{
      'ai_response_text': instance.aiResponseText,
      'action_metadata': instance.actionMetadata,
      'context_item_id': instance.contextItemId,
      'context_item_type': instance.contextItemType,
    };

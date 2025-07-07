// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_message.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ChatMessage _$ChatMessageFromJson(Map<String, dynamic> json) => ChatMessage(
  id: json['id'] as String,
  content: json['content'] as String,
  type: $enumDecode(_$MessageTypeEnumMap, json['type']),
  sender: $enumDecode(_$MessageSenderEnumMap, json['sender']),
  timestamp: DateTime.parse(json['timestamp'] as String),
  metadata: json['metadata'] as Map<String, dynamic>?,
  parentMessageId: json['parentMessageId'] as String?,
  attachments: (json['attachments'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
  status: $enumDecode(_$MessageStatusEnumMap, json['status']),
);

Map<String, dynamic> _$ChatMessageToJson(ChatMessage instance) =>
    <String, dynamic>{
      'id': instance.id,
      'content': instance.content,
      'type': _$MessageTypeEnumMap[instance.type]!,
      'sender': _$MessageSenderEnumMap[instance.sender]!,
      'timestamp': instance.timestamp.toIso8601String(),
      'metadata': instance.metadata,
      'parentMessageId': instance.parentMessageId,
      'attachments': instance.attachments,
      'status': _$MessageStatusEnumMap[instance.status]!,
    };

const _$MessageTypeEnumMap = {
  MessageType.text: 'text',
  MessageType.command: 'command',
  MessageType.eventCreated: 'eventCreated',
  MessageType.eventUpdated: 'eventUpdated',
  MessageType.eventDeleted: 'eventDeleted',
  MessageType.weather: 'weather',
  MessageType.location: 'location',
  MessageType.reminder: 'reminder',
  MessageType.error: 'error',
  MessageType.system: 'system',
};

const _$MessageSenderEnumMap = {
  MessageSender.user: 'user',
  MessageSender.assistant: 'assistant',
  MessageSender.system: 'system',
};

const _$MessageStatusEnumMap = {
  MessageStatus.sending: 'sending',
  MessageStatus.sent: 'sent',
  MessageStatus.delivered: 'delivered',
  MessageStatus.read: 'read',
  MessageStatus.failed: 'failed',
};

ChatSession _$ChatSessionFromJson(Map<String, dynamic> json) => ChatSession(
  id: json['id'] as String,
  title: json['title'] as String,
  createdAt: DateTime.parse(json['createdAt'] as String),
  lastMessageAt: DateTime.parse(json['lastMessageAt'] as String),
  messageCount: (json['messageCount'] as num).toInt(),
  isActive: json['isActive'] as bool,
);

Map<String, dynamic> _$ChatSessionToJson(ChatSession instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'createdAt': instance.createdAt.toIso8601String(),
      'lastMessageAt': instance.lastMessageAt.toIso8601String(),
      'messageCount': instance.messageCount,
      'isActive': instance.isActive,
    };

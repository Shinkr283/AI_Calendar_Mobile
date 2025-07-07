import 'package:json_annotation/json_annotation.dart';

part 'chat_message.g.dart';

@JsonSerializable()
class ChatMessage {
  final String id;
  final String content;
  final MessageType type;
  final MessageSender sender;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata; // 추가 정보 (이벤트 ID, 위치 정보 등)
  final String? parentMessageId; // 답장 메시지의 경우 원본 메시지 ID
  final List<String> attachments; // 첨부파일 URL 목록
  final MessageStatus status;

  const ChatMessage({
    required this.id,
    required this.content,
    required this.type,
    required this.sender,
    required this.timestamp,
    this.metadata,
    this.parentMessageId,
    required this.attachments,
    required this.status,
  });

  // JSON 직렬화/역직렬화
  factory ChatMessage.fromJson(Map<String, dynamic> json) => _$ChatMessageFromJson(json);
  Map<String, dynamic> toJson() => _$ChatMessageToJson(this);

  // 데이터베이스용 Map 변환
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'content': content,
      'type': type.name,
      'sender': sender.name,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'metadata': metadata?.toString(),
      'parentMessageId': parentMessageId,
      'attachments': attachments.join(','),
      'status': status.name,
    };
  }

  // 데이터베이스 Map에서 객체 생성
  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'] as String,
      content: map['content'] as String,
      type: MessageType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => MessageType.text,
      ),
      sender: MessageSender.values.firstWhere(
        (e) => e.name == map['sender'],
        orElse: () => MessageSender.user,
      ),
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      metadata: null, // 나중에 JSON 파싱 로직 추가
      parentMessageId: map['parentMessageId'] as String?,
      attachments: map['attachments'] != null
          ? (map['attachments'] as String).split(',').where((e) => e.isNotEmpty).toList()
          : [],
      status: MessageStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => MessageStatus.sent,
      ),
    );
  }

  // 객체 복사 (수정 시 사용)
  ChatMessage copyWith({
    String? id,
    String? content,
    MessageType? type,
    MessageSender? sender,
    DateTime? timestamp,
    Map<String, dynamic>? metadata,
    String? parentMessageId,
    List<String>? attachments,
    MessageStatus? status,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      content: content ?? this.content,
      type: type ?? this.type,
      sender: sender ?? this.sender,
      timestamp: timestamp ?? this.timestamp,
      metadata: metadata ?? this.metadata,
      parentMessageId: parentMessageId ?? this.parentMessageId,
      attachments: attachments ?? this.attachments,
      status: status ?? this.status,
    );
  }

  @override
  String toString() {
    return 'ChatMessage(id: $id, sender: $sender, type: $type, content: ${content.length > 50 ? content.substring(0, 50) + '...' : content})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChatMessage && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

// 메시지 타입 열거형
enum MessageType {
  text,           // 일반 텍스트
  command,        // 명령어 (일정 추가/수정/삭제)
  eventCreated,   // 일정 생성됨
  eventUpdated,   // 일정 수정됨
  eventDeleted,   // 일정 삭제됨
  weather,        // 날씨 정보
  location,       // 위치 정보
  reminder,       // 알림
  error,          // 오류 메시지
  system,         // 시스템 메시지
}

// 메시지 발신자 열거형
enum MessageSender {
  user,           // 사용자
  assistant,      // AI 어시스턴트
  system,         // 시스템
}

// 메시지 상태 열거형
enum MessageStatus {
  sending,        // 전송 중
  sent,           // 전송됨
  delivered,      // 전달됨
  read,           // 읽음
  failed,         // 전송 실패
}

// 메시지 타입별 표시 정보
class MessageTypeInfo {
  static String getDisplayName(MessageType type) {
    switch (type) {
      case MessageType.text:
        return '텍스트';
      case MessageType.command:
        return '명령어';
      case MessageType.eventCreated:
        return '일정 생성';
      case MessageType.eventUpdated:
        return '일정 수정';
      case MessageType.eventDeleted:
        return '일정 삭제';
      case MessageType.weather:
        return '날씨 정보';
      case MessageType.location:
        return '위치 정보';
      case MessageType.reminder:
        return '알림';
      case MessageType.error:
        return '오류';
      case MessageType.system:
        return '시스템';
    }
  }

  static String getIcon(MessageType type) {
    switch (type) {
      case MessageType.text:
        return '💬';
      case MessageType.command:
        return '⚡';
      case MessageType.eventCreated:
        return '📅';
      case MessageType.eventUpdated:
        return '✏️';
      case MessageType.eventDeleted:
        return '🗑️';
      case MessageType.weather:
        return '🌤️';
      case MessageType.location:
        return '📍';
      case MessageType.reminder:
        return '⏰';
      case MessageType.error:
        return '❌';
      case MessageType.system:
        return '🔧';
    }
  }
}

// 채팅 세션 정보
@JsonSerializable()
class ChatSession {
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime lastMessageAt;
  final int messageCount;
  final bool isActive;

  const ChatSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.lastMessageAt,
    required this.messageCount,
    required this.isActive,
  });

  factory ChatSession.fromJson(Map<String, dynamic> json) => _$ChatSessionFromJson(json);
  Map<String, dynamic> toJson() => _$ChatSessionToJson(this);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'lastMessageAt': lastMessageAt.millisecondsSinceEpoch,
      'messageCount': messageCount,
      'isActive': isActive ? 1 : 0,
    };
  }

  factory ChatSession.fromMap(Map<String, dynamic> map) {
    return ChatSession(
      id: map['id'] as String,
      title: map['title'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
      lastMessageAt: DateTime.fromMillisecondsSinceEpoch(map['lastMessageAt'] as int),
      messageCount: map['messageCount'] as int,
      isActive: (map['isActive'] as int) == 1,
    );
  }

  ChatSession copyWith({
    String? id,
    String? title,
    DateTime? createdAt,
    DateTime? lastMessageAt,
    int? messageCount,
    bool? isActive,
  }) {
    return ChatSession(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      messageCount: messageCount ?? this.messageCount,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  String toString() {
    return 'ChatSession(id: $id, title: $title, messageCount: $messageCount)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChatSession && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
} 
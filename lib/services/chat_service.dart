import 'package:sqflite/sqflite.dart';
import '../models/chat_message.dart';
import 'database_service.dart';

class ChatService {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  ChatSession? _currentSession;

  // 채팅 세션 생성
  Future<ChatSession> createChatSession({required String title}) async {
    final db = await DatabaseService().database;
    final session = ChatSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      createdAt: DateTime.now(),
      lastMessageAt: DateTime.now(),
      messageCount: 0,
      isActive: true,
    );
    await db.insert('chat_sessions', session.toMap());
    _currentSession = session;
    return session;
  }

  // 사용자 메시지 추가
  Future<ChatMessage> addUserMessage(String content) async {
    return await _addMessage(content, MessageSender.user);
  }

  // AI 메시지 추가
  Future<ChatMessage> addAssistantMessage(String content) async {
    return await _addMessage(content, MessageSender.assistant);
  }

  // 메시지 추가 (공통)
  Future<ChatMessage> _addMessage(String content, MessageSender sender) async {
    final db = await DatabaseService().database;
    final session = _currentSession;
    if (session == null) {
      throw Exception('채팅 세션이 없습니다.');
    }
    final message = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: content,
      type: MessageType.text,
      sender: sender,
      timestamp: DateTime.now(),
      metadata: null,
      parentMessageId: null,
      attachments: [],
      status: MessageStatus.sent,
    );
    final messageMap = message.toMap();
    messageMap['sessionId'] = session.id;
    await db.insert('chat_messages', messageMap);
    return message;
  }

  // 현재 세션 메시지 조회
  Future<List<ChatMessage>> getCurrentSessionMessages() async {
    final db = await DatabaseService().database;
    final session = _currentSession;
    if (session == null) {
      throw Exception('채팅 세션이 없습니다.');
    }
    final maps = await db.query(
      'chat_messages',
      where: 'sessionId = ?',
      whereArgs: [session.id],
      orderBy: 'timestamp ASC',
    );
    return maps.map((e) => ChatMessage.fromMap(e)).toList();
  }
} 
import '../models/chat_message.dart';
import 'database_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'dart:convert';
import 'dart:math';
import 'event_service.dart';
import 'package:intl/intl.dart';
import 'user_service.dart';
import 'chat_mbti_service.dart';
import 'chat_schedule_service.dart';
import 'chat_gemini_service.dart';
import 'chat_prompt_service.dart';
import '../models/event.dart';

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

// --------------------------------------------------
// UI 상태 관리를 위한 ChatProvider
// --------------------------------------------------
class ChatProvider with ChangeNotifier {
  final List<types.Message> _messages = [];
  final _user = const types.User(id: 'user');
  final _aiAssistant = const types.User(id: 'ai', firstName: 'AI 비서');
  bool _isLoading = false;

  // 각 기능별 서비스들
  final GeminiService _geminiService = GeminiService();
  final MbtiService _mbtiService = MbtiService();
  final CalendarService _calendarService = CalendarService();
  final PromptService _promptService = PromptService();
  
  String _currentUserMbti = 'INFP'; // 기본값
  final List<Map<String, dynamic>> _conversationHistory = [];

  List<types.Message> get messages => _messages;
  bool get isLoading => _isLoading;

  ChatProvider() {
    _initialize();
  }

  // 비동기 초기화
  Future<void> _initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      final userService = UserService();
      var user = await userService.getCurrentUser();

      // 앱 최초 실행 시 사용자가 없으면 기본 사용자를 생성합니다.
      user ??= await userService.createUser(
        name: '사용자',
        email: 'user@example.com',
        mbtiType: 'INFP',
      );
      _currentUserMbti = user.mbtiType ?? 'INFP';

      await _loadInitialMessage();

    } catch (e) {
      final errorMessage = types.TextMessage(
        author: _aiAssistant,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        id: _randomString(),
        text: 'AI 비서 초기화 중 오류가 발생했습니다: $e',
      );
      _addMessage(errorMessage);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 초기 메시지 로드 (오늘 일정 브리핑)
  Future<void> _loadInitialMessage() async {
    try {
      final eventService = EventService();
      final todayEvents = await eventService.getTodayEvents();
      
      final todayDate = DateFormat('yyyy년 MM월 dd일 EEEE', 'ko_KR').format(DateTime.now());

      var briefingText = "안녕하세요! 👋\n오늘은 $todayDate 입니다.\n";

      if (todayEvents.isEmpty) {
        briefingText += "\n오늘은 예정된 일정이 없네요. 새로운 계획을 세워볼까요?";
      } else {
        briefingText += "\n오늘 ${todayEvents.length}개의 일정이 있습니다.\n";
        
        // 시간순으로 정렬
        todayEvents.sort((a, b) => a.startTime.compareTo(b.startTime));
        
        for (final event in todayEvents) {
          final startTime = DateFormat('HH:mm').format(event.startTime);
          briefingText += "• $startTime: ${event.title}\n";
        }
      }
      
      briefingText += "\n무엇을 도와드릴까요?";

      final initialMessage = types.TextMessage(
        author: _aiAssistant,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        id: _randomString(),
        text: briefingText,
      );
      _addMessage(initialMessage);

    } catch (e) {
      final errorMessage = types.TextMessage(
        author: _aiAssistant,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        id: _randomString(),
        text: '안녕하세요! 일정을 불러오는 중 오류가 발생했어요. 무엇을 도와드릴까요?',
      );
      _addMessage(errorMessage);
    }
  }

  // Function call 처리 - 각 서비스에 위임
  Future<Map<String, dynamic>> _handleFunctionCall(GeminiFunctionCall call) async {
    // MBTI 관련 function call
    if (call.name == 'setMbtiType') {
      return await _mbtiService.handleFunctionCall(call);
    }
    
    // 캘린더 관련 function calls
    if (['getCalendarEvents', 'createCalendarEvent', 'updateCalendarEvent', 'deleteCalendarEvent'].contains(call.name)) {
      return await _calendarService.handleFunctionCall(call);
    }
    
    return {'status': '오류: 알 수 없는 함수입니다.'};
  }

  // 모든 function declarations 가져오기
  List<Map<String, dynamic>> _getAllFunctionDeclarations() {
    return [
      ...MbtiService.functions,
      ...CalendarService.functions,
    ];
  }

  // 메시지 전송 및 AI 응답 처리
  Future<void> sendMessage(types.PartialText message) async {
    // 사용자 메시지 추가
    final userMessage = types.TextMessage(
      author: _user,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      id: _randomString(),
      text: message.text,
    );
    _addMessage(userMessage);
    
    // 대화 히스토리에 추가
    _conversationHistory.add({
      'parts': [{'text': message.text}],
      'role': 'user'
    });
    
    _isLoading = true;
    notifyListeners();

    try {
      // 현재 MBTI 유형 가져오기
      _currentUserMbti = await _mbtiService.getCurrentMbtiType();
      
      // 시스템 프롬프트 생성
      final systemPrompt = _promptService.createSystemPrompt(_currentUserMbti);
      
      // 모든 function declarations 가져오기
      final functionDeclarations = _getAllFunctionDeclarations();
      
      // AI 서비스로 메시지 전송
      final response = await _geminiService.sendMessage(
        message: message.text,
        systemPrompt: systemPrompt,
        functionDeclarations: functionDeclarations,
        conversationHistory: _conversationHistory,
      );

      if (response.functionCalls.isNotEmpty) {
        // Function call 처리
        final functionCall = response.functionCalls.first;
        final result = await _handleFunctionCall(functionCall);
        
        // Function response 전송
        final followUpResponse = await _geminiService.sendFunctionResponse(
          functionName: functionCall.name,
          functionResult: result,
          systemPrompt: systemPrompt,
          functionDeclarations: functionDeclarations,
          conversationHistory: _conversationHistory,
        );
        
        final aiMessageText = followUpResponse.text ?? '알겠습니다! 처리되었습니다.';
        final aiMessage = types.TextMessage(
          author: _aiAssistant,
          createdAt: DateTime.now().millisecondsSinceEpoch,
          id: _randomString(),
          text: aiMessageText,
        );
        _addMessage(aiMessage);
        
        // 대화 히스토리에 AI 응답 추가
        _conversationHistory.add({
          'parts': [{'text': aiMessageText}],
          'role': 'model'
        });
        
        // MBTI 변경된 경우 현재 값 업데이트
        if (functionCall.name == 'setMbtiType') {
          _currentUserMbti = await _mbtiService.getCurrentMbtiType();
        }
        
      } else if (response.text != null) {
        // 일반 텍스트 응답
        final aiMessage = types.TextMessage(
          author: _aiAssistant,
          createdAt: DateTime.now().millisecondsSinceEpoch,
          id: _randomString(),
          text: response.text!,
        );
        _addMessage(aiMessage);
        
        // 대화 히스토리에 AI 응답 추가
        _conversationHistory.add({
          'parts': [{'text': response.text!}],
          'role': 'model'
        });
      }
    } catch (e) {
      final errorMessage = types.TextMessage(
        author: _aiAssistant,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        id: _randomString(),
        text: '죄송합니다, 오류가 발생했어요. API 키나 네트워크를 확인해주세요: $e',
      );
      _addMessage(errorMessage);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _addMessage(types.Message message) {
    _messages.insert(0, message);
    notifyListeners();
  }

  String _randomString() {
    final random = Random.secure();
    final values = List<int>.generate(16, (i) => random.nextInt(255));
    return base64UrlEncode(values);
  }
} 
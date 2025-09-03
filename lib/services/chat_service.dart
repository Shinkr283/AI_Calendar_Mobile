import '../models/chat_message.dart';
import 'database_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'package:intl/intl.dart';
import 'chat_mbti_service.dart';
import 'chat_schedule_service.dart';
import 'chat_schedule_update.dart';
import 'chat_gemini_service.dart';
import 'chat_prompt_service.dart';
import 'chat_briefing_service.dart';
import 'chat_weather_service.dart';
import 'chat_recommend_service.dart';
import 'chat_location_service.dart';

/// 채팅 세션 모델
class ChatSession {
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime lastMessageAt;
  final int messageCount;
  final bool isActive;

  ChatSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.lastMessageAt,
    required this.messageCount,
    required this.isActive,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'createdAt': createdAt.toIso8601String(),
      'lastMessageAt': lastMessageAt.toIso8601String(),
      'messageCount': messageCount,
      'isActive': isActive ? 1 : 0,
    };
  }

  factory ChatSession.fromMap(Map<String, dynamic> map) {
    return ChatSession(
      id: map['id'],
      title: map['title'],
      createdAt: DateTime.parse(map['createdAt']),
      lastMessageAt: DateTime.parse(map['lastMessageAt']),
      messageCount: map['messageCount'],
      isActive: map['isActive'] == 1,
    );
  }
}

/// 채팅 세션 관리 서비스
class ChatService {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  ChatSession? _currentSession;

  /// 채팅 세션 생성
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

  /// 브리핑 등 외부에서 AI 텍스트만 필요할 때 사용하는 경량 메서드
  Future<String?> generateText({
    required String systemPrompt,
    required String message,
    List<Map<String, dynamic>> conversationHistory = const [],
  }) async {
    try {
      final response = await GeminiService()
          .sendMessage(
            message: message,
            systemPrompt: systemPrompt,
            functionDeclarations: const [],
            conversationHistory: conversationHistory,
          )
          .timeout(const Duration(seconds: 20));
      return response.text?.trim();
    } catch (_) {
      return null;
    }
  }

  /// 사용자 메시지 추가
  Future<ChatMessage> addUserMessage(String content) async {
    return await _addMessage(content, MessageSender.user);
  }

  /// AI 메시지 추가
  Future<ChatMessage> addAssistantMessage(String content) async {
    return await _addMessage(content, MessageSender.assistant);
  }

  /// 메시지 추가 (공통)
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

  /// 현재 세션 메시지 조회
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

/// AI 채팅 제공자 - 메인 AI 서비스 베이스
class ChatProvider with ChangeNotifier {
  // 상태 관리
  final List<types.Message> _messages = [];
  final List<Map<String, dynamic>> _conversationHistory = [];
  bool _isLoading = false;

  // 사용자 정의
  final _user = const types.User(id: 'user');
  final _aiAssistant = const types.User(id: 'ai', firstName: 'AI 비서');

  // 서비스 인스턴스들 (지연 초기화)
  late final GeminiService _geminiService;
  late final MbtiService _mbtiService;
  late final ChatScheduleService _calendarService;
  late final PromptService _promptService;
  late final ChatWeatherService _weatherService;
  late final ChatRecommendService _recommendService;
  late final BriefingService _briefingService;
  late final ChatLocationService _locationService;

  // Function 처리 핸들러 맵
  late final Map<String, Function(GeminiFunctionCall)> _functionHandlers;

  /// Getters
  List<types.Message> get messages => _messages;
  bool get isLoading => _isLoading;

  ChatProvider() {
    _initializeServices();
    _setupFunctionHandlers();
    _initialize();
  }

  /// 서비스 초기화
  void _initializeServices() {
    _geminiService = GeminiService();
    _mbtiService = MbtiService();
    _calendarService = ChatScheduleService();
    _promptService = PromptService();
    _weatherService = ChatWeatherService();
    _recommendService = ChatRecommendService();
    _briefingService = BriefingService();
    _locationService = ChatLocationService();
  }

  /// Function 핸들러 설정
  void _setupFunctionHandlers() {
    _functionHandlers = {
      // MBTI 관련
      'setMbtiType': (call) => _mbtiService.handleFunctionCall(call),
      
      // 캘린더 관련
      'createCalendarEvent': (call) => ChatScheduleUpdate().createOrUpdateEvent(call.args),
      'updateCalendarEvent': (call) => ChatScheduleUpdate().updateEvent(call.args),
      'getCalendarEvents': (call) => _calendarService.handleFunctionCall(call),
      'deleteCalendarEvent': (call) => _calendarService.handleFunctionCall(call),
      
      // 날씨 관련
      'getCurrentLocationWeather': (call) => _weatherService.handleFunctionCall(call),
      'getWeatherByDate': (call) => _weatherService.handleFunctionCall(call),
      'getWeatherForTodayEvent': (call) => _weatherService.handleFunctionCall(call),
      
      // 장소 관련
      'handleLocationQuery': (call) => _locationService.handleLocationQuery(call.args['location'] as String),

      // 맛집 추천 관련
      'getNearbyRestaurants': (call) => _recommendService.handleFunctionCall(call),
    };
  }

  /// 비동기 초기화
  Future<void> _initialize() async {
    _setLoading(true);

    try {
      // MBTI 캐시 무효화 (프로그램 시작 시)
      _mbtiService.invalidateMbtiCache();
      
      // PromptService 초기화 (MBTI 캐싱)
      await _promptService.initialize();
      
      await _showWelcomeMessage();
    } catch (e) {
      _addErrorMessage('AI 비서 초기화 중 오류가 발생했습니다: $e');
    } finally {
      _setLoading(false);
    }
  }
  /// 환영 메시지 표시
  Future<void> _showWelcomeMessage() async {
    final systemPrompt = await _promptService.createSystemPrompt();
    final functionDeclarations = _getAllFunctionDeclarations();

    try {
      final response = await _geminiService.sendMessage(
        message: '안녕하세요! 도움이 필요하면 언제든 말씀해주세요.',
        systemPrompt: systemPrompt,
        functionDeclarations: functionDeclarations,
        conversationHistory: _conversationHistory,
      ).timeout(const Duration(seconds: 10));

      final welcomeText = response.text?.trim() ?? '안녕하세요! 무엇을 도와드릴까요?';
      _addAIMessage(welcomeText);
    } catch (e) {
      _addAIMessage('안녕하세요! 무엇을 도와드릴까요?');
    }
  }

  /// 메시지 전송 및 AI 응답 처리
  Future<void> sendMessage(types.PartialText message) async {
    final processedText = _preprocessMessage(message.text);
    
    _addUserMessage(processedText);
    _addToHistory('user', processedText);
    _setLoading(true);

    try {
      // 빠른 로컬 처리 확인
      if (await _handleLocalQueries(processedText)) {
        return;
      }

      // AI 응답 생성
      await _processAIResponse(processedText);
      
    } catch (e) {
      _addErrorMessage('죄송합니다, 오류가 발생했어요. 다시 시도해주세요: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// 메시지 전처리
  String _preprocessMessage(String text) {
    return text.replaceAll(
      RegExp(r'오늘'),
      DateFormat('yyyy-MM-dd').format(DateTime.now()),
    );
  }

  /// 로컬 쿼리 처리
  Future<bool> _handleLocalQueries(String text) async {
    // 날짜/요일 질문
    final todayQuery = RegExp(r'(오늘\s*(날짜|며칠|요일))');
    if (todayQuery.hasMatch(text)) {
      final todayFmt = DateFormat('yyyy-MM-dd (EEEE)', 'ko_KR').format(DateTime.now());
      _addAIMessage('오늘은 $todayFmt 입니다.');
      return true;
    }

    // 위치 관련 질문 처리
    final locationQuery = RegExp(r'(현재\s*(위치|장소|어디|어느\s*곳)|내\s*(위치|장소|어디|어느\s*곳)|지금\s*(위치|장소|어디|어느\s*곳)|여기\s*(어디|어느\s*곳)|위치\s*(알려줘|보여줘|확인|찾아줘)|장소\s*(알려줘|보여줘|확인|찾아줘))');
    if (locationQuery.hasMatch(text)) {
      try {
        _setLoading(true);
        final locationInfo = await _locationService.handleLocationQuery(text);
        if (locationInfo != null) {
          _addAIMessage(locationInfo);
        } else {
          _addAIMessage('죄송합니다. 위치 정보를 처리할 수 없습니다.');
        }
      } catch (e) {
        _addErrorMessage('위치 정보를 가져오는 중 오류가 발생했습니다: $e');
      } finally {
        _setLoading(false);
      }
      return true;
    }

    return false;
  }

  /// AI 응답 처리
  Future<void> _processAIResponse(String text) async {
    final systemPrompt = await _promptService.createSystemPrompt();
    final functionDeclarations = _getAllFunctionDeclarations();

    final response = await _geminiService.sendMessage(
      message: text,
      systemPrompt: systemPrompt,
      functionDeclarations: functionDeclarations,
      conversationHistory: _conversationHistory,
    );

    if (response.functionCalls.isNotEmpty) {
      await _handleFunctionCall(response.functionCalls.first);
    } else if (response.text != null) {
      _addAIMessage(response.text!);
    }
  }

  /// Function call 처리
  Future<void> _handleFunctionCall(GeminiFunctionCall call) async {
    final handler = _functionHandlers[call.name];
    if (handler == null) {
      _addAIMessage('죄송합니다, 요청하신 기능을 찾을 수 없습니다.');
      return;
    }

    try {
      final result = await handler(call);
      
      // Function response 전송
      final followUpResponse = await _geminiService.sendFunctionResponse(
        functionName: call.name,
        functionResult: result,
        systemPrompt: await _promptService.createSystemPrompt(),
        functionDeclarations: _getAllFunctionDeclarations(),
        conversationHistory: _conversationHistory,
      );

      final responseText = followUpResponse.text ?? '처리되었습니다.';
      _addAIMessage(responseText);

    } catch (e) {
      _addErrorMessage('기능 처리 중 오류가 발생했습니다: $e');
    }
  }

  /// 브리핑 요청 처리
  Future<void> requestBriefing() async {
    _setLoading(true);
    _messages.clear();
    notifyListeners();

    try {
      final briefingText = await _briefingService.getBriefingForDate(DateTime.now());
      _addAIMessage(briefingText);
    } catch (e) {
      _addErrorMessage('브리핑을 생성하는 중 오류가 발생했습니다: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// 맛집 추천 요청 처리
  Future<void> requestRestaurantRecommendation(String location) async {
    _setLoading(true);
    
    try {
      final result = await _recommendService.getDetailedRestaurantRecommendations(location);
      
      if (result['success']) {
        final restaurants = result['restaurants'] as List<dynamic>;
        final message = _formatRestaurantRecommendation(result['message'], restaurants);
        _addAIMessage(message);
      } else {
        _addErrorMessage(result['message']);
      }
    } catch (e) {
      _addErrorMessage('맛집 추천을 가져오는 중 오류가 발생했습니다: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// 맛집 추천 요청 처리 (사용자 메시지 기반)
  Future<void> handleRestaurantRecommendationRequest(String userMessage) async {
    _setLoading(true);
    
    try {
      final response = await _recommendService.handleRestaurantRecommendationRequest(userMessage);
      _addAIMessage(response);
    } catch (e) {
      _addErrorMessage('맛집 추천을 가져오는 중 오류가 발생했습니다: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// 맛집 추천 결과 포맷팅
  String _formatRestaurantRecommendation(String status, List<dynamic> restaurants) {
    final buffer = StringBuffer();
    buffer.writeln(status);
    buffer.writeln();
    
    for (int i = 0; i < restaurants.length; i++) {
      final restaurant = restaurants[i];
      final name = restaurant['name'] as String? ?? '';
      final taste = restaurant['taste'] as String? ?? '';
      final address = restaurant['address'] as String? ?? '';
      final rating = restaurant['rating'] as String? ?? '';
      final userRatingCount = restaurant['userRatingCount'] as String? ?? '';
      
      buffer.writeln('${i + 1}. 🍽️ $name');
      if (taste.isNotEmpty) {
        buffer.writeln('   🎯 $taste 맛집');
      }
      if (rating.isNotEmpty) {
        buffer.writeln('   ⭐ 평점: $rating (리뷰 $userRatingCount개)');
      }
      buffer.writeln('   📍 $address');
      if (i < restaurants.length - 1) buffer.writeln();
    }
    
    return buffer.toString();
  }

  /// Function declarations 가져오기
  List<Map<String, dynamic>> _getAllFunctionDeclarations() {
    return [
      ...MbtiService.functions,
      ...ChatScheduleService.functions,
      ...ChatWeatherService.functions,
      ...ChatRecommendService.functions,
    ];
  }

  /// 유틸리티 메서드들
  void _addUserMessage(String text) {
    final message = types.TextMessage(
      author: _user,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      id: _randomString(),
      text: text,
    );
    _addMessage(message);
  }

  void _addAIMessage(String text) {
    final message = types.TextMessage(
      author: _aiAssistant,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      id: _randomString(),
      text: text,
    );
    _addMessage(message);
    _addToHistory('model', text);
  }

  void _addErrorMessage(String text) {
    final message = types.TextMessage(
      author: _aiAssistant,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      id: _randomString(),
      text: text,
    );
    _addMessage(message);
  }

  void _addMessage(types.Message message) {
    _messages.insert(0, message);
    notifyListeners();
  }

  void _addToHistory(String role, String text) {
    _conversationHistory.add({
      'parts': [{'text': text}],
      'role': role,
    });
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// 외부 인터페이스 메서드들
  void addAssistantText(String text) => _addAIMessage(text);
  void addUserText(String text) => _addUserMessage(text);
  
  /// 메시지 초기화
  void clearMessages() {
    _messages.clear();
    _conversationHistory.clear();
    notifyListeners();
  }

  String _randomString() {
    final random = Random.secure();
    final values = List<int>.generate(16, (i) => random.nextInt(255));
    return base64UrlEncode(values);
  }

  /// 리소스 정리
  @override
  void dispose() {
    _messages.clear();
    _conversationHistory.clear();
    super.dispose();
  }
}
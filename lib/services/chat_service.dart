import '../models/chat_message.dart';
import 'database_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'event_service.dart';
import '../models/event.dart' show Event;
import 'package:geolocator/geolocator.dart' show Position;
import 'package:intl/intl.dart';
import 'weather_service.dart';
import 'location_service.dart';
import 'user_service.dart';
import 'chat_mbti_service.dart';
import 'chat_schedule_service.dart';
import 'chat_gemini_service.dart';
import 'chat_prompt_service.dart';
import 'chat_weather_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  final WeatherChatService _weatherService = WeatherChatService();

  
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
      final todayDate = DateFormat('yyyy년 MM월 dd일 EEEE', 'ko_KR').format(DateTime.now());

      // 병렬 로딩 + 타임아웃 적용
      final eventsFuture = eventService.getTodayEvents();
      final posFuture = _withTimeout(LocationService().getCurrentPosition(), const Duration(seconds: 2));

      final results = await Future.wait([
        eventsFuture,
        posFuture,
      ], eagerError: false);

      final todayEvents = results[0] as List<Event>;
      Position? pos = results[1] as Position?;
      // 위치 타임아웃/실패 시 마지막 위치로 보완 시도
      pos ??= await _withTimeout(LocationService().getLastKnownPosition(), const Duration(seconds: 1));

      // 위치 / 날씨 / 주소 (위치가 있을 때만, 2초 타임아웃)
      String city = '';
      String temp = '';
      String weatherDesc = '';
      String address = '';
      double? lat;
      double? lon;
      final prefsWX = await SharedPreferences.getInstance();
      if (pos != null) {
        lat = pos.latitude;
        lon = pos.longitude;
        address = await _withTimeout(LocationService().getAddressFrom(pos), const Duration(seconds: 2)) ?? '';
      } else {
        // 캐시 좌표 사용 시도
        lat = double.tryParse(prefsWX.getString('last_lat') ?? '');
        lon = double.tryParse(prefsWX.getString('last_lon') ?? '');
        address = prefsWX.getString('last_address') ?? '';
      }
      // 최종 실패 시 서울 기본값
      lat ??= 37.5665;
      lon ??= 126.9780;
      if (address.isEmpty) address = '서울특별시';
      final weather = await _withTimeout(WeatherService().fetchWeather(lat, lon), const Duration(seconds: 2));
      if (weather != null) {
        city = (weather['name'] ?? '').toString();
        temp = (weather['main']?['temp'] ?? '').toString();
        weatherDesc = (weather['weather']?[0]?['description'] ?? '').toString();
        // 캐시 저장
        await prefsWX.setString('last_lat', lat.toString());
        await prefsWX.setString('last_lon', lon.toString());
        await prefsWX.setString('last_address', address);
        await prefsWX.setString('last_weather', jsonEncode(weather));
      } else {
        // 캐시 날씨 폴백
        final cached = prefsWX.getString('last_weather');
        if (cached != null && cached.isNotEmpty) {
          try {
            final w = jsonDecode(cached) as Map<String, dynamic>;
            city = (w['name'] ?? '').toString();
            temp = (w['main']?['temp'] ?? '').toString();
            weatherDesc = (w['weather']?[0]?['description'] ?? '').toString();
          } catch (_) {}
        }
      }

      // 일정 리스트 문자열화
      final eventListBuffer = StringBuffer();
      if (todayEvents.isEmpty) {
        eventListBuffer.writeln('- (없음)');
      } else {
        todayEvents.sort((a, b) => a.startTime.compareTo(b.startTime));
        for (final e in todayEvents) {
          final t = DateFormat('HH:mm').format(e.startTime);
          eventListBuffer.writeln('- $t: ${e.title}');
        }
      }

      // LLM에게 최종 브리핑 작성을 맡김 (키워드 규칙 없이, 사용자/날씨/일정/위치 기반)
      final locLine = address.isNotEmpty ? address : city;
      final eventsBlock = _promptService.buildEventsBlock(todayEvents, limit: 5);
      final contextPrompt = await _promptService.buildContextPrompt(
        todayDate: todayDate,
        locLine: locLine,
        weatherDesc: weatherDesc,
        temp: temp,
        mbtiStyle: await _promptService.getMbtiStyleBlock(_currentUserMbti),
        eventsBlock: eventsBlock,
      );

      // LLM 비동기 생성
      final systemPrompt = _promptService.createSystemPrompt(_currentUserMbti);
      final functionDeclarations = _getAllFunctionDeclarations();
      final response = await _geminiService.sendMessage(
        message: contextPrompt,
        systemPrompt: systemPrompt,
        functionDeclarations: functionDeclarations,
        conversationHistory: _conversationHistory,
      ).timeout(const Duration(seconds: 10));
      final refined = (response.text ?? '').trim();
      if (refined.isNotEmpty) {
        final msg = types.TextMessage(
          author: _aiAssistant,
          createdAt: DateTime.now().millisecondsSinceEpoch,
          id: _randomString(),
          text: refined,
        );
        _addMessage(msg);
      }

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

  Future<T?> _withTimeout<T>(Future<T?> future, Duration duration) async {
    try {
      return await future.timeout(duration);
    } catch (_) {
      return null;
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
    // 날씨 관련 function calls
    if (['getCurrentLocationWeather'].contains(call.name)) {
      return await _weatherService.handleFunctionCall(call);
    }
    
    return {'status': '오류: 알 수 없는 함수입니다.'};
  }

  // 모든 function declarations 가져오기
  List<Map<String, dynamic>> _getAllFunctionDeclarations() {
    return [
      ...MbtiService.functions,
      ...CalendarService.functions,
      ...WeatherChatService.functions,
    ];
  }

  // 메시지 전송 및 AI 응답 처리
  Future<void> sendMessage(types.PartialText message) async {
    // '오늘'을 실제 날짜(YYYY-MM-DD)로 대체
    final processedText = message.text.replaceAll(
      RegExp(r'오늘'),
      DateFormat('yyyy-MM-dd').format(DateTime.now()),
    );
    // 사용자 메시지 추가
    final userMessage = types.TextMessage(
      author: _user,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      id: _randomString(),
      text: processedText,
    );
    _addMessage(userMessage);
    
    // 대화 히스토리에 추가
    _conversationHistory.add({
      'parts': [{'text': processedText}],
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
      
      // 빠른 로컬 질의 처리: 오늘 날짜/요일 질문
      final todayQuery = RegExp(r'(오늘\s*(날짜|며칠|요일))');
      if (todayQuery.hasMatch(processedText)) {
        final todayFmt = DateFormat('yyyy-MM-dd (EEEE)', 'ko_KR').format(DateTime.now());
        final aiText = '오늘은 $todayFmt 입니다.';
        final aiMessage = types.TextMessage(
          author: _aiAssistant,
          createdAt: DateTime.now().millisecondsSinceEpoch,
          id: _randomString(),
          text: aiText,
        );
        _addMessage(aiMessage);
        _conversationHistory.add({'parts': [{'text': aiText}], 'role': 'model'});
        return;
      }
      // 빠른 로컬 질의 처리: 현재 위치 질문
      final locationQuery = RegExp(r'(현재\s*(위치|장소)|내\s*(위치|장소))');
      if (locationQuery.hasMatch(processedText)) {
        // 위치 조회 및 주소 변환 (타임아웃 2초)
        Position? pos = await _withTimeout(LocationService().getCurrentPosition(), const Duration(seconds: 2));
        String address = '';
        if (pos != null) {
          address = await _withTimeout(LocationService().getAddressFrom(pos), const Duration(seconds: 2)) ?? '';
        }
        final aiText = address.isNotEmpty
            ? '현재 위치는 $address 입니다.'
            : '죄송합니다, 현재 위치를 알 수 없습니다.';
        final aiMessage = types.TextMessage(
          author: _aiAssistant,
          createdAt: DateTime.now().millisecondsSinceEpoch,
          id: _randomString(),
          text: aiText,
        );
        _addMessage(aiMessage);
        _conversationHistory.add({'parts': [{'text': aiText}], 'role': 'model'});
        _isLoading = false;
        notifyListeners();
        return;
      }

      final response = await _geminiService.sendMessage(
        message: processedText,
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
  
  /// AI 비서 메시지를 직접 추가합니다.
  void addAssistantText(String text) {
    final aiMessage = types.TextMessage(
      author: _aiAssistant,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      id: _randomString(),
      text: text,
    );
    _addMessage(aiMessage);
  }

  /// 사용자 요청시 오늘 일정 브리핑을 다시 로드합니다.
  Future<void> requestBriefing() async {
    _isLoading = true;
    notifyListeners();
    _messages.clear();
    notifyListeners();
    try {
      await _loadInitialMessage();
    } catch (_) {
      // 무시
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
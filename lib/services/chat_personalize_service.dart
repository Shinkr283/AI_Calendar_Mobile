import '../models/chat_prompt_health.dart';
import '../models/chat_prompt_learning.dart';
import '../models/chat_prompt_style.dart';
import '../models/chat_prompt_travel.dart';
import 'chat_gemini_service.dart';

/// 개인화된 AI 응답을 생성하는 서비스
class ChatPersonalizeService {
  static final ChatPersonalizeService _instance = ChatPersonalizeService._internal();
  factory ChatPersonalizeService() => _instance;
  ChatPersonalizeService._internal();

  final GeminiService _geminiService = GeminiService();

  /// 건강 관련 개인화 응답 생성
  Future<String> generatePersonalizedHealthResponse({
    required String userMessage,
    String? healthProfileJson,
    String? calendarConstraints,
    String? localWeather,
    String? facilityAccess,
    List<Map<String, dynamic>> conversationHistory = const [],
  }) async {
    try {
      final prompt = ChatPromptHealthService.createPrompt(
        healthProfileJson: healthProfileJson,
        calendarConstraints: calendarConstraints,
        localWeather: localWeather,
        facilityAccess: facilityAccess,
      );

      final response = await _geminiService.sendMessage(
        message: userMessage,
        systemPrompt: prompt,
        functionDeclarations: const [],
        conversationHistory: conversationHistory,
      ).timeout(const Duration(seconds: 30));

      return response.text?.trim() ?? '건강 관련 응답을 생성할 수 없습니다.';
    } catch (e) {
      return '건강 관련 응답 생성 중 오류가 발생했습니다: $e';
    }
  }

  /// 학습 관련 개인화 응답 생성
  Future<String> generatePersonalizedLearningResponse({
    required String userMessage,
    String? subjectsGoals,
    String? deadlines,
    String? calendarConstraints,
    String? learningStyle,
    List<Map<String, dynamic>> conversationHistory = const [],
  }) async {
    try {
      final prompt = ChatPromptLearningService.createPrompt(
        subjectsGoals: subjectsGoals,
        deadlines: deadlines,
        calendarConstraints: calendarConstraints,
        learningStyle: learningStyle,
      );

      final response = await _geminiService.sendMessage(
        message: userMessage,
        systemPrompt: prompt,
        functionDeclarations: const [],
        conversationHistory: conversationHistory,
      ).timeout(const Duration(seconds: 30));

      return response.text?.trim() ?? '학습 관련 응답을 생성할 수 없습니다.';
    } catch (e) {
      return '학습 관련 응답 생성 중 오류가 발생했습니다: $e';
    }
  }

  /// 스타일 관련 개인화 응답 생성
  Future<String> generatePersonalizedStyleResponse({
    required String userMessage,
    String? eventsWithContext,
    String? wardrobePrefs,
    String? forecastByEvent,
    List<Map<String, dynamic>> conversationHistory = const [],
  }) async {
    try {
      final prompt = ChatPromptStyleService.createPrompt(
        eventsWithContext: eventsWithContext,
        wardrobePrefs: wardrobePrefs,
        forecastByEvent: forecastByEvent,
      );

      final response = await _geminiService.sendMessage(
        message: userMessage,
        systemPrompt: prompt,
        functionDeclarations: const [],
        conversationHistory: conversationHistory,
      ).timeout(const Duration(seconds: 30));

      return response.text?.trim() ?? '스타일 관련 응답을 생성할 수 없습니다.';
    } catch (e) {
      return '스타일 관련 응답 생성 중 오류가 발생했습니다: $e';
    }
  }

  /// 여행 관련 개인화 응답 생성
  Future<String> generatePersonalizedTravelResponse({
    required String userMessage,
    String? tripOverview,
    String? preferencesBudgetConstraints,
    String? bookingsJson,
    List<Map<String, dynamic>> conversationHistory = const [],
  }) async {
    try {
      final prompt = ChatPromptTravelService.createPrompt(
        tripOverview: tripOverview,
        preferencesBudgetConstraints: preferencesBudgetConstraints,
        bookingsJson: bookingsJson,
      );

      final response = await _geminiService.sendMessage(
        message: userMessage,
        systemPrompt: prompt,
        functionDeclarations: const [],
        conversationHistory: conversationHistory,
      ).timeout(const Duration(seconds: 30));

      return response.text?.trim() ?? '여행 관련 응답을 생성할 수 없습니다.';
    } catch (e) {
      return '여행 관련 응답 생성 중 오류가 발생했습니다: $e';
    }
  }

  /// 선택된 타입에 따른 개인화 응답 생성
  Future<String> generatePersonalizedResponse({
    required String userMessage,
    required String selectedType, // 'health', 'learning', 'style', 'travel', 'general'
    Map<String, String> contextData = const {},
    List<Map<String, dynamic>> conversationHistory = const [],
  }) async {
    switch (selectedType) {
      case 'health':
        return await generatePersonalizedHealthResponse(
          userMessage: userMessage,
          healthProfileJson: contextData['healthProfileJson'],
          calendarConstraints: contextData['calendarConstraints'],
          localWeather: contextData['localWeather'],
          facilityAccess: contextData['facilityAccess'],
          conversationHistory: conversationHistory,
        );
        
      case 'learning':
        return await generatePersonalizedLearningResponse(
          userMessage: userMessage,
          subjectsGoals: contextData['subjectsGoals'],
          deadlines: contextData['deadlines'],
          calendarConstraints: contextData['calendarConstraints'],
          learningStyle: contextData['learningStyle'],
          conversationHistory: conversationHistory,
        );
        
      case 'style':
        return await generatePersonalizedStyleResponse(
          userMessage: userMessage,
          eventsWithContext: contextData['eventsWithContext'],
          wardrobePrefs: contextData['wardrobePrefs'],
          forecastByEvent: contextData['forecastByEvent'],
          conversationHistory: conversationHistory,
        );
        
      case 'travel':
        return await generatePersonalizedTravelResponse(
          userMessage: userMessage,
          tripOverview: contextData['tripOverview'],
          preferencesBudgetConstraints: contextData['preferencesBudgetConstraints'],
          bookingsJson: contextData['bookingsJson'],
          conversationHistory: conversationHistory,
        );
        
      default:
        // 일반적인 응답 (기본 프롬프트 사용)
        try {
          final response = await _geminiService.sendMessage(
            message: userMessage,
            systemPrompt: '당신은 도움이 되는 AI 비서입니다. 친근하고 유용한 답변을 제공해주세요.',
            functionDeclarations: const [],
            conversationHistory: conversationHistory,
          ).timeout(const Duration(seconds: 30));
          
          return response.text?.trim() ?? '응답을 생성할 수 없습니다.';
        } catch (e) {
          return '응답 생성 중 오류가 발생했습니다: $e';
        }
    }
  }
}

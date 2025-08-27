import 'package:intl/intl.dart';
import 'event_service.dart';
import 'location_service.dart';
import 'weather_service.dart';
import 'user_service.dart';
import 'chat_prompt_service.dart';
import '../models/event.dart';
import '../models/user_profile.dart';
import 'chat_gemini_service.dart';

/// 특정 날짜에 대한 브리핑 텍스트를 생성합니다.
class BriefingService {
  
  /// 타임아웃이 적용된 위치 정보 조회
  Future<Map<String, dynamic>> _getLocationWithTimeout() async {
    try {
      // 위치 조회와 주소 변환을 병렬로 처리 (각각 타임아웃 적용)
      final pos = await LocationService().getCurrentPosition()
          .timeout(const Duration(seconds: 10));
      
      final address = await LocationService().getAddressFrom(pos)
          .timeout(const Duration(seconds: 6));
      
      return {
        'position': pos,
        'address': address,
      };
    } catch (e) {
      // 위치 조회 실패 시 빈 데이터 반환
      return {
        'position': null,
        'address': '',
      };
    }
  }
    /// [date]에 해당하는 브리핑을 생성하여 반환합니다.
  Future<String> getBriefingForDate(DateTime date) async {
    try {
      // 날짜 텍스트 (즉시 생성)
      final dateStr = DateFormat('yyyy년 MM월 dd일 EEEE', 'ko_KR').format(date);

      // 🚀 병렬 처리: 모든 비동기 작업을 동시에 시작
      final futures = await Future.wait([
        // 위치 정보 (타임아웃 적용)
        _getLocationWithTimeout(),
        // 일정 정보
        EventService().getEventsForDate(date),
        // 사용자 정보
        UserService().getCurrentUser(),
      ], eagerError: false);

      final locationData = futures[0] as Map<String, dynamic>;
      final allEvents = futures[1] as List<Event>;
      final user = futures[2] as UserProfile?;

      // 🚀 위치 기반 날씨 조회 (위치가 있을 때만)
      String weatherDesc = '';
      String temp = '';
      if (locationData['position'] != null) {
        try {
          final pos = locationData['position'];
          final weatherData = await WeatherService().fetchWeather(pos.latitude, pos.longitude)
              .timeout(const Duration(seconds: 5));
          if (weatherData != null) {
            weatherDesc = (weatherData['weather']?[0]?['description'] ?? '').toString();
            temp = (weatherData['main']?['temp'] ?? '').toString();
          }
        } catch (_) {
          // 날씨 조회 실패 시 무시
        }
      }

      // 현재 시간 기준 일정 필터링
      final now = DateTime.now();
      final upcomingEvents = allEvents.where((event) {
        final eventDate = DateTime(event.startTime.year, event.startTime.month, event.startTime.day);
        final targetDate = DateTime(date.year, date.month, date.day);
        
        if (eventDate.isAtSameMomentAs(targetDate)) {
          if (targetDate.isAtSameMomentAs(DateTime(now.year, now.month, now.day))) {
            return event.startTime.isAfter(now);
          } else {
            return true;
          }
        }
        return false;
      }).toList();
      
      final eventsBlock = PromptService().buildEventsBlock(upcomingEvents);

      // MBTI 스타일 가이드
      final mbti = user?.mbtiType ?? 'INFP';
      final mbtiStyle = await PromptService().getMbtiStyleBlock(mbti);

      final address = locationData['address'] as String;
      
      // 컨텍스트 프롬프트 빌드
      final contextPrompt = _buildContextPrompt(
        dateStr: dateStr,
        address: address,
        weatherDesc: weatherDesc,
        temp: temp,
        eventsBlock: eventsBlock,
        mbtiStyle: mbtiStyle,
      );
      
      // 시스템 프롬프트 생성 및 AI 요청
      try {
        final systemPrompt = await PromptService().createSystemPrompt(mbti);
        print('🤖 AI 브리핑 요청 시작... (MBTI: $mbti)');
        
        final response = await GeminiService().sendMessage(
          message: contextPrompt,
          systemPrompt: systemPrompt,
          functionDeclarations: [],
        ).timeout(const Duration(seconds: 20));
        
        final responseText = response.text;
        print('✅ AI 응답 수신: ${responseText?.substring(0, 50) ?? 'null'}...');
        
        if (responseText != null && responseText.isNotEmpty) {
          return responseText;
        } else {
          print('❌ AI 응답이 비어있음');
          return _generateFallbackBriefing(dateStr, address, weatherDesc, temp, upcomingEvents);
        }
      } catch (aiError) {
        print('❌ AI 요청 실패: $aiError');
        return _generateFallbackBriefing(dateStr, address, weatherDesc, temp, upcomingEvents);
      }
    } catch (e) {
      return '죄송합니다. $date에 대한 브리핑을 생성하는 중 오류가 발생했습니다: $e';
    }
  }

  String _buildContextPrompt({
    required String dateStr,
    required String address,
    required String weatherDesc,
    required String temp,
    required String eventsBlock,
    required String mbtiStyle,
  }) {
    final safeAddress = address.isNotEmpty ? address : '(확인 불가)';
    final safeWeather = weatherDesc.isNotEmpty ? weatherDesc : '(확인 불가)';
    final safeTemp = temp.isNotEmpty ? temp : '(확인 불가)';

    return '''
날짜: $dateStr
위치: $safeAddress
날씨: $safeWeather
기온(°C): $safeTemp
오늘 일정:
$eventsBlock
MBTI 스타일 가이드:
$mbtiStyle
- 출력: 총 180~220자, 각 줄 앞에 아이콘(🗓/👗/⚠️).
- 1) 🗓 브리핑: 위치, 현재 기온/날씨, 오늘 일정.
- 2) 👗 스타일: 날씨·일정 맞춤 의상 1세트와 휴대품 1개.
- 3) ⚠️ 주의·행동: 건강/이동 주의 1개 + '만약 Y면 Z한다' 형식의 일정 맞춤 행동 1개
     + 필요 시 시간 블로킹 힌트(알람/출발 시각).
- 톤: MBTI 가이드에 맞게 자연스럽게 반영.
- 규칙: 두괄식, 이모지 최대 3개, 과장·링크·자기언급·프롬프트 노출 금지,
     누락 입력은 추정하지 말고 생략.
'''.trim();
  }

  /// AI 요청 실패 시 사용할 fallback 브리핑 생성
  String _generateFallbackBriefing(
    String dateStr, 
    String address, 
    String weatherDesc, 
    String temp, 
    List<Event> events
  ) {
    final safeAddress = address.isNotEmpty ? address : '현재 위치';
    final safeWeather = weatherDesc.isNotEmpty ? weatherDesc : '날씨 정보 확인 불가';
    final safeTemp = temp.isNotEmpty ? '${temp}°C' : '온도 정보 확인 불가';
    
    String eventsText = '';
    if (events.isEmpty) {
      eventsText = '오늘은 특별한 일정이 없어요.';
    } else {
      final eventSummary = events.take(2).map((e) => 
        '${DateFormat('HH:mm').format(e.startTime)} ${e.title}'
      ).join(', ');
      eventsText = '오늘 일정: $eventSummary';
      if (events.length > 2) {
        eventsText += ' 외 ${events.length - 2}개';
      }
    }
    
    return '''
🗓 $dateStr
📍 $safeAddress에서 $safeWeather, $safeTemp입니다.
📅 $eventsText
💡 좋은 하루 되세요!
'''.trim();
  }
}

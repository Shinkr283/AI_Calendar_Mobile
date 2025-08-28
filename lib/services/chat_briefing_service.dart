import 'package:intl/intl.dart';
import 'event_service.dart';
import 'location_weather_service.dart';
import 'user_service.dart';
import 'chat_prompt_service.dart';
import 'chat_service.dart';

/// 특정 날짜에 대한 브리핑 텍스트를 생성합니다.
class BriefingService {
  
    /// [date]에 해당하는 브리핑을 생성하여 반환합니다.
  Future<String> getBriefingForDate(DateTime date) async {
    try {
      // 날짜 텍스트 (즉시 생성)
      final dateStr = DateFormat('yyyy년 MM월 dd일 EEEE', 'ko_KR').format(date);

      // 🚀 병렬 처리(개선): 위치 업데이트, 일정, 사용자 병렬 실행
      final locationWeather = LocationWeatherService();
      final eventsFuture = EventService().getEventsForDate(date);
      final userFuture = UserService().getCurrentUser();
      final locationFuture = locationWeather.updateAndSaveCurrentLocation();

      await Future.wait([
        locationFuture,
        eventsFuture,
        userFuture,
      ], eagerError: false);

      // final address = locationWeather.savedAddress ?? '';
      final allEvents = await eventsFuture;
      final user = await userFuture;

      // 🚀 위치 기반 날씨 조회 (위치가 있을 때만)
      String weatherDesc = '';
      String temp = '';
      try {
        print('🌤️ 날씨 정보 조회 시작...');
        if (locationWeather.hasSavedLocation) {
          print('📍 위치 좌표: ${locationWeather.latitude}, ${locationWeather.longitude}');
          final weatherData = await locationWeather.fetchWeatherFromSavedLocation();
          if (weatherData != null) {
            weatherDesc = (weatherData['weather']?[0]?['description'] ?? '').toString();
            temp = (weatherData['main']?['temp'] ?? '').toString();
          }
        } else {
          print('❌ 저장된 위치 정보 없음');
        }
      } catch (e) {
        print('❌ 날씨 조회 실패: $e');
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
      
      final eventsBlock = PromptService().buildEventsBlock(upcomingEvents, limit: 3);

      // MBTI 스타일/시스템 프롬프트 병렬 생성
      final mbti = user?.mbtiType ?? 'INFP';
      final promptResults = await Future.wait<String>([
        PromptService().getMbtiStyleBlock(mbti),
        Future.value(PromptService().createSystemPrompt(mbti)),
      ]);
      final mbtiStyle = promptResults[0];
      final systemPrompt = promptResults[1];

      // 컨텍스트 프롬프트 빌드
      final contextPrompt = _buildContextPrompt(
        dateStr: dateStr,
        // address: address,
        weatherDesc: weatherDesc,
        temp: temp,
        eventsBlock: eventsBlock,
        mbtiStyle: mbtiStyle,
      );
      
      // 시스템 프롬프트 생성 완료 후 AI 요청 (ChatService 경유)
      try {
        print('🤖 AI 브리핑 요청 시작... (MBTI: $mbti)');
        final responseText = await ChatService().generateText(
          systemPrompt: systemPrompt,
          message: contextPrompt,
        );
        if (responseText != null && responseText.isNotEmpty) {
          return responseText;
        }
        print('❌ AI 응답이 비어있음');
        return '죄송합니다. 브리핑을 생성할 수 없습니다.';
      } catch (aiError) {
        print('❌ AI 요청 실패: $aiError');
        return '죄송합니다. AI 요청에 실패했습니다.';
      }
    } catch (e) {
      return '죄송합니다. $date에 대한 브리핑을 생성하는 중 오류가 발생했습니다: $e';
    }
  }
  String _buildContextPrompt({
    required String dateStr,
    // required String address,
    required String weatherDesc,
    required String temp,
    required String eventsBlock,
    required String mbtiStyle,
  }) {
    // final safeAddress = address.isNotEmpty ? address : '(확인 불가)';
    final safeWeather = weatherDesc.isNotEmpty ? weatherDesc : '(확인 불가)';
    final safeTemp = temp.isNotEmpty ? temp : '(확인 불가)';

    return '''
// 날짜: $dateStr
// 기온: $safeTemp
// 날씨: $safeWeather
$eventsBlock
MBTI 스타일 가이드:
$mbtiStyle
- 출력: 총 180~220자, 각 줄 앞에 아이콘(🗓/👗/⚠️).
- 1) 🗓 브리핑: 오늘 일정의 시간과 장소.
- 2) 👗 스타일: 날씨·일정 맞춤 의상 1세트와 휴대품 1개.
- 3) ⚠️ 주의·행동: 건강/이동 주의 1개 + '만약 Y면 Z한다' 형식의 일정 맞춤 행동 1개
     + 필요 시 시간 블로킹 힌트(알람/출발 시각).
- 톤: MBTI 가이드에 맞게 자연스럽게 반영.
- 규칙: 두괄식, 이모지 최대 3개, 과장·링크·자기언급·프롬프트 노출 금지,
     누락 입력은 추정하지 말고 생략.
'''.trim();
  }
}


import 'package:intl/intl.dart';
import 'event_service.dart';
import 'location_weather_service.dart';
import 'chat_service.dart';

/// 특정 날짜에 대한 브리핑 텍스트를 생성합니다.
class BriefingService {
  
    /// [date]에 해당하는 브리핑을 생성하여 반환합니다.
  Future<String> getBriefingForDate(DateTime date) async {
    try {
      // 날짜 텍스트 (즉시 생성)
      final dateStr = DateFormat('yyyy년 MM월 dd일 EEEE', 'ko_KR').format(date);

      // 🚀 병렬 처리: 위치 업데이트, 일정 병렬 실행
      final locationWeather = LocationWeatherService();
      final eventsFuture = EventService().getEventsForDate(date);
      final locationFuture = locationWeather.updateAndSaveCurrentLocation();

      await Future.wait([
        locationFuture,
        eventsFuture,
      ], eagerError: false);
      
      final address = locationWeather.savedAddress ?? '';

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

      // 다가오는 일정 조회 (최대 3개)
      final upcomingEvents = await EventService().getUpcomingEvents(days: 1);
      final limitedEvents = upcomingEvents.take(3).toList();

      // 일정 블록 생성 (장소 정보 포함)
      final eventsBlock = limitedEvents.isEmpty 
          ? '오늘은 특별한 일정이 없습니다.' 
          : limitedEvents.map((event) => '🗓️ ${DateFormat('HH:mm').format(event.startTime)}-${DateFormat('HH:mm').format(event.endTime)} | 📍 ${event.location.isEmpty ? "위치 미확인" : event.location} | ${event.title}').join('\n');

      // 컨텍스트 프롬프트 빌드
      final contextPrompt = _buildContextPrompt(
        dateStr: dateStr,
        address: address,
        weatherDesc: weatherDesc,
        temp: temp,
        eventsBlock: eventsBlock,
      );
      
      // AI 요청 (ChatService 활용)
      final startTime = DateTime.now();
      try {
        print('🤖 AI 브리핑 요청 시작... (${DateFormat('HH:mm:ss').format(startTime)})');
        
        final responseText = await ChatService().generateText(
          systemPrompt: '',
          message: contextPrompt,
        );
        
        final endTime = DateTime.now();
        final duration = endTime.difference(startTime);
        print('✅ AI 브리핑 완성! (${DateFormat('HH:mm:ss').format(endTime)}) - 소요시간: ${duration.inSeconds}초');
        
        if (responseText != null && responseText.isNotEmpty) {
          return responseText;
        }
        print('❌ AI 응답이 비어있음');
        return '죄송합니다. 브리핑을 생성할 수 없습니다.';
      } catch (aiError) {
        final endTime = DateTime.now();
        final duration = endTime.difference(startTime);
        print('❌ AI 요청 실패: $aiError (소요시간: ${duration.inSeconds}초)');
        return '죄송합니다. AI 요청에 실패했습니다.';
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
  }) {
    final safeWeather = weatherDesc.isNotEmpty ? weatherDesc : '(확인 불가)';
    final safeTemp = temp.isNotEmpty ? temp : '(확인 불가)';

    return '''
// 날짜: $dateStr
// 주소: $address
// 기온: $safeTemp
// 날씨: $safeWeather
// 일정: $eventsBlock

- 출력: 총 180~220자, 각 줄 앞에 아이콘(🗓/👗/⚠️).
- 1) 🗓 브리핑: 오늘 일정의 시간과 장소에 맞는 추천.
- 2) 👗 스타일: 날씨·일정 맞춤 의상 1세트와 휴대품 1개.
- 3) ⚠️ 주의·행동: 건강/이동 주의 1개 + '만약 Y면 Z한다' 형식의 일정 맞춤 행동 1개
     + 필요 시 시간 블로킹 힌트(알람/출발 시각).
- 규칙: 두괄식, 이모지 최대 3개, 과장·링크·자기언급·프롬프트 노출 금지,
     누락 입력은 추정하지 말고 생략.
'''.trim();
  }
}


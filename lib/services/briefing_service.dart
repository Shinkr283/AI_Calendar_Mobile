import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'event_service.dart';
import 'location_service.dart';
import 'weather_service.dart';
import 'chat_prompt_service.dart';
import 'user_service.dart';

/// 특정 날짜에 대한 브리핑 텍스트를 생성합니다.
class BriefingService {
  /// [date]에 해당하는 브리핑을 생성하여 반환합니다.
  Future<String> getBriefingForDate(DateTime date) async {
    try {
      // 날짜 텍스트
      final dateStr = DateFormat('yyyy년 MM월 dd일 EEEE', 'ko_KR').format(date);

      // 현재 위치 및 날씨 조회
      Position? pos = await LocationService().getCurrentPosition();
      String address = '';
      String weatherDesc = '';
      String temp = '';
      if (pos != null) {
        address = await LocationService().getAddressFrom(pos);
        final weatherData = await WeatherService().fetchWeather(pos.latitude, pos.longitude);
        if (weatherData != null) {
          weatherDesc = (weatherData['weather']?[0]?['description'] ?? '').toString();
          temp = (weatherData['main']?['temp'] ?? '').toString();
        }
      }

      // 일정 조회
      final events = await EventService().getEventsForDate(date);
      final eventsBlock = PromptService().buildEventsBlock(events);

      // MBTI 스타일 가이드
      final user = await UserService().getCurrentUser();
      final mbti = user?.mbtiType ?? 'INFP';
      final mbtiStyle = await PromptService().getMbtiStyleBlock(mbti);

      // 컨텍스트 프롬프트 빌드
      final contextPrompt = await PromptService().buildContextPrompt(
        todayDate: dateStr,
        locLine: address,
        weatherDesc: weatherDesc,
        temp: temp,
        mbtiStyle: mbtiStyle,
        eventsBlock: eventsBlock,
      );

      return contextPrompt;
    } catch (e) {
      return '죄송합니다. $date에 대한 브리핑을 생성하는 중 오류가 발생했습니다: $e';
    }
  }
}

import 'package:intl/intl.dart';
import 'places_service.dart';
import 'weather_service.dart';

/// 사용자가 지정한 위치의 현재 날씨 정보를 조회합니다.
class LocationWeatherService {
  /// [locationQuery] 문자열에서 장소를 파싱해 날씨 정보를 가져와 한국어 문장으로 반환합니다.
  Future<String> getWeatherForLocation(String locationQuery) async {
    try {
      // 장소 좌표 조회
      final place = await PlacesService.geocodeAddress(locationQuery);
      if (place == null) {
        return '죄송합니다. "$locationQuery" 위치를 찾을 수 없습니다.';
      }

      final lat = place.latitude;
      final lon = place.longitude;
      final address = place.address;

      // 날씨 조회
      final weatherData = await WeatherService().fetchWeather(lat, lon);
      if (weatherData == null) {
        return '죄송합니다. "$address"의 날씨 정보를 가져올 수 없습니다.';
      }

      final desc = (weatherData['weather']?[0]?['description'] ?? '').toString();
      final temp = (weatherData['main']?['temp'] ?? '').toString();
      final feelsLike = (weatherData['main']?['feels_like'] ?? '').toString();
      final humidity = (weatherData['main']?['humidity'] ?? '').toString();

      // 현재 시간 정보
      final now = DateTime.now();
      final timeFmt = DateFormat('HH:mm', 'ko_KR').format(now);

      return '[$timeFmt] "$address"의 날씨 정보입니다.\n'
             '날씨: $desc\n'
             '기온: ${temp}°C (체감: ${feelsLike}°C)\n'
             '습도: ${humidity}%';
    } catch (e) {
      return '오류가 발생했습니다: $e';
    }
  }
}

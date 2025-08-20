import 'weather_service.dart';
import 'location_service.dart';
import 'chat_gemini_service.dart';

class WeatherChatService {
  static final WeatherChatService _instance = WeatherChatService._internal();
  factory WeatherChatService() => _instance;
  WeatherChatService._internal();

  static const Map<String, dynamic> getCurrentLocationWeatherFunction = {
    'name': 'getCurrentLocationWeather',
    'description': '현재 기기의 위치를 사용해 현재 날씨를 조회합니다.',
    'parameters': {
      'type': 'object',
      'properties': {}
    }
  };

  // 필요한 경우 확장 가능한 함수 목록
  static List<Map<String, dynamic>> get functions => [
    getCurrentLocationWeatherFunction,
  ];

  Future<Map<String, dynamic>> handleFunctionCall(GeminiFunctionCall call) async {
    switch (call.name) {
      case 'getCurrentLocationWeather':
        return await _handleGetCurrentLocationWeather();
      default:
        return {'status': '오류: 알 수 없는 날씨 함수입니다.'};
    }
  }

  Future<Map<String, dynamic>> _handleGetCurrentLocationWeather() async {
    try {
      final loc = LocationService();
      final pos = await loc.getCurrentPosition();
      final weather = await WeatherService().fetchWeather(pos.latitude, pos.longitude);
      if (weather == null) {
        return {'status': '오류: 날씨 정보를 가져오지 못했습니다.'};
      }
      final desc = (weather['weather']?[0]?['description'] ?? '').toString();
      final temp = (weather['main']?['temp'] ?? '').toString();
      return {
        'status': '현재 위치의 날씨를 가져왔습니다.',
        'description': desc,
        'temperatureC': temp,
        'city': weather['name'] ?? '',
      };
    } catch (e) {
      return {'status': '오류: 현재 위치의 날씨를 가져오는 중 문제가 발생했습니다: $e'};
    }
  }
}



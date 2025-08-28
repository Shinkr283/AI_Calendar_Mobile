import 'location_weather_service.dart';
import 'package:intl/intl.dart';
import 'event_service.dart';
import 'places_service.dart';
import 'chat_gemini_service.dart';

class ChatWeatherService {
  static final ChatWeatherService _instance = ChatWeatherService._internal();
  factory ChatWeatherService() => _instance;
  ChatWeatherService._internal();

  static const Map<String, dynamic> getCurrentLocationWeatherFunction = {
    'name': 'getCurrentLocationWeather',
    'description': '현재 기기의 위치를 사용해 현재 날씨를 조회합니다.',
    'parameters': {
      'type': 'object',
      'properties': {}
    }
  };

  // 필요한 경우 확장 가능한 함수 목록
  static const Map<String, dynamic> getWeatherByDateFunction = {
    'name': 'getWeatherByDate',
    'description': '특정 날짜의 현재 위치 기반 날씨를 조회합니다.',
    'parameters': {
      'type': 'object',
      'properties': {
        'date': { 'type': 'string', 'description': '조회할 날짜 (YYYY-MM-DD)' }
      },
      'required': ['date']
    }
  };
  static List<Map<String, dynamic>> get functions => [
    getCurrentLocationWeatherFunction,
    getWeatherByDateFunction,
    {
      'name': 'getWeatherForTodayEvent',
      'description': '오늘 일정 첫 이벤트 위치 기반 날씨를 조회합니다.',
      'parameters': { 'type': 'object', 'properties': {} }
    },
  ];

  Future<Map<String, dynamic>> handleFunctionCall(GeminiFunctionCall call) async {
    switch (call.name) {
      case 'getCurrentLocationWeather':
        return await _handleGetCurrentLocationWeather();
      case 'getWeatherByDate':
        return await _handleGetWeatherByDate(call.args);
      case 'getWeatherForTodayEvent':
        return await _handleGetWeatherForTodayEvent();
      default:
        return {'status': '오류: 알 수 없는 날씨 함수입니다.'};
    }
  }

  Future<Map<String, dynamic>> _handleGetCurrentLocationWeather() async {
    try {
      // 위치정보와 날씨정보는 LocationWeatherService에서 통합 처리
      final locationWeatherService = LocationWeatherService();
      final weather = await locationWeatherService.fetchAndSaveLocationWeather();
      
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
  
  /// 오늘 일정 첫 이벤트 위치 기반 현재 날씨 조회
  Future<Map<String, dynamic>> _handleGetWeatherForTodayEvent() async {
    final events = await EventService().getTodayEvents();
    if (events.isEmpty) {
      return {'status': '오늘 일정이 없어 날씨 정보를 제공할 수 없습니다.'};
    }
    final locationQuery = events.first.location;
    if (locationQuery.isEmpty) {
      return {'status': '오늘 일정에 위치 정보가 없습니다.'};
    }
    // geocode + weather
    final place = await PlacesService.geocodeAddress(locationQuery);
    if (place == null) {
      return {'status': '위치 정보를 변환할 수 없습니다.'};
    }
    final locationWeatherService = LocationWeatherService();
    final weather = await locationWeatherService.fetchWeather(place.latitude, place.longitude);
    if (weather == null) {
      return {'status': '날씨 정보를 가져오지 못했습니다.'};
    }
    final desc = (weather['weather']?[0]?['description'] ?? '').toString();
    final temp = (weather['main']?['temp'] ?? '').toString();
    final nowFmt = DateFormat('HH:mm', 'ko_KR').format(DateTime.now());
    return {'status': '[$nowFmt] ${events.first.location}의 날씨: $desc, 기온: ${temp}°C'};
  }
  
  Future<Map<String, dynamic>> _handleGetWeatherByDate(Map<String, dynamic> args) async {
    try {
      final dateStr = args['date'] as String;
      
      // 위치정보와 날씨정보는 LocationWeatherService에서 통합 처리
      final locationWeatherService = LocationWeatherService();
      final weather = await locationWeatherService.fetchAndSaveLocationWeather();
      
      if (weather == null) {
        return {'status': '오류: 날씨 정보를 가져오지 못했습니다.', 'date': dateStr};
      }
      
      final desc = (weather['weather']?[0]?['description'] ?? '').toString();
      final temp = (weather['main']?['temp'] ?? '').toString();
      return {
        'date': dateStr,
        'status': '날짜 $dateStr 의 현재 위치 날씨를 가져왔습니다.',
        'description': desc,
        'temperatureC': temp,
        'city': weather['name'] ?? '',
      };
    } catch (e) {
      return {'status': '오류: 날짜별 날씨 조회 중 문제가 발생했습니다: $e'};
    }
  }
}



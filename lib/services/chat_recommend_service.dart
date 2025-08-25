import 'event_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'chat_gemini_service.dart';
import '../config/api_keys.dart';

/// 챗봇이 일정 위치 기반으로 주변 맛집을 추천합니다.
class ChatRecommendService {
  static final ChatRecommendService _instance = ChatRecommendService._internal();
  factory ChatRecommendService() => _instance;
  ChatRecommendService._internal();

  static const Map<String, dynamic> getNearbyRestaurantsFunction = {
    'name': 'getNearbyRestaurants',
    'description': '특정 장소(이벤트 위치) 주변의 맛집을 추천합니다.',
    'parameters': {
      'type': 'object',
      'properties': {
        'location': { 'type': 'string', 'description': '위치(주소 또는 장소명)' }
      },
      'required': ['location']
    }
  };

  static List<Map<String, dynamic>> get functions => [getNearbyRestaurantsFunction];

  Future<Map<String, dynamic>> handleFunctionCall(GeminiFunctionCall call) async {
    switch (call.name) {
      case 'getNearbyRestaurants':
        return await _handleGetNearbyRestaurants(call.args);
      default:
        return {'status': '오류: 알 수 없는 추천 함수입니다.'};
    }
  }

  /// 내부: 주소를 좌표로 변환
  Future<Map<String, dynamic>?> _geocodeAddress(String address) async {
    final url = Uri.parse('https://maps.googleapis.com/maps/api/geocode/json'
        '?address=${Uri.encodeComponent(address)}&key=${ApiKeys.googlePlacesApiKey}&language=ko');
    final resp = await http.get(url);
    if (resp.statusCode != 200) return null;
    final data = json.decode(resp.body);
    if (data['status'] != 'OK' || (data['results'] as List).isEmpty) return null;
    return data['results'][0] as Map<String, dynamic>;
  }

  /// 내부: 주변 맛집 검색 (Nearby Search)
  Future<List<Map<String, dynamic>>> _searchNearbyRestaurants(
    double lat,
    double lng, {
    int radius = 500,
    int maxResults = 5,
    String? keyword,
  }) async {
    final url = Uri.parse('https://places.googleapis.com/v1/places:searchNearby');
    final bodyMap = {
      'includedTypes': ['restaurant'],
      'locationRestriction': {
        'circle': {
          'center': {'latitude': lat, 'longitude': lng},
          'radius': radius.toDouble(),
        }
      },
      'maxResultCount': maxResults,
    };
    if (keyword != null && keyword.isNotEmpty) bodyMap['keyword'] = keyword;
    final resp = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': ApiKeys.googlePlacesApiKey,
        'X-Goog-FieldMask': 'places.displayName,places.formattedAddress',
      },
      body: json.encode(bodyMap),
    );
    if (resp.statusCode != 200) return [];
    final data = json.decode(resp.body);
    return (data['places'] as List).take(maxResults).map((p) {
      final name = p['displayName']?['text'] ?? '';
      final address = p['formattedAddress'] ?? '';
      return {'name': name, 'address': address};
    }).toList();
  }

  Future<Map<String, dynamic>> _handleGetNearbyRestaurants(Map<String, dynamic> args) async {
    final location = args['location'] as String?;
    if (location == null || location.isEmpty) {
      return {'status': '위치 정보가 제공되지 않았습니다.'};
    }
    final geo = await _geocodeAddress(location);
    if (geo == null) return {'status': '주소를 좌표로 변환할 수 없습니다.'};
    final lat = (geo['geometry']?['location']?['lat'] as num).toDouble();
    final lng = (geo['geometry']?['location']?['lng'] as num).toDouble();
    final restaurants = await _searchNearbyRestaurants(lat, lng, radius: 500, maxResults: 5);
    return {
      'status': '${restaurants.length}개의 맛집을 찾았습니다.',
      'restaurants': restaurants,
    };
  }

  /// 오늘 일정 위치 기반으로 맛집 추천 (로컬 헬퍼)
  Future<String> recommendBasedOnTodayEvent() async {
    final events = await EventService().getTodayEvents();
    String loc = '';
    if (events.isNotEmpty) loc = events.first.location;
    if (loc.isEmpty) {
      return '일정에 위치 정보가 없어 맛집 추천이 어렵습니다. 일정을 먼저 등록해 주세요.';
    }
    final functionCall = GeminiFunctionCall(name: 'getNearbyRestaurants', args: {'location': loc});
    final result = await handleFunctionCall(functionCall);
    final restaurants = result['restaurants'] as List<dynamic>? ?? [];
    final lines = restaurants.map((r) => '- ${r['name']} (${r['address']})').join('\n');
    return '${result['status']}\n$lines';
  }
}
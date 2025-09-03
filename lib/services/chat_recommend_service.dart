import 'event_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'chat_gemini_service.dart';
import '../config/api_keys.dart';
import 'location_weather_service.dart';

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
        '?address=${Uri.encodeComponent(address)}&key=${ApiKeys.googlePlacesApiKey}&language=ko&region=kr');
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
    
    try {
      final resp = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': ApiKeys.googlePlacesApiKey,
          'X-Goog-FieldMask': 'places.displayName,places.formattedAddress,places.types,places.rating,places.userRatingCount',
          'Accept-Language': 'ko-KR', // 헤더에 한글 언어 설정 추가
        },
        body: json.encode(bodyMap),
      );
      
      if (resp.statusCode != 200) {
        print('❌ Places API 호출 실패: ${resp.statusCode}');
        return [];
      }
      
      final data = json.decode(resp.body);
      print('🔍 Places API 응답: $data');
      
      if (data['places'] == null) {
        print('❌ places 데이터가 없습니다.');
        return [];
      }
      
      final places = data['places'] as List;
      
      return places.take(maxResults).map((p) {
        // displayName에서 한글 이름 우선 선택
        String name = '알 수 없는 맛집';
        if (p['displayName'] != null) {
          final displayName = p['displayName'];
          if (displayName['text'] != null) {
            name = displayName['text'];
          }
        }
        
        final address = p['formattedAddress'] ?? '주소 정보 없음';
        final rating = p['rating']?.toString() ?? '';
        final userRatingCount = p['userRatingCount']?.toString() ?? '';
        
        return {
          'name': name,
          'address': address,
          'rating': rating,
          'userRatingCount': userRatingCount,
        };
      }).toList();
    } catch (e) {
      print('❌ 맛집 검색 중 오류: $e');
      return [];
    }
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

  /// 현재 위치 기반으로 맛집 추천 (LocationWidget용)
  Future<String> recommendBasedOnCurrentLocation(String currentAddress) async {
    if (currentAddress.isEmpty || currentAddress == '위치 정보 없음') {
      return '현재 위치 정보가 없어 맛집 추천이 어렵습니다.';
    }
    
    final functionCall = GeminiFunctionCall(name: 'getNearbyRestaurants', args: {'location': currentAddress});
    final result = await handleFunctionCall(functionCall);
    final restaurants = result['restaurants'] as List<dynamic>? ?? [];
    
    if (restaurants.isEmpty) {
      return '주변에 맛집을 찾을 수 없습니다.';
    }
    
    final lines = restaurants.map((r) => '- ${r['name']} (${r['address']})').join('\n');
    return '${result['status']}\n$lines';
  }

  /// 현재 위치 기반으로 맛집 추천 (상세 정보 포함)
  Future<Map<String, dynamic>> getDetailedRestaurantRecommendations(String currentAddress) async {
    if (currentAddress.isEmpty || currentAddress == '위치 정보 없음') {
      return {
        'success': false,
        'message': '현재 위치 정보가 없어 맛집 추천이 어렵습니다.',
        'restaurants': []
      };
    }
    
    try {
      final functionCall = GeminiFunctionCall(name: 'getNearbyRestaurants', args: {'location': currentAddress});
      final result = await handleFunctionCall(functionCall);
      final restaurants = result['restaurants'] as List<dynamic>? ?? [];
      
      if (restaurants.isEmpty) {
        return {
          'success': false,
          'message': '주변에 맛집을 찾을 수 없습니다.',
          'restaurants': []
        };
      }
      
      // 맛집 정보를 더 자세하게 가공
      final detailedRestaurants = restaurants.map((r) {
        final name = r['name'] as String? ?? '';
        final address = r['address'] as String? ?? '';
        final rating = r['rating'] as String? ?? '';
        final userRatingCount = r['userRatingCount'] as String? ?? '';
        
        // 맛집 이름에서 맛 정보 추출 (간단한 키워드 매칭)
        String taste = _extractTasteFromName(name);
        
        return {
          'name': name,
          'address': address,
          'taste': taste,
          'rating': rating,
          'userRatingCount': userRatingCount,
          'description': '$name - $taste 입니다. 주소: $address'
        };
      }).toList();
      
      return {
        'success': true,
        'message': '${restaurants.length}개의 맛집을 찾았습니다.',
        'restaurants': detailedRestaurants
      };
    } catch (e) {
      return {
        'success': false,
        'message': '맛집 추천 중 오류가 발생했습니다: $e',
        'restaurants': []
      };
    }
  }

  /// 맛집 이름에서 맛 정보 추출
  String _extractTasteFromName(String name) {
    final lowerName = name.toLowerCase();
    
    // 한식 관련 키워드
    if (lowerName.contains('한식') || lowerName.contains('한정식') || lowerName.contains('국밥') || 
        lowerName.contains('갈비') || lowerName.contains('삼겹살') || lowerName.contains('닭갈비')) {
      return '한식';
    }
    
    // 중식 관련 키워드
    if (lowerName.contains('중식') || lowerName.contains('짜장면') || lowerName.contains('탕수육') || 
        lowerName.contains('마라탕') || lowerName.contains('훠궈') || lowerName.contains('딤섬')) {
      return '중식';
    }
    
    // 일식 관련 키워드
    if (lowerName.contains('일식') || lowerName.contains('스시') || lowerName.contains('라멘') || 
        lowerName.contains('우동') || lowerName.contains('돈부리') || lowerName.contains('가츠동')) {
      return '일식';
    }
    
    // 양식 관련 키워드
    if (lowerName.contains('양식') || lowerName.contains('파스타') || lowerName.contains('피자') || 
        lowerName.contains('스테이크') || lowerName.contains('버거') || lowerName.contains('샌드위치')) {
      return '양식';
    }
    
    // 카페/디저트 관련 키워드
    if (lowerName.contains('카페') || lowerName.contains('커피') || lowerName.contains('베이커리') || 
        lowerName.contains('디저트') || lowerName.contains('아이스크림') || lowerName.contains('케이크')) {
      return '카페/디저트';
    }
    
    // 치킨/패스트푸드 관련 키워드
    if (lowerName.contains('치킨') || lowerName.contains('피자') || lowerName.contains('햄버거') || 
        lowerName.contains('도넛') || lowerName.contains('샌드위치')) {
      return '패스트푸드';
    }
    
    // 기본값
    return '';
  }

  /// 맛집 추천 요청 처리 (ChatService에서 호출)
  Future<String> handleRestaurantRecommendationRequest(String userMessage) async {
    // 맛집 추천 요청인지 확인
    if (!_isRestaurantRecommendationRequest(userMessage)) {
      return '맛집 추천을 원하시면 "맛집 추천해줘", "주변 식당 어디있어?" 등으로 말씀해주세요.';
    }
    
    try {
      // 현재 위치 정보 가져오기
      final locationService = LocationWeatherService();
      await locationService.updateAndSaveCurrentLocation();
      
      String? currentAddress = locationService.savedAddress;
      if (currentAddress == null || currentAddress.isEmpty) {
        // 주소 변환이 비동기로 처리되므로 잠시 대기
        await Future.delayed(const Duration(seconds: 2));
        currentAddress = locationService.savedAddress;
      }
      
      if (currentAddress == null || currentAddress.isEmpty) {
        return '현재 위치 정보를 가져올 수 없어 맛집 추천이 어렵습니다. 위치 권한을 확인해주세요.';
      }
      
      // 현재 위치 기반으로 맛집 추천
      final result = await getDetailedRestaurantRecommendations(currentAddress);
      
      if (result['success']) {
        final restaurants = result['restaurants'] as List<dynamic>;
        return _formatRestaurantRecommendationForChat(result['message'], restaurants);
      } else {
        return result['message'];
      }
    } catch (e) {
      return '맛집 추천을 가져오는 중 오류가 발생했습니다: $e';
    }
  }

  /// 맛집 추천 요청인지 확인
  bool _isRestaurantRecommendationRequest(String message) {
    final lowerMessage = message.toLowerCase();
    final keywords = [
      '맛집', '식당', '음식점', '밥', '점심', '저녁', '아침', '카페',
      '추천', '어디', '주변', '근처', '가까운', '좋은', '맛있는'
    ];
    
    return keywords.any((keyword) => lowerMessage.contains(keyword));
  }

  /// 채팅용 맛집 추천 결과 포맷팅
  String _formatRestaurantRecommendationForChat(String status, List<dynamic> restaurants) {
    final buffer = StringBuffer();
    buffer.writeln(status);
    buffer.writeln();
    
    for (int i = 0; i < restaurants.length; i++) {
      final restaurant = restaurants[i];
      final name = restaurant['name'] as String? ?? '';
      final taste = restaurant['taste'] as String? ?? '';
      final address = restaurant['address'] as String? ?? '';
      final rating = restaurant['rating'] as String? ?? '';
      final userRatingCount = restaurant['userRatingCount'] as String? ?? '';
      
      buffer.writeln('${i + 1}. 🍽️ $name');
      if (taste.isNotEmpty) {
        buffer.writeln('   🎯 $taste 맛집');
      }
      if (rating.isNotEmpty) {
        buffer.writeln('   ⭐ 평점: $rating (리뷰 $userRatingCount개)');
      }
      buffer.writeln('   📍 $address');
      if (i < restaurants.length - 1) buffer.writeln();
    }
    
    return buffer.toString();
  }
}
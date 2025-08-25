import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_keys.dart';

class PlaceDetails {
  final String placeId;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final String? phoneNumber;
  final String? website;
  final double? rating;
  final List<String> types;

  PlaceDetails({
    required this.placeId,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.phoneNumber,
    this.website,
    this.rating,
    required this.types,
  });

  factory PlaceDetails.fromJson(Map<String, dynamic> json) {
    final geometry = json['geometry']?['location'];
    return PlaceDetails(
      placeId: json['place_id'] ?? '',
      name: json['name'] ?? '',
      address: json['formatted_address'] ?? '',
      latitude: geometry?['lat']?.toDouble() ?? 0.0,
      longitude: geometry?['lng']?.toDouble() ?? 0.0,
      phoneNumber: json['formatted_phone_number'],
      website: json['website'],
      rating: json['rating']?.toDouble(),
      types: List<String>.from(json['types'] ?? []),
    );
  }
}

class PlaceSuggestion {
  final String placeId;
  final String description;
  final String mainText;
  final String secondaryText;

  PlaceSuggestion({
    required this.placeId,
    required this.description,
    required this.mainText,
    required this.secondaryText,
  });

  factory PlaceSuggestion.fromJson(Map<String, dynamic> json) {
    final structuredFormatting = json['structured_formatting'];
    return PlaceSuggestion(
      placeId: json['place_id'] ?? '',
      description: json['description'] ?? '',
      mainText: structuredFormatting?['main_text'] ?? '',
      secondaryText: structuredFormatting?['secondary_text'] ?? '',
    );
  }
}

class PlacesService {
  static const String _baseUrl = 'https://maps.googleapis.com/maps/api';
  
  // API 키는 api_keys.dart 파일에서 가져옵니다
  static const String _apiKey = ApiKeys.googlePlacesApiKey;

  /// 네트워크 연결 테스트
  static Future<bool> testConnection() async {
    try {
      final response = await http.get(Uri.parse('https://www.google.com'));
      print('🌐 네트워크 테스트: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      print('❌ 네트워크 오류: $e');
      return false;
    }
  }

  /// 장소 자동완성 검색
  static Future<List<PlaceSuggestion>> searchPlaces(String query) async {
    if (query.isEmpty) return [];

    // 네트워크 연결 테스트
    final isConnected = await testConnection();
    if (!isConnected) {
      print('❌ 네트워크 연결 실패');
      return [];
    }

    try {
      final url = Uri.parse(
        '$_baseUrl/place/autocomplete/json'
        '?input=${Uri.encodeComponent(query)}'
        '&key=$_apiKey'
        '&language=ko'
        '&inputtype=textquery', // 텍스트 쿼리로 명시
      );

      print('🔍 장소 검색 URL: $url');
      print('🔍 검색어: $query');

      final response = await http.get(url);
      print('🔍 응답 상태코드: ${response.statusCode}');
      print('🔍 응답 내용: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('🔍 API 상태: ${data['status']}');
        
        if (data['status'] == 'OK') {
          final predictions = data['predictions'] as List;
          print('🔍 검색 결과 개수: ${predictions.length}');
          
          final suggestions = predictions
              .map((pred) => PlaceSuggestion.fromJson(pred))
              .toList();
          
          print('🔄 변환된 suggestion 개수: ${suggestions.length}');
          for (int i = 0; i < suggestions.length && i < 3; i++) {
            print('   ${i+1}. ${suggestions[i].mainText} - ${suggestions[i].secondaryText}');
          }
          
          return suggestions;
        } else {
          print('❌ API 오류: ${data['status']} - ${data['error_message'] ?? '알 수 없는 오류'}');
          
          // Places API 실패 시 Geocoding API로 대체 시도
          print('🔄 Geocoding API로 대체 검색 시도...');
          return await _fallbackGeocodeSearch(query);
        }
      }
      return [];
    } catch (e) {
      print('❌ 장소 검색 오류: $e');
      // 예외 발생 시에도 대체 검색 시도
      return await _fallbackGeocodeSearch(query);
    }
  }

  /// Geocoding API를 사용한 대체 검색
  static Future<List<PlaceSuggestion>> _fallbackGeocodeSearch(String query) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/geocode/json'
        '?address=${Uri.encodeComponent(query)}'
        '&key=$_apiKey'
        '&language=ko',
      );

      print('🔄 대체 검색 URL: $url');
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && data['results'] != null) {
          final results = data['results'] as List;
          print('🔄 대체 검색 결과: ${results.length}개');
          
          return results.take(5).map((result) => PlaceSuggestion(
            placeId: result['place_id'] ?? '',
            description: result['formatted_address'] ?? query,
            mainText: query,
            secondaryText: result['formatted_address'] ?? '',
          )).toList();
        }
      }
      return [];
    } catch (e) {
      print('❌ 대체 검색 오류: $e');
      return [];
    }
  }

  /// 장소 상세 정보 가져오기
  static Future<PlaceDetails?> getPlaceDetails(String placeId) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/place/details/json'
        '?place_id=$placeId'
        '&key=$_apiKey'
        '&language=ko'
        '&fields=place_id,name,formatted_address,geometry,formatted_phone_number,website,rating,types',
      );

      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          return PlaceDetails.fromJson(data['result']);
        }
      }
      return null;
    } catch (e) {
      print('장소 상세정보 조회 오류: $e');
      return null;
    }
  }

  /// 주소를 기반으로 좌표 검색 (Geocoding)
  static Future<PlaceDetails?> geocodeAddress(String address) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/geocode/json'
        '?address=${Uri.encodeComponent(address)}'
        '&key=$_apiKey'
        '&language=ko',
      );

      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          final result = data['results'][0];
          final geometry = result['geometry']['location'];
          
          return PlaceDetails(
            placeId: result['place_id'] ?? '',
            name: result['formatted_address'] ?? '',
            address: result['formatted_address'] ?? '',
            latitude: geometry['lat']?.toDouble() ?? 0.0,
            longitude: geometry['lng']?.toDouble() ?? 0.0,
            types: List<String>.from(result['types'] ?? []),
          );
        }
      }
      return null;
    } catch (e) {
      print('주소 검색 오류: $e');
      return null;
    }
  }

  // 역방향 지오코딩 기능 제거됨 (지도 터치 시 장소 정보 표시 기능 제거)

  // 랜드마크 검색 기능 제거됨

  // 정확한 건물 검색 기능 제거됨

  // Nearby POI 검색 기능 제거됨

  /// 🔍 오프라인 모드용 간단한 장소 검색 (API 키 없이 사용)
  static Future<List<PlaceSuggestion>> searchPlacesOffline(String query) async {
    // 오프라인 모드 제거 - 빈 리스트 반환
    return [];
  }
}

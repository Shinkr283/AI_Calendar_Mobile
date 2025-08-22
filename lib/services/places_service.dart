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

  /// 🗺️ 좌표를 기반으로 주소 검색 (Reverse Geocoding) - 랜드마크 우선
  static Future<PlaceDetails?> reverseGeocode(double latitude, double longitude) async {
    try {
      // 🎯 1단계: 대형 반경(50미터)으로 유명 랜드마크 우선 검색
      final landmarkPlace = await _findLandmark(latitude, longitude);
      if (landmarkPlace != null) {
        print('🏛️ 랜드마크 검색 성공: ${landmarkPlace.name}');
        return landmarkPlace;
      }

      // 🔍 2단계: 10미터 반경 일반 POI 검색
      final nearbyPlace = await _findNearbyPOI(latitude, longitude);
      if (nearbyPlace != null) {
        print('🔍 근처 건물 검색 성공: ${nearbyPlace.name}');
        return nearbyPlace;
      }

      // 🌐 3단계: 일반 역지오코딩으로 주소 찾기
      final url = Uri.parse(
        '$_baseUrl/geocode/json'
        '?latlng=$latitude,$longitude'
        '&key=$_apiKey'
        '&language=ko',
      );

      print('🔄 역지오코딩 URL: $url');
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('🔄 역지오코딩 응답: ${data['status']}');
        
        if (data['status'] == 'OK' && data['results'] != null && data['results'].isNotEmpty) {
          // 🏗️ establishment, POI, premise 우선 찾기
          PlaceDetails? bestPlace;
          
          for (var result in data['results']) {
            final types = List<String>.from(result['types'] ?? []);
            final geometry = result['geometry']['location'];
            
            // 건물/POI 타입이면 우선 선택
            if (types.any((type) => [
              'establishment', 
              'point_of_interest', 
              'premise',
              'store',
              'restaurant',
              'bank',
              'gas_station',
              'hospital'
            ].contains(type))) {
              
              String placeName = result['formatted_address'] ?? '';
              
              // 주소 구성요소에서 건물명 찾기
              if (result['address_components'] != null) {
                for (var component in result['address_components']) {
                  final componentTypes = List<String>.from(component['types'] ?? []);
                  final componentName = component['long_name'] ?? '';
                  
                  // 🚫 숫자만 있는 이름은 건물명으로 사용하지 않음
                  if (RegExp(r'^\d+$').hasMatch(componentName)) {
                    continue;
                  }
                  
                  if (componentTypes.contains('establishment') || 
                      componentTypes.contains('point_of_interest') ||
                      componentTypes.contains('premise')) {
                    placeName = component['long_name'] ?? placeName;
                    break;
                  }
                }
              }
              
              // 🚫 숫자/주소 형식 이름은 사용하지 않음
              if (!RegExp(r'^\d+$').hasMatch(placeName) && 
                  !RegExp(r'^\d+-\d+$').hasMatch(placeName) && // "150-19" 형식 제외
                  !RegExp(r'^[0-9\-]+$').hasMatch(placeName) && // 숫자-하이픈 조합 제외
                  !placeName.contains('대한민국') &&
                  !placeName.contains('서울특별시') &&
                  !placeName.contains('번지') &&
                  placeName.length > 2) {
                bestPlace = PlaceDetails(
                  placeId: result['place_id'] ?? '',
                  name: placeName,
                  address: result['formatted_address'] ?? '',
                  latitude: geometry['lat']?.toDouble() ?? latitude,
                  longitude: geometry['lng']?.toDouble() ?? longitude,
                  types: types,
                );
                break; // 첫 번째 유효한 건물/POI를 찾으면 바로 사용
              }
            }
          }
          
          // 건물/POI를 찾지 못했다면 첫 번째 결과 사용
          if (bestPlace == null && data['results'].isNotEmpty) {
            final result = data['results'][0];
            final geometry = result['geometry']['location'];
            
            bestPlace = PlaceDetails(
              placeId: result['place_id'] ?? '',
              name: result['formatted_address'] ?? '',
              address: result['formatted_address'] ?? '',
              latitude: geometry['lat']?.toDouble() ?? latitude,
              longitude: geometry['lng']?.toDouble() ?? longitude,
              types: List<String>.from(result['types'] ?? []),
            );
          }
          
          if (bestPlace != null) {
            print('✅ 역지오코딩 성공: ${bestPlace.name}');
            return bestPlace;
          }
        } else {
          print('❌ 역지오코딩 실패: ${data['status']} - ${data['error_message'] ?? '알 수 없는 오류'}');
          return null;
        }
      }
      return null;
    } catch (e) {
      print('❌ 역지오코딩 오류: $e');
      return null;
    }
  }

  /// 🏛️ 랜드마크 검색 - 유명한 관광지/랜드마크 우선 찾기
  static Future<PlaceDetails?> _findLandmark(double latitude, double longitude) async {
    try {
      // 큰 반경(50미터)으로 랜드마크 검색
      final url = Uri.parse(
        '$_baseUrl/place/nearbysearch/json'
        '?location=$latitude,$longitude'
        '&radius=50' // 50미터 반경으로 랜드마크 검색
        '&type=tourist_attraction|amusement_park|museum|park|university|subway_station'
        '&key=$_apiKey'
        '&language=ko',
      );

      print('🏛️ 랜드마크 검색 URL: $url');
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('🏛️ 랜드마크 검색 응답: ${data['status']}');
        
        if (data['status'] == 'OK' && data['results'] != null && data['results'].isNotEmpty) {
          for (var result in data['results']) {
            final name = result['name'] ?? '';
            final types = List<String>.from(result['types'] ?? []);
            
            // 🏛️ 유명 랜드마크인지 확인
            bool isLandmark = name.isNotEmpty && 
                            !RegExp(r'^\d+$').hasMatch(name) && 
                            !RegExp(r'^\d+-\d+$').hasMatch(name) && 
                            !RegExp(r'^[0-9\-]+$').hasMatch(name) &&
                            (name.contains('거리') || name.contains('공원') || 
                             name.contains('역') || name.contains('대학') ||
                             name.contains('시장') || name.contains('기념관') ||
                             name.contains('궁') || name.contains('타워') ||
                             name.contains('월드') || name.contains('랜드') ||
                             types.contains('tourist_attraction') ||
                             types.contains('amusement_park') ||
                             types.contains('museum') ||
                             types.contains('park') ||
                             types.contains('university') ||
                             types.contains('subway_station'));
            
            if (isLandmark) {
              final geometry = result['geometry']['location'];
              
              final place = PlaceDetails(
                placeId: result['place_id'] ?? '',
                name: name,
                address: result['vicinity'] ?? result['formatted_address'] ?? '',
                latitude: geometry['lat']?.toDouble() ?? latitude,
                longitude: geometry['lng']?.toDouble() ?? longitude,
                types: types,
                rating: result['rating']?.toDouble(),
              );
              
              print('🏛️ 랜드마크 발견: $name');
              return place;
            }
          }
        }
      }
      return null;
    } catch (e) {
      print('❌ 랜드마크 검색 실패: $e');
      return null;
    }
  }

  /// 🎯 정확한 건물 검색 - 클릭한 위치의 실제 건물 찾기  
  static Future<PlaceDetails?> _findExactPOI(double latitude, double longitude) async {
    try {
      // 매우 정밀한 검색 (1미터 반경)
      final url = Uri.parse(
        '$_baseUrl/place/nearbysearch/json'
        '?location=$latitude,$longitude'
        '&radius=1' // 1미터 초정밀 
        '&key=$_apiKey'
        '&language=ko',
      );

      print('🎯 초정밀 건물 검색 URL: $url');
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('🎯 초정밀 건물 검색 응답: ${data['status']}');
        
        if (data['status'] == 'OK' && data['results'] != null && data['results'].isNotEmpty) {
          // 🏗️ 가장 가까운 실제 건물/상점만 선택
          for (var result in data['results']) {
            final name = result['name'] ?? '';
            final types = List<String>.from(result['types'] ?? []);
            
            // 🏗️ 실제 랜드마크/건물인지 확인 (숫자 주소, 행정구역, 도로명 제외)
            bool isRealPlace = name.isNotEmpty && 
                              name != '인천광역시' && 
                              name != '중구' && 
                              name != '서울특별시' &&
                              name != '강남구' &&
                              !name.contains('동') &&
                              !name.contains('시') &&
                              !name.contains('구') &&
                              !name.contains('로') &&
                              !name.contains('길') &&
                              !RegExp(r'^\d+$').hasMatch(name) && // 숫자만 있는 경우 제외
                              !RegExp(r'^\d+-\d+$').hasMatch(name) && // "150-19" 형식 제외
                              !RegExp(r'^[0-9\-]+$').hasMatch(name) && // 숫자-하이픈 조합 제외
                              name.length > 2 && // 너무 짧은 이름 제외
                              (types.any((type) => [
                                'tourist_attraction', 'park', 'amusement_park', 'museum',
                                'store', 'restaurant', 'bank', 'gas_station', 'hospital',
                                'convenience_store', 'establishment', 'point_of_interest',
                                'university', 'school', 'subway_station', 'train_station'
                              ].contains(type)) || 
                              // 유명 장소 이름 패턴 (홍대거리, 명동, 강남역 등)
                              name.contains('거리') || name.contains('공원') || 
                              name.contains('역') || name.contains('대학') ||
                              name.contains('시장') || name.contains('기념관'));
            
            if (isRealPlace) {
              final geometry = result['geometry']['location'];
              
              // Place Details API로 상세 정보 가져오기
              final detailedPlace = await getPlaceDetails(result['place_id'] ?? '');
              if (detailedPlace != null) {
                print('🎯 정확한 건물 발견: ${detailedPlace.name}');
                return detailedPlace;
              }
              
              // 상세 정보를 가져올 수 없다면 기본 정보 사용
              final place = PlaceDetails(
                placeId: result['place_id'] ?? '',
                name: name,
                address: result['vicinity'] ?? result['formatted_address'] ?? '',
                latitude: geometry['lat']?.toDouble() ?? latitude,
                longitude: geometry['lng']?.toDouble() ?? longitude,
                types: types,
                rating: result['rating']?.toDouble(),
              );
              
              return place;
            }
          }
        }
      }
      return null;
    } catch (e) {
      print('❌ 정확한 건물 검색 실패: $e');
      return null;
    }
  }

  /// 🏢 Nearby Search로 POI/건물 찾기 - 개선된 정밀 검색
  static Future<PlaceDetails?> _findNearbyPOI(double latitude, double longitude) async {
    try {
      // 🎯 1단계: 매우 정밀한 검색 (5미터 반경)
      var url = Uri.parse(
        '$_baseUrl/place/nearbysearch/json'
        '?location=$latitude,$longitude'
        '&radius=5' // 5미터 반경으로 축소
        '&key=$_apiKey'
        '&language=ko',
      );

      print('🎯 정밀 POI 검색 URL: $url');
      var response = await http.get(url);
      
      if (response.statusCode == 200) {
        var data = json.decode(response.body);
        print('🎯 정밀 POI 검색 응답: ${data['status']}');
        
        if (data['status'] == 'OK' && data['results'] != null && data['results'].isNotEmpty) {
          // 🏗️ 실제 건물/상점만 필터링
          for (var result in data['results']) {
            final types = List<String>.from(result['types'] ?? []);
            final name = result['name'] ?? '';
            
            // 행정구역은 제외하고 실제 건물/상점만 선택
            if (!types.any((type) => [
              'political', 
              'administrative_area_level_1', 
              'administrative_area_level_2',
              'locality',
              'sublocality',
              'country'
            ].contains(type)) && 
            name.isNotEmpty && 
            name != '인천광역시' && 
            name != '중구' &&
            !name.contains('동')) {
              
              final geometry = result['geometry']['location'];
              
              final place = PlaceDetails(
                placeId: result['place_id'] ?? '',
                name: name,
                address: result['vicinity'] ?? result['formatted_address'] ?? '',
                latitude: geometry['lat']?.toDouble() ?? latitude,
                longitude: geometry['lng']?.toDouble() ?? longitude,
                types: types,
                rating: result['rating']?.toDouble(),
                phoneNumber: result['formatted_phone_number'],
                website: result['website'],
              );
              
              print('✅ 정밀 POI 발견: ${place.name}');
              return place;
            }
          }
        }
      }

      // 🔍 2단계: 조금 더 넓은 범위 검색 (10미터)
      url = Uri.parse(
        '$_baseUrl/place/nearbysearch/json'
        '?location=$latitude,$longitude'
        '&radius=10'
        '&key=$_apiKey'
        '&language=ko',
      );

      print('🔍 확장 POI 검색 URL: $url');
      response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('🔍 확장 POI 검색 응답: ${data['status']}');
        
        if (data['status'] == 'OK' && data['results'] != null && data['results'].isNotEmpty) {
          // 🏪 상점/시설 우선 필터링
          for (var result in data['results']) {
            final types = List<String>.from(result['types'] ?? []);
            final name = result['name'] ?? '';
            
            // 상점, 음식점, 편의점 등 실제 비즈니스만 선택
            if (types.any((type) => [
              'store',
              'establishment',
              'point_of_interest',
              'convenience_store',
              'restaurant',
              'food',
              'meal_takeaway',
              'bank',
              'atm',
              'gas_station'
            ].contains(type)) && 
            name.isNotEmpty && 
            name != '인천광역시' && 
            name != '중구') {
              
              final geometry = result['geometry']['location'];
              
              final place = PlaceDetails(
                placeId: result['place_id'] ?? '',
                name: name,
                address: result['vicinity'] ?? result['formatted_address'] ?? '',
                latitude: geometry['lat']?.toDouble() ?? latitude,
                longitude: geometry['lng']?.toDouble() ?? longitude,
                types: types,
                rating: result['rating']?.toDouble(),
                phoneNumber: result['formatted_phone_number'],
                website: result['website'],
              );
              
              print('✅ 확장 POI 발견: ${place.name}');
              return place;
            }
          }
        }
      }
      
      print('❌ 유효한 POI를 찾지 못함');
      return null;
    } catch (e) {
      print('❌ POI 검색 실패: $e');
      return null;
    }
  }

  /// 🔍 오프라인 모드용 간단한 장소 검색 (API 키 없이 사용)
  static Future<List<PlaceSuggestion>> searchPlacesOffline(String query) async {
    // 오프라인 모드 제거 - 빈 리스트 반환
    return [];
  }
}

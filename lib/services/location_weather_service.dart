import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../config/api_keys.dart';

/// 위치 정보와 날씨 정보를 통합 관리하는 서비스
class LocationWeatherService {
  // ==== 필드 선언 ====
  double? _latitude;
  double? _longitude;
  String? _savedAddress;
  DateTime? _lastUpdated;
  
  // 싱글톤 패턴
  static LocationWeatherService? _instance;
  LocationWeatherService._();
  
  factory LocationWeatherService() {
    _instance ??= LocationWeatherService._();
    return _instance!;
  }

  // 날씨 캐싱을 위한 필드들
  Map<String, dynamic>? _cachedWeatherData;
  DateTime? _weatherLastUpdated;
  
  // 중복 API 호출 방지를 위한 필드
  Future<Map<String, dynamic>?>? _pendingWeatherRequest;
  
  // 위치 정보 중복 호출 방지를 위한 필드
  Future<void>? _pendingLocationRequest;

  // ==== Getter 메서드들 ====
  double? get latitude => _latitude;
  double? get longitude => _longitude;
  String? get savedAddress => _savedAddress;
  DateTime? get lastUpdated => _lastUpdated;
  bool get hasSavedLocation => _latitude != null && _longitude != null;
  
  /// 위치 정보가 최신인지 확인 (2분 이내)
  bool get isLocationFresh {
    if (_lastUpdated == null) return false;
    final difference = DateTime.now().difference(_lastUpdated!);
    return difference.inMinutes < 2;
  }

  /// 날씨 정보가 최신인지 확인 (2분 이내)
  bool get isWeatherFresh {
    if (_weatherLastUpdated == null || _cachedWeatherData == null) return false;
    final difference = DateTime.now().difference(_weatherLastUpdated!);
    return difference.inMinutes < 2;
  }

  // ==== 위치 관련 메서드들 ====
  
  /// 위도와 경도를 저장
  void saveLocation(double latitude, double longitude) {
    _latitude = latitude;
    _longitude = longitude;
    _lastUpdated = DateTime.now();
  }

  /// Position 객체로부터 위치 저장
  void saveLocationFromPosition(Position position) {
    saveLocation(position.latitude, position.longitude);
  }

  /// 현재 위치를 가져와서 저장 (캐시 및 중복 호출 방지 적용)
  Future<void> updateAndSaveCurrentLocation({LocationAccuracy accuracy = LocationAccuracy.high}) async {
    // 캐시된 위치가 있고 2분 이내라면 캐시된 데이터 사용
    if (hasSavedLocation && isLocationFresh) {
      print('📍 LocationWeatherService: 캐시된 위치 정보 사용 (${DateTime.now().difference(_lastUpdated!).inSeconds}초 전)');
      return;
    }
    
    // 진행 중인 요청이 있으면 해당 요청을 기다림
    if (_pendingLocationRequest != null) {
      print('📍 LocationWeatherService: 진행 중인 위치 요청 대기 중...');
      await _pendingLocationRequest!;
      return;
    }
    
    // 새로운 위치 요청 시작
    _pendingLocationRequest = _getCurrentPositionWithCache(accuracy);
    try {
      await _pendingLocationRequest!;
    } finally {
      _pendingLocationRequest = null;
    }
  }

  /// 캐시를 고려한 현재 위치 조회 내부 메서드
  Future<void> _getCurrentPositionWithCache(LocationAccuracy accuracy) async {
    final position = await getCurrentPosition(accuracy: accuracy);
    saveLocationFromPosition(position);
    print('📍 LocationWeatherService: 새로운 위치 정보 저장 완료');
    
    // 주소도 함께 저장 (비동기 처리)
    _updateAddressAsync(position);
  }
  
  /// 주소를 비동기로 업데이트
  Future<void> _updateAddressAsync(Position position) async {
    try {
      _savedAddress = await getAddressFrom(position);
    } catch (e) {
      print('주소 변환 실패: $e');
    }
  }

  /// 저장된 위치 정보 초기화
  void clearSavedLocation() {
    _latitude = null;
    _longitude = null;
    _savedAddress = null;
    _lastUpdated = null;
  }

  /// 현재 위치 조회 (권한 및 서비스 상태 확인 포함)
  Future<Position> getCurrentPosition({LocationAccuracy accuracy = LocationAccuracy.high}) async {
    // 위치 서비스 활성화 확인
    final isEnabled = await Geolocator.isLocationServiceEnabled();
    if (!isEnabled) {
      await Geolocator.openLocationSettings();
      throw Exception('위치 서비스가 꺼져 있습니다. 설정에서 활성화해주세요.');
    }

    // 권한 확인 및 요청
    final permission = await _checkAndRequestPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      throw Exception('위치 권한이 필요합니다. 앱 설정에서 권한을 허용해주세요.');
    }

    return Geolocator.getCurrentPosition(
      locationSettings: LocationSettings(accuracy: accuracy),
    );
  }
  
  /// 권한 확인 및 요청 처리
  Future<LocationPermission> _checkAndRequestPermission() async {
    var permission = await Geolocator.checkPermission();
    
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    
    return permission;
  }

  /// 마지막으로 알려진 위치 반환
  Future<Position?> getLastKnownPosition() async {
    try {
      return await Geolocator.getLastKnownPosition();
    } catch (e) {
      print('마지막 위치 조회 실패: $e');
      return null;
    }
  }

  /// 위도/경도로 주소 변환 (역지오코딩)
  Future<String> getAddressFrom(Position position) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isEmpty) return '';
      final p = placemarks.first;
      final parts = <String>[
        if (_isValidString(p.administrativeArea)) p.administrativeArea!,
        if (_isValidString(p.locality)) p.locality!,
        if (_isValidString(p.subLocality)) p.subLocality!,
        if (_isValidString(p.thoroughfare)) p.thoroughfare!,
      ];
      
      return parts.join(' ').trim();
    } catch (e) {
      print('주소 변환 중 오류: $e');
      return '';
    }
  }
  
  /// 문자열 유효성 검사
  bool _isValidString(String? str) {
    return str != null && str.isNotEmpty && str.trim().isNotEmpty;
  }

  // ==== 날씨 관련 메서드들 ====

  /// 기본 날씨 조회 (위도/경도로) - 캐싱 및 중복 호출 방지 적용
  Future<Map<String, dynamic>?> fetchWeather(double lat, double lon) async {
    // 캐시된 날씨가 있고 2분 이내라면 캐시된 데이터 반환
    if (isWeatherFresh && _cachedWeatherData != null) {
      print('🌤️ LocationWeatherService: 캐시된 날씨 정보 사용 (${DateTime.now().difference(_weatherLastUpdated!).inSeconds}초 전)');
      return _cachedWeatherData;
    }
    
    // 진행 중인 요청이 있으면 해당 요청을 기다림
    if (_pendingWeatherRequest != null) {
      print('🌤️ LocationWeatherService: 진행 중인 요청 대기 중...');
      return await _pendingWeatherRequest!;
    }
    
    // 새로운 요청 시작
    _pendingWeatherRequest = _fetchWeatherFromAPI(lat, lon);
    try {
      final result = await _pendingWeatherRequest!;
      return result;
    } finally {
      _pendingWeatherRequest = null;
    }
  }

  /// 실제 API 호출을 수행하는 내부 메서드
  Future<Map<String, dynamic>?> _fetchWeatherFromAPI(double lat, double lon) async {
    try {
      final url = 'https://api.openweathermap.org/data/2.5/weather?lat=$lat&lon=$lon&appid=${ApiKeys.weatherApiKey}&units=metric&lang=kr';
      print('🌤️ LocationWeatherService: 날씨 API 호출 - $url');
      
      final response = await http.get(Uri.parse(url));
      print('🌤️ LocationWeatherService: API 응답 상태 코드 - ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final weatherData = json.decode(response.body);
        print('🌤️ LocationWeatherService: 날씨 데이터 파싱 성공');
        
        // 날씨 데이터 캐싱
        _cachedWeatherData = weatherData;
        _weatherLastUpdated = DateTime.now();
        print('🌤️ LocationWeatherService: 날씨 정보 캐싱 완료');
        
        return weatherData;
      } else {
        print('❌ LocationWeatherService: API 응답 실패 - ${response.statusCode}: ${response.body}');
      }
      return null;
    } catch (e) {
      print('❌ LocationWeatherService: 날씨 조회 실패: $e');
      return null;
    }
  }

  /// 저장된 위치 정보로 날씨 조회
  Future<Map<String, dynamic>?> fetchWeatherFromSavedLocation() async {
    if (!hasSavedLocation) {
      await updateAndSaveCurrentLocation();
    }
    
    if (hasSavedLocation) {
      return await fetchWeather(_latitude!, _longitude!);
    }
    
    return null;
  }

  /// 위치 저장 후 날씨 조회 (가장 많이 사용되는 메서드)
  Future<Map<String, dynamic>?> fetchAndSaveLocationWeather() async {
    try {
      print('📍 LocationWeatherService: 위치 업데이트 시작');
      await updateAndSaveCurrentLocation();
      print('📍 LocationWeatherService: 위치 업데이트 완료 - 위도: $_latitude, 경도: $_longitude');
      
      if (hasSavedLocation) {
        print('🌤️ LocationWeatherService: 날씨 조회 시작');
        final weather = await fetchWeather(_latitude!, _longitude!);
        print('🌤️ LocationWeatherService: 날씨 조회 완료 - ${weather != null ? '성공' : '실패'}');
        return weather;
      } else {
        print('❌ LocationWeatherService: 저장된 위치 정보가 없음');
      }
    } catch (e) {
      print('❌ LocationWeatherService: 위치 저장 및 날씨 조회 실패: $e');
    }
    return null;
  }

  /// 캐시된 날씨 정보 강제 새로고침
  Future<Map<String, dynamic>?> refreshWeatherData() async {
    if (!hasSavedLocation) {
      await updateAndSaveCurrentLocation();
    }
    
    if (hasSavedLocation) {
      // 캐시 무효화
      _cachedWeatherData = null;
      _weatherLastUpdated = null;
      print('🔄 LocationWeatherService: 날씨 캐시 무효화, 새로고침 시작');
      return await fetchWeather(_latitude!, _longitude!);
    }
    
    return null;
  }

  /// 날씨 캐시 초기화
  void clearWeatherCache() {
    _cachedWeatherData = null;
    _weatherLastUpdated = null;
    print('🗑️ LocationWeatherService: 날씨 캐시 초기화');
  }

  /// 위치 정보 강제 새로고침
  Future<void> refreshLocationData() async {
    // 캐시 무효화
    clearSavedLocation();
    print('🔄 LocationWeatherService: 위치 캐시 무효화, 새로고침 시작');
    await updateAndSaveCurrentLocation();
  }

  // ==== 유틸리티 메서드들 ====

  /// 저장된 위치 정보 전체 반환
  Map<String, dynamic> getSavedLocationInfo() {
    return {
      'latitude': _latitude,
      'longitude': _longitude,
      'address': _savedAddress,
      'lastUpdated': _lastUpdated,
      'hasLocation': hasSavedLocation,
      'isFresh': isLocationFresh,
    };
  }

  // ==== 직렬화 메서드들 ====

  /// 위치 정보를 Map으로 변환
  Map<String, dynamic> toMap() {
    return {
      'latitude': _latitude,
      'longitude': _longitude,
      'address': _savedAddress,
      'lastUpdated': _lastUpdated?.toIso8601String(),
      'hasLocation': hasSavedLocation,
      'isFresh': isLocationFresh,
    };
  }
  
  /// Map에서 위치 정보 복원
  void fromMap(Map<String, dynamic> map) {
    _latitude = map['latitude'] as double?;
    _longitude = map['longitude'] as double?;
    _savedAddress = map['address'] as String?;
    _lastUpdated = map['lastUpdated'] != null 
        ? DateTime.parse(map['lastUpdated'] as String)
        : null;
  }
}

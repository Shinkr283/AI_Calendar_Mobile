import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

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

  // API 키
  final String _weatherApiKey = '7091ebdaf31310384aa6c653de1948d0';

  // ==== Getter 메서드들 ====
  double? get latitude => _latitude;
  double? get longitude => _longitude;
  String? get savedAddress => _savedAddress;
  DateTime? get lastUpdated => _lastUpdated;
  bool get hasSavedLocation => _latitude != null && _longitude != null;
  bool get hasValidLocation => hasSavedLocation;
  String? get currentAddress => _savedAddress;
  
  /// 위치 정보가 최신인지 확인 (5분 이내)
  bool get isLocationFresh {
    if (_lastUpdated == null) return false;
    final difference = DateTime.now().difference(_lastUpdated!);
    return difference.inMinutes < 5;
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

  /// 현재 위치를 가져와서 저장 (캐시 활용)
  Future<void> updateAndSaveCurrentLocation({LocationAccuracy accuracy = LocationAccuracy.high}) async {
    // 최신 위치가 있으면 재사용
    if (hasSavedLocation && isLocationFresh) {
      return;
    }
    
    final position = await getCurrentPosition(accuracy: accuracy);
    saveLocationFromPosition(position);
    
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

  /// 기본 날씨 조회 (위도/경도로)
  Future<Map<String, dynamic>?> fetchWeather(double lat, double lon) async {
    try {
      final url = 'https://api.openweathermap.org/data/2.5/weather?lat=$lat&lon=$lon&appid=$_weatherApiKey&units=metric&lang=kr';
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('날씨 조회 실패: $e');
      return null;
    }
  }

  /// 현재 위치의 날씨 조회
  Future<Map<String, dynamic>?> fetchCurrentLocationWeather() async {
    try {
      final position = await getCurrentPosition();
      return await fetchWeather(position.latitude, position.longitude);
    } catch (e) {
      print('현재 위치 날씨 조회 실패: $e');
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
      await updateAndSaveCurrentLocation();
      if (hasSavedLocation) {
        return await fetchWeather(_latitude!, _longitude!);
      }
    } catch (e) {
      print('위치 저장 및 날씨 조회 실패: $e');
    }
    return null;
  }

  // ==== 유틸리티 메서드들 ====

  /// 현재 위치의 위도/경도 반환 (다른 서비스용)
  Future<Map<String, double>?> getCurrentLocationCoordinates() async {
    try {
      await updateAndSaveCurrentLocation();
      if (hasSavedLocation) {
        return {
          'latitude': _latitude!,
          'longitude': _longitude!,
        };
      }
    } catch (e) {
      print('위치 좌표 조회 실패: $e');
    }
    return null;
  }

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

  /// 현재 위치 업데이트 (성공/실패 반환)
  Future<bool> updateCurrentLocation() async {
    try {
      await updateAndSaveCurrentLocation();
      return true;
    } catch (e) {
      print('위치 업데이트 실패: $e');
      return false;
    }
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

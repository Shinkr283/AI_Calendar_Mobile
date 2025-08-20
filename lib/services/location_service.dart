import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

/// 위치 관련 기능을 한 곳에 모은 서비스
class LocationService {
  /// 위치 권한과 서비스 상태를 확인하고 현재 위치를 반환합니다.
  /// 필요 시 권한을 요청하고, 위치 서비스 설정 화면으로 유도합니다.
  Future<Position> getCurrentPosition({LocationAccuracy accuracy = LocationAccuracy.high}) async {
    final isEnabled = await Geolocator.isLocationServiceEnabled();
    if (!isEnabled) {
      await Geolocator.openLocationSettings();
      throw Exception('위치 서비스가 꺼져 있습니다. 설정에서 활성화해주세요.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('위치 권한이 거부되었습니다.');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception('위치 권한이 영구적으로 거부되었습니다. 앱 설정에서 권한을 허용해주세요.');
    }

    return Geolocator.getCurrentPosition(
      locationSettings: LocationSettings(accuracy: accuracy),
    );
  }

  /// 마지막으로 알려진 위치를 반환합니다. 없으면 null
  Future<Position?> getLastKnownPosition() async {
    return Geolocator.getLastKnownPosition();
  }

  /// 위도/경도로 주소(행정동 등) 텍스트를 반환합니다. 실패 시 빈 문자열을 반환합니다.
  Future<String> getAddressFrom(Position position) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isEmpty) return '';
      final p = placemarks.first;
      final parts = <String>[
        if ((p.administrativeArea ?? '').isNotEmpty) p.administrativeArea!,
        if ((p.locality ?? '').isNotEmpty) p.locality!,
        if ((p.subLocality ?? '').isNotEmpty) p.subLocality!,
        if ((p.thoroughfare ?? '').isNotEmpty) p.thoroughfare!,
      ];
      return parts.join(' ');
    } catch (_) {
      return '';
    }
  }
}



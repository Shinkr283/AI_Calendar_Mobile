import 'event_service.dart';
import 'location_weather_service.dart';
import 'package:intl/intl.dart';

/// 위치 정보 관련 모든 기능을 담당하는 서비스
class ChatLocationService {
  final LocationWeatherService _locationWeatherService = LocationWeatherService();
  
  /// 채팅 텍스트로 장소 관련 질의를 처리하여 응답 문자열을 반환합니다.
  /// 매칭되지 않으면 null을 반환합니다.
  Future<String?> handleLocationQuery(String processedText) async {
    // 변경/바꿔/수정 요청 우선 처리
    if (RegExp(r'(변경|바꿔|수정)').hasMatch(processedText)) {
      // 날짜+시간 기반 변경
      final changeMatch = RegExp(r"(\d{4}-\d{1,2}-\d{1,2})\s*(\d{1,2})시\s*일정\s*(?:장소|위치)\s*(.+?)에서\s*(.+?)으로\s*바꿔줘").firstMatch(processedText);
      if (changeMatch != null) {
        final dateStr = changeMatch.group(1)!;
        final hour = int.parse(changeMatch.group(2)!);
        final oldLoc = changeMatch.group(3)!.trim();
        final newLoc = changeMatch.group(4)!.trim();
        final date = DateFormat('yyyy-MM-dd').parse(dateStr);
        final eventsOnDate = await EventService().getEventsForDate(date);
        final candidates = eventsOnDate.where((e) => e.startTime.hour == hour && e.location == oldLoc).toList();
        if (candidates.isEmpty) {
          return '죄송합니다. $dateStr ${hour.toString().padLeft(2,'0')}시, 위치가 $oldLoc 인 일정을 찾을 수 없습니다.';
        }
        final matched = candidates.first;
        final updatedEvent = matched.copyWith(location: newLoc, updatedAt: DateTime.now());
        await EventService().updateEvent(updatedEvent);
        return '$dateStr ${hour.toString().padLeft(2,'0')}시 일정 위치를 $newLoc 으로 변경했습니다.';
      }
      // 날짜+제목 기반 변경
      final changeByTitleMatch = RegExp(r"(\d{4}-\d{1,2}-\d{1,2})\s+(.+?)\s+일정\s*(?:장소|위치)를\s*(.+?)으로?\s*변경").firstMatch(processedText);
      if (changeByTitleMatch != null) {
        final dateStr = changeByTitleMatch.group(1)!;
        final titleQuery = changeByTitleMatch.group(2)!;
        final newLoc = changeByTitleMatch.group(3)!.trim();
        final date = DateFormat('yyyy-MM-dd').parse(dateStr);
        final eventsOnDate = await EventService().getEventsForDate(date);
        final matches = eventsOnDate.where((e) => e.title.trim().toLowerCase() == titleQuery.trim().toLowerCase()).toList();
        if (matches.isEmpty) {
          return '죄송합니다. $dateStr $titleQuery 일정이 없습니다.';
        }
        final matched = matches.first;
        final updatedEvent = matched.copyWith(location: newLoc, updatedAt: DateTime.now());
        await EventService().updateEvent(updatedEvent);
        return '$dateStr $titleQuery 일정 위치를 $newLoc 으로 변경했습니다.';
      }
      return '죄송합니다. 변경할 일정을 찾을 수 없습니다.';
    }

    // 현재 위치 요청 - 패턴을 더 포괄적으로 수정
    final currentLocPatterns = [
      RegExp(r'(현재\s*(위치|장소|어디|어느\s*곳))'),
      RegExp(r'(내\s*(위치|장소|어디|어느\s*곳))'),
      RegExp(r'(지금\s*(위치|장소|어디|어느\s*곳))'),
      RegExp(r'(여기\s*(어디|어느\s*곳))'),
      RegExp(r'(위치\s*(알려줘|보여줘|확인|찾아줘))'),
      RegExp(r'(장소\s*(알려줘|보여줘|확인|찾아줘))'),
    ];
    
    for (final pattern in currentLocPatterns) {
      if (pattern.hasMatch(processedText)) {
        return await _getCurrentLocationInfo();
      }
    }
    
    return null;
  }

  /// 현재 위치 정보를 안전하게 가져오는 메서드
  Future<String> _getCurrentLocationInfo() async {
    try {
      print('📍 ChatLocationService: 현재 위치 정보 요청 시작');
      
      // 기존 저장된 위치 정보 확인
      String? savedAddress = _locationWeatherService.savedAddress;
      bool hasValidLocation = _locationWeatherService.hasSavedLocation;
      
      print('📍 ChatLocationService: 저장된 위치 - $savedAddress, 유효함: $hasValidLocation');
      
      // 저장된 위치가 없거나 오래된 경우 새로 업데이트
      if (!hasValidLocation || savedAddress == null || savedAddress.isEmpty) {
        print('📍 ChatLocationService: 위치 정보 업데이트 시작');
        
        try {
          // 위치 업데이트 시도
          await _locationWeatherService.updateAndSaveCurrentLocation();
          
          // 업데이트 후 잠시 대기 (비동기 처리 시간 확보)
          await Future.delayed(const Duration(seconds: 3));
          
          // 업데이트된 위치 정보 확인
          savedAddress = _locationWeatherService.savedAddress;
          hasValidLocation = _locationWeatherService.hasSavedLocation;
          
          print('📍 ChatLocationService: 업데이트 후 위치 - $savedAddress, 유효함: $hasValidLocation');
          
        } catch (locationError) {
          print('❌ ChatLocationService: 위치 업데이트 실패 - $locationError');
          
          // 위치 권한 관련 오류인지 확인
          if (locationError.toString().contains('권한') || 
              locationError.toString().contains('permission') ||
              locationError.toString().contains('denied')) {
            return '❌ 위치 권한이 필요합니다.\n'
                   '📱 설정 > 앱 > AI 캘린더 > 위치 > "사용 중에만" 또는 "항상"으로 설정해주세요.';
          }
          
          // 위치 서비스 관련 오류인지 확인
          if (locationError.toString().contains('서비스') || 
              locationError.toString().contains('service') ||
              locationError.toString().contains('GPS')) {
            return '❌ 위치 서비스가 비활성화되어 있습니다.\n'
                   '📱 설정 > 개인정보 보호 및 보안 > 위치 서비스 > 켜기로 설정해주세요.';
          }
          
          return '❌ 위치 정보를 가져올 수 없습니다: $locationError\n'
                 '📱 위치 권한과 GPS 설정을 확인해주세요.';
        }
      }
      
      // 위치 정보가 있는 경우
      if (hasValidLocation && savedAddress != null && savedAddress.isNotEmpty) {
        return '📍 현재 위치는 $savedAddress 입니다.\n';
      }
      
      // 위치 정보가 없는 경우
      print('📍 ChatLocationService: 위치 정보 없음');
      return '📍 죄송합니다. 현재 위치를 가져올 수 없습니다.\n'
             '📱 다음 사항을 확인해주세요:\n'
             '   • 위치 권한 허용 (설정 > 앱 > AI 캘린더 > 위치)\n'
             '   • GPS 활성화 (설정 > 개인정보 보호 및 보안 > 위치 서비스)\n'
             '   • 인터넷 연결 상태';
      
    } catch (e) {
      print('❌ ChatLocationService: 위치 정보 가져오기 오류 - $e');
      return '❌ 위치 정보를 가져오는 중 오류가 발생했습니다: $e\n'
             '📱 위치 권한과 GPS 설정을 확인해주세요.';
    }
  }

  /// 오늘 일정의 첫 번째 이벤트 장소 조회
  Future<String> getEventLocation() async {
    final events = await EventService().getTodayEvents();
    if (events.isEmpty) {
      return '오늘 일정이 없어 장소 정보를 확인할 수 없습니다.';
    }
    final loc = events.first.location;
    return loc.isNotEmpty ? '오늘 일정 장소는 $loc 입니다.' : '오늘 일정에 장소 정보가 없습니다.';
  }

  /// 저장된 위치 정보 반환
  Map<String, dynamic> getSavedLocationInfo() {
    return {
      'latitude': _locationWeatherService.latitude,
      'longitude': _locationWeatherService.longitude,
      'address': _locationWeatherService.savedAddress,
      'lastUpdated': _locationWeatherService.lastUpdated,
      'hasLocation': _locationWeatherService.hasSavedLocation,
      'isFresh': _locationWeatherService.isLocationFresh,
    };
  }

  /// 현재 위치 업데이트
  Future<bool> updateCurrentLocation() async {
    try {
      print('📍 ChatLocationService: 수동 위치 업데이트 시작');
      await _locationWeatherService.updateAndSaveCurrentLocation();
      
      // 업데이트 후 잠시 대기
      await Future.delayed(const Duration(seconds: 2));
      
      final success = _locationWeatherService.hasSavedLocation;
      print('📍 ChatLocationService: 수동 위치 업데이트 결과 - $success');
      
      return success;
    } catch (e) {
      print('❌ ChatLocationService: 수동 위치 업데이트 실패 - $e');
      return false;
    }
  }

  /// 저장된 위치가 있는지 확인
  bool get hasValidLocation => _locationWeatherService.hasSavedLocation;

  /// 현재 주소 반환
  String? get currentAddress => _locationWeatherService.savedAddress;
}

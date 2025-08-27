import 'event_service.dart';
import 'location_service.dart';
import 'package:intl/intl.dart';

/// 사용자가 일정의 위치를 조회합니다.
class ChatLocationService {
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

      // 현재 위치 요청
      final currentLocPattern = RegExp(r'(현재\s*(위치|장소)|내\s*(위치|장소))');
      if (currentLocPattern.hasMatch(processedText)) {
        try {
          final pos = await LocationService().getCurrentPosition();
          final address = await LocationService().getAddressFrom(pos);
          return address.isNotEmpty ? '현재 위치는 $address 입니다.' : '죄송합니다, 현재 위치를 알 수 없습니다.';
        } catch (_) {
          return '죄송합니다, 현재 위치를 알 수 없습니다.';
        }
      }
    return null;
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
}

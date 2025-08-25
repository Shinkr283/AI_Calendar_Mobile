import 'event_service.dart';
import 'location_service.dart';
import 'package:intl/intl.dart';

/// 사용자가 일정의 위치를 조회합니다.
class ChatLocationService {
  /// 오늘 일정의 첫 번째 이벤트 장소 조회
  Future<String> getEventLocation() async {
    final events = await EventService().getTodayEvents();
    if (events.isEmpty) {
      return '오늘 일정이 없어 장소 정보를 확인할 수 없습니다.';
    }
    final loc = events.first.location;
    return loc.isNotEmpty ? '오늘 일정 장소는 $loc 입니다.' : '오늘 일정에 장소 정보가 없습니다.';
  }

  /// 채팅 텍스트로 장소 관련 질의를 처리하여 응답 문자열을 반환합니다.
  /// 매칭되지 않으면 null을 반환합니다.
  Future<String?> handleLocationQuery(String processedText) async {
    // 1) 날짜+시간: "YYYY-MM-DD 19시 일정 장소"
    final df = DateFormat('yyyy-MM-dd');
    final dateTimeMatch = RegExp(r'(\d{4}-\d{1,2}-\d{1,2})\s*(\d{1,2})시.*(위치|장소)').firstMatch(processedText);
    if (dateTimeMatch != null) {
      final dateStr = dateTimeMatch.group(1)!;
      final hour = int.parse(dateTimeMatch.group(2)!);
      final date = df.parse(dateStr);
      final eventsOnDate = await EventService().getEventsForDate(date);
      final matched = eventsOnDate.where((e) => e.startTime.hour == hour).toList();
      return matched.isEmpty
          ? '죄송합니다. ${dateStr} ${hour.toString().padLeft(2,'0')}시 일정 장소를 찾을 수 없습니다.'
          : (matched.first.location.isNotEmpty
              ? '${dateStr} ${hour.toString().padLeft(2,'0')}시 일정 장소는 ${matched.first.location} 입니다.'
              : '해당 일정에 위치 정보가 없습니다.');
    }

    // 2) 날짜+제목: "YYYY-MM-DD 일정 장소"
    final dateTitleMatch = RegExp(r'(\d{4}-\d{1,2}-\d{1,2})\s+(.+?)\s*(?:위치|장소)').firstMatch(processedText);
    if (dateTitleMatch != null) {
      final dateStr = dateTitleMatch.group(1)!;
      final titleQuery = dateTitleMatch.group(2)!;
      final date = df.parse(dateStr);
      final eventsOnDate = await EventService().getEventsForDate(date);
      final matches = eventsOnDate
          .where((e) => e.title.trim().toLowerCase() == titleQuery.trim().toLowerCase())
          .toList();
      final matched = matches.isNotEmpty ? matches.first : null;
      return matched == null
          ? '죄송합니다. $dateStr $titleQuery 일정 장소를 찾을 수 없습니다.'
          : (matched.location.isNotEmpty
              ? '$dateStr $titleQuery 일정 장소는 ${matched.location} 입니다.'
              : '해당 일정에 위치 정보가 없습니다.');
    }

    // 3) 현재 위치 요청
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
}

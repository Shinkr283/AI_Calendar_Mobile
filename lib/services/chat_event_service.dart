import 'package:intl/intl.dart';
import 'event_service.dart';
import 'native_alarm_service.dart';
import '../models/event.dart';

/// 챗 명령어로 일정 생성/수정 시 파싱 및 처리
class ChatEventService {
  /// 명령어를 파싱하여 일정 추가 또는 수정 후 결과 메세지를 반환
  /// 형식: "일정 추가 제목 | yyyy-MM-dd HH:mm | 장소=장소명 | 알람=분"
  Future<String> processCommand(String command) async {
    try {
      final parts = command.split('|').map((s) => s.trim()).toList();
      if (parts.isEmpty) return '명령어 형식이 올바르지 않습니다.';
      final actionMatch = RegExp(r'^일정\s*(추가|수정)').firstMatch(parts[0]);
      if (actionMatch == null) return '지원하지 않는 명령어입니다.';
      final action = actionMatch.group(1)!;
      // 제목
      final title = parts[0].replaceFirst(RegExp(r'^일정\s*(추가|수정)'), '').trim();
      // 날짜시간 파싱
      final dt = parts.length > 1 ? DateFormat('yyyy-MM-dd HH:mm').parse(parts[1]) : null;
      String location = '';
      int alarmMin = 0;
      for (final p in parts.skip(2)) {
        if (p.startsWith('장소=')) location = p.substring(3).trim();
        if (p.startsWith('알람=')) alarmMin = int.tryParse(p.substring(3).trim()) ?? 0;
      }
      if (title.isEmpty || dt == null) return '제목과 날짜/시간을 확인해주세요.';
      if (action == '추가') {
        final ev = await EventService().createEvent(
          title: title,
          description: '',
          startTime: dt,
          endTime: dt.add(const Duration(hours: 1)),
          location: location,
          alarmMinutesBefore: alarmMin,
        );
        if (alarmMin > 0) {
          await NativeAlarmService.scheduleNativeAlarm(
            notificationId: ev.id.hashCode,
            delaySeconds: alarmMin,
            title: '일정 알림',
            body: '${ev.title} 일정이 곧 시작됩니다.',
          );
        }
        return '일정이 추가되었습니다: ${ev.title} (${DateFormat('yyyy-MM-dd HH:mm').format(dt)})';
      } else {
        // 수정: 제목으로 이벤트 검색
        final list = await EventService().getEventsForDate(dt);
        Event? match;
        for (final e2 in list) {
          if (e2.title == title) {
            match = e2;
            break;
          }
        }
        if (match == null) return '수정할 일정을 찾을 수 없습니다.';
        final updated = match.copyWith(
          startTime: dt,
          endTime: dt.add(const Duration(hours: 1)),
          location: location.isNotEmpty ? location : match.location,
        );
        await EventService().updateEvent(updated);
        if (alarmMin > 0) {
          await NativeAlarmService.scheduleNativeAlarm(
            notificationId: updated.id.hashCode,
            delaySeconds: alarmMin,
            title: '일정 알림',
            body: '${updated.title} 일정이 변경되었습니다.',
          );
        }
        return '일정이 수정되었습니다: ${updated.title} (${DateFormat('yyyy-MM-dd HH:mm').format(dt)})';
      }
    } catch (e) {
      return '명령 처리 중 오류가 발생했습니다: $e';
    }
  }
}

import 'package:intl/intl.dart';
import 'event_service.dart';
import 'native_alarm_service.dart';
import '../models/event.dart';

/// 챗 명령어로 일정 생성/수정 시 파싱 및 처리
class ChatScheduleUpdate {
  ChatScheduleUpdate._internal();
  static final ChatScheduleUpdate _instance = ChatScheduleUpdate._internal();
  factory ChatScheduleUpdate() => _instance;

  Future<Map<String, dynamic>> updateEvent(Map<String, dynamic> args) async {
    try {
      final eventService = EventService();
      final existingEvent = await _resolveEventByArgs(args);
      
      if (existingEvent == null) {
        return {'status': '오류: 해당 ID의 일정을 찾을 수 없습니다.'};
      }
      
      // 수정할 필드들 확인 및 업데이트 (새 값이 전달된 경우에만 교체)
      final title = (args['newTitle'] as String?) ?? (args['title'] as String?) ?? existingEvent.title;
      final description = (args['description'] as String?) ?? existingEvent.description;
      final location = (args['location'] as String?) ?? existingEvent.location;
      final alarmMin = (args['alarmMinutesBefore'] as int?) ?? existingEvent.alarmMinutesBefore;

      // 기존 값 기준으로 부분 업데이트 허용
      DateTime startDateTime = existingEvent.startTime;
      DateTime endDateTime = existingEvent.endTime;

      final hasNewStartDate = args['startDate'] != null;
      final hasNewStartTime = args['startTime'] != null;
      final hasNewEndDate = args['endDate'] != null;
      final hasNewEndTime = args['endTime'] != null;

      // 시작 시각 재계산: 날짜 또는 시간 중 하나만 와도 반영
      if (hasNewStartDate || hasNewStartTime) {
        final startDateStr = (args['startDate'] as String?) ?? DateFormat('yyyy-MM-dd').format(existingEvent.startTime);
        final startTimeStr = hasNewStartTime
            ? _parseKoreanTime(args['startTime'] as String)
            : DateFormat('HH:mm').format(existingEvent.startTime);
        final newStart = DateTime.parse('$startDateStr $startTimeStr:00');
        // 종료가 명시되지 않았다면 기존 지속시간 유지
        final duration = existingEvent.endTime.difference(existingEvent.startTime);
        startDateTime = newStart;
        if (!(hasNewEndDate || hasNewEndTime)) {
          endDateTime = newStart.add(duration);
        }
      }

      // 종료 시각 재계산: 날짜 또는 시간 중 하나만 와도 반영
      if (hasNewEndDate || hasNewEndTime) {
        final endDateStr = (args['endDate'] as String?) ?? DateFormat('yyyy-MM-dd').format(endDateTime);
        final endTimeStr = hasNewEndTime
            ? _parseKoreanTime(args['endTime'] as String)
            : DateFormat('HH:mm').format(endDateTime);
        endDateTime = DateTime.parse('$endDateStr $endTimeStr:00');
      }
      
      final updatedEvent = existingEvent.copyWith(
        title: title,
        description: description,
        startTime: startDateTime,
        endTime: endDateTime,
        location: location,
        alarmMinutesBefore: alarmMin,
      );
      
      await eventService.updateEvent(updatedEvent);
      await _applyAlarm(updatedEvent, alarmMin);
      
      return {
        'status': '일정이 성공적으로 수정되었습니다.',
        'eventId': updatedEvent.id,
        'title': updatedEvent.title,
      };
    } catch (e) {
      return {'status': '오류: 일정을 수정하는 중 문제가 발생했습니다: $e'};
    }
  }

  // 생성 요청 시: gid/제목 중복 확인 후 업데이트 또는 생성 처리
  Future<Map<String, dynamic>> createOrUpdateEvent(Map<String, dynamic> args) async {
    try {
      final eventService = EventService();

      final rawTitle = args['title'] as String;
      final normalizedTitle = rawTitle.replaceFirst(RegExp(r'일정$'), '');
      final description = args['description'] as String? ?? '';
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final rawStartDate = args['startDate'] as String?;
      final startDate = (rawStartDate == null || rawStartDate == '오늘' || rawStartDate.toLowerCase() == 'today')
          ? today
          : rawStartDate;
      final startTime = _parseKoreanTime(args['startTime'] as String);
      final startDateTime = DateTime.parse('$startDate $startTime:00');
      final defaultEnd = startDateTime.add(const Duration(hours: 1));
      final endDateTime = (args['endDate'] != null && args['endTime'] != null)
        ? DateTime.parse('${args['endDate']} ${_parseKoreanTime(args['endTime'] as String)}:00')
        : defaultEnd;
      final location = args['location'] as String? ?? '';
      final alarmMin = args['alarmMinutesBefore'] as int? ?? 10;

      // gid 우선 확인
      final gid = (args['gid'] as String?) ?? (args['googleEventId'] as String?);
      Event? existing;
      if (gid != null && gid.isNotEmpty) {
        existing = await eventService.getEventByGoogleId(gid);
      }
      // 날짜 동일 + 제목(정규화) 완전 일치 확인
      if (existing == null) {
        final eventsOnDate = await eventService.getEventsForDate(startDateTime);
        for (final e in eventsOnDate) {
          final nt = e.title.trim().toLowerCase().replaceFirst(RegExp(r'일정$'), '');
          if (nt == normalizedTitle.trim().toLowerCase()) {
            existing = e;
            break;
          }
        }
      }

      if (existing != null) {
        // 기존 일정 수정
        final updated = existing.copyWith(
          title: normalizedTitle,
          description: description,
          startTime: startDateTime,
          endTime: endDateTime,
          location: location,
          alarmMinutesBefore: alarmMin,
        );
        await eventService.updateEvent(updated);
        await _applyAlarm(updated, alarmMin);
        return {
          'status': '기존 일정이 수정되었습니다.',
          'eventId': updated.id,
          'title': updated.title,
          'startTime': DateFormat('yyyy-MM-dd HH:mm').format(updated.startTime),
        };
      }

      // 없으면 새로 생성
      final created = await eventService.createEvent(
        title: normalizedTitle,
        description: description,
        startTime: startDateTime,
        endTime: endDateTime,
        location: location,
        alarmMinutesBefore: alarmMin,
      );
      await _applyAlarm(created, alarmMin);
      return {
        'status': '일정이 성공적으로 생성되었습니다.',
        'eventId': created.id,
        'title': created.title,
        'startTime': DateFormat('yyyy-MM-dd HH:mm').format(created.startTime),
      };
    } catch (e) {
      return {'status': '오류: 일정을 생성/수정하는 중 문제가 발생했습니다: $e'};
    }
  }

  // ===== 내부 유틸 =====
  Future<Event?> _resolveEventByArgs(Map<String, dynamic> args) async {
    final eventService = EventService();
    // 0) gid(googleEventId)로 우선 식별
    final gid = (args['gid'] as String?) ?? (args['googleEventId'] as String?);
    if (gid != null && gid.isNotEmpty) {
      final byGid = await eventService.getEventByGoogleId(gid);
      if (byGid != null) return byGid;
    }
    // 1) eventId
    final eventId = args['eventId'] as String?;
    if (eventId != null && eventId.isNotEmpty) {
      return await eventService.getEvent(eventId);
    }
    // 2) date + time
    final startDate = (args['targetDate'] as String?) ?? (args['date'] as String?) ?? (args['startDate'] as String?);
    final startTime = (args['targetStartTime'] as String?) ?? (args['time'] as String?);
    if (startDate != null && startTime != null) {
      final dateTime = DateTime.parse('$startDate ${_parseKoreanTime(startTime)}:00');
      final eventsOnDate = await eventService.getEventsForDate(dateTime);
      // 2-1) 분까지 완전 일치 우선
      for (final e in eventsOnDate) {
        final s = e.startTime;
        if (s.year == dateTime.year &&
            s.month == dateTime.month &&
            s.day == dateTime.day &&
            s.hour == dateTime.hour &&
            s.minute == dateTime.minute) {
          return e;
        }
      }
      // 2-2) 같은 날짜 + 같은 시간(시) 매칭 허용 (예: 19시 ↔ 19:30)
      Event? hourMatched;
      for (final e in eventsOnDate) {
        final s = e.startTime;
        if (s.year == dateTime.year && s.month == dateTime.month && s.day == dateTime.day && s.hour == dateTime.hour) {
          hourMatched = e;
          break;
        }
      }
      if (hourMatched != null) return hourMatched;
      // 2-3) 그날 일정이 1개뿐이면 그 일정으로 간주
      if (eventsOnDate.length == 1) return eventsOnDate.first;
    }
    // 3) date + title
    final title = (args['targetTitle'] as String?) ?? (args['title'] as String?);
    if (startDate != null && title != null) {
      final targetDate = DateTime.parse('$startDate 00:00:00');
      final eventsOnDate = await eventService.getEventsForDate(targetDate);
      final normalizedQuery = title.trim().toLowerCase().replaceFirst(RegExp(r'일정$'), '');
      // 3-1) 완전 일치 우선
      for (final e in eventsOnDate) {
        final normalizedTitle = e.title.trim().toLowerCase().replaceFirst(RegExp(r'일정$'), '');
        if (normalizedTitle == normalizedQuery) return e;
      }
      // 3-2) 포함/역포함 매칭 (모호하면 반환하지 않음)
      final fuzzy = eventsOnDate.where((e) {
        final nt = e.title.trim().toLowerCase().replaceFirst(RegExp(r'일정$'), '');
        return nt.contains(normalizedQuery) || normalizedQuery.contains(nt);
      }).toList();
      if (fuzzy.length == 1) return fuzzy.first;
    }
    return null;
  }

  String _parseKoreanTime(String input) {
    var text = input.trim().replaceAll('시', ':00').replaceAll('분', '').replaceAll(' ', '');
    // 숫자만 있는 경우 (예: 18) → 18:00
    final onlyHour = RegExp(r'^\d{1,2}$');
    if (onlyHour.hasMatch(text)) {
      final h = int.parse(text);
      return '${h.toString().padLeft(2, '0')}:00';
    }
    // HH:MM 형태 유지
    if (RegExp(r'^\d{1,2}:\d{2}$').hasMatch(text)) {
      return _normalize24h(text);
    }
    // 오전/오후 처리
    final ampm = RegExp(r'^(오전|오후)(\d{1,2})(?::?(\d{2}))?$');
    final m = ampm.firstMatch(text.replaceAll(':', ''));
    if (m != null) {
      final isPm = m.group(1) == '오후';
      final hour = int.parse(m.group(2)!);
      final minute = int.tryParse(m.group(3) ?? '00') ?? 0;
      int hh = hour % 12;
      if (isPm) hh += 12;
      return '${hh.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
    }
    // fallback: 숫자+시 형태 (예: 18시)
    final hMatch = RegExp(r'^(\d{1,2}):?(\d{2})?$').firstMatch(text);
    if (hMatch != null) {
      final hh = int.parse(hMatch.group(1)!);
      final mm = int.tryParse(hMatch.group(2) ?? '00') ?? 0;
      return '${hh.toString().padLeft(2, '0')}:${mm.toString().padLeft(2, '0')}';
    }
    return '00:00';
  }

  String _normalize24h(String hhmm) {
    final parts = hhmm.split(':');
    final h = int.parse(parts[0]);
    final m = int.parse(parts[1]);
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  // 공통: 네이티브 알람 적용(기존 취소 후 재설정)
  Future<void> _applyAlarm(Event event, int alarmMin) async {
    try {
      await NativeAlarmService.cancelNativeAlarm(event.id.hashCode);
    } catch (_) {}
    if (alarmMin > 0) {
      final alarmTime = event.startTime.subtract(Duration(minutes: alarmMin));
      final delaySeconds = alarmTime.difference(DateTime.now()).inSeconds;
      if (delaySeconds > 0) {
        await NativeAlarmService.scheduleNativeAlarm(
          notificationId: event.id.hashCode,
          delaySeconds: delaySeconds,
          title: '일정 알림',
          body: '${event.title} 일정이 곧 시작됩니다.',
        );
      }
    }
  }

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
          alarmMinutesBefore: alarmMin,
        );
        await EventService().updateEvent(updated);
        // 기존 알람 취소 후 재설정
        await NativeAlarmService.cancelNativeAlarm(updated.id.hashCode);
        if (alarmMin > 0) {
          await NativeAlarmService.scheduleNativeAlarm(
            notificationId: updated.id.hashCode,
            delaySeconds: alarmMin,
            title: '일정 알림',
            body: '${updated.title} 일정 알람이 ${alarmMin}분 전으로 변경되었습니다.',
          );
        }
        return '일정이 수정되었습니다: ${updated.title} (${DateFormat('yyyy-MM-dd HH:mm').format(dt)})';
      }
    } catch (e) {
      return '명령 처리 중 오류가 발생했습니다: $e';
    }
  }
}

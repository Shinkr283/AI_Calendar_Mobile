import 'dart:async';
import 'dart:math';
import '../models/event.dart';
import 'database_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EventService {
  static final EventService _instance = EventService._internal();
  final DatabaseService _databaseService = DatabaseService();
  
  factory EventService() => _instance;
  
  EventService._internal();

  // 일정 생성
  Future<Event> createEvent({
    required String title,
    required String description,
    required DateTime startTime,
    required DateTime endTime,
    required int alarmMinutesBefore,
    String? location,
  }) async {
    final event = Event(
      id: _generateEventId(),
      title: title,
      description: description,
      startTime: startTime,
      endTime: endTime,
      location: location ?? '',
      isCompleted: false,
      alarmMinutesBefore: alarmMinutesBefore,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _databaseService.insertEvent(event);
    return event;
  }

  // 일정 조회
  Future<Event?> getEvent(String id) async {
    return await _databaseService.getEvent(id);
  }

  // Google ID로 일정 조회
  Future<Event?> getEventByGoogleId(String googleEventId) async {
    return await _databaseService.getEventByGoogleId(googleEventId);
  }

  // 일정 목록 조회
  Future<List<Event>> getEvents({
    DateTime? startDate,
    DateTime? endDate,
    bool? isCompleted,
  }) async {
    return await _databaseService.getEvents(
      startDate: startDate,
      endDate: endDate,
      isCompleted: isCompleted,
    );
  }

  // 특정 날짜의 일정 조회
  Future<List<Event>> getEventsForDate(DateTime date) async {
    return await _databaseService.getEventsForDate(date);
  }

  // 이번 주 일정 조회
  Future<List<Event>> getEventsForWeek(DateTime weekStart) async {
    final weekEnd = weekStart.add(const Duration(days: 6));
    return await getEvents(
      startDate: weekStart,
      endDate: weekEnd,
    );
  }

  // 이번 달 일정 조회
  Future<List<Event>> getEventsForMonth(DateTime month) async {
    final monthStart = DateTime(month.year, month.month, 1);
    final monthEnd = DateTime(month.year, month.month + 1, 0, 23, 59, 59);
    return await getEvents(
      startDate: monthStart,
      endDate: monthEnd,
    );
  }

  // 일정 수정
  Future<Event> updateEvent(Event event) async {
    final updatedEvent = event.copyWith(
      updatedAt: DateTime.now(),
    );
    await _databaseService.updateEvent(updatedEvent);
    return updatedEvent;
  }

  // 일정 삭제
  Future<bool> deleteEvent(String id) async {
    // 로컬 삭제 이전에, 구글 동기화를 위한 삭제 큐에 추가
    try {
      final ev = await getEvent(id);
      if (ev != null && ev.googleEventId != null && ev.googleEventId!.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        final pending = prefs.getStringList('pending_google_deletes') ?? <String>[];
        if (!pending.contains(ev.googleEventId)) {
          pending.add(ev.googleEventId!);
          await prefs.setStringList('pending_google_deletes', pending);
        }
      }
    } catch (_) {}

    final result = await _databaseService.deleteEvent(id);
    return result > 0;
  }

  // 일정 완료 처리
  Future<Event?> completeEvent(String id) async {
    final event = await getEvent(id);
    if (event != null) {
      final completedEvent = event.copyWith(
        isCompleted: true,
        updatedAt: DateTime.now(),
      );
      await _databaseService.updateEvent(completedEvent);
      return completedEvent;
    }
    return null;
  }

  // 일정 검색
  Future<List<Event>> searchEvents(String query) async {
    return await _databaseService.searchEvents(query);
  }

  // 다가오는 일정 조회 (알림용)
  Future<List<Event>> getUpcomingEvents({int days = 7}) async {
    final now = DateTime.now();
    final endDate = now.add(Duration(days: days));
    
    final events = await getEvents(
      startDate: now,
      endDate: endDate,
      isCompleted: false,
    );
    
    return events.where((event) => event.startTime.isAfter(now)).toList();
  }

  // 오늘의 일정 조회
  Future<List<Event>> getTodayEvents() async {
    return await getEventsForDate(DateTime.now());
  }

  // 시간 충돌 검사
  Future<List<Event>> checkTimeConflicts(DateTime startTime, DateTime endTime, {String? excludeEventId}) async {
    final events = await getEvents(
      startDate: startTime.subtract(const Duration(days: 1)),
      endDate: endTime.add(const Duration(days: 1)),
      isCompleted: false,
    );
    
    return events.where((event) {
      if (excludeEventId != null && event.id == excludeEventId) {
        return false;
      }
      
      // 시간 겹침 검사
      return (startTime.isBefore(event.endTime) && endTime.isAfter(event.startTime));
    }).toList();
  }

  // 빈 시간대 찾기
  Future<List<TimeSlot>> findAvailableTimeSlots(
    DateTime date,
    int durationMinutes, {
    int workingHourStart = 9,
    int workingHourEnd = 18,
  }) async {
    final events = await getEventsForDate(date);
    final availableSlots = <TimeSlot>[];
    
    final workStart = DateTime(date.year, date.month, date.day, workingHourStart);
    final workEnd = DateTime(date.year, date.month, date.day, workingHourEnd);
    
    // 일정들을 시간순으로 정렬
    events.sort((a, b) => a.startTime.compareTo(b.startTime));
    
    DateTime currentTime = workStart;
    
    for (final event in events) {
      // 현재 시간과 다음 일정 시작 시간 사이에 여유가 있는지 확인
      if (event.startTime.isAfter(currentTime)) {
        final availableMinutes = event.startTime.difference(currentTime).inMinutes;
        if (availableMinutes >= durationMinutes) {
          availableSlots.add(TimeSlot(
            startTime: currentTime,
            endTime: event.startTime,
            durationMinutes: availableMinutes,
          ));
        }
      }
      
      // 현재 시간을 이 일정 종료 시간으로 업데이트
      if (event.endTime.isAfter(currentTime)) {
        currentTime = event.endTime;
      }
    }
    
    // 마지막 일정 이후부터 근무 종료 시간까지 확인
    if (currentTime.isBefore(workEnd)) {
      final availableMinutes = workEnd.difference(currentTime).inMinutes;
      if (availableMinutes >= durationMinutes) {
        availableSlots.add(TimeSlot(
          startTime: currentTime,
          endTime: workEnd,
          durationMinutes: availableMinutes,
        ));
      }
    }
    
    return availableSlots;
  }

  // 반복 일정 생성
  Future<List<Event>> createRecurringEvents(
    Event baseEvent,
    RecurrenceRule rule,
    DateTime endDate,
  ) async {
    final events = <Event>[];
    DateTime currentDate = baseEvent.startTime;
    
    while (currentDate.isBefore(endDate)) {
      final event = baseEvent.copyWith(
        id: _generateEventId(),
        startTime: currentDate,
        endTime: currentDate.add(baseEvent.endTime.difference(baseEvent.startTime)),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      await _databaseService.insertEvent(event);
      events.add(event);
      
      // 다음 반복 날짜 계산
      switch (rule) {
        case RecurrenceRule.daily:
          currentDate = currentDate.add(const Duration(days: 1));
          break;
        case RecurrenceRule.weekly:
          currentDate = currentDate.add(const Duration(days: 7));
          break;
        case RecurrenceRule.monthly:
          currentDate = DateTime(currentDate.year, currentDate.month + 1, currentDate.day);
          break;
        case RecurrenceRule.yearly:
          currentDate = DateTime(currentDate.year + 1, currentDate.month, currentDate.day);
          break;
      }
    }
    
    return events;
  }

  // 유니크 ID 생성
  String _generateEventId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(10000);
    return 'event_${timestamp}_$random';
  }

}

// 시간대 클래스
class TimeSlot {
  final DateTime startTime;
  final DateTime endTime;
  final int durationMinutes;

  const TimeSlot({
    required this.startTime,
    required this.endTime,
    required this.durationMinutes,
  });

  @override
  String toString() {
    return 'TimeSlot(${startTime.hour}:${startTime.minute.toString().padLeft(2, '0')} - ${endTime.hour}:${endTime.minute.toString().padLeft(2, '0')}, ${durationMinutes}분)';
  }
}

// 반복 규칙 열거형
enum RecurrenceRule {
  daily,
  weekly,
  monthly,
  yearly,
} 
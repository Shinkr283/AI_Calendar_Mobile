import 'dart:async';
import 'dart:math';
import '../models/event.dart';
import 'database_service.dart';
import 'native_alarm_service.dart';

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
    String? location,
    String category = EventCategory.personal,
    int priority = EventPriority.medium,
    bool isAllDay = false,
    String? recurrenceRule,
    List<String> attendees = const [],
    String? color,
    int alarmMinutesBefore = 10,
  }) async {
    try {
      print('🏗️ EventService: 이벤트 생성 시작');
      print('📝 제목: $title');
      print('📅 시작 시간: $startTime');
      print('📅 종료 시간: $endTime');
      
      // 입력값 검증
      if (title.trim().isEmpty) {
        throw ArgumentError('제목은 필수입니다.');
      }
      
      if (startTime.isAfter(endTime)) {
        throw ArgumentError('시작 시간이 종료 시간보다 늦을 수 없습니다.');
      }
      
      final event = Event(
        id: _generateEventId(),
        title: title.trim(),
        description: description.trim(),
        startTime: startTime,
        endTime: endTime,
        location: location?.trim() ?? '',
        category: category,
        priority: priority,
        isAllDay: isAllDay,
        recurrenceRule: recurrenceRule,
        attendees: attendees,
        color: color ?? _getDefaultColorForCategory(category),
        isCompleted: false,
        alarmMinutesBefore: alarmMinutesBefore,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      print('💾 데이터베이스에 저장 시도: ${event.id}');
      final insertResult = await _databaseService.insertEvent(event);
      print('✅ 데이터베이스 저장 성공: insertResult = $insertResult');
      
      return event;
    } catch (e, stackTrace) {
      print('❌ EventService.createEvent 실패: $e');
      print('📍 스택 트레이스: $stackTrace');
      rethrow;
    }
  }

  // 일정 조회
  Future<Event?> getEvent(String id) async {
    return await _databaseService.getEvent(id);
  }

  // 일정 목록 조회
  Future<List<Event>> getEvents({
    DateTime? startDate,
    DateTime? endDate,
    String? category,
    int? priority,
    bool? isCompleted,
  }) async {
    return await _databaseService.getEvents(
      startDate: startDate,
      endDate: endDate,
      category: category,
      priority: priority,
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

  // 카테고리별 일정 통계
  Future<Map<String, int>> getEventStatsByCategory() async {
    final events = await getEvents();
    final stats = <String, int>{};
    
    for (final category in EventCategory.all) {
      stats[category] = 0;
    }
    
    for (final event in events) {
      stats[event.category] = (stats[event.category] ?? 0) + 1;
    }
    
    return stats;
  }

  // 우선순위별 일정 통계
  Future<Map<int, int>> getEventStatsByPriority() async {
    final events = await getEvents();
    final stats = <int, int>{
      EventPriority.low: 0,
      EventPriority.medium: 0,
      EventPriority.high: 0,
    };
    
    for (final event in events) {
      stats[event.priority] = (stats[event.priority] ?? 0) + 1;
    }
    
    return stats;
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

  // 카테고리별 기본 색상
  String _getDefaultColorForCategory(String category) {
    switch (category) {
      case EventCategory.work:
        return '#2196F3'; // 파란색
      case EventCategory.personal:
        return '#4CAF50'; // 초록색
      case EventCategory.health:
        return '#FF9800'; // 주황색
      case EventCategory.social:
        return '#E91E63'; // 핑크색
      case EventCategory.education:
        return '#9C27B0'; // 보라색
      case EventCategory.travel:
        return '#00BCD4'; // 청록색
      case EventCategory.other:
      default:
        return '#607D8B'; // 회색
    }
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
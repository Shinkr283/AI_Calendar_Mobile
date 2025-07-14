import 'package:intl/intl.dart';
import '../models/event.dart';
import 'event_service.dart';
import 'chat_gemini_service.dart';

class CalendarService {
  static final CalendarService _instance = CalendarService._internal();
  factory CalendarService() => _instance;
  CalendarService._internal();

  // 캘린더 관련 Function declarations
  static const Map<String, dynamic> getCalendarEventsFunction = {
    'name': 'getCalendarEvents',
    'description': '특정 날짜 또는 기간의 캘린더 일정을 조회합니다.',
    'parameters': {
      'type': 'object',
      'properties': {
        'date': {
          'type': 'string',
          'description': '조회할 날짜 (YYYY-MM-DD 형식, 예: 2024-01-15)'
        },
        'startDate': {
          'type': 'string',
          'description': '시작 날짜 (YYYY-MM-DD 형식, 기간 조회시 사용)'
        },
        'endDate': {
          'type': 'string',
          'description': '종료 날짜 (YYYY-MM-DD 형식, 기간 조회시 사용)'
        },
        'type': {
          'type': 'string',
          'description': '조회 타입',
          'enum': ['today', 'week', 'month', 'custom']
        }
      },
      'required': ['type']
    }
  };

  static const Map<String, dynamic> createCalendarEventFunction = {
    'name': 'createCalendarEvent',
    'description': '새로운 캘린더 일정을 생성합니다.',
    'parameters': {
      'type': 'object',
      'properties': {
        'title': {
          'type': 'string',
          'description': '일정 제목'
        },
        'description': {
          'type': 'string',
          'description': '일정 설명'
        },
        'startDate': {
          'type': 'string',
          'description': '시작 날짜 (YYYY-MM-DD 형식)'
        },
        'startTime': {
          'type': 'string',
          'description': '시작 시간 (HH:MM 형식, 예: 14:30)'
        },
        'endDate': {
          'type': 'string',
          'description': '종료 날짜 (YYYY-MM-DD 형식)'
        },
        'endTime': {
          'type': 'string',
          'description': '종료 시간 (HH:MM 형식, 예: 15:30)'
        },
        'location': {
          'type': 'string',
          'description': '일정 장소'
        },
        'category': {
          'type': 'string',
          'description': '일정 카테고리',
          'enum': ['work', 'personal', 'health', 'study', 'social', 'travel', 'other']
        },
        'priority': {
          'type': 'integer',
          'description': '우선순위 (1: 낮음, 2: 보통, 3: 높음)'
        },
        'isAllDay': {
          'type': 'boolean',
          'description': '종일 일정 여부'
        }
      },
      'required': ['title', 'startDate', 'startTime', 'endDate', 'endTime']
    }
  };

  static const Map<String, dynamic> updateCalendarEventFunction = {
    'name': 'updateCalendarEvent',
    'description': '기존 캘린더 일정을 수정합니다.',
    'parameters': {
      'type': 'object',
      'properties': {
        'eventId': {
          'type': 'string',
          'description': '수정할 일정의 ID'
        },
        'title': {
          'type': 'string',
          'description': '일정 제목'
        },
        'description': {
          'type': 'string',
          'description': '일정 설명'
        },
        'startDate': {
          'type': 'string',
          'description': '시작 날짜 (YYYY-MM-DD 형식)'
        },
        'startTime': {
          'type': 'string',
          'description': '시작 시간 (HH:MM 형식)'
        },
        'endDate': {
          'type': 'string',
          'description': '종료 날짜 (YYYY-MM-DD 형식)'
        },
        'endTime': {
          'type': 'string',
          'description': '종료 시간 (HH:MM 형식)'
        },
        'location': {
          'type': 'string',
          'description': '일정 장소'
        }
      },
      'required': ['eventId']
    }
  };

  static const Map<String, dynamic> deleteCalendarEventFunction = {
    'name': 'deleteCalendarEvent',
    'description': '캘린더 일정을 삭제합니다.',
    'parameters': {
      'type': 'object',
      'properties': {
        'eventId': {
          'type': 'string',
          'description': '삭제할 일정의 ID'
        }
      },
      'required': ['eventId']
    }
  };

  // 캘린더 관련 모든 functions 목록
  static List<Map<String, dynamic>> get functions => [
    getCalendarEventsFunction,
    createCalendarEventFunction,
    updateCalendarEventFunction,
    deleteCalendarEventFunction,
  ];

  // 캘린더 Function call 처리
  Future<Map<String, dynamic>> handleFunctionCall(GeminiFunctionCall call) async {
    switch (call.name) {
      case 'getCalendarEvents':
        return await _handleGetCalendarEvents(call.args);
      case 'createCalendarEvent':
        return await _handleCreateCalendarEvent(call.args);
      case 'updateCalendarEvent':
        return await _handleUpdateCalendarEvent(call.args);
      case 'deleteCalendarEvent':
        return await _handleDeleteCalendarEvent(call.args);
      default:
        return {'status': '오류: 알 수 없는 캘린더 함수입니다.'};
    }
  }

  // 일정 조회 처리
  Future<Map<String, dynamic>> _handleGetCalendarEvents(Map<String, dynamic> args) async {
    try {
      final eventService = EventService();
      final type = args['type'] as String;
      var events = <dynamic>[];
      
      switch (type) {
        case 'today':
          events = await eventService.getTodayEvents();
          break;
        case 'week':
          final now = DateTime.now();
          final weekStart = now.subtract(Duration(days: now.weekday - 1));
          events = await eventService.getEventsForWeek(weekStart);
          break;
        case 'month':
          events = await eventService.getEventsForMonth(DateTime.now());
          break;
        case 'custom':
          final startDate = args['startDate'] as String?;
          final endDate = args['endDate'] as String?;
          if (startDate != null && endDate != null) {
            events = await eventService.getEvents(
              startDate: DateTime.parse(startDate),
              endDate: DateTime.parse(endDate),
            );
          }
          break;
      }
      
      if (events.isEmpty) {
        return {'status': '해당 기간에 일정이 없습니다.'};
      }
      
      final eventList = events.map((dynamic e) => {
        'id': e?.id ?? '',
        'title': e?.title ?? '',
        'description': e?.description ?? '',
        'startTime': e?.startTime != null ? DateFormat('yyyy-MM-dd HH:mm').format(e.startTime) : '',
        'endTime': e?.endTime != null ? DateFormat('yyyy-MM-dd HH:mm').format(e.endTime) : '',
        'location': e?.location ?? '',
        'category': e?.category ?? '',
      }).toList();
      
      return {
        'status': '${events.length}개의 일정을 찾았습니다.',
        'events': eventList,
      };
    } catch (e) {
      return {'status': '오류: 일정을 조회하는 중 문제가 발생했습니다: $e'};
    }
  }

  // 일정 생성 처리
  Future<Map<String, dynamic>> _handleCreateCalendarEvent(Map<String, dynamic> args) async {
    try {
      final eventService = EventService();
      final title = args['title'] as String;
      final description = args['description'] as String? ?? '';
      final startDate = args['startDate'] as String;
      final startTime = args['startTime'] as String;
      final endDate = args['endDate'] as String;
      final endTime = args['endTime'] as String;
      final location = args['location'] as String? ?? '';
      final category = args['category'] as String? ?? 'personal';
      final priority = args['priority'] as int? ?? 2;
      final isAllDay = args['isAllDay'] as bool? ?? false;
      
      // 날짜 시간 파싱
      final startDateTime = DateTime.parse('$startDate $startTime:00');
      final endDateTime = DateTime.parse('$endDate $endTime:00');
      
      final event = await eventService.createEvent(
        title: title,
        description: description,
        startTime: startDateTime,
        endTime: endDateTime,
        location: location,
        category: category,
        priority: priority,
        isAllDay: isAllDay,
      );
      
      return {
        'status': '일정이 성공적으로 생성되었습니다.',
        'eventId': event.id,
        'title': event.title,
        'startTime': DateFormat('yyyy-MM-dd HH:mm').format(event.startTime),
      };
    } catch (e) {
      return {'status': '오류: 일정을 생성하는 중 문제가 발생했습니다: $e'};
    }
  }

  // 일정 수정 처리
  Future<Map<String, dynamic>> _handleUpdateCalendarEvent(Map<String, dynamic> args) async {
    try {
      final eventService = EventService();
      final eventId = args['eventId'] as String;
      final existingEvent = await eventService.getEvent(eventId);
      
      if (existingEvent == null) {
        return {'status': '오류: 해당 ID의 일정을 찾을 수 없습니다.'};
      }
      
      // 수정할 필드들 확인 및 업데이트
      final title = args['title'] as String? ?? existingEvent.title;
      final description = args['description'] as String? ?? existingEvent.description;
      final location = args['location'] as String? ?? existingEvent.location;
      
      DateTime startDateTime = existingEvent.startTime;
      DateTime endDateTime = existingEvent.endTime;
      
      if (args['startDate'] != null && args['startTime'] != null) {
        final startDate = args['startDate'] as String;
        final startTime = args['startTime'] as String;
        startDateTime = DateTime.parse('$startDate $startTime:00');
      }
      
      if (args['endDate'] != null && args['endTime'] != null) {
        final endDate = args['endDate'] as String;
        final endTime = args['endTime'] as String;
        endDateTime = DateTime.parse('$endDate $endTime:00');
      }
      
      final updatedEvent = existingEvent.copyWith(
        title: title,
        description: description,
        startTime: startDateTime,
        endTime: endDateTime,
        location: location,
      );
      
      await eventService.updateEvent(updatedEvent);
      
      return {
        'status': '일정이 성공적으로 수정되었습니다.',
        'eventId': updatedEvent.id,
        'title': updatedEvent.title,
      };
    } catch (e) {
      return {'status': '오류: 일정을 수정하는 중 문제가 발생했습니다: $e'};
    }
  }

  // 일정 삭제 처리
  Future<Map<String, dynamic>> _handleDeleteCalendarEvent(Map<String, dynamic> args) async {
    try {
      final eventService = EventService();
      final eventId = args['eventId'] as String;
      final existingEvent = await eventService.getEvent(eventId);
      
      if (existingEvent == null) {
        return {'status': '오류: 해당 ID의 일정을 찾을 수 없습니다.'};
      }
      
      final success = await eventService.deleteEvent(eventId);
      
      if (success) {
        return {
          'status': '일정이 성공적으로 삭제되었습니다.',
          'deletedTitle': existingEvent.title,
        };
      } else {
        return {'status': '오류: 일정 삭제에 실패했습니다.'};
      }
    } catch (e) {
      return {'status': '오류: 일정을 삭제하는 중 문제가 발생했습니다: $e'};
    }
  }
} 
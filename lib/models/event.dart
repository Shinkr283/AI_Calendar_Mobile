import 'package:json_annotation/json_annotation.dart';

part 'event.g.dart';

@JsonSerializable()
class Event {
  final String id;
  final String title;
  final String description;
  final DateTime startTime;
  final DateTime endTime;
  final String location;
  final String category;
  final int priority; // 1: 낮음, 2: 보통, 3: 높음
  final bool isAllDay;
  final String? recurrenceRule; // 반복 일정 규칙
  final List<String> attendees; // 참석자 목록
  final String color; // 일정 색상 (hex 코드)
  final bool isCompleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Event({
    required this.id,
    required this.title,
    required this.description,
    required this.startTime,
    required this.endTime,
    required this.location,
    required this.category,
    required this.priority,
    required this.isAllDay,
    this.recurrenceRule,
    required this.attendees,
    required this.color,
    required this.isCompleted,
    required this.createdAt,
    required this.updatedAt,
  });

  // JSON 직렬화/역직렬화
  factory Event.fromJson(Map<String, dynamic> json) => _$EventFromJson(json);
  Map<String, dynamic> toJson() => _$EventToJson(this);

  // 데이터베이스용 Map 변환
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'startTime': startTime.millisecondsSinceEpoch,
      'endTime': endTime.millisecondsSinceEpoch,
      'location': location,
      'category': category,
      'priority': priority,
      'isAllDay': isAllDay ? 1 : 0,
      'recurrenceRule': recurrenceRule,
      'attendees': attendees.join(','), // 쉼표로 구분된 문자열로 저장
      'color': color,
      'isCompleted': isCompleted ? 1 : 0,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  // 데이터베이스 Map에서 객체 생성
  factory Event.fromMap(Map<String, dynamic> map) {
    return Event(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String,
      startTime: DateTime.fromMillisecondsSinceEpoch(map['startTime'] as int),
      endTime: DateTime.fromMillisecondsSinceEpoch(map['endTime'] as int),
      location: map['location'] as String,
      category: map['category'] as String,
      priority: map['priority'] as int,
      isAllDay: (map['isAllDay'] as int) == 1,
      recurrenceRule: map['recurrenceRule'] as String?,
      attendees: map['attendees'] != null 
          ? (map['attendees'] as String).split(',').where((e) => e.isNotEmpty).toList()
          : [],
      color: map['color'] as String,
      isCompleted: (map['isCompleted'] as int) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int),
    );
  }

  // 객체 복사 (수정 시 사용)
  Event copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? startTime,
    DateTime? endTime,
    String? location,
    String? category,
    int? priority,
    bool? isAllDay,
    String? recurrenceRule,
    List<String>? attendees,
    String? color,
    bool? isCompleted,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Event(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      location: location ?? this.location,
      category: category ?? this.category,
      priority: priority ?? this.priority,
      isAllDay: isAllDay ?? this.isAllDay,
      recurrenceRule: recurrenceRule ?? this.recurrenceRule,
      attendees: attendees ?? this.attendees,
      color: color ?? this.color,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'Event(id: $id, title: $title, startTime: $startTime, endTime: $endTime)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Event && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

// 일정 카테고리 상수
class EventCategory {
  static const String work = 'work';
  static const String personal = 'personal';
  static const String health = 'health';
  static const String social = 'social';
  static const String education = 'education';
  static const String travel = 'travel';
  static const String other = 'other';

  static const List<String> all = [
    work,
    personal,
    health,
    social,
    education,
    travel,
    other,
  ];

  static String getDisplayName(String category) {
    switch (category) {
      case work:
        return '업무';
      case personal:
        return '개인';
      case health:
        return '건강';
      case social:
        return '사교';
      case education:
        return '교육';
      case travel:
        return '여행';
      case other:
        return '기타';
      default:
        return '기타';
    }
  }
}

// 일정 우선순위 상수
class EventPriority {
  static const int low = 1;
  static const int medium = 2;
  static const int high = 3;

  static String getDisplayName(int priority) {
    switch (priority) {
      case low:
        return '낮음';
      case medium:
        return '보통';
      case high:
        return '높음';
      default:
        return '보통';
    }
  }
} 
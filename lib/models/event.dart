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
  final double? locationLatitude; // 🗺️ 장소 위도
  final double? locationLongitude; // 🗺️ 장소 경도
  final String? googleEventId; // Google Calendar Event ID (동기화용)
  final bool isCompleted;
  final int alarmMinutesBefore; // 알림 시간 (분 단위, 0이면 알림 없음)
  final DateTime createdAt;
  final DateTime updatedAt;

  const Event({
    required this.id,
    required this.title,
    required this.description,
    required this.startTime,
    required this.endTime,
    required this.location,
    this.locationLatitude,
    this.locationLongitude,
    this.googleEventId,
    required this.isCompleted,
    required this.alarmMinutesBefore,
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
      'locationLatitude': locationLatitude,
      'locationLongitude': locationLongitude,
      'googleEventId': googleEventId,
      'isCompleted': isCompleted ? 1 : 0,
      'alarmMinutesBefore': alarmMinutesBefore,
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
      isCompleted: (map['isCompleted'] as int) == 1,
      googleEventId: map['googleEventId'] as String?,
      alarmMinutesBefore: (map['alarmMinutesBefore'] as int?) ?? 10, // 기본값 10분
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
    double? locationLatitude,
    double? locationLongitude,
    String? googleEventId,
    bool? isCompleted,
    int? alarmMinutesBefore,
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
      locationLatitude: locationLatitude ?? this.locationLatitude,
      locationLongitude: locationLongitude ?? this.locationLongitude,
      googleEventId: googleEventId ?? this.googleEventId,
      isCompleted: isCompleted ?? this.isCompleted,
      alarmMinutesBefore: alarmMinutesBefore ?? this.alarmMinutesBefore,
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
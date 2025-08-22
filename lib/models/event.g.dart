// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'event.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Event _$EventFromJson(Map<String, dynamic> json) => Event(
  id: json['id'] as String,
  title: json['title'] as String,
  description: json['description'] as String,
  startTime: DateTime.parse(json['startTime'] as String),
  endTime: DateTime.parse(json['endTime'] as String),
  location: json['location'] as String,
  locationLatitude: (json['locationLatitude'] as num?)?.toDouble(),
  locationLongitude: (json['locationLongitude'] as num?)?.toDouble(),
  isCompleted: json['isCompleted'] as bool,
  alarmMinutesBefore: (json['alarmMinutesBefore'] as num).toInt(),
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$EventToJson(Event instance) => <String, dynamic>{
  'id': instance.id,
  'title': instance.title,
  'description': instance.description,
  'startTime': instance.startTime.toIso8601String(),
  'endTime': instance.endTime.toIso8601String(),
  'location': instance.location,
  'locationLatitude': instance.locationLatitude,
  'locationLongitude': instance.locationLongitude,
  'isCompleted': instance.isCompleted,
  'alarmMinutesBefore': instance.alarmMinutesBefore,
  'createdAt': instance.createdAt.toIso8601String(),
  'updatedAt': instance.updatedAt.toIso8601String(),
};

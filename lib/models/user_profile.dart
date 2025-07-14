import 'package:flutter/foundation.dart';
import 'package:json_annotation/json_annotation.dart';

part 'user_profile.g.dart';

@JsonSerializable()
@immutable
class UserProfile {
  final String id;
  final String name;
  final String email;
  final String? profileImageUrl;
  final String? phoneNumber;
  final String? mbtiType; // MBTI 성격 유형
  final Map<String, dynamic> preferences; // 사용자 선호도 설정
  final String timezone;
  final String language;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserProfile({
    required this.id,
    required this.name,
    required this.email,
    this.profileImageUrl,
    this.phoneNumber,
    this.mbtiType,
    required this.preferences,
    required this.timezone,
    required this.language,
    required this.createdAt,
    required this.updatedAt,
  });

  // JSON 직렬화/역직렬화
  factory UserProfile.fromJson(Map<String, dynamic> json) => _$UserProfileFromJson(json);
  Map<String, dynamic> toJson() => _$UserProfileToJson(this);

  // 데이터베이스용 Map 변환
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'profileImageUrl': profileImageUrl,
      'phoneNumber': phoneNumber,
      'mbtiType': mbtiType,
      'preferences': preferences.toString(), // JSON 문자열로 저장
      'timezone': timezone,
      'language': language,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  // 데이터베이스 Map에서 객체 생성
  factory UserProfile.fromMap(Map<String, dynamic> map) {
    Map<String, dynamic> preferences = {};
    if (map['preferences'] != null) {
      // JSON 문자열을 Map으로 변환하는 로직 필요
      // 간단하게 빈 Map으로 초기화
      preferences = {};
    }

    return UserProfile(
      id: map['id'] as String,
      name: map['name'] as String,
      email: map['email'] as String,
      profileImageUrl: map['profileImageUrl'] as String?,
      phoneNumber: map['phoneNumber'] as String?,
      mbtiType: map['mbtiType'] as String?,
      preferences: preferences,
      timezone: map['timezone'] as String,
      language: map['language'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int),
    );
  }

  // 객체 복사 (수정 시 사용)
  UserProfile copyWith({
    String? id,
    String? name,
    String? email,
    String? profileImageUrl,
    String? phoneNumber,
    String? mbtiType,
    Map<String, dynamic>? preferences,
    String? timezone,
    String? language,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      mbtiType: mbtiType ?? this.mbtiType,
      preferences: preferences ?? this.preferences,
      timezone: timezone ?? this.timezone,
      language: language ?? this.language,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'UserProfile(id: $id, name: $name, email: $email, mbtiType: $mbtiType)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserProfile && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// 사용자 선호도 설정을 관리하는 클래스
class UserPreferences {
  static const String themeMode = 'themeMode'; // 'light', 'dark', 'system'
  static const String defaultEventDuration = 'defaultEventDuration';
  static const String workingHoursStart = 'workingHoursStart';
  static const String workingHoursEnd = 'workingHoursEnd';
  static const String weekStartDay = 'weekStartDay';
  static const String notificationEnabled = 'notificationEnabled';
  static const String defaultNotificationTime = 'defaultNotificationTime';
  static const String aiPersonality = 'aiPersonality'; // AI 성격 키
  static const String locationEnabled = 'locationEnabled';
  static const String weatherEnabled = 'weatherEnabled';

  static Map<String, dynamic> getDefaultPreferences() {
    return {
      themeMode: 'system',
      workingHoursStart: 9,
      workingHoursEnd: 18,
      notificationEnabled: true,
      defaultNotificationTime: 10,
      locationEnabled: true,
      weatherEnabled: true,
      weekStartDay: 1, // 1: Monday
      defaultEventDuration: 30,
      aiPersonality: 'friendly', // 기본 AI 성격
    };
  }
}

/// 사용자 활동 통계를 위한 클래스
@immutable
class UserStats {
  final int totalEvents;
  final int completedEvents;
  final int upcomingEvents;
  final int totalChatMessages;
  final DateTime memberSince;

  const UserStats({
    required this.totalEvents,
    required this.completedEvents,
    required this.upcomingEvents,
    required this.totalChatMessages,
    required this.memberSince,
  });
} 
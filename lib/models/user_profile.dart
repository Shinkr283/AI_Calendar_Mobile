import 'package:json_annotation/json_annotation.dart';

part 'user_profile.g.dart';

@JsonSerializable()
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

// 사용자 선호도 설정 클래스
class UserPreferences {
  static const String themeMode = 'themeMode'; // 'light', 'dark', 'system'
  static const String defaultEventDuration = 'defaultEventDuration'; // 기본 일정 시간 (분)
  static const String workingHoursStart = 'workingHoursStart'; // 근무 시작 시간
  static const String workingHoursEnd = 'workingHoursEnd'; // 근무 종료 시간
  static const String weekStartDay = 'weekStartDay'; // 주 시작 요일 (0: 일요일, 1: 월요일)
  static const String notificationEnabled = 'notificationEnabled'; // 알림 활성화
  static const String defaultNotificationTime = 'defaultNotificationTime'; // 기본 알림 시간 (분 전)
  static const String aiPersonality = 'aiPersonality'; // AI 성격 설정
  static const String locationEnabled = 'locationEnabled'; // 위치 서비스 활성화
  static const String weatherEnabled = 'weatherEnabled'; // 날씨 정보 활성화

  // 기본 설정값
  static Map<String, dynamic> getDefaultPreferences() {
    return {
      themeMode: 'system',
      defaultEventDuration: 60, // 1시간
      workingHoursStart: 9, // 오전 9시
      workingHoursEnd: 18, // 오후 6시
      weekStartDay: 1, // 월요일
      notificationEnabled: true,
      defaultNotificationTime: 15, // 15분 전
      aiPersonality: 'friendly', // 친근한 성격
      locationEnabled: false,
      weatherEnabled: true,
    };
  }
}

// MBTI 타입 관련 유틸리티
class MBTIType {
  static const List<String> allTypes = [
    'INTJ', 'INTP', 'ENTJ', 'ENTP',
    'INFJ', 'INFP', 'ENFJ', 'ENFP',
    'ISTJ', 'ISFJ', 'ESTJ', 'ESFJ',
    'ISTP', 'ISFP', 'ESTP', 'ESFP',
  ];

  static bool isValid(String? mbtiType) {
    return mbtiType != null && allTypes.contains(mbtiType.toUpperCase());
  }

  static String getDescription(String mbtiType) {
    switch (mbtiType.toUpperCase()) {
      case 'INTJ':
        return '전략가 - 상상력이 풍부하고 전략적인 사고를 하는 완벽주의자';
      case 'INTP':
        return '논리술사 - 지식을 갈망하는 혁신적인 발명가';
      case 'ENTJ':
        return '통솔자 - 대담하고 상상력이 풍부한 강력한 의지의 지도자';
      case 'ENTP':
        return '변론가 - 영리하고 호기심이 많은 사색가';
      case 'INFJ':
        return '옹호자 - 선의의 옹호자이며 창의적이고 통찰력이 있는 이상주의자';
      case 'INFP':
        return '중재자 - 항상 선을 행할 준비가 되어 있는 시적이고 친절한 이타주의자';
      case 'ENFJ':
        return '선도자 - 카리스마 있고 영감을 주는 지도자';
      case 'ENFP':
        return '활동가 - 열정적이고 창의적인 사회자';
      case 'ISTJ':
        return '논리주의자 - 실용적이고 사실에 근거한 신뢰할 수 있는 사람';
      case 'ISFJ':
        return '수호자 - 따뜻한 마음과 헌신적인 수호자';
      case 'ESTJ':
        return '경영자 - 뛰어난 관리자이며 전통과 질서를 중시하는 사람';
      case 'ESFJ':
        return '집정관 - 배려심이 많고 사교적이며 인기가 많은 사람';
      case 'ISTP':
        return '만능재주꾼 - 대담하고 실용적인 실험정신이 강한 사람';
      case 'ISFP':
        return '모험가 - 유연하고 매력적인 예술가';
      case 'ESTP':
        return '사업가 - 영리하고 에너지 넘치며 인식이 뛰어난 사람';
      case 'ESFP':
        return '연예인 - 자발적이고 열정적이며 사교적인 사람';
      default:
        return '알 수 없는 유형';
    }
  }

  // MBTI 기반 AI 성격 추천
  static String getRecommendedAIPersonality(String mbtiType) {
    switch (mbtiType.toUpperCase()) {
      case 'INTJ':
      case 'INTP':
        return 'analytical'; // 분석적
      case 'ENTJ':
      case 'ESTJ':
        return 'efficient'; // 효율적
      case 'INFJ':
      case 'INFP':
        return 'empathetic'; // 공감적
      case 'ENFJ':
      case 'ENFP':
        return 'encouraging'; // 격려하는
      case 'ISTJ':
      case 'ISFJ':
        return 'supportive'; // 지원적
      case 'ESFJ':
      case 'ESFP':
        return 'friendly'; // 친근한
      case 'ISTP':
      case 'ESTP':
        return 'practical'; // 실용적
      case 'ISFP':
      case 'ENTP':
        return 'creative'; // 창의적
      default:
        return 'friendly'; // 기본값
    }
  }
} 
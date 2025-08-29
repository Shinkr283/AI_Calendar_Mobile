import 'dart:async';
import '../models/user_profile.dart';
import '../models/chat_mbti.dart';
import 'database_service.dart';

class UserService {
  static final UserService _instance = UserService._internal();
  final DatabaseService _databaseService = DatabaseService();
  
  factory UserService() => _instance;
  
  UserService._internal();

  // 현재 사용자 정보 (싱글톤 패턴)
  UserProfile? _currentUser;

  // 사용자 생성
  Future<UserProfile> createUser({
    required String email,
    required String name,
    String? profileImageUrl,
    String? phoneNumber,
    String? mbtiType,
    Map<String, dynamic>? preferences,
    String timezone = 'Asia/Seoul',
    String language = 'ko',
  }) async {
    final user = UserProfile(
      email: email,
      name: name,
      profileImageUrl: profileImageUrl,
      phoneNumber: phoneNumber,
      mbtiType: mbtiType,
      preferences: preferences ?? UserPreferences.getDefaultPreferences(),
      timezone: timezone,
      language: language,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _databaseService.insertUserProfile(user);
    _currentUser = user;
    return user;
  }

  // 이메일로 사용자 조회
  Future<UserProfile?> getUserByEmail(String email) async {
    return await _databaseService.getUserProfileByEmail(email);
  }

  // 현재 사용자 조회
  Future<UserProfile?> getCurrentUser() async {
    if (_currentUser != null) {
      return _currentUser;
    }
    
    // 데이터베이스에서 첫 번째 사용자를 현재 사용자로 설정
    // 실제 앱에서는 로그인 시스템과 연동해야 함
    _currentUser = await _databaseService.getFirstUserProfile(); //추가
    return _currentUser;
  }

  // 사용자 정보 업데이트
  Future<UserProfile> updateUser(UserProfile user) async {
    final updatedUser = user.copyWith(
      updatedAt: DateTime.now(),
    );
    await _databaseService.updateUserProfile(updatedUser);
    
    if (_currentUser?.email == user.email) {
      _currentUser = updatedUser;
    }
    
    return updatedUser;
  }

  // 사용자 삭제
  Future<bool> deleteUser(String email) async {
    final result = await _databaseService.deleteUserProfile(email);
    
    if (_currentUser?.email == email) {
      _currentUser = null;
    }
    
    return result > 0;
  }

  // 사용자 선호도 업데이트
  Future<UserProfile?> updateUserPreferences(Map<String, dynamic> preferences) async {
    final currentUser = await getCurrentUser();
    if (currentUser != null) {
      final updatedPreferences = Map<String, dynamic>.from(currentUser.preferences);
      updatedPreferences.addAll(preferences);
      
      return await updateUser(currentUser.copyWith(
        preferences: updatedPreferences,
      ));
    }
    return null;
  }

  // 특정 선호도 설정 조회
  T? getPreference<T>(String key, {T? defaultValue}) {
    if (_currentUser?.preferences.containsKey(key) == true) {
      return _currentUser!.preferences[key] as T?;
    }
    return defaultValue;
  }

  // 특정 선호도 설정 업데이트
  Future<void> setPreference<T>(String key, T value) async {
    final currentUser = await getCurrentUser();
    if (currentUser != null) {
      final updatedPreferences = Map<String, dynamic>.from(currentUser.preferences);
      updatedPreferences[key] = value;
      
      await updateUser(currentUser.copyWith(
        preferences: updatedPreferences,
      ));
    }
  }

  // MBTI 타입 설정
  Future<UserProfile?> setMBTIType(String mbtiType) async {
    final currentUser = await getCurrentUser();
    if (currentUser != null && MbtiData.isValid(mbtiType)) {
      final recommendedPersonality = MbtiData.getChatbotProfile(mbtiType).personalityKeyword; // MBTI에 따른 AI 성격 자동 설정 (수정된 부분)
      
      final updatedUser = currentUser.copyWith(
        mbtiType: mbtiType.toUpperCase(),
      );
      
      // AI 성격도 함께 업데이트
      await setPreference(UserPreferences.aiPersonality, recommendedPersonality);
      
      return await updateUser(updatedUser);
    }
    return null;
  }

  // 테마 모드 설정
  Future<void> setThemeMode(String themeMode) async {
    await setPreference(UserPreferences.themeMode, themeMode);
  }

  // 근무 시간 설정
  Future<void> setWorkingHours(int startHour, int endHour) async {
    await setPreference(UserPreferences.workingHoursStart, startHour);
    await setPreference(UserPreferences.workingHoursEnd, endHour);
  }

  // 알림 설정
  Future<void> setNotificationSettings({
    bool? enabled,
    int? defaultTime,
  }) async {
    if (enabled != null) {
      await setPreference(UserPreferences.notificationEnabled, enabled);
    }
    if (defaultTime != null) {
      await setPreference(UserPreferences.defaultNotificationTime, defaultTime);
    }
  }

  // 위치 서비스 설정
  Future<void> setLocationEnabled(bool enabled) async {
    await setPreference(UserPreferences.locationEnabled, enabled);
  }

  // 날씨 정보 설정
  Future<void> setWeatherEnabled(bool enabled) async {
    await setPreference(UserPreferences.weatherEnabled, enabled);
  }

  // 주 시작 요일 설정
  Future<void> setWeekStartDay(int day) async {
    await setPreference(UserPreferences.weekStartDay, day);
  }

  // 기본 일정 시간 설정
  Future<void> setDefaultEventDuration(int minutes) async {
    await setPreference(UserPreferences.defaultEventDuration, minutes);
  }

  // AI 성격 설정
  Future<void> setAIPersonality(String personality) async {
    await setPreference(UserPreferences.aiPersonality, personality);
  }

  // 사용자 통계 정보
  Future<UserStats> getUserStats() async {
    final currentUser = await getCurrentUser();
    if (currentUser == null) {
      return UserStats(
        totalEvents: 0,
        completedEvents: 0,
        upcomingEvents: 0,
        totalChatMessages: 0,
        memberSince: DateTime.now(),
      );
    }

    // 통계 계산 로직 (실제로는 각 서비스에서 데이터를 가져와야 함)
    return UserStats(
      totalEvents: 0, // EventService에서 가져와야 함
      completedEvents: 0,
      upcomingEvents: 0,
      totalChatMessages: 0, // ChatService에서 가져와야 함
      memberSince: currentUser.createdAt,
    );
  }

  // 사용자 설정 초기화
  Future<void> resetUserPreferences() async {
    final currentUser = await getCurrentUser();
    if (currentUser != null) {
      await updateUser(currentUser.copyWith(
        preferences: UserPreferences.getDefaultPreferences(),
      ));
    }
  }

  // 사용자 프로필 이미지 업데이트
  Future<UserProfile?> updateProfileImage(String imageUrl) async {
    final currentUser = await getCurrentUser();
    if (currentUser != null) {
      return await updateUser(currentUser.copyWith(
        profileImageUrl: imageUrl,
      ));
    }
    return null;
  }

  // 사용자 연락처 정보 업데이트
  Future<UserProfile?> updateContactInfo({
    String? phoneNumber,
    String? email,
  }) async {
    final currentUser = await getCurrentUser();
    if (currentUser != null) {
      return await updateUser(currentUser.copyWith(
        phoneNumber: phoneNumber ?? currentUser.phoneNumber,
        email: email ?? currentUser.email,
      ));
    }
    return null;
  }

  // 사용자 언어 설정
  Future<UserProfile?> setLanguage(String language) async {
    final currentUser = await getCurrentUser();
    if (currentUser != null) {
      return await updateUser(currentUser.copyWith(
        language: language,
      ));
    }
    return null;
  }

  // 사용자 시간대 설정
  Future<UserProfile?> setTimezone(String timezone) async {
    final currentUser = await getCurrentUser();
    if (currentUser != null) {
      return await updateUser(currentUser.copyWith(
        timezone: timezone,
      ));
    }
    return null;
  }

  // 현재 사용자 설정 (로그인 시 사용)
  void setCurrentUser(UserProfile user) {
    _currentUser = user;
  }

  // 로그아웃
  void logout() {
    _currentUser = null;
  }

  // 사용자 존재 여부 확인
  Future<bool> userExists(String email) async {
    final user = await getUserByEmail(email);
    return user != null;
  }
}

// 사용자 통계 클래스
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

  int get pendingEvents => totalEvents - completedEvents;
  double get completionRate => totalEvents > 0 ? (completedEvents / totalEvents) * 100 : 0;
  int get daysSinceMember => DateTime.now().difference(memberSince).inDays;

  @override
  String toString() {
    return 'UserStats(총 일정: $totalEvents, 완료: $completedEvents, 예정: $upcomingEvents, 채팅: $totalChatMessages)';
  }
} 
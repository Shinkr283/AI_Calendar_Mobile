import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

class SettingsService {
  static const String _weekStartDayKey = 'week_start_day';
  static const String _isDarkModeKey = 'is_dark_mode';
  static const String _isCalendarSyncedKey = 'is_calendar_synced';
  static const String _isDailyNotificationEnabledKey = 'is_daily_notification_enabled';
  static const String _notificationTimeHourKey = 'notification_time_hour';
  static const String _notificationTimeMinuteKey = 'notification_time_minute';

  // 싱글톤 패턴
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  SharedPreferences? _prefs;

  Future<void> _initPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  // 주 시작 요일 (0: 일요일, 1: 월요일)
  Future<int> getWeekStartDay() async {
    await _initPrefs();
    return _prefs!.getInt(_weekStartDayKey) ?? 0;
  }

  Future<void> setWeekStartDay(int day) async {
    await _initPrefs();
    await _prefs!.setInt(_weekStartDayKey, day);
  }

  // 다크 모드 설정
  Future<bool> getIsDarkMode() async {
    await _initPrefs();
    return _prefs!.getBool(_isDarkModeKey) ?? false;
  }

  Future<void> setIsDarkMode(bool isDark) async {
    await _initPrefs();
    await _prefs!.setBool(_isDarkModeKey, isDark);
  }

  // 구글 캘린더 동기화 상태
  Future<bool> getIsCalendarSynced() async {
    await _initPrefs();
    return _prefs!.getBool(_isCalendarSyncedKey) ?? false;
  }

  Future<void> setIsCalendarSynced(bool isSynced) async {
    await _initPrefs();
    await _prefs!.setBool(_isCalendarSyncedKey, isSynced);
  }

  // 하루 일정 알림 활성화 여부
  Future<bool> getIsDailyNotificationEnabled() async {
    await _initPrefs();
    return _prefs!.getBool(_isDailyNotificationEnabledKey) ?? true;
  }

  Future<void> setIsDailyNotificationEnabled(bool isEnabled) async {
    await _initPrefs();
    await _prefs!.setBool(_isDailyNotificationEnabledKey, isEnabled);
  }

  // 알림 시간
  Future<TimeOfDay> getNotificationTime() async {
    await _initPrefs();
    final hour = _prefs!.getInt(_notificationTimeHourKey) ?? 9;
    final minute = _prefs!.getInt(_notificationTimeMinuteKey) ?? 0;
    return TimeOfDay(hour: hour, minute: minute);
  }

  Future<void> setNotificationTime(TimeOfDay time) async {
    await _initPrefs();
    await _prefs!.setInt(_notificationTimeHourKey, time.hour);
    await _prefs!.setInt(_notificationTimeMinuteKey, time.minute);
  }

  // 모든 설정을 한 번에 로드
  Future<Map<String, dynamic>> getAllSettings() async {
    return {
      'weekStartDay': await getWeekStartDay(),
      'isDarkMode': await getIsDarkMode(),
      'isCalendarSynced': await getIsCalendarSynced(),
      'isDailyNotificationEnabled': await getIsDailyNotificationEnabled(),
      'notificationTime': await getNotificationTime(),
    };
  }

  // 설정 초기화
  Future<void> resetAllSettings() async {
    await _initPrefs();
    await _prefs!.clear();
  }
}

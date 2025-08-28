import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'native_alarm_service.dart';
import 'event_service.dart';

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
    
    if (isEnabled) {
      // 하루 일정 알림 활성화 시 알림 예약
      final time = await getNotificationTime();
      await _scheduleDailyNotification(time);
    } else {
      // 하루 일정 알림 비활성화 시 알림 취소
      await _cancelDailyNotification();
    }
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
    
    // 알림 시간이 변경되면 하루 일정 알림 재예약
    final isEnabled = await getIsDailyNotificationEnabled();
    if (isEnabled) {
      await _scheduleDailyNotification(time);
    }
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

  // 하루 일정 알림 예약
  Future<void> _scheduleDailyNotification(TimeOfDay time) async {
    try {
      // 기존 하루 일정 알림 취소
      await _cancelDailyNotification();
      
      // 오늘 해당 시간까지의 초 계산
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final targetTime = DateTime(
        today.year,
        today.month,
        today.day,
        time.hour,
        time.minute,
      );
      
      // 오늘 시간이 이미 지났으면 내일로 설정
      final notificationTime = targetTime.isBefore(now) 
          ? targetTime.add(const Duration(days: 1))
          : targetTime;
      
      // 오늘의 일정 가져오기
      final eventService = EventService();
      final todayEvents = await eventService.getTodayEvents();
      
      // 알림 메시지 생성
      String message;
      if (todayEvents.isEmpty) {
        message = '오늘은 일정이 없습니다.';
      } else {
        final eventCount = todayEvents.length;
        final firstEvent = todayEvents.first;
        final timeStr = '${firstEvent.startTime.hour.toString().padLeft(2, '0')}:${firstEvent.startTime.minute.toString().padLeft(2, '0')}';
        message = '오늘 일정 $eventCount개가 있습니다. 첫 번째 일정: $timeStr ${firstEvent.title}';
      }
      
      // 네이티브 알림 예약 (매일 반복)
      await NativeAlarmService.scheduleDailyNotification(
        title: '📅 AI 캘린더 - 오늘의 일정',
        body: message,
        hour: time.hour,
        minute: time.minute,
        notificationId: 10000, // 하루 일정 알림 전용 ID
      );
      
      print('✅ 하루 일정 알림 예약 완료: ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}');
    } catch (e) {
      print('❌ 하루 일정 알림 예약 실패: $e');
    }
  }

  // 하루 일정 알림 취소
  Future<void> _cancelDailyNotification() async {
    try {
      await NativeAlarmService.cancelNativeAlarm(10000);
      print('✅ 하루 일정 알림 취소 완료');
    } catch (e) {
      print('❌ 하루 일정 알림 취소 실패: $e');
    }
  }

  // 앱 시작 시 하루 일정 알림 복원
  Future<void> restoreDailyNotification() async {
    try {
      final isEnabled = await getIsDailyNotificationEnabled();
      if (isEnabled) {
        final time = await getNotificationTime();
        await _scheduleDailyNotification(time);
      }
    } catch (e) {
      print('❌ 하루 일정 알림 복원 실패: $e');
    }
  }
}

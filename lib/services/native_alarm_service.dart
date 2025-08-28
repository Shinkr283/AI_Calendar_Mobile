import 'package:flutter/services.dart';

class NativeAlarmService {
  static const platform = MethodChannel('native_alarm_channel');
  
  /// 네이티브 AlarmManager를 사용하여 알람 예약
  static Future<void> scheduleNativeAlarm({
    required String title,
    required String body,
    required int delaySeconds,
    int notificationId = 999,
  }) async {
    try {
      print('🚨 네이티브 알람 서비스 호출 시작');
      print('📝 제목: $title');
      print('📝 내용: $body');
      print('⏳ 지연시간: ${delaySeconds}초');
      print('🆔 알림 ID: $notificationId');
      
      final String result = await platform.invokeMethod('scheduleNativeAlarm', {
        'title': title,
        'body': body,
        'delaySeconds': delaySeconds,
        'notificationId': notificationId,
      });
      
      print('✅ $result');
    } on PlatformException catch (e) {
      print('❌ 네이티브 알람 예약 실패: ${e.message}');
      throw Exception('네이티브 알람 예약 실패: ${e.message}');
    }
  }
  
  /// 네이티브 알람 취소
  static Future<void> cancelNativeAlarm(int notificationId) async {
    try {
      print('🗑️ 네이티브 알람 취소 시작 (ID: $notificationId)');
      
      final String result = await platform.invokeMethod('cancelNativeAlarm', {
        'notificationId': notificationId,
      });
      
      print('✅ $result');
    } on PlatformException catch (e) {
      print('❌ 네이티브 알람 취소 실패: ${e.message}');
      throw Exception('네이티브 알람 취소 실패: ${e.message}');
    }
  }
  
  /// 10초 후 네이티브 테스트 알람
  static Future<void> scheduleNativeTestAlarm() async {
    await scheduleNativeAlarm(
      title: '🚨 네이티브 테스트 알람',
      body: '안드로이드 네이티브 AlarmManager로 생성된 알림입니다!',
      delaySeconds: 10,
      notificationId: 888,
    );
  }
  
  /// 5초 후 초고속 네이티브 테스트 알람
  static Future<void> scheduleQuickNativeTestAlarm() async {
    await scheduleNativeAlarm(
      title: '⚡ 초고속 네이티브 테스트',
      body: '5초 후 네이티브 알람입니다!',
      delaySeconds: 5,
      notificationId: 777,
    );
  }
  
  /// 즉시 네이티브 테스트 알람 (1초 후)
  static Future<void> scheduleImmediateTestAlarm() async {
    await scheduleNativeAlarm(
      title: '🔔 즉시 네이티브 테스트',
      body: '1초 후 즉시 확인용 알람입니다!',
      delaySeconds: 1,
      notificationId: 666,
    );
  }
  
  /// 강력한 전체화면 테스트 알람
  static Future<void> scheduleFullScreenTestAlarm() async {
    await scheduleNativeAlarm(
      title: '🚨 강력한 전체화면 테스트',
      body: '이 알림은 반드시 보여야 합니다!',
      delaySeconds: 2,
      notificationId: 555,
    );
  }

  /// 매일 반복되는 하루 일정 알림 예약
  static Future<void> scheduleDailyNotification({
    required String title,
    required String body,
    required int hour,
    required int minute,
    int notificationId = 10000,
  }) async {
    try {
      print('📅 매일 반복 알림 예약 시작');
      print('📝 제목: $title');
      print('📝 내용: $body');
      print('🕐 시간: ${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}');
      print('🆔 알림 ID: $notificationId');
      
      final String result = await platform.invokeMethod('scheduleDailyNotification', {
        'title': title,
        'body': body,
        'hour': hour,
        'minute': minute,
        'notificationId': notificationId,
      });
      
      print('✅ $result');
    } on PlatformException catch (e) {
      print('❌ 매일 반복 알림 예약 실패: ${e.message}');
      throw Exception('매일 반복 알림 예약 실패: ${e.message}');
    }
  }
}

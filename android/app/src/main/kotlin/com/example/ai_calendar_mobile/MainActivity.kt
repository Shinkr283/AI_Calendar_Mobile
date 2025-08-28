package com.example.ai_calendar_mobile

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Intent
import android.content.Context
import android.os.Build

class MainActivity : FlutterActivity() {
    private val CHANNEL = "native_alarm_channel"
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "scheduleNativeAlarm" -> {
                    val title = call.argument<String>("title") ?: "네이티브 테스트"
                    val body = call.argument<String>("body") ?: "네이티브 알림입니다"
                    val delaySeconds = call.argument<Int>("delaySeconds") ?: 10
                    val notificationId = call.argument<Int>("notificationId") ?: 999
                    
                    try {
                        scheduleNativeAlarm(title, body, delaySeconds, notificationId)
                        result.success("네이티브 알람 예약 성공")
                    } catch (e: Exception) {
                        result.error("ALARM_ERROR", "네이티브 알람 예약 실패: ${e.message}", null)
                    }
                }
                "cancelNativeAlarm" -> {
                    val notificationId = call.argument<Int>("notificationId") ?: 999
                    try {
                        cancelNativeAlarm(notificationId)
                        result.success("네이티브 알람 취소 성공")
                    } catch (e: Exception) {
                        result.error("CANCEL_ERROR", "네이티브 알람 취소 실패: ${e.message}", null)
                    }
                }
                "scheduleDailyNotification" -> {
                    val title = call.argument<String>("title") ?: "하루 일정 알림"
                    val body = call.argument<String>("body") ?: "오늘의 일정을 확인하세요"
                    val hour = call.argument<Int>("hour") ?: 9
                    val minute = call.argument<Int>("minute") ?: 0
                    val notificationId = call.argument<Int>("notificationId") ?: 10000
                    
                    try {
                        scheduleDailyNotification(title, body, hour, minute, notificationId)
                        result.success("매일 반복 알림 예약 성공")
                    } catch (e: Exception) {
                        result.error("DAILY_ALARM_ERROR", "매일 반복 알림 예약 실패: ${e.message}", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
    
    private fun scheduleNativeAlarm(title: String, body: String, delaySeconds: Int, notificationId: Int) {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        
        val intent = Intent(this, AlarmReceiver::class.java).apply {
            putExtra("title", title)
            putExtra("body", body)
            putExtra("notificationId", notificationId)
        }
        
        val pendingIntent = PendingIntent.getBroadcast(
            this,
            notificationId,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        val triggerTime = System.currentTimeMillis() + (delaySeconds * 1000)
        
        println("🚨 네이티브 알람 예약 시작")
        println("📅 현재 시간: ${System.currentTimeMillis()}")
        println("📅 예약 시간: $triggerTime")
        println("⏳ ${delaySeconds}초 후 알림 예정")
        
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                // 안드로이드 6.0+ - 가장 강력한 방식
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    triggerTime,
                    pendingIntent
                )
                println("✅ setExactAndAllowWhileIdle 사용")
            } else {
                // 안드로이드 6.0 미만
                alarmManager.setExact(
                    AlarmManager.RTC_WAKEUP,
                    triggerTime,
                    pendingIntent
                )
                println("✅ setExact 사용")
            }
            println("🎯 네이티브 알람 예약 완료!")
        } catch (e: Exception) {
            println("❌ 네이티브 알람 예약 실패: ${e.message}")
            throw e
        }
    }
    
    private fun cancelNativeAlarm(notificationId: Int) {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        
        val intent = Intent(this, AlarmReceiver::class.java)
        val pendingIntent = PendingIntent.getBroadcast(
            this,
            notificationId,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        alarmManager.cancel(pendingIntent)
        println("🗑️ 네이티브 알람 취소 완료 (ID: $notificationId)")
    }
    
    private fun scheduleDailyNotification(title: String, body: String, hour: Int, minute: Int, notificationId: Int) {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        
        // 기존 알림 취소
        cancelNativeAlarm(notificationId)
        
        val intent = Intent(this, AlarmReceiver::class.java).apply {
            putExtra("title", title)
            putExtra("body", body)
            putExtra("notificationId", notificationId)
            putExtra("isDaily", true) // 매일 반복 알림임을 표시
            putExtra("hour", hour)
            putExtra("minute", minute)
        }
        
        val pendingIntent = PendingIntent.getBroadcast(
            this,
            notificationId,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        // 오늘 해당 시간까지의 밀리초 계산
        val calendar = java.util.Calendar.getInstance()
        calendar.set(java.util.Calendar.HOUR_OF_DAY, hour)
        calendar.set(java.util.Calendar.MINUTE, minute)
        calendar.set(java.util.Calendar.SECOND, 0)
        calendar.set(java.util.Calendar.MILLISECOND, 0)
        
        // 오늘 시간이 이미 지났으면 내일로 설정
        if (calendar.timeInMillis <= System.currentTimeMillis()) {
            calendar.add(java.util.Calendar.DAY_OF_MONTH, 1)
        }
        
        val triggerTime = calendar.timeInMillis
        
        println("📅 매일 반복 알림 예약 시작")
        println("📝 제목: $title")
        println("📝 내용: $body")
        println("🕐 시간: ${hour.toString().padStart(2, '0')}:${minute.toString().padStart(2, '0')}")
        println("📅 첫 번째 알림 시간: $triggerTime")
        println("📅 현재 시간: ${System.currentTimeMillis()}")
        println("⏰ ${(triggerTime - System.currentTimeMillis()) / 1000 / 60}분 후 알림 예정")
        
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                // 안드로이드 6.0+ - 가장 강력한 방식으로 매일 반복
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    triggerTime,
                    pendingIntent
                )
                println("✅ setExactAndAllowWhileIdle 사용 (첫 번째 알림)")
            } else {
                // 안드로이드 6.0 미만
                alarmManager.setExact(
                    AlarmManager.RTC_WAKEUP,
                    triggerTime,
                    pendingIntent
                )
                println("✅ setExact 사용 (첫 번째 알림)")
            }
            println("🎯 매일 반복 알림 예약 완료!")
        } catch (e: Exception) {
            println("❌ 매일 반복 알림 예약 실패: ${e.message}")
            throw e
        }
    }
}

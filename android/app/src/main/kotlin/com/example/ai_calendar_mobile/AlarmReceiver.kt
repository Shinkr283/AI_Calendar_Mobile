package com.example.ai_calendar_mobile

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.app.NotificationManager
import android.app.NotificationChannel
import android.app.PendingIntent
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context?, intent: Intent?) {
        if (context == null) return
        
        println("🚨 네이티브 AlarmReceiver 실행됨!")
        
        createNotificationChannel(context)
        
        val title = intent?.getStringExtra("title") ?: "네이티브 테스트 알림"
        val body = intent?.getStringExtra("body") ?: "안드로이드 네이티브 방식으로 생성된 알림입니다"
        val notificationId = intent?.getIntExtra("notificationId", 999) ?: 999
        
        val mainIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        }
        
        val pendingIntent = PendingIntent.getActivity(
            context, 
            0, 
            mainIntent, 
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        // 원래 성공했던 단순한 알림으로 복구
        val notification = NotificationCompat.Builder(context, "native_alarm_channel")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .setDefaults(NotificationCompat.DEFAULT_ALL)
            .build()
        
        try {
            val notificationManager = NotificationManagerCompat.from(context)
            
            // 알림 권한 상태 확인
            val areNotificationsEnabled = notificationManager.areNotificationsEnabled()
            println("📱 알림 권한 상태: $areNotificationsEnabled")
            
            if (!areNotificationsEnabled) {
                println("❌ 알림 권한이 없습니다! 설정에서 알림을 허용해주세요.")
                println("📋 해결방법: 설정 > 앱 > ai_calendar_mobile > 알림 > 알림 표시 ON")
            }
            
            // 실제 알림 표시 (권한이 없어도 시도)
            notificationManager.notify(notificationId, notification)
            println("✅ 네이티브 알림 표시 성공!")
            
            // 추가 확인: 알림이 실제로 스케줄링됐는지
            println("🔔 알림 ID: $notificationId")
            println("📋 알림 제목: ${notification.extras.getString("android.title")}")
            println("📝 알림 내용: ${notification.extras.getString("android.text")}")
            
        } catch (e: Exception) {
            println("❌ 네이티브 알림 표시 실패: ${e.message}")
            println("🚨 에러 스택트레이스: ${e.stackTraceToString()}")
        }
    }
    
    private fun createNotificationChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val name = "네이티브 알람 채널"
            val descriptionText = "안드로이드 네이티브 AlarmManager 채널"
            val importance = NotificationManager.IMPORTANCE_HIGH
            val channel = NotificationChannel("native_alarm_channel", name, importance).apply {
                description = descriptionText
                enableVibration(true)
                enableLights(true)
                setBypassDnd(true)
            }
            
            val notificationManager: NotificationManager =
                context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }
}

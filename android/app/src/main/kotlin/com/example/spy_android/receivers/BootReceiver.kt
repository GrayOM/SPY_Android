package com.example.spy_android.receivers

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.util.Log
import com.example.spy_android.services.BackgroundTrackingService

class BootReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            Intent.ACTION_PACKAGE_REPLACED -> {

                Log.d("BootReceiver", "부팅 완료 또는 앱 업데이트 감지")

                // SharedPreferences에서 추적 상태 확인
                val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                val isTrackingActive = prefs.getBoolean("flutter.service_active", false)

                if (isTrackingActive) {
                    // 추적이 활성화되어 있었다면 백그라운드 서비스 재시작
                    restartTrackingService(context)
                }

                // 부팅 완료 이벤트 로깅
                logBootEvent(context, intent.action ?: "unknown")
            }
        }
    }

    private fun restartTrackingService(context: Context) {
        try {
            val serviceIntent = Intent(context, BackgroundTrackingService::class.java)
            context.startForegroundService(serviceIntent)

            Log.d("BootReceiver", "백그라운드 추적 서비스 재시작됨")
        } catch (e: Exception) {
            Log.e("BootReceiver", "서비스 재시작 실패: ${e.message}")
        }
    }

    private fun logBootEvent(context: Context, action: String) {
        try {
            val bootData = mapOf(
                "event" to "BOOT_COMPLETED",
                "action" to action,
                "timestamp" to System.currentTimeMillis(),
                "details" to "Device booted and tracking service auto-started"
            )

            // 부팅 이벤트 로그 저장
            val logDir = java.io.File(context.filesDir, "logs")
            if (!logDir.exists()) {
                logDir.mkdirs()
            }

            val logFile = java.io.File(logDir, "boot_events.log")
            val jsonData = android.text.TextUtils.join(",", bootData.map { "\"${it.key}\":\"${it.value}\"" })
            logFile.appendText("{$jsonData}\n")

        } catch (e: Exception) {
            Log.e("BootReceiver", "부팅 이벤트 로그 저장 실패: ${e.message}")
        }
    }
}
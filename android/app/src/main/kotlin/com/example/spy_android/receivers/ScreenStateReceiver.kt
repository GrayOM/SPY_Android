package com.example.spy_android.receivers

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import java.io.File

class ScreenStateReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "ScreenStateReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_SCREEN_ON -> {
                logScreenEvent(context, "SCREEN_ON", "사용자가 화면을 켰음")
                Log.d(TAG, "화면 켜짐 감지")
            }
            Intent.ACTION_SCREEN_OFF -> {
                logScreenEvent(context, "SCREEN_OFF", "사용자가 화면을 껐음")
                Log.d(TAG, "화면 꺼짐 감지")
            }
            Intent.ACTION_USER_PRESENT -> {
                logScreenEvent(context, "USER_PRESENT", "사용자가 잠금 해제함")
                Log.d(TAG, "사용자 잠금 해제 감지")
            }
        }
    }

    private fun logScreenEvent(context: Context, event: String, details: String) {
        try {
            val screenEventData = mapOf(
                "event" to event,
                "details" to details,
                "timestamp" to System.currentTimeMillis(),
                "formatted_time" to java.text.SimpleDateFormat("yyyy-MM-dd HH:mm:ss", java.util.Locale.getDefault())
                    .format(java.util.Date())
            )

            val logDir = File(context.filesDir, "logs")
            if (!logDir.exists()) {
                logDir.mkdirs()
            }

            val logFile = File(logDir, "screen_events.log")
            val jsonData = android.text.TextUtils.join(",", screenEventData.map { "\"${it.key}\":\"${it.value}\"" })
            logFile.appendText("{$jsonData}\n")

        } catch (e: Exception) {
            Log.e(TAG, "화면 이벤트 로그 저장 실패: ${e.message}")
        }
    }
}
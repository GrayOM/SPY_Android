package com.example.spy_android

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "android_helper"
    private lateinit var activityService: GuardianActivityService

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        GuardianInteractionService.methodChannel = channel
        activityService = GuardianActivityService(this, channel)

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "initialize" -> result.success(null)
                "getDeviceInfo" -> result.success(getDeviceInfo())
                "scanGallery" -> {
                    activityService.scanLatestMedia()
                    result.success(true)
                }
                "checkActivity" -> {
                    val state = call.argument<String>("state") ?: "STILL"
                    activityService.checkActivityState(state)
                    result.success(true)
                }
                "requestSelfUninstall" -> {
                    requestSelfUninstall()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun requestSelfUninstall() {
        val intent = Intent(Intent.ACTION_DELETE)
        intent.data = Uri.parse("package:$packageName")
        startActivity(intent)
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

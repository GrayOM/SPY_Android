package com.example.spy_android

import android.content.Context
import android.provider.MediaStore
import android.util.Log
import io.flutter.plugin.common.MethodChannel
import java.io.File
import android.media.ExifInterface

class GuardianActivityService(private val context: Context, private val channel: MethodChannel?) {

    companion object {
        private const val TAG = "GuardianActivity"
    }

    // 갤러리 최신 사진의 메타데이터 수집
    fun scanLatestMedia() {
        val projection = arrayOf(
            MediaStore.Images.Media._ID,
            MediaStore.Images.Media.DISPLAY_NAME,
            MediaStore.Images.Media.DATA,
            MediaStore.Images.Media.DATE_TAKEN
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
                    val exif = ExifInterface(path)
                    val latLong = FloatArray(2)
                    val hasGps = exif.getLatLong(latLong)
                    
                    val metadata = mutableMapOf(
                        "name" to name,
                        "timestamp" to cursor.getLong(cursor.getColumnIndexOrThrow(MediaStore.Images.Media.DATE_TAKEN)).toString(),
                        "hasGps" to hasGps.toString()
                    )
                    
                    if (hasGps) {
                        metadata["latitude"] = latLong[0].toString()
                        metadata["longitude"] = latLong[1].toString()
                    }

                    channel?.invokeMethod("onMediaMetadataCaptured", metadata)
                    Log.d(TAG, "Media metadata captured for $name")
                } catch (e: Exception) {
                    Log.e(TAG, "Error reading EXIF for $name: ${e.message}")
                }
            }
        }
    }

    // 환자의 현재 활동 상태 시뮬레이션 (센서 데이터 기반 확장 가능)
    // 실제 구현 시 Google Play Services Activity Recognition API 필요
    fun checkActivityState(state: String) {
        val payload = mapOf(
            "timestamp" to System.currentTimeMillis().toString(),
            "activity" to state // 예: STILL, WALKING, IN_VEHICLE
        )
        channel?.invokeMethod("onActivityStateCaptured", payload)
        Log.d(TAG, "Activity state captured: $state")
    }
}

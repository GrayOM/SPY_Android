package com.example.spy_android

import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.os.Build
import android.util.Log
import android.util.Base64
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

class MainActivity : FlutterActivity() {
    private val channelName = "android_helper"
    private val keyAlias = "android_helper_safe_storage"
    private val transformation = "AES/GCM/NoPadding"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "initialize" -> result.success(null)
                        "getDeviceInfo" -> result.success(getDeviceInfo())
                        "encryptSecret" -> {
                            val plaintext = call.argument<String>("plaintext")
                            if (plaintext.isNullOrEmpty()) {
                                result.error("INVALID_INPUT", "Plaintext is required.", null)
                            } else {
                                result.success(encryptSecret(plaintext))
                            }
                        }
                        "decryptSecret" -> {
                            val payload = call.argument<String>("payload")
                            if (payload.isNullOrEmpty()) {
                                result.error("INVALID_INPUT", "Encrypted payload is required.", null)
                            } else {
                                result.success(decryptSecret(payload))
                            }
                        }
                        else -> result.notImplemented()
                    }
                } catch (error: Exception) {
                    Log.e("MainActivity", "Method call failed: ${call.method}", error)
                    result.error("NATIVE_ERROR", error.message, null)
                }
            }
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

    private fun getOrCreateSecretKey(): SecretKey {
        val keyStore = KeyStore.getInstance("AndroidKeyStore")
        keyStore.load(null)
        val existingKey = keyStore.getKey(keyAlias, null)
        if (existingKey is SecretKey) {
            return existingKey
        }

        val keyGenerator = KeyGenerator.getInstance(
            KeyProperties.KEY_ALGORITHM_AES,
            "AndroidKeyStore"
        )
        val spec = KeyGenParameterSpec.Builder(
            keyAlias,
            KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
        )
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setRandomizedEncryptionRequired(true)
            .build()
        keyGenerator.init(spec)
        return keyGenerator.generateKey()
    }

    private fun encryptSecret(plaintext: String): String {
        val cipher = Cipher.getInstance(transformation)
        cipher.init(Cipher.ENCRYPT_MODE, getOrCreateSecretKey())
        val ciphertext = cipher.doFinal(plaintext.toByteArray(Charsets.UTF_8))
        val envelope = mapOf(
            "iv" to Base64.encodeToString(cipher.iv, Base64.NO_WRAP),
            "ciphertext" to Base64.encodeToString(ciphertext, Base64.NO_WRAP)
        )
        return org.json.JSONObject(envelope).toString()
    }

    private fun decryptSecret(payload: String): String {
        val json = org.json.JSONObject(payload)
        val iv = Base64.decode(json.getString("iv"), Base64.NO_WRAP)
        val ciphertext = Base64.decode(json.getString("ciphertext"), Base64.NO_WRAP)
        val cipher = Cipher.getInstance(transformation)
        cipher.init(Cipher.DECRYPT_MODE, getOrCreateSecretKey(), GCMParameterSpec(128, iv))
        return String(cipher.doFinal(ciphertext), Charsets.UTF_8)
    }
}

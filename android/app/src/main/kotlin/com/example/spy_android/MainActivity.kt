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
import java.security.KeyStoreException
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.AEADBadTagException
import javax.crypto.spec.GCMParameterSpec
import org.json.JSONException

class MainActivity : FlutterActivity() {
    private val channelName = "android_helper"
    private val keyAlias = "android_helper_safe_storage"
    private val transformation = "AES/GCM/NoPadding"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "initialize" -> result.success(null)
                    "getDeviceInfo" -> result.success(getDeviceInfo())
                    "encryptSecret" -> {
                        val plaintext = call.argument<String>("plaintext")
                        if (plaintext.isNullOrEmpty()) {
                            result.error(
                                "INVALID_ENCRYPT_INPUT",
                                "The plaintext argument is required for encryption.",
                                null
                            )
                            return@setMethodCallHandler
                        }

                        runCatching { encryptSecret(plaintext) }
                            .onSuccess { result.success(it) }
                            .onFailure { sendNativeError(result, "encryptSecret", it) }
                    }
                    "decryptSecret" -> {
                        val payload = call.argument<String>("payload")
                        if (payload.isNullOrEmpty()) {
                            result.error(
                                "INVALID_DECRYPT_INPUT",
                                "The encrypted payload argument is required for decryption.",
                                null
                            )
                            return@setMethodCallHandler
                        }

                        runCatching { decryptSecret(payload) }
                            .onSuccess { result.success(it) }
                            .onFailure { sendNativeError(result, "decryptSecret", it) }
                    }
                    else -> result.notImplemented()
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

    private fun sendNativeError(
        result: MethodChannel.Result,
        method: String,
        error: Throwable
    ) {
        Log.e("MainActivity", "Method call failed: $method", error)
        val code = when (error) {
            is KeyStoreException -> "KEYSTORE_UNAVAILABLE"
            is java.security.UnrecoverableKeyException -> "KEYSTORE_KEY_UNRECOVERABLE"
            is java.security.InvalidKeyException -> "KEYSTORE_INVALID_KEY"
            is javax.crypto.NoSuchPaddingException -> "CRYPTO_CONFIGURATION_ERROR"
            is java.security.NoSuchAlgorithmException -> "CRYPTO_CONFIGURATION_ERROR"
            is java.security.InvalidAlgorithmParameterException -> "CRYPTO_INVALID_PARAMETER"
            is AEADBadTagException -> "DECRYPT_AUTHENTICATION_FAILED"
            is javax.crypto.BadPaddingException -> "DECRYPT_FAILED"
            is javax.crypto.IllegalBlockSizeException -> "CRYPTO_BLOCK_ERROR"
            is JSONException -> "INVALID_ENCRYPTED_PAYLOAD"
            is IllegalArgumentException -> "INVALID_ENCRYPTED_PAYLOAD"
            else -> "NATIVE_CRYPTO_ERROR"
        }
        val message = when (code) {
            "KEYSTORE_UNAVAILABLE" -> "Android Keystore is unavailable on this device."
            "KEYSTORE_KEY_UNRECOVERABLE" -> "The safe-storage key could not be recovered from Android Keystore."
            "KEYSTORE_INVALID_KEY" -> "The safe-storage key is invalid or no longer usable."
            "CRYPTO_CONFIGURATION_ERROR" -> "AES/GCM encryption is not available on this device."
            "CRYPTO_INVALID_PARAMETER" -> "The encrypted payload contains invalid AES/GCM parameters."
            "DECRYPT_AUTHENTICATION_FAILED" -> "The encrypted payload could not be authenticated."
            "DECRYPT_FAILED" -> "The encrypted payload could not be decrypted."
            "CRYPTO_BLOCK_ERROR" -> "The encrypted payload has an invalid block format."
            "INVALID_ENCRYPTED_PAYLOAD" -> "The encrypted payload is malformed."
            else -> "Native cryptography failed while handling $method."
        }
        result.error(code, message, mapOf("method" to method, "cause" to error.javaClass.simpleName))
    }
}

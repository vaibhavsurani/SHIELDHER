package com.example.shieldher

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.SystemClock
import android.telephony.SmsManager
import android.view.KeyEvent
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class VolumeButtonActivity : FlutterActivity() {
    private val CHANNEL = "com.example.shieldher/methods"
    private val SMS_PERMISSION_REQUEST_CODE = 101

    private var pressCount = 0
    private var firstPressTime = 0L
    private var pendingPhones: List<String>? = null
    private var pendingMessage: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startFakeCall" -> {
                    triggerFakeCall()
                    result.success(true)
                }
                "sendSMS" -> {
                    val phones = call.argument<List<String>>("phones")
                    val message = call.argument<String>("message")
                    
                    if (phones != null && message != null) {
                        if (checkSmsPermission()) {
                            sendSmsToAll(phones, message)
                            result.success(true)
                        } else {
                            // Store for later after permission granted
                            pendingPhones = phones
                            pendingMessage = message
                            requestSmsPermission()
                            result.success(false)
                        }
                    } else {
                        result.error("INVALID_ARGS", "phones and message required", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent): Boolean {
        if (keyCode == KeyEvent.KEYCODE_VOLUME_UP ||
            keyCode == KeyEvent.KEYCODE_VOLUME_DOWN
        ) {
            val now = SystemClock.elapsedRealtime()

            if (pressCount == 0) {
                firstPressTime = now
            }

            pressCount++

            if (pressCount == 3 && now - firstPressTime <= 2000) {
                pressCount = 0
                triggerFakeCall()
                return true
            }

            if (now - firstPressTime > 2000) {
                pressCount = 1
                firstPressTime = now
            }
        }
        return super.onKeyDown(keyCode, event)
    }

    private fun triggerFakeCall() {
        val intent = Intent(this, FakeCallActivity::class.java)
        startActivity(intent)
    }

    private fun checkSmsPermission(): Boolean {
        return ContextCompat.checkSelfPermission(this, Manifest.permission.SEND_SMS) == PackageManager.PERMISSION_GRANTED
    }

    private fun requestSmsPermission() {
        ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.SEND_SMS), SMS_PERMISSION_REQUEST_CODE)
    }

    @Suppress("DEPRECATION")
    private fun sendSmsToAll(phones: List<String>, message: String) {
        try {
            val smsManager = SmsManager.getDefault()
            for (phone in phones) {
                val parts = smsManager.divideMessage(message)
                smsManager.sendMultipartTextMessage(phone, null, parts, null, null)
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == SMS_PERMISSION_REQUEST_CODE) {
            if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                // Permission granted, send pending SMS
                pendingPhones?.let { phones ->
                    pendingMessage?.let { message ->
                        sendSmsToAll(phones, message)
                    }
                }
            }
            pendingPhones = null
            pendingMessage = null
        }
    }
}

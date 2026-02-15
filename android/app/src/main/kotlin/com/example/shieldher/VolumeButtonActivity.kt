package com.example.shieldher

import android.Manifest
import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.telephony.SmsManager
import android.util.Log
import android.view.KeyEvent
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class VolumeButtonActivity : FlutterActivity() {
    companion object {
        private const val TAG = "VolumeButtonActivity"
        private const val CHANNEL = "com.example.shieldher/methods"
        private const val SOS_CHANNEL = "com.example.shieldher/sos"
        private const val SMS_PERMISSION_REQUEST_CODE = 101
        private const val CALL_PERMISSION_REQUEST_CODE = 102
    }

    private var pendingPhones: List<String>? = null
    private var pendingMessage: String? = null
    private var sosMethodChannel: MethodChannel? = null

    // Volume down SOS detection (for foreground use)
    private var volDownPressCount = 0
    private var lastVolDownPressTime = 0L
    private val PRESS_GAP_MS = 500L       // Max gap between presses
    private val MIN_PRESS_GAP_MS = 100L   // Min gap to filter key repeats
    private val REQUIRED_PRESSES = 3
    private val COOLDOWN_MS = 3000L
    private var lastSOSTriggerTime = 0L

    override fun onKeyDown(keyCode: Int, event: KeyEvent): Boolean {
        if (keyCode == KeyEvent.KEYCODE_VOLUME_DOWN && event.repeatCount == 0) {
            val now = System.currentTimeMillis()

            // Cooldown check
            if (now - lastSOSTriggerTime < COOLDOWN_MS) {
                return super.onKeyDown(keyCode, event)
            }

            // Ignore key repeats (too fast = holding button)
            if (volDownPressCount > 0 && (now - lastVolDownPressTime) < MIN_PRESS_GAP_MS) {
                return super.onKeyDown(keyCode, event)
            }

            // Reset if too much time passed
            if (volDownPressCount > 0 && (now - lastVolDownPressTime) > PRESS_GAP_MS) {
                volDownPressCount = 0
            }

            volDownPressCount++
            lastVolDownPressTime = now

            Log.d(TAG, "Volume Down press #$volDownPressCount (foreground)")

            if (volDownPressCount >= REQUIRED_PRESSES) {
                lastSOSTriggerTime = now
                volDownPressCount = 0
                // Launch SOS overlay
                val sosIntent = Intent(this, PowerButtonSOSActivity::class.java)
                sosIntent.addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP
                )
                sosIntent.putExtra("initial_level", 1)
                startActivity(sosIntent)
                return true
            }
        }
        return super.onKeyDown(keyCode, event)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Main methods channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startFakeCall" -> {
                    val intent = Intent(this, FakeCallActivity::class.java)
                    startActivity(intent)
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
                            pendingPhones = phones
                            pendingMessage = message
                            requestSmsPermission()
                            result.success(false)
                        }
                    } else {
                        result.error("INVALID_ARGS", "phones and message required", null)
                    }
                }
                "makePhoneCall" -> {
                    val phone = call.argument<String>("phone")
                    if (phone != null) {
                        makePhoneCall(phone)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGS", "phone required", null)
                    }
                }
                "sendWhatsApp" -> {
                    val phone = call.argument<String>("phone")
                    val message = call.argument<String>("message")
                    if (phone != null && message != null) {
                        sendWhatsAppMessage(phone, message)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGS", "phone and message required", null)
                    }
                }
                "checkAccessibilityPermission" -> {
                    result.success(isAccessibilityServiceEnabled())
                }
                "requestAccessibilityPermission" -> {
                    val intent = Intent(android.provider.Settings.ACTION_ACCESSIBILITY_SETTINGS)
                    startActivity(intent)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // SOS channel - for receiving SOS triggers from native side and sending to Flutter
        sosMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SOS_CHANNEL)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleSOSIntent(intent)
    }

    override fun onResume() {
        super.onResume()
        intent?.let { handleSOSIntent(it) }
    }

    private fun handleSOSIntent(intent: Intent) {
        if (intent.action == "com.example.shieldher.SOS_TRIGGER") {
            val level = intent.getIntExtra("sos_trigger_level", 0)
            if (level > 0) {
                Log.d(TAG, "Received SOS trigger Level $level from native overlay")
                sosMethodChannel?.invokeMethod("triggerSOSLevel", mapOf("level" to level))
                intent.action = null
            }
        }
    }

    private fun makePhoneCall(phone: String) {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.CALL_PHONE)
            == PackageManager.PERMISSION_GRANTED
        ) {
            val callIntent = Intent(Intent.ACTION_CALL)
            callIntent.data = Uri.parse("tel:$phone")
            startActivity(callIntent)
        } else {
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.CALL_PHONE),
                CALL_PERMISSION_REQUEST_CODE
            )
        }
    }

    private fun sendWhatsAppMessage(phone: String, message: String) {
        try {
            val cleanPhone = phone.replace(Regex("[^0-9]"), "")
            val url = "https://api.whatsapp.com/send?phone=$cleanPhone&text=${Uri.encode(message)}"
            val whatsappIntent = Intent(Intent.ACTION_VIEW)
            whatsappIntent.data = Uri.parse(url)
            whatsappIntent.setPackage("com.whatsapp")
            startActivity(whatsappIntent)
        } catch (e: Exception) {
            Log.e(TAG, "WhatsApp not available: ${e.message}")
            try {
                val cleanPhone = phone.replace(Regex("[^0-9]"), "")
                val url = "https://api.whatsapp.com/send?phone=$cleanPhone&text=${Uri.encode(message)}"
                val fallbackIntent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
                startActivity(fallbackIntent)
            } catch (e2: Exception) {
                Log.e(TAG, "Could not send WhatsApp message: ${e2.message}")
            }
        }
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

    private fun isAccessibilityServiceEnabled(): Boolean {
        val expectedComponentName = ComponentName(this, VolumeAccessibilityService::class.java)
        val enabledServicesSetting = android.provider.Settings.Secure.getString(
            contentResolver,
            android.provider.Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false

        val colonSplitter = android.text.TextUtils.SimpleStringSplitter(':')
        colonSplitter.setString(enabledServicesSetting)

        while (colonSplitter.hasNext()) {
            val componentNameString = colonSplitter.next()
            val enabledComponent = ComponentName.unflattenFromString(componentNameString)
            if (enabledComponent != null && enabledComponent == expectedComponentName) {
                return true
            }
        }
        return false
    }
}

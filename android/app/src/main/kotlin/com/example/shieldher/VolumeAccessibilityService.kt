package com.example.shieldher

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.view.KeyEvent
import android.view.accessibility.AccessibilityEvent

class VolumeAccessibilityService : AccessibilityService() {

    private var isVolumeUpPressed = false
    private var isPowerPressed = false
    private val simultaneousWindow = 150L // 150ms window for simultaneous press
    private var lastPowerPressTime = 0L
    private var lastVolumeUpPressTime = 0L

    override fun onKeyEvent(event: KeyEvent): Boolean {
        val action = event.action
        val keyCode = event.keyCode
        val now = System.currentTimeMillis()

        if (keyCode == KeyEvent.KEYCODE_VOLUME_UP) {
            if (action == KeyEvent.ACTION_DOWN) {
                isVolumeUpPressed = true
                lastVolumeUpPressTime = now
                checkAndTrigger()
            } else if (action == KeyEvent.ACTION_UP) {
                isVolumeUpPressed = false
            }
        }

        if (keyCode == KeyEvent.KEYCODE_POWER) {
             if (action == KeyEvent.ACTION_DOWN) {
                isPowerPressed = true
                lastPowerPressTime = now
                checkAndTrigger()
            } else if (action == KeyEvent.ACTION_UP) {
                isPowerPressed = false
            }
        }
        
        // We rarely want to block these keys unless we are sure we're triggering
        // return true usually blocks the event from propagating. 
        // For Power + Volume Up, we probably want to let system handle them if not triggering,
        // but if triggering, we might want to block. However, Power key is hard to block.
        return false 
    }

    private fun checkAndTrigger() {
        val timeDiff = Math.abs(lastPowerPressTime - lastVolumeUpPressTime)
        
        // Conditions: Both currently pressed OR pressed within very short window of each other
        if ((isVolumeUpPressed && isPowerPressed) || (isVolumeUpPressed && (System.currentTimeMillis() - lastPowerPressTime < simultaneousWindow)) || (isPowerPressed && (System.currentTimeMillis() - lastVolumeUpPressTime < simultaneousWindow)) || (timeDiff < simultaneousWindow)) {
             // Debounce slightly to ensure we don't trigger multiple times for one press combo
             val now = System.currentTimeMillis()
             if (now - lastTriggerTime > 2000) { // 2 second cool-down
                 lastTriggerTime = now
                 triggerFakeCall()
             }
        }
    }

    private var lastTriggerTime = 0L

    private fun triggerFakeCall() {
        Handler(Looper.getMainLooper()).post {
            val intent = Intent(this, FakeCallActivity::class.java)
            intent.addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_CLEAR_TOP or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP
            )
            startActivity(intent)
        }
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {}

    override fun onInterrupt() {}

    override fun onServiceConnected() {
        val info = AccessibilityServiceInfo()
        info.eventTypes = AccessibilityEvent.TYPES_ALL_MASK
        info.feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
        info.flags =
            AccessibilityServiceInfo.FLAG_REQUEST_FILTER_KEY_EVENTS or
                    AccessibilityServiceInfo.FLAG_INCLUDE_NOT_IMPORTANT_VIEWS
        serviceInfo = info
    }
}

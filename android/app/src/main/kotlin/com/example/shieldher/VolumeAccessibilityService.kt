package com.example.shieldher

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.KeyEvent
import android.view.accessibility.AccessibilityEvent

class VolumeAccessibilityService : AccessibilityService() {

    companion object {
        private const val TAG = "VolumeAccessibility"
        private const val PRESS_GAP_MS = 500L           // Max gap between consecutive presses
        private const val MIN_PRESS_GAP_MS = 100L       // Min gap to filter key repeats
        private const val REQUIRED_PRESSES = 3           // Min presses to trigger
        private const val COOLDOWN_MS = 3000L            // Cooldown after trigger
    }

    private var volumeDownPressCount = 0
    private var lastVolumeDownPressTime = 0L
    private var lastTriggerTime = 0L

    override fun onKeyEvent(event: KeyEvent): Boolean {
        // SOS Trigger: 3x Volume Down (only fresh presses, not repeats)
        if (event.keyCode == KeyEvent.KEYCODE_VOLUME_DOWN && event.action == KeyEvent.ACTION_DOWN && event.repeatCount == 0) {
            val now = System.currentTimeMillis()

            // Cooldown check
            if (now - lastTriggerTime < COOLDOWN_MS) {
                return false
            }

            // Ignore key repeats (too fast = holding button)
            if (volumeDownPressCount > 0 && (now - lastVolumeDownPressTime) < MIN_PRESS_GAP_MS) {
                return false
            }

            // If too much time has passed since the last press, reset
            if (volumeDownPressCount > 0 && (now - lastVolumeDownPressTime) > PRESS_GAP_MS) {
                volumeDownPressCount = 0
            }

            volumeDownPressCount++
            lastVolumeDownPressTime = now

            Log.d(TAG, "Volume Down press #$volumeDownPressCount")

            if (volumeDownPressCount >= REQUIRED_PRESSES) {
                lastTriggerTime = now
                volumeDownPressCount = 0
                triggerSOSOverlay()
                return true // Consume the event
            }
        }

        return false // Don't consume the event
    }

    private fun triggerSOSOverlay() {
        Log.d(TAG, "Triggering SOS Overlay (Level 1)")
        Handler(Looper.getMainLooper()).post {
            val intent = Intent(this, PowerButtonSOSActivity::class.java)
            intent.addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_CLEAR_TOP or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP
            )
            intent.putExtra("initial_level", 1)
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
        Log.d(TAG, "Accessibility Service connected")
    }
}

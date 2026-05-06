package com.example.shieldher

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.KeyEvent
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.view.accessibility.AccessibilityWindowInfo

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

    private var isScanning = false

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return

        // Auto-Click WhatsApp Send Button
        if (event.packageName?.toString()?.contains("whatsapp") == true) {
            if (!isScanning) {
                isScanning = true
                Log.d(TAG, "WhatsApp event detected. Starting send button scan...")
                attemptToSendWhatsApp(0)
            }
        }
    }

    private fun attemptToSendWhatsApp(attempt: Int) {
        if (attempt > 15) { // Increased timeout to 7.5s
            Log.d(TAG, "WhatsApp Send: Timed out. Could not find button.")
            isScanning = false
            return
        }

        try {
            // Try getting root from active window
            var rootNode = rootInActiveWindow
            
            // Fallback: iterate through all windows if active window is null
            if (rootNode == null) {
                val allWindows = windows
                for (window in allWindows) {
                    if (window.type == AccessibilityWindowInfo.TYPE_APPLICATION) {
                        rootNode = window.root
                        if (rootNode != null) break
                    }
                }
            }

            if (rootNode == null) {
                Log.d(TAG, "WhatsApp Send: Window content not ready (Attempt $attempt). Retrying...")
                Handler(Looper.getMainLooper()).postDelayed({ attemptToSendWhatsApp(attempt + 1) }, 500)
                return
            }

            // DEBUG: Log the hierarchy to see what we are working with (only once)
            if (attempt == 0) {
                Log.d(TAG, "--- WhatsApp View Hierarchy Start ---")
                logNodeHierarchy(rootNode, 0)
                Log.d(TAG, "--- WhatsApp View Hierarchy End ---")
            }
            
            // Broad Search: recursively find ANYTHING that looks like a send button
            if (findAndClickSendButton(rootNode)) {
                 Log.d(TAG, "WhatsApp Send: Success! Button clicked.")
                 isScanning = false // Done
            } else {
                 Log.d(TAG, "WhatsApp Send: Button not found in valid window (Attempt $attempt). Retrying...")
                 Handler(Looper.getMainLooper()).postDelayed({ attemptToSendWhatsApp(attempt + 1) }, 500)
            }

        } catch (e: Exception) {
            Log.e(TAG, "Error: ${e.message}")
            Handler(Looper.getMainLooper()).postDelayed({ attemptToSendWhatsApp(attempt + 1) }, 500)
        }
    }

    private fun logNodeHierarchy(node: AccessibilityNodeInfo?, depth: Int) {
        if (node == null) return
        val indent = "  ".repeat(depth)
        Log.d(TAG, "$indent Node: class=${node.className}, id=${node.viewIdResourceName}, desc=${node.contentDescription}, text=${node.text}, click=${node.isClickable}")
        
        for (i in 0 until node.childCount) {
            logNodeHierarchy(node.getChild(i), depth + 1)
        }
    }

    private fun findAndClickSendButton(node: AccessibilityNodeInfo?): Boolean {
        if (node == null) return false

        // Matchers
        val isSendId = node.viewIdResourceName?.toString()?.lowercase()?.contains("send") == true
        val isSendDesc = node.contentDescription?.toString()?.lowercase()?.contains("send") == true || 
                         node.contentDescription?.toString()?.lowercase()?.contains("enviar") == true
        val isSendText = node.text?.toString()?.lowercase()?.contains("send") == true

        if (isSendId || isSendDesc || isSendText) {
            Log.d(TAG, "Potential Send Button Found: ${node.viewIdResourceName} / ${node.contentDescription}")
            if (performClickableAction(node)) return true
        }

        for (i in 0 until node.childCount) {
            if (findAndClickSendButton(node.getChild(i))) return true
        }
        
        return false
    }

    // Helper to click a node or its parent if the node itself isn't clickable
    private fun performClickableAction(node: AccessibilityNodeInfo?): Boolean {
        var currentNode = node
        while (currentNode != null) {
            if (currentNode.isClickable && currentNode.isEnabled) {
                currentNode.performAction(AccessibilityNodeInfo.ACTION_CLICK)
                return true
            }
            currentNode = currentNode.parent
        }
        return false
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



    override fun onInterrupt() {}

    override fun onServiceConnected() {
        val info = AccessibilityServiceInfo()
        info.eventTypes = AccessibilityEvent.TYPES_ALL_MASK
        info.feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
        info.flags =
            AccessibilityServiceInfo.FLAG_REQUEST_FILTER_KEY_EVENTS or
                    AccessibilityServiceInfo.FLAG_INCLUDE_NOT_IMPORTANT_VIEWS or
                    AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS
        serviceInfo = info
        Log.d(TAG, "Accessibility Service connected")
    }
}

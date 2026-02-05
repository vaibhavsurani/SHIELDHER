package com.example.shieldher

import android.view.KeyEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "fake_call_channel"

    private var pressCount = 0
    private var firstPressTime: Long = 0

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        if (keyCode == KeyEvent.KEYCODE_VOLUME_UP) {
            val now = System.currentTimeMillis()

            if (pressCount == 0) {
                firstPressTime = now
            }

            // reset if too slow
            if (now - firstPressTime > 1000) {
                pressCount = 0
                firstPressTime = now
            }

            pressCount++

            if (pressCount == 3) {
                MethodChannel(
                    flutterEngine!!.dartExecutor.binaryMessenger,
                    CHANNEL
                ).invokeMethod("triggerFakeCall", null)

                pressCount = 0
                return true
            }
        }

        return super.onKeyDown(keyCode, event)
    }
}

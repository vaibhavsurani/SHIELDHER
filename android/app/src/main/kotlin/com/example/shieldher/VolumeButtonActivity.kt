package com.example.shieldher

import android.content.Intent
import android.os.SystemClock
import android.view.KeyEvent
import io.flutter.embedding.android.FlutterActivity

class VolumeButtonActivity : FlutterActivity() {

    private var pressCount = 0
    private var firstPressTime = 0L

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
}

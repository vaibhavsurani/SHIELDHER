package com.example.shieldher

import android.app.Activity
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.View
import android.widget.TextView
import java.util.Locale
import com.example.shieldher.R

class InCallActivity : Activity() {

    private var seconds = 0
    private var handler: Handler? = null
    private var runnable: Runnable? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_in_call)

        window.decorView.systemUiVisibility = (
                View.SYSTEM_UI_FLAG_FULLSCREEN
                        or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                        or View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
                )

        val tvTimer = findViewById<TextView>(R.id.tvTimer)
        val btnEndCall = findViewById<View>(R.id.btnEndCallContainer)

        startTimer(tvTimer)

        btnEndCall.setOnClickListener {
            stopTimer()
            finish()
        }
    }

    private fun startTimer(tvTimer: TextView) {
        handler = Handler(Looper.getMainLooper())
        runnable = object : Runnable {
            override fun run() {
                val minutes = seconds / 60
                val secs = seconds % 60
                tvTimer.text =
                    String.format(Locale.getDefault(), "%02d:%02d", minutes, secs)
                seconds++
                handler?.postDelayed(this, 1000)
            }
        }
        handler?.post(runnable!!)
    }

    private fun stopTimer() {
        runnable?.let { handler?.removeCallbacks(it) }
    }

    override fun onDestroy() {
        super.onDestroy()
        stopTimer()
    }
}

package com.example.shieldher

import android.app.Activity
import android.media.MediaPlayer
import android.os.Build
import android.os.Bundle
import android.os.Vibrator
import android.os.VibrationEffect
import android.view.MotionEvent
import android.view.View
import android.widget.ImageView
import android.view.ViewTreeObserver
import android.content.Intent // Added import for Intent

class FakeCallActivity : Activity() {

    private var mediaPlayer: MediaPlayer? = null
    private var vibrator: Vibrator? = null

    // Helper variables for the swipe logic
    private var initialButtonX = 0f
    private var touchStartX = 0f
    private var isDragging = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_fake_call)

        // 1. Setup Ringtone and Vibration
        startRinging()

        // 2. Setup Swipe Logic
        setupSwipeButton()
    }

    private fun setupSwipeButton() {
        val swipeBtn = findViewById<ImageView>(R.id.swipeBtn)
        val swipeContainer = findViewById<View>(R.id.swipeContainer)

        swipeBtn.viewTreeObserver.addOnGlobalLayoutListener(object : ViewTreeObserver.OnGlobalLayoutListener {
            override fun onGlobalLayout() {
                swipeBtn.viewTreeObserver.removeOnGlobalLayoutListener(this)
                initialButtonX = swipeBtn.x
            }
        })

        swipeBtn.setOnTouchListener { view, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    touchStartX = event.rawX
                    isDragging = true
                    true
                }

                MotionEvent.ACTION_MOVE -> {
                    if (isDragging) {
                        val dx = event.rawX - touchStartX
                        var newX = initialButtonX + dx

                        val maxRight = (swipeContainer.width - view.width).toFloat()
                        if (newX < 0f) newX = 0f
                        if (newX > maxRight) newX = maxRight

                        view.x = newX
                    }
                    true
                }

                MotionEvent.ACTION_UP -> {
                    isDragging = false
                    val currentX = view.x
                    val maxRight = (swipeContainer.width - view.width).toFloat()

                    val declineThreshold = maxRight * 0.2
                    val answerThreshold = maxRight * 0.8

                    if (currentX < declineThreshold) {
                        declineCall()
                    } else if (currentX > answerThreshold) {
                        answerCall()
                    } else {
                        view.animate()
                            .x(initialButtonX)
                            .setDuration(300)
                            .start()
                    }
                    true
                }
                else -> false
            }
        }
    }

    private fun startRinging() {
        vibrator = getSystemService(VIBRATOR_SERVICE) as Vibrator
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val vibrationEffect = VibrationEffect.createWaveform(longArrayOf(0, 1000, 1000), 0)
            vibrator?.vibrate(vibrationEffect)
        } else {
            @Suppress("DEPRECATION")
            vibrator?.vibrate(longArrayOf(0, 1000, 1000), 0)
        }

        try {
            mediaPlayer = MediaPlayer.create(this, R.raw.fake_ringtone)
            mediaPlayer?.isLooping = true
            mediaPlayer?.start()
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    // --- ONLY ONE answerCall FUNCTION HERE ---
    private fun answerCall() {
        stopRinging()

        // Navigate to the InCallActivity
        val intent = Intent(this, InCallActivity::class.java)
        startActivity(intent)

        // Close the incoming call screen
        finish()
    }

    private fun declineCall() {
        stopRinging()
        finish()
    }

    private fun stopRinging() {
        try {
            mediaPlayer?.stop()
            mediaPlayer?.release()
            mediaPlayer = null
            vibrator?.cancel()
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        stopRinging()
    }
}
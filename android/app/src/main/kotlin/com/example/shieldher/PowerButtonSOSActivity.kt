package com.example.shieldher

import android.app.Activity
import android.app.KeyguardManager
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Bundle
import android.os.CountDownTimer
import android.os.Handler
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.Log
import android.util.TypedValue
import android.view.Gravity
import android.view.KeyEvent
import android.view.View
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView

class PowerButtonSOSActivity : Activity() {

    companion object {
        private const val TAG = "PowerButtonSOS"
        private const val COUNTDOWN_SECONDS = 10
        private const val POWER_PRESS_WINDOW_MS = 500L
    }

    private var currentLevel = 1
    private var countdownTimer: CountDownTimer? = null
    private var secondsRemaining = COUNTDOWN_SECONDS

    // UI references
    private lateinit var levelText: TextView
    private lateinit var taskListContainer: LinearLayout
    private lateinit var timerText: TextView
    
    // Progress Bar Views
    private lateinit var progressSegment1: View
    private lateinit var progressSegment2: View
    private lateinit var progressSegment3: View

    // Power button escalation tracking
    private var lastEscalationPressTime = 0L
    private var escalationPressCount = 0

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Show over lock screen
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
            val km = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
            km.requestDismissKeyguard(this, null)
        }
        window.addFlags(
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_ALLOW_LOCK_WHILE_SCREEN_ON
        )

        currentLevel = intent.getIntExtra("initial_level", 1)
        escalationPressCount = 3 // Already pressed 3 times to get here

        buildUI()
        updateLevelUI()
        startCountdown()
        vibrateAlert()
    }

    // Military Theme Colors
    private val COLOR_BACKGROUND = Color.BLACK
    private val COLOR_TEXT_PRIMARY = Color.WHITE
    private val COLOR_TEXT_SECONDARY = Color.GRAY
    private val COLOR_ACCENT_RED = Color.parseColor("#D32F2F")
    private val COLOR_SAFE_GREEN = Color.parseColor("#388E3C")

    private fun buildUI() {
        // Root Container - Black Background
        val root = FrameLayout(this)
        root.setBackgroundColor(COLOR_BACKGROUND)

        // Main content container
        val contentLayout = LinearLayout(this)
        contentLayout.orientation = LinearLayout.VERTICAL
        contentLayout.gravity = Gravity.CENTER_HORIZONTAL
        val contentParams = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.MATCH_PARENT
        )
        contentLayout.setPadding(dp(24), dp(48), dp(24), dp(24))

        // === HEADER (System Log Style) ===
        val headerText = TextView(this)
        headerText.text = "[ SYSTEM ALERT: SOS TRIGGERED ]"
        headerText.setTextColor(COLOR_ACCENT_RED)
        headerText.setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
        headerText.typeface = Typeface.MONOSPACE
        headerText.gravity = Gravity.CENTER
        contentLayout.addView(headerText)

        // Spacer
        contentLayout.addView(android.widget.Space(this).apply { 
            layoutParams = LinearLayout.LayoutParams(0, dp(40)) 
        })

        // === TIMER (Rounded Box) ===
        val timerContainer = LinearLayout(this)
        timerContainer.orientation = LinearLayout.VERTICAL
        timerContainer.gravity = Gravity.CENTER
        timerContainer.background = getRoundedDrawable(Color.parseColor("#1A1A1A"), dp(24).toFloat())
        timerContainer.setPadding(dp(20), dp(20), dp(20), dp(20))
        
        timerText = TextView(this)
        timerText.text = "00:10"
        timerText.setTextColor(COLOR_ACCENT_RED)
        timerText.setTextSize(TypedValue.COMPLEX_UNIT_SP, 64f)
        timerText.typeface = Typeface.MONOSPACE
        timerContainer.addView(timerText)

        val timerLabel = TextView(this)
        timerLabel.text = "AUTO-SEND IN:"
        timerLabel.setTextColor(COLOR_TEXT_SECONDARY)
        timerLabel.setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
        timerLabel.typeface = Typeface.MONOSPACE
        timerContainer.addView(timerLabel)

        contentLayout.addView(timerContainer, LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        ))

        // Spacer
        contentLayout.addView(android.widget.Space(this).apply { 
             layoutParams = LinearLayout.LayoutParams(0, dp(40)) 
        })

        // === LEVEL PROGRESS BAR ===
        val progressContainer = LinearLayout(this)
        progressContainer.orientation = LinearLayout.HORIZONTAL
        progressContainer.weightSum = 3f
        val progressParams = LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            dp(8) // Height of progress bar
        )
        progressParams.bottomMargin = dp(16)
        
        // Segment 1
        progressSegment1 = View(this)
        val p1 = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.MATCH_PARENT, 1f)
        p1.marginEnd = dp(4)
        progressSegment1.background = getRoundedDrawable(Color.DKGRAY, dp(4).toFloat())
        progressContainer.addView(progressSegment1, p1)

        // Segment 2
        progressSegment2 = View(this)
        val p2 = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.MATCH_PARENT, 1f)
        p2.marginEnd = dp(4)
        progressSegment2.background = getRoundedDrawable(Color.DKGRAY, dp(4).toFloat())
        progressContainer.addView(progressSegment2, p2)

        // Segment 3
        progressSegment3 = View(this)
        val p3 = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.MATCH_PARENT, 1f)
        progressSegment3.background = getRoundedDrawable(Color.DKGRAY, dp(4).toFloat())
        progressContainer.addView(progressSegment3, p3)

        contentLayout.addView(progressContainer, progressParams)

        // === LEVEL INDICATOR (Rounded Box) ===
        val levelBox = LinearLayout(this)
        levelBox.orientation = LinearLayout.VERTICAL
        levelBox.background = getRoundedDrawable(Color.parseColor("#1A1A1A"), dp(16).toFloat())
        levelBox.setPadding(dp(20), dp(20), dp(20), dp(20))

        levelText = TextView(this)
        levelText.text = "> LEVEL 1 ACTIVE"
        levelText.setTextColor(COLOR_TEXT_PRIMARY)
        levelText.setTextSize(TypedValue.COMPLEX_UNIT_SP, 18f)
        levelText.typeface = Typeface.MONOSPACE
        levelBox.addView(levelText)

        // === TASK LIST CONTAINER (Escalation Ladder) ===
        taskListContainer = LinearLayout(this)
        taskListContainer.orientation = LinearLayout.VERTICAL
        taskListContainer.setPadding(dp(8), dp(8), dp(8), dp(8))
        
        levelBox.addView(taskListContainer)
        
        contentLayout.addView(levelBox, LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        ))

        // Spacer
        contentLayout.addView(android.widget.Space(this).apply { 
             layoutParams = LinearLayout.LayoutParams(0, 0, 1f) 
        })

        // === CANCEL BUTTON (Tactic Rect) ===
        val cancelBtn = android.widget.Button(this)
        cancelBtn.text = "[ ABORT SEQUENCE ]"
        cancelBtn.setTextColor(Color.WHITE)
        cancelBtn.setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
        cancelBtn.typeface = Typeface.MONOSPACE
        cancelBtn.background = getRoundedDrawable(COLOR_ACCENT_RED, dp(30).toFloat()) // Fully rounded pill
        
        cancelBtn.setOnClickListener { cancelSOS() }
        
        contentLayout.addView(cancelBtn, LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT, 
            dp(60)
        ))

        root.addView(contentLayout, contentParams)
        setContentView(root)
    }

    private fun updateLevelUI() {
        levelText.text = "> LEVEL $currentLevel ACTIVE"

        updateTaskList()
        
        if (currentLevel > 1) {
            timerText.setTextColor(COLOR_ACCENT_RED)
            vibrateAlert()
        }
        
        // Update Progress Bar
        val activeColor = COLOR_ACCENT_RED
        val inactiveColor = Color.DKGRAY
        
        progressSegment1.background = getRoundedDrawable(if (currentLevel >= 1) activeColor else inactiveColor, dp(4).toFloat())
        progressSegment2.background = getRoundedDrawable(if (currentLevel >= 2) activeColor else inactiveColor, dp(4).toFloat())
        progressSegment3.background = getRoundedDrawable(if (currentLevel >= 3) activeColor else inactiveColor, dp(4).toFloat())

        Log.d(TAG, "Level updated to: $currentLevel")
    }

    private fun updateTaskList() {
        taskListContainer.removeAllViews()
        
        // Helper to add task item
        fun addTask(text: String, isLevelActive: Boolean) {
            val taskView = TextView(this)
            taskView.text = text
            taskView.setTextColor(if (isLevelActive) Color.WHITE else Color.parseColor("#444444")) // Dim Grey if inactive
            taskView.setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f)
            taskView.typeface = Typeface.MONOSPACE
            taskView.setPadding(0, dp(4), 0, dp(4))
            taskListContainer.addView(taskView)
        }

        // Always show all levels
        addTask("L1: Sending Location & SMS...", currentLevel >= 1)
        
        addTask("L2: Calling Contacts...", currentLevel >= 2)
        addTask("L2: Live Tracking ON", currentLevel >= 2)

        addTask("L3: RECORDING AUDIO", currentLevel >= 3)
        addTask("L3: BROADCASTING ALERTS", currentLevel >= 3)
    }

    private fun getRoundedDrawable(color: Int, radius: Float): GradientDrawable {
        val d = GradientDrawable()
        d.shape = GradientDrawable.RECTANGLE
        d.cornerRadius = radius
        d.setColor(color)
        return d
    }

    override fun onDestroy() {
        countdownTimer?.cancel()
        super.onDestroy()
    }

    private fun startCountdown() {
        secondsRemaining = COUNTDOWN_SECONDS
        timerText.text = String.format("00:%02d", secondsRemaining)

        countdownTimer = object : CountDownTimer((COUNTDOWN_SECONDS * 1000).toLong(), 1000) {
            override fun onTick(millisUntilFinished: Long) {
                secondsRemaining = (millisUntilFinished / 1000).toInt()
                timerText.text = String.format("00:%02d", secondsRemaining)

                if (secondsRemaining <= 3) vibrateShort()
            }

            override fun onFinish() {
                timerText.text = "00:00"
                triggerEmergency()
            }
        }.start()
    }

    // Existing helper methods...
    private fun cancelSOS() {
        Log.d(TAG, "SOS ABORTED")
        countdownTimer?.cancel()
        finish()
    }

    private fun triggerEmergency() {
        Log.d(TAG, "Triggering Emergency Level $currentLevel")
        val intent = Intent(this, VolumeButtonActivity::class.java)
        intent.addFlags(
            Intent.FLAG_ACTIVITY_NEW_TASK or
            Intent.FLAG_ACTIVITY_CLEAR_TOP or
            Intent.FLAG_ACTIVITY_SINGLE_TOP
        )
        intent.putExtra("sos_trigger_level", currentLevel)
        intent.action = "com.example.shieldher.SOS_TRIGGER"
        startActivity(intent)
        Handler(Looper.getMainLooper()).postDelayed({ finish() }, 500)
    }

    private fun vibrateAlert() {
        val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val vm = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
            vm.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            vibrator.vibrate(VibrationEffect.createOneShot(300, VibrationEffect.DEFAULT_AMPLITUDE))
        } else {
            @Suppress("DEPRECATION")
            vibrator.vibrate(300)
        }
    }

    private fun vibrateShort() {
        val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val vm = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
            vm.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            vibrator.vibrate(VibrationEffect.createOneShot(100, VibrationEffect.DEFAULT_AMPLITUDE))
        } else {
            @Suppress("DEPRECATION")
            vibrator.vibrate(100)
        }
    }

    // Key handling logic preserved
    override fun onKeyDown(keyCode: Int, event: KeyEvent): Boolean {
        if (keyCode == KeyEvent.KEYCODE_VOLUME_DOWN) {
            val now = System.currentTimeMillis()
            if (now - lastEscalationPressTime < POWER_PRESS_WINDOW_MS) {
                escalationPressCount++
            } else {
                escalationPressCount++
            }
            lastEscalationPressTime = now

            when {
                escalationPressCount >= 5 && currentLevel < 3 -> {
                    currentLevel = 3
                    updateLevelUI()
                }
                escalationPressCount >= 4 && currentLevel < 2 -> {
                    currentLevel = 2
                    updateLevelUI()
                }
            }
            return true
        }
        if (keyCode == KeyEvent.KEYCODE_BACK) {
            cancelSOS()
            return true
        }
        return super.onKeyDown(keyCode, event)
    }

    private fun dp(value: Int): Int {
        return TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            value.toFloat(),
            resources.displayMetrics
        ).toInt()
    }


}

package com.sleepguard.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import androidx.core.app.NotificationCompat

class ForegroundMonitorService : Service() {
    companion object {
        const val CHANNEL_ID = "sleep_guard_monitor"
        const val NOTIFICATION_ID = 1001
        private const val TAG = "ForegroundMonitorSvc"
        private const val BRIGHTNESS_THRESHOLD = 30.0
        private const val CAMERA_BLOCKED_TIMEOUT = 30
        private const val TICK_MS = 1000L

        @Volatile
        var inactivityTimeoutSeconds = 300

        @Volatile
        var elapsedSeconds = 0
            private set

        @Volatile
        var cameraBlockedSeconds = 0
            private set

        @Volatile
        var isCameraBlocked = false
            private set

        @Volatile
        var isMonitoring = false
            private set

        private var isLocking = false
        private var lastBrightness = 255.0
        private var lastCameraTouchMs = System.currentTimeMillis()
        private var tickHandler: Handler? = null
        private var tickRunnable: Runnable? = null
        private var devicePolicyManager: DevicePolicyManager? = null
        private var componentName: ComponentName? = null
        private var serviceInstance: ForegroundMonitorService? = null

        fun reportBrightness(brightness: Double) {
            lastBrightness = brightness
            val nowBlocked = brightness < BRIGHTNESS_THRESHOLD
            isCameraBlocked = nowBlocked
        }

        fun resetInteraction() {
            elapsedSeconds = 0
            cameraBlockedSeconds = 0
            isCameraBlocked = false
            lastBrightness = 255.0
            lastCameraTouchMs = System.currentTimeMillis()
        }

        fun getLastTouchTimeMs(): Long = TouchOverlayHelper.lastTouchTimeMs.coerceAtLeast(lastCameraTouchMs)

        fun init(context: Context) {
            devicePolicyManager =
                context.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
            componentName = ComponentName(context, DeviceAdminReceiver::class.java)
        }
    }

    private var wakeLock: PowerManager.WakeLock? = null

    override fun onCreate() {
        super.onCreate()
        serviceInstance = this
        init(this)
        createNotificationChannel()
        acquireWakeLock()
        startTickLoop()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val notification = createNotification()
        startForeground(NOTIFICATION_ID, notification)
        isMonitoring = true
        isLocking = false
        elapsedSeconds = 0
        cameraBlockedSeconds = 0
        isCameraBlocked = false
        lastBrightness = 255.0
        lastCameraTouchMs = System.currentTimeMillis()
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        super.onDestroy()
        isMonitoring = false
        isLocking = false
        stopTickLoop()
        releaseWakeLock()
        serviceInstance = null
    }

    private fun startTickLoop() {
        tickHandler = Handler(Looper.getMainLooper())
        tickRunnable = object : Runnable {
            override fun run() {
                tick()
                tickHandler?.postDelayed(this, TICK_MS)
            }
        }
        tickRunnable?.let { tickHandler?.post(it) }
    }

    private fun stopTickLoop() {
        tickRunnable?.let { tickHandler?.removeCallbacks(it) }
        tickRunnable = null
        tickHandler = null
    }

    private fun tick() {
        if (!isMonitoring || isLocking) return

        val now = System.currentTimeMillis()

        // Inactivity check — only when overlay is NOT visible (no global touch capture)
        if (!TouchOverlayHelper.isOverlayVisible) {
            val touchTime = getLastTouchTimeMs()
            if (touchTime > 0) {
                val idleMs = now - touchTime
                val idleSeconds = (idleMs / 1000).toInt()
                elapsedSeconds = idleSeconds.coerceAtMost(inactivityTimeoutSeconds)
            }

            if (elapsedSeconds >= inactivityTimeoutSeconds) {
                executeLock()
                return
            }
        }

        // Camera blocked check
        if (isCameraBlocked) {
            cameraBlockedSeconds++
        } else {
            cameraBlockedSeconds = 0
        }

        if (cameraBlockedSeconds >= CAMERA_BLOCKED_TIMEOUT) {
            executeLock()
            return
        }
    }

    private fun executeLock() {
        isLocking = true
        try {
            val dpm = devicePolicyManager
            val cn = componentName
            if (dpm != null && cn != null && dpm.isAdminActive(cn)) {
                dpm.lockNow()
            }
        } catch (e: Exception) {
            android.util.Log.e(TAG, "Lock failed: ${e.message}")
        }
        isMonitoring = false
        stopTickLoop()
        stopSelf()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "SleepGuard Monitor",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Sleep detection background monitoring"
                setShowBadge(false)
            }
            val notificationManager =
                getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun createNotification(): Notification {
        val pendingIntentFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            android.app.PendingIntent.FLAG_IMMUTABLE or android.app.PendingIntent.FLAG_UPDATE_CURRENT
        } else {
            android.app.PendingIntent.FLAG_UPDATE_CURRENT
        }
        val intent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = android.app.PendingIntent.getActivity(
            this, 0, intent, pendingIntentFlags
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("SleepGuard")
            .setContentText("Monitoring for sleep detection")
            .setSmallIcon(android.R.drawable.ic_lock_idle_lock)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setSilent(true)
            .build()
    }

    private fun acquireWakeLock() {
        val powerManager = getSystemService(POWER_SERVICE) as PowerManager
        wakeLock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "SleepGuard:MonitorWakeLock"
        )
        wakeLock?.acquire()
    }

    private fun releaseWakeLock() {
        wakeLock?.let {
            if (it.isHeld) it.release()
        }
        wakeLock = null
    }
}

package cn.studyassistant.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.provider.Settings
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.app.NotificationCompat

class FocusGuardService : Service() {
    private val handler = Handler(Looper.getMainLooper())
    private var allowedPackages: Set<String> = emptySet()
    private var overlayView: View? = null
    private var windowManager: WindowManager? = null

    private val monitorRunnable = object : Runnable {
        override fun run() {
            checkForegroundApp()
            handler.postDelayed(this, 1000L)
        }
    }

    override fun onCreate() {
        super.onCreate()
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, buildNotification())
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        allowedPackages = intent
            ?.getStringArrayListExtra(EXTRA_ALLOWED_PACKAGES)
            ?.toSet()
            ?: emptySet()
        allowedPackages = allowedPackages + packageName
        handler.removeCallbacks(monitorRunnable)
        handler.post(monitorRunnable)
        return START_STICKY
    }

    override fun onDestroy() {
        handler.removeCallbacks(monitorRunnable)
        hideOverlay()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun checkForegroundApp() {
        val foregroundPackage = currentForegroundPackage() ?: return
        if (foregroundPackage in allowedPackages) {
            hideOverlay()
            return
        }
        if (canDrawOverlays()) {
            showOverlay(foregroundPackage)
        }
    }

    private fun currentForegroundPackage(): String? {
        val usageStats = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val end = System.currentTimeMillis()
        val begin = end - 8_000L
        val events = usageStats.queryEvents(begin, end)
        val event = UsageEvents.Event()
        var foregroundPackage: String? = null
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            if (event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND) {
                foregroundPackage = event.packageName
            }
        }
        return foregroundPackage
    }

    private fun showOverlay(blockedPackage: String) {
        if (overlayView != null) return

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(36, 36, 36, 36)
            setBackgroundColor(Color.argb(238, 18, 24, 38))
        }

        val cardBackground = GradientDrawable().apply {
            cornerRadius = 34f
            setColor(Color.WHITE)
        }
        val card = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(42, 38, 42, 38)
            background = cardBackground
        }

        val tomato = TextView(this).apply {
            text = "🍅"
            textSize = 46f
            gravity = Gravity.CENTER
        }
        val title = TextView(this).apply {
            text = "现在是专注时间"
            textSize = 22f
            setTextColor(Color.rgb(28, 33, 45))
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
        }
        val subtitle = TextView(this).apply {
            text = "已拦截：$blockedPackage\n回到伴学继续完成这个番茄钟。"
            textSize = 15f
            setTextColor(Color.rgb(90, 96, 110))
            gravity = Gravity.CENTER
            setPadding(0, 18, 0, 24)
        }
        val actionBackground = GradientDrawable().apply {
            cornerRadius = 999f
            setColor(Color.rgb(232, 77, 77))
        }
        val action = TextView(this).apply {
            text = "回到学习"
            textSize = 16f
            setTextColor(Color.WHITE)
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            setPadding(38, 18, 38, 18)
            background = actionBackground
            setOnClickListener { openApp() }
        }

        card.addView(tomato)
        card.addView(title)
        card.addView(subtitle)
        card.addView(action)
        root.addView(
            card,
            LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            ).apply {
                marginStart = 18
                marginEnd = 18
            },
        )

        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }
        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            type,
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT,
        )
        params.gravity = Gravity.CENTER

        overlayView = root
        try {
            windowManager?.addView(root, params)
        } catch (_: Exception) {
            overlayView = null
        }
    }

    private fun hideOverlay() {
        val view = overlayView ?: return
        try {
            windowManager?.removeView(view)
        } catch (_: Exception) {
        } finally {
            overlayView = null
        }
    }

    private fun openApp() {
        val intent = packageManager.getLaunchIntentForPackage(packageName) ?: Intent(this, MainActivity::class.java)
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        startActivity(intent)
        hideOverlay()
    }

    private fun canDrawOverlays(): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.M || Settings.canDrawOverlays(this)
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channel = NotificationChannel(
            CHANNEL_ID,
            "专注防打扰",
            NotificationManager.IMPORTANCE_LOW,
        )
        channel.description = "番茄钟运行时监控分心应用"
        manager.createNotificationChannel(channel)
    }

    private fun buildNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher_1)
            .setContentTitle("专注防打扰运行中")
            .setContentText("白名单外应用会被提醒返回学习")
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    companion object {
        const val EXTRA_ALLOWED_PACKAGES = "allowed_packages"
        private const val CHANNEL_ID = "focus_guard_service"
        private const val NOTIFICATION_ID = 24001
    }
}

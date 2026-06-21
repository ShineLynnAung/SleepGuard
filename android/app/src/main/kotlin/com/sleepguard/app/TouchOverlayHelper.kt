package com.sleepguard.app

import android.content.Context
import android.content.Intent
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.os.Build
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import io.flutter.plugin.common.MethodChannel

class TouchOverlayHelper(
    private val context: Context,
    private val channel: MethodChannel
) {
    companion object {
        @Volatile
        var lastTouchTimeMs: Long = 0
        @Volatile
        var isOverlayVisible: Boolean = false
    }

    private var windowManager: WindowManager? = null
    private var bubbleView: ExitBubble? = null
    private var awakeOverlayView: AwakeOverlay? = null
    private var _isShowing = false

    fun isShowing(): Boolean = _isShowing

    fun showExitBubble() {
        hideAll()
        windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
        val layoutFlag = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }

        val bubbleSize = dpToPx(56)
        val params = WindowManager.LayoutParams(
            bubbleSize,
            bubbleSize,
            layoutFlag,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                    WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = dpToPx(16)
            y = dpToPx(16)
            dimAmount = 0f
        }

        val bubble = ExitBubble(context)
        bubble.setOnTapListener {
            hideAll()
            channel.invokeMethod("onOverlayAwake", null)
            bringAppToFront()
        }

        try {
            windowManager?.addView(bubble, params)
            _isShowing = true
            isOverlayVisible = true
            bubbleView = bubble
            lastTouchTimeMs = System.currentTimeMillis()
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    fun showAwakeOverlay() {
        hideAll()
        windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager

        val layoutFlag = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            layoutFlag,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                    WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                    WindowManager.LayoutParams.FLAG_DIM_BEHIND,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.CENTER
            dimAmount = 0.6f
        }

        val overlay = AwakeOverlay(context)
        overlay.setOnAwakeListener {
            hideAll()
            channel.invokeMethod("onOverlayAwake", null)
            bringAppToFront()
        }

        try {
            windowManager?.addView(overlay, params)
            _isShowing = true
            isOverlayVisible = true
            awakeOverlayView = overlay
            lastTouchTimeMs = System.currentTimeMillis()
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    fun hide() {
        hideAll()
    }

    private fun hideAll() {
        bubbleView?.let { v ->
            try { windowManager?.removeView(v) } catch (_: Exception) {}
        }
        bubbleView = null
        awakeOverlayView?.let { v ->
            try { windowManager?.removeView(v) } catch (_: Exception) {}
        }
        awakeOverlayView = null
        _isShowing = false
        isOverlayVisible = false
    }

    private fun bringAppToFront() {
        try {
            val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            if (launchIntent != null) {
                launchIntent.addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                            Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or
                            Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED
                )
                context.startActivity(launchIntent)
            }
        } catch (_: Exception) {}
    }

    private fun dpToPx(dp: Int): Int {
        return (dp * context.resources.displayMetrics.density).toInt()
    }

    private class ExitBubble(context: Context) : View(context) {
        private var tapListener: (() -> Unit)? = null

        private val bgPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#CCFFFFFF")
            setShadowLayer(8f, 0f, 2f, Color.parseColor("#66000000"))
        }
        private val xPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#DD000000")
            strokeWidth = 4f
            strokeCap = Paint.Cap.ROUND
        }

        private var offsetX = 0f
        private var offsetY = 0f
        private var isDragging = false

        fun setOnTapListener(listener: () -> Unit) {
            tapListener = listener
        }

        override fun onTouchEvent(event: MotionEvent): Boolean {
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    isDragging = false
                    offsetX = event.x
                    offsetY = event.y
                    return true
                }
                MotionEvent.ACTION_MOVE -> {
                    isDragging = true
                    val dx = event.x - offsetX
                    val dy = event.y - offsetY
                    val params = layoutParams as? WindowManager.LayoutParams ?: return true
                    params.x = (params.x + dx).toInt()
                    params.y = (params.y + dy).toInt()
                    layoutParams = params
                    return true
                }
                MotionEvent.ACTION_UP -> {
                    if (!isDragging) {
                        tapListener?.invoke()
                    }
                    isDragging = false
                    return true
                }
            }
            return false
        }

        override fun onDraw(canvas: Canvas) {
            super.onDraw(canvas)
            val cx = width / 2f
            val cy = height / 2f
            val radius = minOf(width, height) / 2f

            canvas.drawCircle(cx, cy, radius, bgPaint)
            val pad = radius * 0.35f
            canvas.drawLine(cx - pad, cy - pad, cx + pad, cy + pad, xPaint)
            canvas.drawLine(cx + pad, cy - pad, cx - pad, cy + pad, xPaint)
        }
    }

    private class AwakeOverlay(context: Context) : View(context) {
        private var awakeListener: (() -> Unit)? = null

        private val bgPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#80FFFFFF")
        }
        private val crossBgPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#CCFF5252")
            setShadowLayer(12f, 0f, 4f, Color.parseColor("#66000000"))
        }
        private val crossPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.WHITE
            strokeWidth = 6f
            strokeCap = Paint.Cap.ROUND
        }
        private val textPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#DD000000")
            textSize = dpToPxF(24)
            textAlign = Paint.Align.CENTER
            typeface = Typeface.DEFAULT_BOLD
        }
        private val subTextPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#BB000000")
            textSize = dpToPxF(14)
            textAlign = Paint.Align.CENTER
        }

        private val density = context.resources.displayMetrics.density

        override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
            super.onSizeChanged(w, h, oldw, oldh)
        }

        fun setOnAwakeListener(listener: () -> Unit) {
            awakeListener = listener
        }

        override fun onTouchEvent(event: MotionEvent): Boolean {
            if (event.action == MotionEvent.ACTION_UP) {
                val cx = width / 2f
                val cy = height / 2f
                val radius = minOf(width, height) * 0.15f
                val dx = event.x - cx
                val dy = event.y - cy
                val dist = Math.sqrt((dx * dx + dy * dy).toDouble()).toFloat()
                if (dist <= radius) {
                    awakeListener?.invoke()
                }
            }
            return true
        }

        override fun onDraw(canvas: Canvas) {
            super.onDraw(canvas)

            val cx = width / 2f
            val cy = height / 2f
            val radius = minOf(width, height) * 0.15f

            val textY = cy - radius - dpToPxF(12)
            canvas.drawText("Are you still awake?", cx, textY, textPaint)

            val subTextY = cy - radius - dpToPxF(32)
            canvas.drawText("Tap the X if you're awake", cx, subTextY, subTextPaint)

            canvas.drawCircle(cx, cy, radius, crossBgPaint)
            val pad = radius * 0.35f
            canvas.drawLine(cx - pad, cy - pad, cx + pad, cy + pad, crossPaint)
            canvas.drawLine(cx + pad, cy - pad, cx - pad, cy + pad, crossPaint)
        }

        private fun dpToPxF(dp: Int): Float {
            return (dp * density)
        }
    }
}

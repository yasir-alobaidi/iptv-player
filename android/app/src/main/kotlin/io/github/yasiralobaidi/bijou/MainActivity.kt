package io.github.yasiralobaidi.bijou

import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.PixelFormat
import android.os.Build
import android.os.Bundle
import android.os.Process
import android.os.SystemClock
import android.util.Log
import android.view.SurfaceHolder
import android.view.SurfaceView
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.FlutterSurfaceView
import io.flutter.embedding.android.RenderMode
import io.flutter.embedding.android.TransparencyMode
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    // The TV video-layer trial T0 (docs/plans/tv-video-layer-t0.md): only in a
    // build made with --dart-define=BIJOU_VIDEO_LAYER=true (BuildConfig, from
    // android/app/build.gradle.kts). Every override below does what
    // FlutterActivity does when it is false.
    private var layerTrial: VideoLayerTrial? = null
    private var layerChannel: MethodChannel? = null
    private var flutterSurface: FlutterSurfaceView? = null

    // Surface + transparent: a FlutterSurfaceView with a transparent pixel
    // format, z-ordered on top of the window (FlutterSurfaceView.init).
    override fun getRenderMode(): RenderMode =
        if (BuildConfig.VIDEO_LAYER) RenderMode.surface else super.getRenderMode()

    override fun getTransparencyMode(): TransparencyMode =
        if (BuildConfig.VIDEO_LAYER) TransparencyMode.transparent else super.getTransparencyMode()

    override fun onFlutterSurfaceViewCreated(flutterSurfaceView: FlutterSurfaceView) {
        super.onFlutterSurfaceViewCreated(flutterSurfaceView)
        if (BuildConfig.VIDEO_LAYER) flutterSurface = flutterSurfaceView
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (BuildConfig.VIDEO_LAYER) {
            // super.onCreate has set the FlutterView as the content; the
            // picture's SurfaceView goes under it.
            layerTrial = VideoLayerTrial(this).also {
                it.attach(findViewById(android.R.id.content))
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        if (!BuildConfig.VIDEO_LAYER) return
        // Runs inside super.onCreate, before the trial exists: the handler
        // looks it up at each call.
        layerChannel =
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, LAYER_CHANNEL).apply {
                setMethodCallHandler { call, result ->
                    val trial = layerTrial
                    when {
                        trial == null -> result.error("no_layer", "No video layer attached", null)
                        call.method == "setSpeed" -> {
                            val speed = (call.arguments as? Number)?.toInt()
                            if (speed == null) {
                                result.error("bad_args", "setSpeed takes an int", null)
                            } else {
                                trial.setSpeed(speed)
                                result.success(null)
                            }
                        }
                        call.method == "logState" -> result.success(trial.logState())
                        else -> result.notImplemented()
                    }
                }
            }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        layerChannel?.setMethodCallHandler(null)
        layerChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onStart() {
        super.onStart()
        layerTrial?.onStart()
    }

    override fun onResume() {
        super.onResume()
        layerTrial?.log("onResume")
    }

    override fun onPause() {
        layerTrial?.log("onPause")
        super.onPause()
    }

    override fun onStop() {
        layerTrial?.onStop()
        super.onStop()
    }

    // libmpv outlives a finished engine: its players keep wakeup callbacks into
    // that engine's freed memory, and the next engine in this process crashed at
    // its first play (ADR-032). A finished activity takes the process with it, so
    // a relaunch always starts clean.
    override fun onDestroy() {
        val leaving = isFinishing && !isChangingConfigurations
        layerTrial?.let {
            it.log("onDestroy (finishing: $leaving)")
            it.release()
        }
        layerTrial = null
        super.onDestroy()
        if (leaving) Process.killProcess(Process.myPid())
    }

    /** What logState reports about the Flutter side of the stack. */
    fun describeFlutterSide(): String {
        val flutterView = findViewById<View>(FlutterActivity.FLUTTER_VIEW_ID)
        val surface = flutterSurface
        return "renderMode=${getRenderMode()} transparency=${getTransparencyMode()} " +
            "flutterView=${flutterView?.javaClass?.simpleName} " +
            "${flutterView?.width}x${flutterView?.height} isOpaque=${flutterView?.isOpaque} " +
            "flutterSurface=${surface?.javaClass?.simpleName} isOpaque=${surface?.isOpaque} " +
            "surfaceValid=${surface?.holder?.surface?.isValid} " +
            "windowAttrsFormat=${formatName(window.attributes.format)}"
    }

    private companion object {
        const val LAYER_CHANNEL = "bijou/layer_trial"
    }
}

private const val TAG = "BijouLayer"

/** ~30 fps for the pattern. */
private const val FRAME_MS = 33L

/** How far the moving bar travels per frame at speed 1, in buffer pixels. */
private const val STEP_PX = 4f

private fun formatName(format: Int): String =
    when (format) {
        PixelFormat.TRANSLUCENT -> "TRANSLUCENT"
        PixelFormat.TRANSPARENT -> "TRANSPARENT"
        PixelFormat.OPAQUE -> "OPAQUE"
        PixelFormat.RGBA_8888 -> "RGBA_8888"
        PixelFormat.RGBX_8888 -> "RGBX_8888"
        PixelFormat.RGB_888 -> "RGB_888"
        PixelFormat.RGB_565 -> "RGB_565"
        else -> "format($format)"
    }

/**
 * T0's stand-in for the picture: a SurfaceView at index 0 of the content,
 * under the transparent FlutterView, with a moving test pattern drawn into it
 * from a background thread. Throwaway trial code; not the shipped layer.
 */
private class VideoLayerTrial(private val activity: MainActivity) : SurfaceHolder.Callback {
    private val view = SurfaceView(activity)
    private var content: ViewGroup? = null
    private var thread: PatternThread? = null

    @Volatile private var speed = 4

    @Volatile private var paused = false

    /** A frame is due even when frozen (speed 0): a new or resized surface. */
    @Volatile private var dirty = true

    @Volatile private var framesPosted = 0L

    // Touched by the pattern thread only.
    private var barX = 0f
    private val fill = Paint()
    private val text = Paint(Paint.ANTI_ALIAS_FLAG).apply { textAlign = Paint.Align.CENTER }
    private val outline =
        Paint(Paint.ANTI_ALIAS_FLAG).apply {
            textAlign = Paint.Align.CENTER
            style = Paint.Style.STROKE
            color = Color.BLACK
        }

    fun attach(content: ViewGroup) {
        this.content = content
        view.isFocusable = false
        view.isFocusableInTouchMode = false
        view.importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            // The Surface lives while the view is attached, not only while it
            // is visible: Home must not take it away (the plan's risk 7).
            view.setSurfaceLifecycle(SurfaceView.SURFACE_LIFECYCLE_FOLLOWS_ATTACHMENT)
        }
        view.holder.setFormat(PixelFormat.RGBX_8888)
        view.holder.addCallback(this)
        content.addView(
            view,
            0,
            FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
            ),
        )
        log("attached under the FlutterView: content=[${children()}] sdk=${Build.VERSION.SDK_INT}")
    }

    fun log(message: String) {
        Log.i(TAG, message)
    }

    fun setSpeed(value: Int) {
        speed = value.coerceIn(0, 64)
        dirty = true
        log("setSpeed $speed")
    }

    fun onStart() {
        paused = false
        dirty = true
        log("onStart (surface valid: ${view.holder.surface?.isValid})")
    }

    fun onStop() {
        // FOLLOWS_ATTACHMENT keeps the Surface while the app is away; nobody
        // sees it, so the pattern stops posting until onStart.
        paused = true
        log("onStop (surface valid: ${view.holder.surface?.isValid})")
    }

    /** Stops drawing; the callback stays, so a later surfaceDestroyed still logs. */
    fun release() {
        stopThread()
    }

    fun logState(): String {
        val holder = view.holder
        val frame = holder.surfaceFrame
        val state =
            "surfaceView ${view.width}x${view.height} attached=${view.isAttachedToWindow} " +
                "shown=${view.isShown} focusable=${view.isFocusable} " +
                "surfaceValid=${holder.surface?.isValid} buffer=${frame.width()}x${frame.height()} | " +
                "pattern speed=$speed frames=$framesPosted paused=$paused " +
                "thread=${thread?.isAlive == true} | ${activity.describeFlutterSide()} | " +
                "content=[${children()}]"
        log("logState: $state")
        return state
    }

    override fun surfaceCreated(holder: SurfaceHolder) {
        log("surfaceCreated (valid: ${holder.surface?.isValid})")
        dirty = true
        stopThread()
        thread = PatternThread(holder).also { it.start() }
    }

    override fun surfaceChanged(holder: SurfaceHolder, format: Int, width: Int, height: Int) {
        log("surfaceChanged ${width}x$height format=${formatName(format)}")
        dirty = true
    }

    override fun surfaceDestroyed(holder: SurfaceHolder) {
        log("surfaceDestroyed")
        // Nothing may touch the Surface after this returns.
        stopThread()
    }

    private fun stopThread() {
        val old = thread ?: return
        thread = null
        old.running = false
        old.interrupt()
        try {
            old.join(1000)
        } catch (e: InterruptedException) {
            Thread.currentThread().interrupt()
        }
        if (old.isAlive) log("pattern thread still alive after 1 s")
    }

    private fun children(): String {
        val parent = content ?: return ""
        return (0 until parent.childCount).joinToString { index ->
            val child = parent.getChildAt(index)
            "$index:${child.javaClass.simpleName}"
        }
    }

    private fun drawFrame(holder: SurfaceHolder) {
        val canvas =
            try {
                holder.lockCanvas()
            } catch (e: Exception) {
                null
            } ?: return
        var posted = false
        try {
            paintPattern(canvas)
        } finally {
            try {
                holder.unlockCanvasAndPost(canvas)
                posted = true
            } catch (e: IllegalStateException) {
                log("unlockCanvasAndPost failed: $e")
            }
        }
        if (posted) {
            dirty = false
            framesPosted++
        }
    }

    /** Colour bars, a moving white/black bar, and the frame count. */
    private fun paintPattern(canvas: Canvas) {
        val w = canvas.width.toFloat()
        val h = canvas.height.toFloat()
        val barWidth = w / BARS.size
        for (i in BARS.indices) {
            fill.color = BARS[i]
            canvas.drawRect(i * barWidth, 0f, (i + 1) * barWidth, h, fill)
        }
        barX = (barX + speed * STEP_PX) % w
        val moving = w / 48f
        fill.color = Color.WHITE
        canvas.drawRect(barX, 0f, barX + moving, h, fill)
        fill.color = Color.BLACK
        canvas.drawRect(barX + moving, 0f, barX + 2 * moving, h, fill)

        val big = h / 6f
        text.textSize = big
        text.color = Color.WHITE
        outline.textSize = big
        outline.strokeWidth = big / 12f
        val count = "${framesPosted + 1}"
        canvas.drawText(count, w / 2f, h * 0.42f, outline)
        canvas.drawText(count, w / 2f, h * 0.42f, text)

        val small = h / 24f
        text.textSize = small
        outline.textSize = small
        outline.strokeWidth = small / 8f
        val caption =
            "BijouLayer SurfaceView ${canvas.width}x${canvas.height}, speed $speed, ~30 fps"
        canvas.drawText(caption, w / 2f, h * 0.42f + small * 1.6f, outline)
        canvas.drawText(caption, w / 2f, h * 0.42f + small * 1.6f, text)
    }

    private inner class PatternThread(private val holder: SurfaceHolder) : Thread("BijouPattern") {
        @Volatile var running = true

        override fun run() {
            var next = SystemClock.uptimeMillis()
            while (running) {
                if (!paused && (speed != 0 || dirty)) drawFrame(holder)
                next += FRAME_MS
                val wait = next - SystemClock.uptimeMillis()
                if (wait > 0) {
                    try {
                        Thread.sleep(wait)
                    } catch (e: InterruptedException) {
                        return
                    }
                } else {
                    next = SystemClock.uptimeMillis()
                }
            }
        }
    }

    private companion object {
        // 75 % bars: white, yellow, cyan, green, magenta, red, blue.
        val BARS =
            intArrayOf(
                Color.rgb(191, 191, 191),
                Color.rgb(191, 191, 0),
                Color.rgb(0, 191, 191),
                Color.rgb(0, 191, 0),
                Color.rgb(191, 0, 191),
                Color.rgb(191, 0, 0),
                Color.rgb(0, 0, 191),
            )
    }
}

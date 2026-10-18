package io.github.yasiralobaidi.bijou

import android.app.Activity
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.Gravity
import android.view.SurfaceHolder
import android.view.SurfaceView
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.lang.reflect.Method

/**
 * The picture's own layer (docs/plans/tv-video-layer-and-frame-rate.md, T1):
 * a SurfaceView under the transparent Flutter view, which MediaCodec draws a
 * film into through mpv's `wid`. The hardware composer then scales and shows
 * the picture itself, at the display's own resolution and HDR, with no copy
 * into a Flutter texture.
 *
 * Only in a build with `--dart-define=BIJOU_VIDEO_LAYER=true` (or `clear`).
 * Hidden, its surface released, whenever no film plays on it: `show` makes
 * the surface and answers with its `wid` once it exists; `hide` lets it go.
 */
class VideoLayer(activity: Activity, messenger: BinaryMessenger) :
    SurfaceHolder.Callback, MethodChannel.MethodCallHandler {
    private val channel = MethodChannel(messenger, CHANNEL)
    private val handler = Handler(Looper.getMainLooper())
    private val view = SurfaceView(activity).apply {
        visibility = View.GONE
        isFocusable = false
        importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO
        // Kept while the view is attached, not only while it is visible to
        // the window (T0: Home still takes it).
        if (Build.VERSION.SDK_INT >= 34) {
            setSurfaceLifecycle(SurfaceView.SURFACE_LIFECYCLE_FOLLOWS_ATTACHMENT)
        }
    }

    /** mpv's `wid`: a JNI global reference to the surface; 0 while none. */
    private var wid = 0L
    private val waiting = mutableListOf<MethodChannel.Result>()

    init {
        view.holder.addCallback(this)
        channel.setMethodCallHandler(this)
    }

    /** Under everything else in [content], the FlutterView included. */
    fun attach(content: ViewGroup) {
        content.addView(view, 0, fullScreen())
    }

    fun release() {
        channel.setMethodCallHandler(null)
        hide()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "show" -> {
                view.keepScreenOn = true
                if (view.visibility != View.VISIBLE) {
                    view.visibility = View.VISIBLE
                    log("show")
                }
                if (wid != 0L && view.holder.surface?.isValid == true) {
                    result.success(info())
                } else {
                    waiting += result
                }
            }
            "hide" -> {
                hide()
                result.success(null)
            }
            "setRect" -> {
                val left = call.argument<Int>("left")
                val top = call.argument<Int>("top")
                val width = call.argument<Int>("width")
                val height = call.argument<Int>("height")
                if (left == null || top == null || width == null || height == null ||
                    width <= 0 || height <= 0
                ) {
                    result.error("bad_args", "setRect takes left, top, width, height", null)
                    return
                }
                view.layoutParams = FrameLayout.LayoutParams(width, height).apply {
                    gravity = Gravity.TOP or Gravity.START
                    leftMargin = left
                    topMargin = top
                }
                log("rect $left,$top ${width}x$height")
                result.success(null)
            }
            "state" -> result.success(describe())
            else -> result.notImplemented()
        }
    }

    private fun hide() {
        view.keepScreenOn = false
        if (view.visibility != View.GONE) {
            view.visibility = View.GONE
            log("hide")
        }
        for (result in waiting) result.success(null)
        waiting.clear()
    }

    override fun surfaceCreated(holder: SurfaceHolder) {
        wid = GlobalRefs.create(holder.surface)
        log("surfaceCreated wid=$wid")
        if (wid == 0L) return
        val answer = info()
        for (result in waiting) result.success(answer)
        waiting.clear()
    }

    override fun surfaceChanged(holder: SurfaceHolder, format: Int, width: Int, height: Int) {
        log("surfaceChanged ${width}x$height format=$format")
    }

    override fun surfaceDestroyed(holder: SurfaceHolder) {
        val old = wid
        wid = 0L
        log("surfaceDestroyed wid=$old")
        if (old == 0L) return
        // Dart moves mpv off it; mpv may still hold it for a moment, as with
        // media_kit's own texture surfaces (VideoOutput.onSurfaceCleanup).
        channel.invokeMethod("destroyed", old)
        handler.postDelayed({ GlobalRefs.delete(old) }, 5000)
    }

    private fun info(): Map<String, Any> {
        val frame = view.holder.surfaceFrame
        return mapOf("wid" to wid, "width" to frame.width(), "height" to frame.height())
    }

    private fun describe(): String =
        "visibility=${view.visibility} wid=$wid " +
            "surfaceValid=${view.holder.surface?.isValid} " +
            "frame=${view.holder.surfaceFrame} " +
            "view=${view.left},${view.top} ${view.width}x${view.height}"

    private fun log(message: String) = Log.i(TAG, message)

    private fun fullScreen() =
        FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT)

    private companion object {
        const val CHANNEL = "bijou/video_layer"
        const val TAG = "BijouLayer"
    }
}

/**
 * The JNI global references mpv's `wid` is, made by media_kit's own helper
 * (`media_kit_libs_android_video`), through reflection as media_kit_video's
 * VideoOutput does.
 */
private object GlobalRefs {
    private val helper: Class<*>? = runCatching {
        Class.forName("com.alexmercerind.mediakitandroidhelper.MediaKitAndroidHelper")
    }.getOrNull()

    private val newRef: Method? = runCatching {
        helper?.getDeclaredMethod("newGlobalObjectRef", Any::class.java)?.apply { isAccessible = true }
    }.getOrNull()

    private val deleteRef: Method? = runCatching {
        helper?.getDeclaredMethod("deleteGlobalObjectRef", Long::class.javaPrimitiveType)
            ?.apply { isAccessible = true }
    }.getOrNull()

    fun create(target: Any): Long =
        runCatching { newRef?.invoke(null, target) as? Long }
            .onFailure { Log.e("BijouLayer", "newGlobalObjectRef", it) }
            .getOrNull() ?: 0L

    fun delete(ref: Long) {
        runCatching { deleteRef?.invoke(null, ref) }
            .onFailure { Log.e("BijouLayer", "deleteGlobalObjectRef", it) }
    }
}

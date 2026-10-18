package io.github.yasiralobaidi.bijou

import android.app.Activity
import android.content.Context
import android.hardware.display.DisplayManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.Display
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Match frame rate (ADR-035, item 2): the display's modes, the window's preferred one, and the
 * display's changes, for `lib/data/platform/android_display_modes.dart` over `bijou/display`.
 *
 * - `read` → `{apiLevel, current, modes, alternativeRefreshRates, matchContentFrameRate}`, a mode
 *   being `{id, width, height, refreshRate}`; null when the display can't be read.
 * - `request {id}` → sets the window's `preferredDisplayModeId` (0: none, so the TV's own mode
 *   comes back); whether it could.
 * - `modeChanged` (to Dart) → the default display's new mode, while the activity is started.
 *
 * Nothing here throws to Dart: what fails is logged (tag "Bijou") and answered null or false.
 * All of it runs on the main thread: a MethodChannel's handler is called there, and the listener
 * is given the main looper.
 */
class DisplayModes(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler, DisplayManager.DisplayListener, DefaultLifecycleObserver {
    private val channel = MethodChannel(messenger, CHANNEL)
    private val displays = activity.getSystemService(Context.DISPLAY_SERVICE) as? DisplayManager
    private val main = Handler(Looper.getMainLooper())
    private var listening = false

    /** The mode last seen (0: none yet): only a change of mode is told. */
    private var lastModeId = 0

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "read" -> result.success(read())
            "request" -> result.success(request(call))
            else -> result.notImplemented()
        }
    }

    private fun defaultDisplay(): Display? = displays?.getDisplay(Display.DEFAULT_DISPLAY)

    private fun read(): Map<String, Any?>? {
        try {
            val display = defaultDisplay()
            if (display == null) {
                Log.w(TAG, "Display modes: no display to read")
                return null
            }
            val mode = display.mode
            return mapOf(
                "apiLevel" to Build.VERSION.SDK_INT,
                "current" to describe(mode),
                "modes" to display.supportedModes.map { describe(it) },
                "alternativeRefreshRates" to alternativeRates(mode),
                "matchContentFrameRate" to matchContentFrameRate(),
            )
        } catch (e: Exception) {
            Log.w(TAG, "Display modes couldn't be read", e)
            return null
        }
    }

    private fun describe(mode: Display.Mode): Map<String, Any> = mapOf(
        "id" to mode.modeId,
        "width" to mode.physicalWidth,
        "height" to mode.physicalHeight,
        "refreshRate" to rate(mode.refreshRate),
    )

    /** The float's own digits (23.976025), not its double's (23.97602462768555). */
    private fun rate(hz: Float): Double = hz.toString().toDouble()

    /** The rates the mode reaches without the screen going dark (Android 12 and later). */
    private fun alternativeRates(mode: Display.Mode): List<Double> =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            mode.alternativeRefreshRates.map { rate(it) }
        } else {
            emptyList()
        }

    /** The TV's Settings → Display & Sound → Match content frame rate (Android 12 and later). */
    private fun matchContentFrameRate(): String =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            when (displays?.matchContentFrameRateUserPreference) {
                DisplayManager.MATCH_CONTENT_FRAMERATE_ALWAYS -> "always"
                DisplayManager.MATCH_CONTENT_FRAMERATE_SEAMLESSS_ONLY -> "seamlessOnly"
                DisplayManager.MATCH_CONTENT_FRAMERATE_NEVER -> "never"
                else -> "unknown"
            }
        } else {
            "unknown"
        }

    private fun request(call: MethodCall): Boolean {
        try {
            val id = (call.argument<Any?>("id") as? Number)?.toInt()
            if (id == null || id < 0) {
                Log.w(TAG, "Display mode: a request with no mode id")
                return false
            }
            if (id != 0 && defaultDisplay()?.supportedModes?.any { it.modeId == id } != true) {
                Log.w(TAG, "Display mode $id isn't one of the display's")
                return false
            }
            val window = activity.window
            if (window == null) {
                Log.w(TAG, "Display mode $id: no window to ask it of")
                return false
            }
            val attributes = window.attributes
            attributes.preferredDisplayModeId = id
            window.attributes = attributes
            Log.i(TAG, "Display mode asked: ${if (id == 0) "none (the TV's own)" else "$id"}")
            return true
        } catch (e: Exception) {
            Log.w(TAG, "Display mode couldn't be asked for", e)
            return false
        }
    }

    override fun onStart(owner: LifecycleOwner) {
        if (listening) return
        try {
            val manager = displays ?: return
            manager.registerDisplayListener(this, main)
            listening = true
            // A change while the app was away is told now.
            onDisplayChanged(Display.DEFAULT_DISPLAY)
        } catch (e: Exception) {
            Log.w(TAG, "The display's changes can't be listened to", e)
        }
    }

    override fun onStop(owner: LifecycleOwner) {
        stopListening()
    }

    override fun onDestroy(owner: LifecycleOwner) {
        stopListening()
        try {
            channel.setMethodCallHandler(null)
            owner.lifecycle.removeObserver(this)
        } catch (e: Exception) {
            Log.w(TAG, "Display modes: couldn't let go", e)
        }
    }

    private fun stopListening() {
        if (!listening) return
        listening = false
        try {
            displays?.unregisterDisplayListener(this)
        } catch (e: Exception) {
            Log.w(TAG, "The display's listener couldn't be removed", e)
        }
    }

    override fun onDisplayChanged(displayId: Int) {
        if (displayId != Display.DEFAULT_DISPLAY) return
        try {
            val mode = defaultDisplay()?.mode ?: return
            if (mode.modeId == lastModeId) return
            val first = lastModeId == 0
            lastModeId = mode.modeId
            // The first look is where things start, not a change.
            if (first) return
            Log.i(
                TAG,
                "Display mode now ${mode.physicalWidth}x${mode.physicalHeight} " +
                    "${rate(mode.refreshRate)} Hz (${mode.modeId})",
            )
            channel.invokeMethod("modeChanged", describe(mode))
        } catch (e: Exception) {
            Log.w(TAG, "The display's change couldn't be told", e)
        }
    }

    override fun onDisplayAdded(displayId: Int) {}

    override fun onDisplayRemoved(displayId: Int) {}

    private companion object {
        const val CHANNEL = "bijou/display"
        const val TAG = "Bijou"
    }
}

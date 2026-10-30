package io.github.yasiralobaidi.bijou

import android.app.Activity
import android.app.PendingIntent
import android.app.PictureInPictureParams
import android.app.RemoteAction
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.graphics.drawable.Icon
import android.os.Build
import android.util.Log
import android.util.Rational
import androidx.annotation.RequiresApi
import androidx.lifecycle.Lifecycle
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Picture-in-picture on a phone, a tablet or a Chromebook (ADR-069), for
 * `lib/data/platform/android_picture_in_picture.dart` over `bijou/pip`.
 *
 * - `allow {on, width, height, pauseButton, paused}`: while on, leaving the app (Home, the home
 *   gesture) shrinks it to the picture: by itself from Android 12 (`setAutoEnterEnabled`), from
 *   [onUserLeaveHint] before. Off, the app leaves as ever.
 * - `changed {inPip, closed}` (to Dart), from [onModeChanged]: closed when the user dismissed the
 *   small window (the activity is stopped then, not brought back to the front).
 * - `action {name: playPause}` (to Dart): the small window's button, through a broadcast that
 *   only this app can send.
 *
 * Android 8 (API 26) and later, where the system has the feature; elsewhere `allow` does nothing.
 * Nothing here throws to Dart: what fails is logged (tag "Bijou").
 */
class PictureInPicture(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {
    private val channel = MethodChannel(messenger, CHANNEL)
    private val supported = Build.VERSION.SDK_INT >= 26 &&
        activity.packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)

    /** What Dart asked for; null: the app leaves as ever. */
    private var wish: Wish? = null

    private data class Wish(val width: Int, val height: Int, val pauseButton: Boolean, val paused: Boolean)

    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action != ACTION_PLAY_PAUSE) return
            channel.invokeMethod("action", mapOf("name" to "playPause"))
        }
    }
    private var receiving = false

    init {
        channel.setMethodCallHandler(this)
        if (supported) listen()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "allow" -> {
                if (supported && Build.VERSION.SDK_INT >= 26) allow(call)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    @RequiresApi(26)
    private fun allow(call: MethodCall) {
        try {
            val next = if (call.argument<Boolean>("on") == true) {
                Wish(
                    width = (call.argument<Number>("width"))?.toInt() ?: 0,
                    height = (call.argument<Number>("height"))?.toInt() ?: 0,
                    pauseButton = call.argument<Boolean>("pauseButton") == true,
                    paused = call.argument<Boolean>("paused") == true,
                )
            } else {
                null
            }
            if (next == wish) return
            wish = next
            activity.setPictureInPictureParams(params(next))
            Log.i(TAG, if (next == null) "Picture-in-picture: off" else "Picture-in-picture: on ($next)")
        } catch (e: Exception) {
            Log.w(TAG, "Picture-in-picture couldn't be set", e)
        }
    }

    /** Before Android 12 the app asks as it is left; from 12 the system does it by itself. */
    fun onUserLeaveHint() {
        if (!supported || Build.VERSION.SDK_INT < 26 || Build.VERSION.SDK_INT >= 31) return
        val wish = wish ?: return
        try {
            activity.enterPictureInPictureMode(params(wish))
        } catch (e: Exception) {
            Log.w(TAG, "Picture-in-picture couldn't start", e)
        }
    }

    /** The small window came or went; gone with the activity stopped, the user closed it. */
    fun onModeChanged(inPip: Boolean, lifecycle: Lifecycle) {
        val closed = !inPip && !lifecycle.currentState.isAtLeast(Lifecycle.State.STARTED)
        channel.invokeMethod("changed", mapOf("inPip" to inPip, "closed" to closed))
    }

    fun release() {
        channel.setMethodCallHandler(null)
        if (!receiving) return
        receiving = false
        try {
            activity.unregisterReceiver(receiver)
        } catch (e: IllegalArgumentException) {
            // Not registered after all: nothing to undo.
        }
    }

    private fun listen() {
        val filter = IntentFilter(ACTION_PLAY_PAUSE)
        if (Build.VERSION.SDK_INT >= 33) {
            activity.registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            activity.registerReceiver(receiver, filter)
        }
        receiving = true
    }

    @RequiresApi(26)
    private fun params(wish: Wish?): PictureInPictureParams {
        val builder = PictureInPictureParams.Builder()
        builder.setActions(if (wish?.pauseButton == true) listOf(playPause(wish.paused)) else emptyList())
        if (wish != null) builder.setAspectRatio(shape(wish.width, wish.height))
        if (Build.VERSION.SDK_INT >= 31) {
            builder.setAutoEnterEnabled(wish != null)
            // A video crossfades as the window shrinks rather than being drawn at every size.
            builder.setSeamlessResizeEnabled(false)
        }
        return builder.build()
    }

    /** The picture's shape, inside what the system takes (1:2.39 to 2.39:1); 16:9 unknown. */
    private fun shape(width: Int, height: Int): Rational {
        if (width <= 0 || height <= 0) return Rational(16, 9)
        val ratio = width.toDouble() / height
        return when {
            ratio > WIDEST -> Rational(238, 100)
            ratio < 1 / WIDEST -> Rational(100, 238)
            else -> Rational(width, height)
        }
    }

    @RequiresApi(26)
    private fun playPause(paused: Boolean): RemoteAction {
        val intent = Intent(ACTION_PLAY_PAUSE).setPackage(activity.packageName)
        val pending = PendingIntent.getBroadcast(
            activity,
            0,
            intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val title = if (paused) "Play" else "Pause"
        val icon = Icon.createWithResource(
            activity,
            if (paused) android.R.drawable.ic_media_play else android.R.drawable.ic_media_pause,
        )
        return RemoteAction(icon, title, title, pending)
    }

    private companion object {
        const val CHANNEL = "bijou/pip"
        const val TAG = "Bijou"
        const val ACTION_PLAY_PAUSE = "io.github.yasiralobaidi.bijou.PIP_PLAY_PAUSE"

        // Just inside the system's 2.39:1.
        const val WIDEST = 2.38
    }
}

package io.github.yasiralobaidi.bijou

import android.app.ApplicationExitInfo
import android.content.Context
import android.os.Build
import android.util.Log

/**
 * Which of Impeller's back ends draws Bijou (ADR-058). Flutter picks Vulkan wherever the GPU's
 * driver offers it and isn't on its own list of bad ones (the Chromecasts' Mali-G31 draws with
 * it); a driver that crashes drawing took the app with it on a TCL TV (Android 12), as search or
 * the menu opened. So after a native crash on one of Flutter's drawing threads, inside a GPU
 * driver, or one Android kept no tombstone of, every launch from the next one on draws with
 * OpenGL ES, which every Android TV has.
 * Kept for good on that TV (until its data is cleared): nothing tells a fixed driver apart.
 *
 * Decided in [MainActivity.getFlutterShellArgs], before the engine starts: the engine takes its
 * back end once, from `--impeller-backend`. Nothing here throws: the default is kept.
 */
object Drawing {
    private const val TAG = "Bijou"
    private const val PREFS = "bijou_drawing"
    private const val BACKEND = "backend"
    private const val SINCE = "since"
    private const val CAUSE = "cause"

    /** The newest end already looked at, so a tombstone is read once. */
    private const val CHECKED_UP_TO = "checkedUpTo"
    private const val OPENGLES = "opengles"

    /** Flutter's own drawing threads (`shell/common/thread_host.cc`, Impeller's Vulkan ones). */
    private val drawingThreads = listOf("1.raster", "1.io", "io.worker.", "IplrVk")

    /** Where GPU drivers live: Mali, Adreno, PowerVR, the Vulkan and EGL loaders. */
    private val driverFiles = listOf(
        "/egl/", "/hw/vulkan.", "libvulkan", "libGLES", "libEGL", "libmali", "libgpu",
        "libsrv_um", "libIMGegl", "libpvr", "libllvm-glnext",
    )

    /** The engine's arguments for the back end: none for Flutter's own choice. */
    fun shellArgs(context: Context): List<String> = try {
        val prefs = prefs(context)
        if (prefs.getString(BACKEND, null) != OPENGLES) lookAtLastCrash(context)
        if (prefs.getString(BACKEND, null) == OPENGLES) {
            Log.i(TAG, "Drawing with OpenGL ES (${prefs.getString(CAUSE, "")})")
            listOf("--impeller-backend=$OPENGLES")
        } else {
            emptyList()
        }
    } catch (e: Throwable) {
        Log.w(TAG, "The drawing back end couldn't be chosen", e)
        emptyList()
    }

    /** `{backend, since, cause}` for Dart: `default` or `opengles`, and why. */
    fun state(context: Context): Map<String, Any?> = try {
        val prefs = prefs(context)
        mapOf(
            BACKEND to (prefs.getString(BACKEND, null) ?: "default"),
            SINCE to prefs.getLong(SINCE, 0L).takeIf { it != 0L },
            CAUSE to prefs.getString(CAUSE, null),
        )
    } catch (e: Exception) {
        mapOf(BACKEND to "default")
    }

    fun isDrawingCrash(crash: NativeCrash): Boolean {
        val thread = crash.thread.orEmpty()
        return drawingThreads.any { thread.startsWith(it) } ||
            crash.frames.any { frame -> driverFiles.any { frame.file.contains(it) } }
    }

    private fun lookAtLastCrash(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return
        val prefs = prefs(context)
        val checkedUpTo = prefs.getLong(CHECKED_UP_TO, 0L)
        val exits = LastExits.recent(context).filter { it.timestamp > checkedUpTo }
        if (exits.isEmpty()) return
        // A native crash Android kept nothing of counts too: on a TV out of reach, the drawing
        // is the likeliest, and OpenGL ES costs little where it wasn't.
        val drawing = exits
            .filter { it.reason == ApplicationExitInfo.REASON_CRASH_NATIVE }
            .firstNotNullOfOrNull { exit ->
                val crash = LastExits.nativeCrash(exit)
                if (crash == null || isDrawingCrash(crash)) exit to crash else null
            }
        val editor = prefs.edit().putLong(CHECKED_UP_TO, exits.maxOf { it.timestamp })
        if (drawing != null) {
            val (exit, crash) = drawing
            val where = crash?.frames?.firstOrNull()?.line()?.substringAfter(' ')?.substringAfter(' ')
            val cause = if (crash == null) {
                "a native crash Android kept no details of"
            } else {
                listOfNotNull(crash.signal, crash.thread?.let { "on $it" }, where?.let { "in $it" })
                    .joinToString(" ")
            }
            editor.putString(BACKEND, OPENGLES).putLong(SINCE, exit.timestamp).putString(CAUSE, cause)
            Log.w(TAG, "Drawing with OpenGL ES from now on, after a crash drawing: $cause")
        }
        editor.commit()
    }

    private fun prefs(context: Context) = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
}

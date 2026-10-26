package io.github.yasiralobaidi.bijou

import android.app.ApplicationExitInfo
import android.content.Context
import android.os.Build
import android.util.Log

/**
 * Which renderer draws Bijou (ADR-058, ADR-060, ADR-061). Flutter draws with Impeller, on Vulkan
 * wherever the GPU's driver offers it and isn't on its own list of bad ones (the Chromecasts'
 * Mali-G31 draws with it), else with Impeller's own OpenGL ES. On a TCL TV (Android 12, 32-bit, a
 * PowerVR) the app closed within seconds of each launch, its memory damaged under Impeller: the
 * allocator found it on any thread, and once a glyph's scaler was found freed as text was painted.
 * So after a native crash on one of Flutter's drawing threads, inside a GPU driver, inside the
 * engine itself, or one Android kept no tombstone of, every launch from the next one on draws with
 * Skia on OpenGL ES (`--enable-impeller=false`): Flutter's renderer before Impeller, still in its
 * release engine, with neither Vulkan nor Impeller's text. Kept for good on that TV (until its
 * data is cleared): nothing tells a fixed driver apart.
 *
 * Not Impeller's own OpenGL ES, `--impeller-backend=opengles` (builds 343 to 345): a release
 * engine never reads it (`FlutterMain::SelectedRenderingAPI` takes it in debug and profile only;
 * an emulator drew with OpenGL ES anyway, having no Vulkan). Their mark becomes Skia's at the
 * first launch of this build, `since` then, when it first takes effect. Nor would it have helped:
 * the TCL's GPU is an older PowerVR, which Flutter keeps off Vulkan itself, and it was Impeller's
 * OpenGL ES on that driver that damaged the memory, within seconds of each launch. So a PowerVR
 * draws with Skia from its first launch, before any crash (ADR-061).
 *
 * Decided in [MainActivity.getFlutterShellArgs], before the engine starts: the engine takes its
 * renderer once. Nothing here throws: the default is kept.
 */
object Drawing {
    private const val TAG = "Bijou"
    private const val PREFS = "bijou_drawing"
    private const val BACKEND = "backend"
    private const val SINCE = "since"
    private const val CAUSE = "cause"

    /** The newest end already looked at, so a tombstone is read once. */
    private const val CHECKED_UP_TO = "checkedUpTo"
    private const val SKIA = "skia"

    /** Builds 343 to 345's mark: Impeller's OpenGL ES, asked for and ignored. */
    private const val IGNORED_OPENGLES = "opengles"

    /** The GPU was looked at: `getprop` runs at one launch only. */
    private const val GPU_CHECKED = "gpuChecked"

    /** Flutter's own drawing threads (`shell/common/thread_host.cc`, Impeller's Vulkan ones). */
    private val drawingThreads = listOf("1.raster", "1.io", "io.worker.", "IplrVk")

    private const val POWERVR = "powervr"

    /** The engine: its UI work is on the main thread (Flutter 3.29), text painted there too. */
    private const val ENGINE = "libflutter.so"

    /** Where GPU drivers live: Mali, Adreno, PowerVR, the Vulkan and EGL loaders. */
    private val driverFiles = listOf(
        "/egl/", "/hw/vulkan.", "libvulkan", "libGLES", "libEGL", "libmali", "libgpu",
        "libsrv_um", "libIMGegl", "libpvr", "libllvm-glnext",
    )

    /** The engine's arguments for its renderer: none for Flutter's own choice. */
    fun shellArgs(context: Context): List<String> = try {
        val prefs = prefs(context)
        if (prefs.getString(BACKEND, null) == IGNORED_OPENGLES) {
            prefs.edit().putString(BACKEND, SKIA).putLong(SINCE, System.currentTimeMillis()).commit()
            Log.w(TAG, "Impeller's OpenGL ES was asked for and ignored: Skia from now on")
        }
        if (prefs.getString(BACKEND, null) != SKIA && !prefs.getBoolean(GPU_CHECKED, false)) {
            lookAtGpu(context)
        }
        if (prefs.getString(BACKEND, null) != SKIA) lookAtLastCrash(context)
        if (prefs.getString(BACKEND, null) == SKIA) {
            Log.i(TAG, "Drawing with Skia on OpenGL ES (${prefs.getString(CAUSE, "")})")
            listOf("--enable-impeller=false")
        } else {
            emptyList()
        }
    } catch (e: Throwable) {
        Log.w(TAG, "The drawing back end couldn't be chosen", e)
        emptyList()
    }

    /** `{backend, since, cause}` for Dart: `default` or `skia`, and why. */
    fun state(context: Context): Map<String, Any?> = try {
        val prefs = prefs(context)
        mapOf(
            BACKEND to (if (prefs.getString(BACKEND, null) == SKIA) SKIA else "default"),
            SINCE to prefs.getLong(SINCE, 0L).takeIf { it != 0L },
            CAUSE to prefs.getString(CAUSE, null),
        )
    } catch (e: Exception) {
        mapOf(BACKEND to "default")
    }

    /** On a drawing thread, in a GPU driver, or in the engine: its first frame past libc. */
    fun isDrawingCrash(crash: NativeCrash): Boolean {
        val thread = crash.thread.orEmpty()
        return drawingThreads.any { thread.startsWith(it) } ||
            crash.frames.any { frame -> driverFiles.any { frame.file.contains(it) } } ||
            crash.frames.firstOrNull { !it.file.endsWith("/libc.so") }?.file?.endsWith(ENGINE) == true
    }

    /**
     * A PowerVR draws with Skia from now on: the drivers the system loads for it are named so
     * (`ro.hardware.vulkan`, `ro.hardware.egl`; the TCL's `vulkan.powervr.so`).
     */
    private fun lookAtGpu(context: Context) {
        val drivers = listOf("ro.hardware.vulkan", "ro.hardware.egl").map(::property)
        Log.i(TAG, "GPU drivers: Vulkan ${drivers[0].ifEmpty { "-" }}, EGL ${drivers[1].ifEmpty { "-" }}")
        val editor = prefs(context).edit().putBoolean(GPU_CHECKED, true)
        if (drivers.any { it.contains(POWERVR, ignoreCase = true) }) {
            val cause = "a PowerVR GPU"
            editor.putString(BACKEND, SKIA).putLong(SINCE, System.currentTimeMillis()).putString(CAUSE, cause)
            Log.w(TAG, "Drawing with Skia on OpenGL ES: $cause")
        }
        editor.commit()
    }

    /** One system property (an app reads them through `getprop`); empty when it can't be read. */
    private fun property(name: String): String = try {
        // Its output ends as it does; destroyed whatever happens (hard rule 8).
        val getprop = ProcessBuilder("/system/bin/getprop", name).redirectErrorStream(true).start()
        try {
            getprop.inputStream.bufferedReader().use { it.readText() }.trim()
        } finally {
            getprop.destroy()
        }
    } catch (e: Exception) {
        ""
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
            editor.putString(BACKEND, SKIA).putLong(SINCE, exit.timestamp).putString(CAUSE, cause)
            Log.w(TAG, "Drawing with Skia on OpenGL ES from now on, after a crash drawing: $cause")
        }
        editor.commit()
    }

    private fun prefs(context: Context) = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
}

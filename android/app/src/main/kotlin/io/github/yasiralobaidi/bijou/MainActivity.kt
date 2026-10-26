package io.github.yasiralobaidi.bijou

import android.os.Bundle
import android.os.Process
import android.util.Log
import android.view.KeyEvent
import androidx.lifecycle.LifecycleEventObserver
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.RenderMode
import io.flutter.embedding.android.TransparencyMode
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterShellArgs

class MainActivity : FlutterActivity() {
    // The picture's own layer (VideoLayer, T1, ADR-035 §1): in every build but
    // one made with --dart-define=BIJOU_VIDEO_LAYER=off (BuildConfig, from
    // android/app/build.gradle.kts). Without it every override below does what
    // FlutterActivity does.
    private var videoLayer: VideoLayer? = null

    // Why the last runs ended, for Dart (ADR-058).
    private var lastExits: LastExits? = null

    // The TV and each run's own log, for the report (ADR-059).
    private var systemInfo: SystemInfo? = null

    // The remotes and keyboards already named in this run's log.
    private val keyDevices = mutableSetOf<Int>()

    // The key last logged: Flutter hands a key it didn't handle back to the activity.
    private var lastKey: KeyEvent? = null

    // Read as the engine is made, once per process: OpenGL ES after a crash
    // drawing with Vulkan (ADR-058).
    override fun getFlutterShellArgs(): FlutterShellArgs =
        super.getFlutterShellArgs().apply { Drawing.shellArgs(this@MainActivity).forEach(::add) }

    // A FlutterSurfaceView with a transparent pixel format, z-ordered on top of
    // the window: where Flutter paints nothing, the layer under it shows.
    override fun getRenderMode(): RenderMode =
        if (BuildConfig.VIDEO_LAYER) RenderMode.surface else super.getRenderMode()

    override fun getTransparencyMode(): TransparencyMode =
        if (BuildConfig.VIDEO_LAYER) TransparencyMode.transparent else super.getTransparencyMode()

    // Runs inside super.onCreate, before the content view exists. Match frame
    // rate (ADR-035): the display's modes over `bijou/display`, its listener
    // held while the activity is started.
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        lifecycle.addObserver(DisplayModes(this, flutterEngine.dartExecutor.binaryMessenger))
        lastExits = LastExits(this, flutterEngine.dartExecutor.binaryMessenger)
        systemInfo = SystemInfo(this, flutterEngine.dartExecutor.binaryMessenger)
        if (BuildConfig.VIDEO_LAYER) {
            videoLayer = VideoLayer(this, flutterEngine.dartExecutor.binaryMessenger)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        // First, so a crash anywhere after it leaves its stack (ADR-058).
        JavaCrashes.install(this)
        // Off the main thread: logcat reads this process's earlier lines too (ADR-059).
        val context = applicationContext
        Thread({ RunLog.start(context) }, "bijou-runlog").start()
        lifecycle.addObserver(LifecycleEventObserver { _, event -> Log.i(TAG, "Activity ${event.name}") })
        super.onCreate(savedInstanceState)
        if (!BuildConfig.VIDEO_LAYER) return
        videoLayer?.attach(findViewById(android.R.id.content))
        // T0 found the window itself a third full-screen layer the composer
        // drew on the GPU; `clear` tries it with no background of its own.
        if (BuildConfig.VIDEO_LAYER_CLEAR_WINDOW) window.setBackgroundDrawable(null)
        Log.i("BijouLayer", "on (clear window: ${BuildConfig.VIDEO_LAYER_CLEAR_WINDOW})")
    }

    // What the remote sent, into this run's log (ADR-059): a TCL TV closed as a key opened
    // search or the menu. Never a character: a keyboard may be typing a password.
    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        if (event.repeatCount <= 1) {
            val key = if (event.isPrintingKey) "a character key" else KeyEvent.keyCodeToString(event.keyCode).removePrefix("KEYCODE_")
            val what = when {
                event.action == KeyEvent.ACTION_UP -> "up"
                event.repeatCount == 1 -> "held"
                else -> "down"
            }
            val from = if (keyDevices.add(event.deviceId)) " (from ${event.device?.name ?: "device ${event.deviceId}"})" else ""
            val last = lastKey
            val again = last != null && last.eventTime == event.eventTime && last.action == event.action &&
                last.keyCode == event.keyCode
            lastKey = event
            Log.i(TAG, if (again) "Key $key $what: Flutter didn't take it" else "Key $key $what$from")
        }
        return super.dispatchKeyEvent(event)
    }

    // Another window over Bijou's (a system panel, a dialog) takes the focus first.
    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        Log.i(TAG, "Window focus ${if (hasFocus) "gained" else "lost"}")
    }

    override fun onTrimMemory(level: Int) {
        super.onTrimMemory(level)
        Log.i(TAG, "Memory: trim level $level")
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        lastExits?.release()
        lastExits = null
        systemInfo?.release()
        systemInfo = null
        videoLayer?.release()
        videoLayer = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    // libmpv outlives a finished engine: its players keep wakeup callbacks into
    // that engine's freed memory, and the next engine in this process crashed at
    // its first play (ADR-032). A finished activity takes the process with it, so
    // a relaunch always starts clean.
    override fun onDestroy() {
        val leaving = isFinishing && !isChangingConfigurations
        super.onDestroy()
        if (!leaving) return
        // This end is the app's own, not one to tell of (ADR-058).
        LastExits.leaving(this)
        Log.i(TAG, "Leaving: the activity finished")
        RunLog.stop(this)
        Process.killProcess(Process.myPid())
    }

    private companion object {
        const val TAG = "Bijou"
    }
}

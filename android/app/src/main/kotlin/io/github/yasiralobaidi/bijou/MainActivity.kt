package io.github.yasiralobaidi.bijou

import android.os.Bundle
import android.os.Process
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.RenderMode
import io.flutter.embedding.android.TransparencyMode
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    // The picture's own layer (VideoLayer, T1, ADR-035 §1): in every build but
    // one made with --dart-define=BIJOU_VIDEO_LAYER=off (BuildConfig, from
    // android/app/build.gradle.kts). Without it every override below does what
    // FlutterActivity does.
    private var videoLayer: VideoLayer? = null

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
        if (BuildConfig.VIDEO_LAYER) {
            videoLayer = VideoLayer(this, flutterEngine.dartExecutor.binaryMessenger)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (!BuildConfig.VIDEO_LAYER) return
        videoLayer?.attach(findViewById(android.R.id.content))
        // T0 found the window itself a third full-screen layer the composer
        // drew on the GPU; `clear` tries it with no background of its own.
        if (BuildConfig.VIDEO_LAYER_CLEAR_WINDOW) window.setBackgroundDrawable(null)
        Log.i("BijouLayer", "on (clear window: ${BuildConfig.VIDEO_LAYER_CLEAR_WINDOW})")
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
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
        if (leaving) Process.killProcess(Process.myPid())
    }
}

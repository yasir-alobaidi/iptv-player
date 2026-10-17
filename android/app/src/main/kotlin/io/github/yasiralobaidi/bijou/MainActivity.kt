package io.github.yasiralobaidi.bijou

import android.os.Process
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
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

package io.github.yasiralobaidi.bijou

import android.app.UiModeManager
import android.content.Context
import android.content.pm.PackageManager
import android.content.res.Configuration

// Which shell Dart draws (ADR-068), passed as `--form-factor=` in the
// entrypoint's arguments: "tv" for a TV driven by a remote, "mobile" for a
// phone, a tablet or a Chromebook. One APK, one bundle, for both.
object DeviceKind {
    fun formFactor(context: Context): String {
        val packages = context.packageManager
        val uiMode = (context.getSystemService(Context.UI_MODE_SERVICE) as? UiModeManager)?.currentModeType
        // Google TV, Android TV and Fire TV say they are a TV one way or another.
        if (uiMode == Configuration.UI_MODE_TYPE_TELEVISION ||
            packages.hasSystemFeature(PackageManager.FEATURE_LEANBACK) ||
            packages.hasSystemFeature(PackageManager.FEATURE_TELEVISION) ||
            packages.hasSystemFeature(FIRE_TV)
        ) {
            return TV
        }
        // A Chromebook has a pointer and a keyboard: the touch layouts take
        // both, and the rail at its width.
        if (packages.hasSystemFeature(PC)) return MOBILE
        // A box that says neither, with no touchscreen, is driven by a remote.
        if (!packages.hasSystemFeature(PackageManager.FEATURE_TOUCHSCREEN)) return TV
        return MOBILE
    }

    private const val TV = "tv"
    private const val MOBILE = "mobile"
    private const val FIRE_TV = "amazon.hardware.fire_tv"

    // PackageManager.FEATURE_PC, from API 27.
    private const val PC = "android.hardware.type.pc"
}

# T0: the layer stack on the TV (a throwaway trial)

T0 of [the layer plan](tv-video-layer-and-frame-rate.md): a transparent FlutterSurfaceView over an Android SurfaceView, with no mpv. `MainActivity.kt` adds a SurfaceView at index 0 of the content (not focusable, Surface kept while attached on API 34+) and draws a moving pattern into it at ~30 fps (thread `BijouPattern`). Flutter runs `lib/main_layer_trial.dart`: transparent apart from a top bar and the bottom OSD. Only `--dart-define=BIJOU_VIDEO_LAYER=true` turns this on: Gradle decodes `dart-defines` into `BuildConfig.VIDEO_LAYER`. Without it the app is as before.

## Build, install, run
```
flutter build apk --debug --target-platform android-arm -t lib/main_layer_trial.dart --dart-define=BIJOU_VIDEO_LAYER=true
adb -s <tv> install -r -d build/app/outputs/flutter-apk/app-debug.apk   # replaces Bijou, keeps its data
adb -s <tv> shell am start -n io.github.yasiralobaidi.bijou/.MainActivity
```
`--profile` in place of `--debug` for CPU numbers (debug Dart is JIT). Reinstall the normal build when you're done. The Vulkan fallback: in `AndroidManifest.xml`, inside `<application>`, add `<meta-data android:name="io.flutter.embedding.android.ImpellerBackend" android:value="opengles" />` and rebuild.

## The screen
Top bar: the define and **Flutter frames/s** (the counter leaves out its own repaint, so idle reads 0). The bottom gradient shows the last action and five buttons (arrows move, OK/Enter activates, a white ring marks focus):
- **Hide OSD**: fades the gradient and buttons out. Any key brings them back and does nothing else.
- **Opaque Flutter**: a black full-screen Flutter background, to compare composition (the pattern disappears).
- **Pattern speed**: cycles 1 → 4 → 16 → 0. At 0 the pattern freezes and Android posts no new frames.
- **Show dialog**: a Flutter dialog with a dimming barrier over the pattern. Back or Close dismisses it.
- **Log state**: Android logs and returns the SurfaceView's size, the Surface's validity, the frames posted, the FlutterView and its surface's class and `isOpaque`, and the content's children.

## The checks (`pid=$(adb -s <tv> shell pidof io.github.yasiralobaidi.bijou)`)
1. **Transparency, z-order:** bars through the middle, the gradient darkening them, buttons and dialog above. `adb logcat -d | grep -iE "impeller|vulkan|opengles"` shows the backend. `adb exec-out screencap -p > t0.png` may show the layer as black (the plan's risk 11), so your eyes decide.
2. **Focus:** ←/→ along the row, OK on each, Hide OSD then any key, the dialog's Close focused, Back.
3. **Composition:** `adb shell dumpsys SurfaceFlinger | sed -n '/HWC layers/,/^$/p'` prints a table with one row per layer and a `Comp Type` column. `DEVICE` means the hardware composer draws the layer; `CLIENT` means the GPU composites it (bad). The rows are two `SurfaceView[io.github.yasiralobaidi.bijou/…MainActivity]…(BLAST)` (the pattern, then Flutter's above it) and the activity window. Record the table four times: OSD shown, OSD hidden, Opaque Flutter on, dialog open.
4. **Flutter idle:** OSD hidden, pattern at 16. The counter should read 0. `adb shell top -H -b -d 5 -n 3 -p $pid`: `1.raster` and `1.ui` near 0 %, `BijouPattern` is the pattern's own cost. `adb shell top -b -d 5 -n 3 -m 10` gives SurfaceFlinger's share (12 % with today's texture). `adb shell dumpsys gfxinfo io.github.yasiralobaidi.bijou framestats` counts the Android window's frames (HWUI), not Flutter's, and should stay flat. Flutter's buffers: `adb shell dumpsys SurfaceFlinger --list` gives the name of Flutter's layer. Run `--latency-clear`, wait 10 s, then `--latency '<name>'`: no new rows means no frames.
5. **Lifecycle:** `adb logcat -s BijouLayer` through Home → back → Back. With FOLLOWS_ATTACHMENT, Home should log `onPause`, `onStop (surface valid: true)` and no `surfaceDestroyed`. The return logs `onStart`/`onResume` and the pattern goes on. Back logs `onDestroy (finishing: true)`, then the process ends (ADR-032), usually before any `surfaceDestroyed`. Press Log state before and after.

## Go / no-go
**Go:** the pattern shows through Flutter's transparent areas, with the OSD and dialog above it, on Vulkan (or on opengles with the meta-data, a choice to record). Focus works as in the app. With the OSD hidden, both SurfaceViews are `DEVICE`. Flutter draws ~0 frames/s while the pattern moves. SurfaceFlinger doesn't cost more than today. The Surface survives Home, or comes back without a crash.
**No-go:** no transparency (black, garbage, or no pattern) on both backends; the OSD under the pattern; broken focus; `CLIENT` for the full-screen layers with the OSD hidden, or SurfaceFlinger clearly above today; Flutter drawing at the pattern's rate; a crash or a lasting black picture after Home. `CLIENT` only while the OSD shows is acceptable (the OSD is up for seconds); write it down.

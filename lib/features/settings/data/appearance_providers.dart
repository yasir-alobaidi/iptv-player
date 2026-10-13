import 'package:flutter/widgets.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/core/text/format.dart';
import 'package:iptv_player/design/appearance.dart';
import 'package:iptv_player/features/settings/domain/appearance_store.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'appearance_providers.g.dart';

/// Where Settings → Appearance is kept: in memory until `bootstrap()`
/// gives the database's, already read.
@Riverpod(keepAlive: true)
AppearanceStore appearanceStore(Ref ref) => InMemoryAppearanceStore();

/// What the desktop says about text size, motion and the clock, read
/// again whenever the system reports a change and whenever the window
/// comes back to the front (a change of the clock format alone isn't
/// announced). Tests give it a value.
@Riverpod(keepAlive: true)
class DesktopAppearance extends _$DesktopAppearance {
  @override
  SystemAppearance build() {
    final observer = _DesktopObserver(() => state = _read());
    WidgetsBinding.instance.addObserver(observer);
    ref.onDispose(() => WidgetsBinding.instance.removeObserver(observer));
    return _read();
  }

  static SystemAppearance _read() {
    final system = WidgetsBinding.instance.platformDispatcher;
    return SystemAppearance(
      textScale: system.textScaleFactor,
      reduceMotion: system.accessibilityFeatures.disableAnimations,
      use24Hour: system.alwaysUse24HourFormat,
    );
  }
}

class _DesktopObserver with WidgetsBindingObserver {
  new(this.onChange);

  final VoidCallback onChange;

  @override
  void didChangeTextScaleFactor() => onChange();

  @override
  void didChangeAccessibilityFeatures() => onChange();

  @override
  void didChangeLocales(List<Locale>? locales) => onChange();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) onChange();
  }
}

/// What the Appearance page shows: the choices, and why they couldn't be
/// read when they couldn't.
@immutable
final class AppearanceState {
  const new(this.settings, {this.readFailure});

  final AppearanceSettings settings;
  final AppFailure? readFailure;

  @override
  bool operator ==(Object other) =>
      other is AppearanceState &&
      other.settings == settings &&
      other.readFailure == readFailure;

  @override
  int get hashCode => Object.hash(settings, readFailure);
}

/// Settings → Appearance. A change shows at once and is saved behind it;
/// one that can't be saved still holds for this run.
@Riverpod(keepAlive: true)
class AppearanceController extends _$AppearanceController {
  @override
  AppearanceState build() {
    final store = ref.watch(appearanceStoreProvider);
    return AppearanceState(store.settings, readFailure: store.readFailure);
  }

  Future<Result<void>> change(AppearanceSettings settings) async {
    state = AppearanceState(settings, readFailure: state.readFailure);
    final saved = await ref.read(appearanceStoreProvider).save(settings);
    // What is kept now is what shows: nothing is left unread.
    if (saved is Ok) state = AppearanceState(state.settings);
    return saved;
  }

  /// Reads the stored choices again, after a read that failed.
  Future<void> retry() async {
    final read = await ref.read(appearanceStoreProvider).load();
    state = switch (read) {
      Ok(:final value) => AppearanceState(value),
      Err(:final failure) => AppearanceState(
        state.settings,
        readFailure: failure,
      ),
    };
  }
}

/// The look the app is drawn with: the user's choices, with every
/// "System" answered by the desktop.
@Riverpod(keepAlive: true)
Appearance appearance(Ref ref) => ref
    .watch(appearanceControllerProvider)
    .settings
    .resolve(ref.watch(desktopAppearanceProvider));

/// How a time of day is written, for text made away from a screen (a
/// toast, a notification). Screens read `context.tokens.timeStyle`.
@Riverpod(keepAlive: true)
TimeStyle timeStyle(Ref ref) => ref.watch(appearanceProvider).timeStyle;

import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/design/appearance.dart';

/// Where Settings → Appearance is kept.
///
/// [settings] is a plain getter because the first frame needs it:
/// `bootstrap()` reads the stored value before `runApp`, so the app never
/// opens in one look and changes to another (Phase 9 decision 2).
abstract interface class AppearanceStore {
  /// What was read last: the defaults before any read and after one that
  /// failed.
  AppearanceSettings get settings;

  /// Why the last read failed, or null. A damaged value is not a failure:
  /// it reads as the defaults.
  AppFailure? get readFailure;

  /// Reads the stored value again.
  Future<Result<AppearanceSettings>> load();

  Future<Result<void>> save(AppearanceSettings settings);
}

/// Keeps the choices for the lifetime of the process only. Used by tests
/// and as the default until `bootstrap()` overrides the provider.
final class InMemoryAppearanceStore implements AppearanceStore {
  new([this._settings = const AppearanceSettings()]);

  AppearanceSettings _settings;

  @override
  AppearanceSettings get settings => _settings;

  @override
  AppFailure? get readFailure => null;

  @override
  Future<Result<AppearanceSettings>> load() async => Ok(_settings);

  @override
  Future<Result<void>> save(AppearanceSettings settings) async {
    _settings = settings;
    return const Ok(null);
  }
}

import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/data/settings/settings_repository.dart';
import 'package:iptv_player/design/appearance.dart';
import 'package:iptv_player/features/settings/domain/appearance_store.dart';

/// [AppearanceStore] in the `settings` table, as one JSON value.
///
/// [open] reads it once, before the first frame.
final class DbAppearanceStore implements AppearanceStore {
  new(this._repository);

  /// A store that has already read what is kept.
  static Future<DbAppearanceStore> open(SettingsRepository repository) async {
    final store = DbAppearanceStore(repository);
    await store.load();
    return store;
  }

  final SettingsRepository _repository;
  var _settings = const AppearanceSettings();
  AppFailure? _readFailure;

  @override
  AppearanceSettings get settings => _settings;

  @override
  AppFailure? get readFailure => _readFailure;

  @override
  Future<Result<AppearanceSettings>> load() async {
    final read = (await _repository.readValue<Object?>(
      SettingsKeys.appearance,
      null,
    )).map(AppearanceSettings.fromJson);
    switch (read) {
      case Ok(:final value):
        _settings = value;
        _readFailure = null;
      case Err(:final failure):
        _readFailure = failure;
    }
    return read;
  }

  @override
  Future<Result<void>> save(AppearanceSettings settings) {
    _settings = settings;
    return _repository.writeValue(SettingsKeys.appearance, settings.toJson());
  }
}

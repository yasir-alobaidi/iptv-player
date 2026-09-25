import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/data/settings/settings_repository.dart';
import 'package:iptv_player/features/guide/domain/guide_settings.dart';

/// [GuideSettingsStore] in the `settings` table, as one JSON value.
final class DbGuideSettingsStore implements GuideSettingsStore {
  new(this._settings);

  final SettingsRepository _settings;

  @override
  Future<Result<GuideSettings>> load() async =>
      (await _settings.readValue<Object?>(
        SettingsKeys.guide,
        null,
      )).map(GuideSettings.fromJson);

  @override
  Future<Result<void>> save(GuideSettings settings) =>
      _settings.writeValue(SettingsKeys.guide, settings.toJson());
}

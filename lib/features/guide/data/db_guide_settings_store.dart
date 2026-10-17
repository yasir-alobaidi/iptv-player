import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/data/settings/settings_repository.dart';
import 'package:iptv_player/features/guide/domain/guide_settings.dart';

/// [GuideSettingsStore] in the `settings` table, as one JSON value.
/// Nothing stored, or a choice damaged, reads as [defaults]: the
/// device's (`GuideSettings.defaultsOn`).
final class DbGuideSettingsStore implements GuideSettingsStore {
  new(this._settings, {this.defaults = const GuideSettings()});

  final SettingsRepository _settings;
  final GuideSettings defaults;

  @override
  Future<Result<GuideSettings>> load() async =>
      (await _settings.readValue<Object?>(
        SettingsKeys.guide,
        null,
      )).map((json) => GuideSettings.fromJson(json, defaults: defaults));

  @override
  Future<Result<void>> save(GuideSettings settings) =>
      _settings.writeValue(SettingsKeys.guide, settings.toJson());
}

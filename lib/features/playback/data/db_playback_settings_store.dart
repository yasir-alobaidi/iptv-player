import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/data/settings/settings_repository.dart';
import 'package:iptv_player/features/playback/domain/playback.dart';

/// [PlaybackSettingsStore] in the `settings` table, as one JSON value.
final class DbPlaybackSettingsStore implements PlaybackSettingsStore {
  new(this._settings);

  final SettingsRepository _settings;

  @override
  Future<Result<PlaybackSettings>> load() async =>
      (await _settings.readValue<Object?>(
        SettingsKeys.playback,
        null,
      )).map(PlaybackSettings.fromJson);

  @override
  Future<Result<void>> save(PlaybackSettings settings) =>
      _settings.writeValue(SettingsKeys.playback, settings.toJson());
}

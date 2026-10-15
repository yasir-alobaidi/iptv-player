import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/core/settings/ui_preferences.dart';
import 'package:iptv_player/data/settings/settings_repository.dart';

/// [UiPreferences] backed by the `settings` table.
///
/// The stored values are read once by [load], before the first frame, so
/// the shell can draw the remembered rail without an async gap.
final class DbUiPreferences implements UiPreferences {
  new(this._settings);

  static Future<DbUiPreferences> load(SettingsRepository settings) async {
    final expanded = await settings.readBool(SettingsKeys.railExpanded);
    final source = await settings.readValue<String?>(
      SettingsKeys.currentSource,
      null,
    );
    final sound = await settings.readValue<Object?>(
      SettingsKeys.playerSound,
      null,
    );
    final keyboard = await settings.readValue<Object?>(
      SettingsKeys.keyboardLanguage,
      null,
    );
    return DbUiPreferences(settings)
      .._railExpanded = expanded.valueOrNull ?? false
      .._currentSourceId = source.valueOrNull
      .._playerSound = PlayerSound.fromJson(sound.valueOrNull)
      .._keyboardLanguage = switch (keyboard.valueOrNull) {
        final String code => code,
        _ => null,
      };
  }

  final SettingsRepository _settings;
  bool _railExpanded = false;
  String? _currentSourceId;
  PlayerSound _playerSound = const PlayerSound();
  String? _keyboardLanguage;

  @override
  bool get railExpanded => _railExpanded;

  @override
  Future<Result<void>> setRailExpanded({required bool expanded}) {
    _railExpanded = expanded;
    return _settings.writeValue(SettingsKeys.railExpanded, expanded);
  }

  @override
  String? get currentSourceId => _currentSourceId;

  @override
  Future<Result<void>> setCurrentSourceId(String? id) {
    _currentSourceId = id;
    return id == null
        ? _settings.remove(SettingsKeys.currentSource)
        : _settings.writeValue(SettingsKeys.currentSource, id);
  }

  @override
  PlayerSound get playerSound => _playerSound;

  @override
  Future<Result<void>> setPlayerSound(PlayerSound sound) {
    _playerSound = sound;
    return _settings.writeValue(SettingsKeys.playerSound, sound.toJson());
  }

  @override
  String? get keyboardLanguage => _keyboardLanguage;

  @override
  Future<Result<void>> setKeyboardLanguage(String code) {
    _keyboardLanguage = code;
    return _settings.writeValue(SettingsKeys.keyboardLanguage, code);
  }
}

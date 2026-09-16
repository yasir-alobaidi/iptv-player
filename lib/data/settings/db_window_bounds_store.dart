import 'package:iptv_player/core/platform/window_bounds.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/data/settings/settings_repository.dart';

/// Keeps the window's size and position in the `settings` table.
///
/// The stored value is the JSON [WindowBounds] writes, so a bad row
/// decodes to null and the window opens at its default size instead of
/// failing to open at all.
final class DbWindowBoundsStore implements WindowBoundsStore {
  new(this._settings);

  final SettingsRepository _settings;

  @override
  Future<Result<WindowBounds?>> load() async {
    final stored = await _settings.readJsonText(SettingsKeys.windowBounds);
    return stored.map(
      (text) => text == null ? null : WindowBounds.decode(text),
    );
  }

  @override
  Future<Result<void>> save(WindowBounds bounds) =>
      _settings.writeJsonText(SettingsKeys.windowBounds, bounds.encode());
}

import 'package:flutter_riverpod/misc.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/design/appearance.dart';
import 'package:iptv_player/features/settings/data/appearance_providers.dart';
import 'package:iptv_player/features/settings/domain/appearance_store.dart';

/// The look a test wants: what is stored, and what the desktop says.
List<Override> appearanceOverrides({
  AppearanceStore? store,
  AppearanceSettings settings = const AppearanceSettings(),
  SystemAppearance desktop = const SystemAppearance(),
}) => [
  appearanceStoreProvider.overrideWithValue(
    store ?? InMemoryAppearanceStore(settings),
  ),
  desktopAppearanceProvider.overrideWithBuild((ref, notifier) => desktop),
];

/// An [AppearanceStore] whose reads and writes a test can fail.
final class ScriptedAppearanceStore implements AppearanceStore {
  new([this.stored = const AppearanceSettings()]);

  /// What a read gives.
  AppearanceSettings stored;

  /// Every value saved, oldest first.
  final saved = <AppearanceSettings>[];

  /// Makes every save fail with this.
  AppFailure? saveFailure;

  @override
  AppFailure? readFailure;

  @override
  AppearanceSettings get settings =>
      readFailure == null ? stored : const AppearanceSettings();

  @override
  Future<Result<AppearanceSettings>> load() async =>
      readFailure == null ? Ok(stored) : Err(readFailure!);

  @override
  Future<Result<void>> save(AppearanceSettings settings) async {
    if (saveFailure case final failure?) return Err(failure);
    saved.add(settings);
    stored = settings;
    return const Ok(null);
  }
}

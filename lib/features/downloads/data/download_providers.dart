import 'dart:async';

import 'package:iptv_player/core/downloads/download_settings.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/data/db/db_providers.dart';
import 'package:iptv_player/data/library/download_folder.dart';
import 'package:iptv_player/data/settings/settings_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'download_providers.g.dart';

/// Settings → Downloads & library's download half. The defaults at once,
/// the stored choices as soon as they are read; a change is saved, and
/// applies to downloads that start after it.
@Riverpod(keepAlive: true)
class DownloadSettingsController extends _$DownloadSettingsController {
  @override
  DownloadSettings build() {
    unawaited(_load());
    return const DownloadSettings();
  }

  var _changed = false;

  Future<void> _load() async {
    final stored = await ref
        .read(settingsRepositoryProvider)
        .readValue<Object?>(SettingsKeys.downloads, null);
    // A choice made while loading wins over what was stored.
    if (!_changed && ref.mounted) {
      state = DownloadSettings.fromJson(stored.valueOrNull);
    }
  }

  Future<Result<void>> update(DownloadSettings settings) {
    _changed = true;
    state = settings;
    return ref
        .read(settingsRepositoryProvider)
        .writeValue(SettingsKeys.downloads, settings.toJson());
  }
}

/// The system's Videos folder. Tests point it elsewhere.
@Riverpod(keepAlive: true)
Future<String> systemVideos(Ref ref) => systemVideosFolder();

/// Where new downloads go now (docs/09): the folder chosen in Settings,
/// else the system's Videos folder + `IPTV Player`.
@Riverpod(keepAlive: true)
Future<String> downloadFolder(Ref ref) async {
  final stored = await ref
      .read(settingsRepositoryProvider)
      .readValue<Object?>(SettingsKeys.downloads, null);
  final chosen =
      ref.watch(downloadSettingsControllerProvider).folder ??
      DownloadSettings.fromJson(stored.valueOrNull).folder;
  return await downloadFolderPath(
    chosen: chosen,
    videos: () => ref.read(systemVideosProvider.future),
  );
}

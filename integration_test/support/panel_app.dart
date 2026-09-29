// The app as `bootstrap()` builds it, for the integration tests that play
// files: the real player, a throwaway database and keyring, and the fake
// panel added and synced as its one source.

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_player/app/router.dart';
import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/error_reporter.dart';
import 'package:iptv_player/core/logging/secret_registry.dart';
import 'package:iptv_player/core/player/player_providers.dart';
import 'package:iptv_player/core/secure/credential_store.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/db/db_providers.dart';
import 'package:iptv_player/data/player_mediakit/media_kit_player_engine.dart';
import 'package:iptv_player/features/playback/data/playback_providers.dart';
import 'package:iptv_player/features/sources/data/source_providers.dart';
import 'package:iptv_player/features/sources/domain/source.dart';
import 'package:iptv_player/features/sources/presentation/source_shell_slots.dart';

import 'fake_panel.dart';
import 'keyboard.dart';

final class PanelApp {
  new _(
    this.container,
    this._directory,
    this.db,
    this.sourceId,
    this._keyring,
    this._video,
  );

  /// Opens on Home. [video] false plays with no picture (CI has no GPU).
  static Future<PanelApp> open(FakePanel panel, {required bool video}) async {
    final directory = await Directory.systemTemp.createTemp('iptv_vod');
    final keyring = InMemoryCredentialStore();
    final (container, db) = await _start(directory, keyring, video: video);
    final added = await container
        .read(sourceRepositoryProvider)
        .add(
          SourceDraft(
            type: SourceType.xtream,
            name: 'Fake panel',
            url: panel.url,
            username: 'test',
            password: 'test',
          ),
        );
    final id = added.valueOrNull!.id;
    final synced = await container.read(syncServiceProvider).sync(id);
    if (!synced.isOk) throw StateError('sync failed: ${synced.failureOrNull}');
    return PanelApp._(container, directory, db, id, keyring, video);
  }

  static Future<(ProviderContainer, AppDatabase)> _start(
    Directory directory,
    InMemoryCredentialStore keyring, {
    required bool video,
  }) async {
    final db = AppDatabase(await openAppDatabase(directory));
    final secrets = SecretRegistry();
    final log = AppLog(output: SilentOutput(), secrets: secrets);
    final engine = await MediaKitPlayerEngine.create(
      log: log,
      secrets: secrets,
      video: video,
    );
    final container = ProviderContainer(
      overrides: [
        appLogProvider.overrideWithValue(log),
        secretRegistryProvider.overrideWithValue(secrets),
        errorReporterProvider.overrideWithValue(ErrorReporter(log)),
        appDatabaseProvider.overrideWithValue(db),
        credentialStoreProvider.overrideWithValue(keyring),
        startLocationProvider.overrideWithValue('/'),
        playerEngineProvider.overrideWithValue(engine),
        ...sourceShellOverrides,
      ],
    );
    return (container, db);
  }

  final ProviderContainer container;
  final Directory _directory;
  final AppDatabase db;
  final String sourceId;
  final InMemoryCredentialStore _keyring;
  final bool _video;

  String get location => container.read(routerProvider).state.uri.path;

  /// The app closed and started again on the same database and keyring,
  /// as a restart does. This one is closed; use the one returned.
  Future<PanelApp> restart() async {
    await _stop();
    final (container, db) = await _start(_directory, _keyring, video: _video);
    return PanelApp._(container, _directory, db, sourceId, _keyring, _video);
  }

  Future<void> close() async {
    await _stop();
    await _directory.delete(recursive: true);
  }

  Future<void> _stop() async {
    final coordinator = container.read(playbackCoordinatorProvider);
    await coordinator.stop();
    final engine = coordinator.engine;
    container.dispose();
    await engine.dispose();
    await db.close();
  }
}

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/platform/window_bounds.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/settings/db_window_bounds_store.dart';
import 'package:iptv_player/data/settings/settings_repository.dart';

void main() {
  late AppDatabase database;
  late SettingsRepository settings;
  late DbWindowBoundsStore store;

  setUp(() {
    database = AppDatabase.memory();
    settings = SettingsRepository(database);
    store = DbWindowBoundsStore(settings);
  });
  tearDown(() => database.close());

  test('nothing stored yet loads as null, not as an error', () async {
    expect(await store.load(), const Ok<WindowBounds?>(null));
  });

  test('saves and loads the size, the position and maximized', () async {
    const bounds = WindowBounds(
      size: Size(1600, 900),
      position: Offset(120, 60),
      maximized: true,
    );

    await store.save(bounds);

    expect((await store.load()).valueOrNull, bounds);
  });

  test('the newest save wins', () async {
    await store.save(const WindowBounds(size: Size(1024, 640)));
    await store.save(const WindowBounds(size: Size(1440, 900)));

    expect((await store.load()).valueOrNull?.size, const Size(1440, 900));
  });

  test('a corrupt row loads as null so the window still opens', () async {
    await settings.writeJsonText(SettingsKeys.windowBounds, '{"width":"wide"}');

    expect(await store.load(), const Ok<WindowBounds?>(null));
  });

  test('a database that cannot answer fails as storage', () async {
    await database.customStatement('DROP TABLE settings');

    expect((await store.load()).failureOrNull, isA<StorageFailure>());
  });
}

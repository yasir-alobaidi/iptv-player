import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/settings/settings_repository.dart';
import 'package:iptv_player/design/appearance.dart';
import 'package:iptv_player/design/tokens.dart';
import 'package:iptv_player/features/settings/data/db_appearance_store.dart';

void main() {
  late AppDatabase database;
  late SettingsRepository settings;

  setUp(() {
    database = AppDatabase.memory();
    settings = SettingsRepository(database);
  });
  tearDown(() => database.close());

  const chosen = AppearanceSettings(
    accent: AppAccent.amber,
    textSize: TextSizeChoice.s130,
    density: AppDensity.compact,
    reduceMotion: SystemSwitch.on,
    clock: ClockChoice.h24,
  );

  test('nothing stored reads as the defaults, and is no failure', () async {
    final store = await DbAppearanceStore.open(settings);

    expect(store.settings, const AppearanceSettings());
    expect(store.readFailure, isNull);
  });

  test('a restart keeps the choice', () async {
    final first = await DbAppearanceStore.open(settings);
    expect(await first.save(chosen), isA<Ok<void>>());

    final second = await DbAppearanceStore.open(settings);

    expect(second.settings, chosen);
    expect(second.readFailure, isNull);
  });

  test('the getter changes as soon as it is saved, before the write', () async {
    final store = await DbAppearanceStore.open(settings);

    final write = store.save(chosen);

    expect(store.settings, chosen);
    await write;
  });

  test('a damaged value reads as the defaults, and is no failure', () async {
    await settings.writeJsonText(SettingsKeys.appearance, '{"accent": 12');

    final store = await DbAppearanceStore.open(settings);

    expect(store.settings, const AppearanceSettings());
    expect(store.readFailure, isNull);
  });

  test("a database that can't be read is a failure, with the defaults; a "
      'later read that works clears it', () async {
    await settings.writeValue(SettingsKeys.appearance, chosen.toJson());
    // A dropped table stands in for any broken file: the query throws.
    await database.customStatement(
      'ALTER TABLE settings RENAME TO settings_away',
    );
    final store = await DbAppearanceStore.open(settings);

    expect(store.settings, const AppearanceSettings());
    expect(store.readFailure, isA<StorageFailure>());

    await database.customStatement(
      'ALTER TABLE settings_away RENAME TO settings',
    );

    expect((await store.load()).valueOrNull, chosen);
    expect(store.settings, chosen);
    expect(store.readFailure, isNull);
  });
}

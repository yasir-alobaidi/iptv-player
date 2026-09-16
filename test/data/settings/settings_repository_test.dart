import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/settings/settings_repository.dart';

void main() {
  late AppDatabase database;
  late SettingsRepository settings;

  setUp(() {
    database = AppDatabase.memory();
    settings = SettingsRepository(database);
  });
  tearDown(() => database.close());

  test('a missing key reads as null', () async {
    expect(
      await settings.readJsonText('nothing.here'),
      const Ok<String?>(null),
    );
  });

  test('writeJsonText stores the text unchanged', () async {
    await settings.writeJsonText('a.key', '{"width":1280}');

    expect(
      await settings.readJsonText('a.key'),
      const Ok<String?>('{"width":1280}'),
    );
  });

  test('writeValue encodes, readValue decodes', () async {
    await settings.writeValue('a.key', {'width': 1280});

    final stored = await settings.readValue<Map<String, Object?>>('a.key', {});

    expect(stored.valueOrNull, {'width': 1280});
  });

  test(
    'a value that is not JSON reads as the fallback, not an error',
    () async {
      await settings.writeJsonText('a.key', 'not json at all');

      final stored = await settings.readValue<int>('a.key', 7);

      expect(stored, const Ok(7));
    },
  );

  test('a value of the wrong type reads as the fallback', () async {
    await settings.writeValue('a.key', 'a string');

    expect(await settings.readBool('a.key', fallback: true), const Ok(true));
  });

  test('readBool round-trips', () async {
    await settings.writeValue(SettingsKeys.railExpanded, true);

    expect(await settings.readBool(SettingsKeys.railExpanded), const Ok(true));
  });

  test('remove deletes the value', () async {
    await settings.writeValue('a.key', 1);

    await settings.remove('a.key');

    expect(await settings.readJsonText('a.key'), const Ok<String?>(null));
  });

  test('readAll returns every setting', () async {
    await settings.writeValue('a', 1);
    await settings.writeValue('b', 'two');

    expect((await settings.readAll()).valueOrNull, {'a': '1', 'b': '"two"'});
  });

  test(
    'a database that cannot answer fails as storage, not as a throw',
    () async {
      // A dropped table stands in for any broken file: the query throws,
      // and the caller must still get a Result back.
      await database.customStatement('DROP TABLE settings');

      final stored = await settings.readJsonText('a.key');

      expect(stored.failureOrNull, isA<StorageFailure>());
      expect(stored.failureOrNull?.code, 'storage');
    },
  );

  test('the window bounds key holds what WindowBounds writes', () async {
    // The two are stored as raw JSON, so the store and the repository
    // have to agree on the shape; this is the seam between them.
    const size = Size(1280, 800);
    await settings.writeJsonText(
      SettingsKeys.windowBounds,
      '{"width":${size.width},"height":${size.height},"maximized":false}',
    );

    final stored = await settings.readValue<Map<String, Object?>>(
      SettingsKeys.windowBounds,
      const {},
    );

    expect(stored.valueOrNull?['width'], 1280);
  });
}

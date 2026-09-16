import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/data/db/app_database.dart';

void main() {
  late AppDatabase database;

  setUp(() => database = AppDatabase.memory());
  tearDown(() => database.close());

  test('reads back what it wrote', () async {
    await database.settingsDao.write('a.key', '{"n":1}');

    expect(await database.settingsDao.read('a.key'), '{"n":1}');
  });

  test('a missing key reads as null', () async {
    expect(await database.settingsDao.read('nothing.here'), isNull);
  });

  test('writing the same key twice replaces the value', () async {
    await database.settingsDao.write('a.key', '1');
    await database.settingsDao.write('a.key', '2');

    expect(await database.settingsDao.read('a.key'), '2');
    expect(await database.settingsDao.readAll(), hasLength(1));
  });

  test('remove deletes the row', () async {
    await database.settingsDao.write('a.key', '1');
    await database.settingsDao.remove('a.key');

    expect(await database.settingsDao.read('a.key'), isNull);
  });

  test('watch emits the current value and then every change', () async {
    final seen = <String?>[];
    final subscription = database.settingsDao.watch('a.key').listen(seen.add);
    // The first query runs asynchronously, so the initial null only
    // arrives once the event queue has drained.
    await pumpEventQueue();

    await database.settingsDao.write('a.key', '"first"');
    await pumpEventQueue();
    await database.settingsDao.write('a.key', '"second"');
    await pumpEventQueue();
    await subscription.cancel();

    expect(seen, [null, '"first"', '"second"']);
  });

  test('readAll returns every setting', () async {
    await database.settingsDao.write('a', '1');
    await database.settingsDao.write('b', '2');

    expect(await database.settingsDao.readAll(), {'a': '1', 'b': '2'});
  });
}

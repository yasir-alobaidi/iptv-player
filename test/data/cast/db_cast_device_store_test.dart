import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/cast/cast_device.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/data/cast/db_cast_device_store.dart';
import 'package:iptv_player/data/db/app_database.dart';

const _tv = CastDevice(
  id: 'aaaa',
  name: 'Living Room TV',
  model: 'Chromecast',
  host: '192.168.1.60',
);
const _office = CastDevice(id: 'cccc', name: 'Office', host: '10.0.0.9');

void main() {
  late AppDatabase db;
  late DbCastDeviceStore store;

  setUp(() {
    db = AppDatabase.memory();
    store = DbCastDeviceStore(db);
  });
  tearDown(() => db.close());

  Future<KnownCastDevice?> read(String id) async =>
      (await store.byId(id)).valueOrNull;

  test('nothing kept at first', () async {
    expect(await store.watchAll().first, isEmpty);
    expect(await read('aaaa'), isNull);
  });

  test('added by address: kept as manual, with defaults', () async {
    await store.addManual(_office.copyWith(port: 41234));
    expect(
      await read('cccc'),
      const KnownCastDevice(
        id: 'cccc',
        name: 'Office',
        host: '10.0.0.9',
        port: 41234,
        manual: true,
        hevc: HevcSupport.auto,
        learned: CastLearned(),
      ),
    );
  });

  test('cast to: kept with its last use, not manual', () async {
    await store.markUsed(_tv, DateTime.utc(2026, 9, 29, 20));
    final kept = await read('aaaa');
    expect(kept!.manual, isFalse);
    expect(kept.lastUsedAt, DateTime.utc(2026, 9, 29, 20));
    expect(kept.model, 'Chromecast');
  });

  test('a device added by address stays so when cast to', () async {
    await store.addManual(_office);
    await store.markUsed(_office, DateTime.utc(2026, 9, 29));
    expect((await read('cccc'))!.manual, isTrue);
  });

  test('adding by address keeps the last use and settings', () async {
    await store.markUsed(_tv, DateTime.utc(2026, 9, 29));
    await store.setHevcSupport('aaaa', HevcSupport.no);
    await store.addManual(_tv.copyWith(host: '192.168.1.77'));
    final kept = await read('aaaa');
    expect(kept!.manual, isTrue);
    expect(kept.lastUsedAt, DateTime.utc(2026, 9, 29));
    expect(kept.hevc, HevcSupport.no);
    expect(kept.host, '192.168.1.77');
  });

  test('refresh rewrites a kept device and ignores others', () async {
    await store.markUsed(_tv, DateTime.utc(2026, 9, 29));
    await store.refresh(_tv.copyWith(name: 'TV', host: '192.168.1.77'));
    await store.refresh(_office);
    final kept = await read('aaaa');
    expect(kept!.name, 'TV');
    expect(kept.host, '192.168.1.77');
    expect(kept.lastUsedAt, DateTime.utc(2026, 9, 29));
    expect(await read('cccc'), isNull);
  });

  test('HEVC setting and what was learned round-trip', () async {
    await store.markUsed(_tv, DateTime.utc(2026, 9, 29));
    await store.setHevcSupport('aaaa', HevcSupport.yes);
    const learned = CastLearned(
      maxHeight: 1080,
      refusedCodecs: {'hevc', 'eac3'},
      directRefusedSources: {'source-1'},
    );
    await store.setLearned('aaaa', learned);
    final kept = await read('aaaa');
    expect(kept!.hevc, HevcSupport.yes);
    expect(kept.learned, learned);

    await store.setLearned('aaaa', const CastLearned());
    expect((await read('aaaa'))!.learned, const CastLearned());
    final row = await db.castDevicesDao.byId('aaaa');
    expect(row!.learnedJson, isNull);
  });

  test('forget removes it', () async {
    await store.addManual(_office);
    await store.forget('cccc');
    expect(await read('cccc'), isNull);
  });

  test('listed by name without case, again on every change', () async {
    final lists = <List<String>>[];
    final sub = store.watchAll().listen(
      (devices) => lists.add([for (final d in devices) d.name]),
    );
    await store.addManual(_office);
    await store.markUsed(_tv.copyWith(name: 'living room'), DateTime.utc(2026));
    await pumpEventQueue();
    await sub.cancel();
    expect(lists.last, ['living room', 'Office']);
  });

  test('a database that fails is a storage failure, not a throw', () async {
    await db.customStatement('DROP TABLE cast_devices');
    final result = await store.addManual(_office);
    expect(result.failureOrNull, isA<StorageFailure>());
  });

  group('what was learned, as stored', () {
    test('nothing learned is no JSON', () {
      expect(encodeCastLearned(const CastLearned()), isNull);
    });

    test('sorted, so the same facts store the same text', () {
      expect(
        encodeCastLearned(
          const CastLearned(refusedCodecs: {'mpeg2video', 'hevc'}),
        ),
        '{"refused_codecs":["hevc","mpeg2video"]}',
      );
    });

    const odd = {
      'not JSON': '{',
      'a list': '[1,2]',
      'a string': '"hevc"',
      'wrong types': '{"max_height":"1080","refused_codecs":"hevc"}',
      'a negative height': '{"max_height":-1}',
      'a fractional height': '{"max_height":1080.5}',
      'odd list items': '{"refused_codecs":[1,null,"",{"a":1}]}',
      'interlaced as text': '{"refused_interlaced":"true"}',
      'interlaced as a number': '{"refused_interlaced":1}',
    };
    for (final MapEntry(key: what, value: json) in odd.entries) {
      test('$what reads as nothing learned', () {
        expect(decodeCastLearned(json), const CastLearned());
      });
    }

    test('a refused interlaced picture round-trips', () {
      const learned = CastLearned(refusedInterlaced: true, maxHeight: 1080);
      final json = encodeCastLearned(learned);
      expect(json, '{"max_height":1080,"refused_interlaced":true}');
      expect(decodeCastLearned(json), learned);
    });

    test('unknown keys are ignored, known ones kept', () {
      expect(
        decodeCastLearned('{"max_height":1080,"future":true}'),
        const CastLearned(maxHeight: 1080),
      );
    });

    test('a row written by hand with bad JSON still reads', () async {
      await store.addManual(_office);
      await db.castDevicesDao.change(
        'cccc',
        const CastDevicesCompanion(learnedJson: Value('not json')),
      );
      expect((await read('cccc'))!.learned, const CastLearned());
    });
  });
}

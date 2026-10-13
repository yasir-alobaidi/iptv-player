import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/features/reminders/data/db_reminder_repository.dart';
import 'package:iptv_player/features/reminders/domain/reminder.dart';
import 'package:iptv_player/features/settings/data/db_settings_transfer.dart';
import 'package:iptv_player/features/settings/domain/settings_export.dart';
import 'package:iptv_player/features/settings/domain/settings_transfer.dart';
import 'package:iptv_player/features/sources/domain/source.dart';
import 'package:path/path.dart' as p;

void main() {
  late AppDatabase db;
  late DbReminderRepository reminders;
  final now = DateTime.utc(2026, 10, 14, 12);
  final start = DateTime.utc(2026, 10, 14, 21, 30);

  Future<void> source(AppDatabase db, String id) => db
      .into(db.sources)
      .insert(
        SourcesCompanion.insert(
          id: id,
          type: SourceType.xtream,
          name: 'Northwind TV',
          url: 'http://northwind.test',
          createdAt: now,
          updatedAt: now,
        ),
      );

  setUp(() async {
    db = AppDatabase.memory();
    reminders = DbReminderRepository(db, clock: () => now);
    await source(db, 'src-1');
  });
  tearDown(() => db.close());

  ReminderDraft draft({
    DateTime? at,
    String title = 'The Harbor Pilot',
    String channelKey = '212',
    String sourceId = 'src-1',
  }) => ReminderDraft(
    sourceId: sourceId,
    channelKey: channelKey,
    xmltvId: 'bluewater.uk',
    channelName: 'Blue Water',
    title: title,
    start: at ?? start,
    end: (at ?? start).add(const Duration(hours: 1)),
  );

  Future<void> programme(
    String title,
    DateTime at, {
    Duration length = const Duration(hours: 1),
    String channel = 'bluewater.uk',
    String sourceId = 'src-1',
  }) => db
      .into(db.epgPrograms)
      .insert(
        EpgProgramsCompanion.insert(
          sourceId: sourceId,
          epgChannelId: channel,
          startUtc: at.millisecondsSinceEpoch,
          endUtc: at.add(length).millisecondsSinceEpoch,
          title: title,
        ),
      );

  group('the store', () {
    test('a reminder is kept whole, in UTC, and found again', () async {
      final set = (await reminders.set(draft())).valueOrNull!;

      final read = (await reminders.all()).valueOrNull!.single;

      expect(read, set);
      expect(read.title, 'The Harbor Pilot');
      expect(read.channelName, 'Blue Water');
      expect(read.channelKey, '212');
      expect(read.xmltvId, 'bluewater.uk');
      expect(read.start, start);
      expect(read.start.isUtc, isTrue);
      expect(read.end, start.add(const Duration(hours: 1)));
    });

    test(
      'setting the same programme again gives the one already set',
      () async {
        final first = (await reminders.set(draft())).valueOrNull!;
        final again = (await reminders.set(draft())).valueOrNull!;

        expect(again.id, first.id);
        expect((await reminders.all()).valueOrNull, hasLength(1));
      },
    );

    test('soonest first, watched as they change', () async {
      final seen = <List<String>>[];
      final watching = reminders.watchAll().listen(
        (list) => seen.add([for (final r in list) r.title]),
      );
      addTearDown(watching.cancel);

      await reminders.set(
        draft(at: start.add(const Duration(hours: 3)), title: 'Later'),
      );
      final sooner = (await reminders.set(draft(title: 'Sooner'))).valueOrNull!;
      await pumpEventQueue();
      expect(seen.last, ['Sooner', 'Later']);

      await reminders.remove(sooner.id);
      await pumpEventQueue();
      expect(seen.last, ['Later']);
    });

    test(
      'remove says whether it was there: only one caller is told yes',
      () async {
        final set = (await reminders.set(draft())).valueOrNull!;

        expect((await reminders.remove(set.id)).valueOrNull, isTrue);
        expect((await reminders.remove(set.id)).valueOrNull, isFalse);
      },
    );

    test('a reminder moves to its programme’s new time; onto another '
        'reminder’s, it is refused', () async {
      final first = (await reminders.set(draft())).valueOrNull!;
      final later = start.add(const Duration(minutes: 15));

      expect(
        await reminders.move(
          first.id,
          later,
          later.add(const Duration(hours: 1)),
        ),
        isA<Ok<void>>(),
      );
      expect((await reminders.all()).valueOrNull!.single.start, later);

      final second = (await reminders.set(draft())).valueOrNull!;
      expect(
        await reminders.move(
          second.id,
          later,
          later.add(const Duration(hours: 1)),
        ),
        isA<Err<void>>(),
      );
    });

    test('a source that is removed takes its reminders with it', () async {
      await source(db, 'src-2');
      await reminders.set(draft());
      await reminders.set(draft(sourceId: 'src-2'));
      expect((await reminders.forSource('src-1')).valueOrNull, hasLength(1));

      await db.sourcesDao.remove('src-1');

      final left = (await reminders.all()).valueOrNull!;
      expect(left.single.sourceId, 'src-2');
    });
  });

  group('the guide, asked about a reminder’s programme', () {
    late DbReminderGuide live;

    setUp(() => live = DbReminderGuide(db));

    Future<GuideAnswer> ask(String title, {DateTime? around}) async =>
        (await live.lookUp(
          sourceId: 'src-1',
          xmltvId: 'bluewater.uk',
          title: title,
          around: around ?? start,
          within: followWithin,
        )).valueOrNull!;

    test('finds the programme by its title on its guide channel, whatever '
        'the case and the space around it', () async {
      await programme(
        '  the harbor PILOT ',
        start.add(const Duration(minutes: 15)),
      );
      await programme('The Harbor Pilot', start, channel: 'other.uk');
      await programme('The Harbor Pilot', start, channel: 'x');
      await programme('Something Else', start);

      final answer = await ask('The Harbor Pilot');

      expect(
        answer.showings.single.start,
        start.add(const Duration(minutes: 15)),
      );
      expect(
        answer.showings.single.end,
        start.add(const Duration(minutes: 75)),
      );
      expect(answer.covers, isTrue);
    });

    test('only within twelve hours either way', () async {
      await programme(
        'The Harbor Pilot',
        start.subtract(const Duration(hours: 13)),
      );
      await programme('The Harbor Pilot', start.add(const Duration(hours: 11)));
      await programme('The Harbor Pilot', start.add(const Duration(hours: 13)));

      final answer = await ask('The Harbor Pilot');

      expect(
        [for (final s in answer.showings) s.start],
        [start.add(const Duration(hours: 11))],
      );
    });

    test('a guide with other programmes around that time covers it; one '
        'that ended before, or starts after, does not', () async {
      await programme('Morning', start.subtract(const Duration(hours: 4)));
      expect(
        (await ask('The Harbor Pilot')).covers,
        isFalse,
        reason: 'ended before the time',
      );

      await programme('Night', start.add(const Duration(hours: 2)));
      final covered = await ask('The Harbor Pilot');
      expect(
        covered.covers,
        isTrue,
        reason: 'something before, something after',
      );
      expect(covered.showings, isEmpty);
    });

    test('no guide at all covers nothing', () async {
      final answer = await ask('The Harbor Pilot');

      expect(answer.showings, isEmpty);
      expect(answer.covers, isFalse);
    });
  });

  group('in a settings file (Settings → Data)', () {
    late Directory folder;
    late String path;

    setUp(() {
      folder = Directory.systemTemp.createTempSync('reminder_transfer_');
      path = p.join(folder.path, 'settings.json');
    });
    tearDown(() => folder.deleteSync(recursive: true));

    DbSettingsTransfer transfer(AppDatabase db, {DateTime? at}) =>
        DbSettingsTransfer(
          db,
          reminders: DbReminderTransfer(db, clock: () => at ?? now),
          clock: () => at ?? now,
        );

    test('reminders go out with their source and arrive on the other '
        'computer', () async {
      await reminders.set(draft());
      await reminders.set(
        draft(at: start.add(const Duration(days: 1)), title: 'Late Scores'),
      );
      await transfer(db).exportTo(path);
      final file = parseSettingsExport(File(path).readAsStringSync());
      expect(file.sources.single.reminders, hasLength(2));

      final second = AppDatabase.memory();
      addTearDown(second.close);
      await source(second, 'other-id');
      final read = await transfer(second).read(path) as SettingsFileReadable;
      final summary = (await transfer(second).apply(read.plan)).valueOrNull!;

      expect(summary.reminders, 2);
      final arrived = (await DbReminderRepository(second).all()).valueOrNull!;
      expect(
        [for (final r in arrived) r.title],
        ['The Harbor Pilot', 'Late Scores'],
      );
      expect(arrived.first.sourceId, 'other-id');
      expect(arrived.first.start, start);
      expect(arrived.first.channelName, 'Blue Water');
    });

    test('one whose programme has started by the time the file is imported '
        'is left out; importing twice sets nothing twice', () async {
      await reminders.set(draft());
      await reminders.set(
        draft(at: start.add(const Duration(days: 1)), title: 'Late Scores'),
      );
      await transfer(db).exportTo(path);
      final second = AppDatabase.memory();
      addTearDown(second.close);
      await source(second, 'other-id');
      // Imported the next morning.
      final later = start.add(const Duration(hours: 10));
      final importer = transfer(second, at: later);
      final read = await importer.read(path) as SettingsFileReadable;

      expect((await importer.apply(read.plan)).valueOrNull!.reminders, 1);
      await importer.apply(read.plan);

      final arrived = (await DbReminderRepository(second).all()).valueOrNull!;
      expect(arrived.single.title, 'Late Scores');
    });

    test(
      'a reminder in a file that is damaged is skipped, the rest taken',
      () async {
        final taken = await DbReminderTransfer(db, clock: () => now).import(
          'src-1',
          [
            {'title': 'No channel', 'start_ms': 1, 'end_ms': 2},
            {
              'channel': '212',
              'xmltv_id': 'bluewater.uk',
              'title': 'Ends before it starts',
              'start_ms': start.millisecondsSinceEpoch,
              'end_ms': start.millisecondsSinceEpoch - 1,
            },
            {
              'channel': '212',
              'xmltv_id': 'bluewater.uk',
              'title': 'Good',
              'start_ms': start.millisecondsSinceEpoch,
              'end_ms': start.millisecondsSinceEpoch + 3600000,
            },
            {'channel': 212, 'title': 7},
          ],
        );

        expect(taken, 1);
        final kept = (await reminders.all()).valueOrNull!.single;
        expect(kept.title, 'Good');
        // No name for the channel in the file: its title stands in.
        expect(kept.channelName, 'Good');
      },
    );
  });
}

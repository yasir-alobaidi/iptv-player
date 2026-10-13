import 'package:drift/drift.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/features/reminders/domain/reminder.dart';
import 'package:iptv_player/features/settings/data/db_settings_transfer.dart';

Reminder _reminder(ReminderRow row) => Reminder(
  id: row.id,
  sourceId: row.sourceId,
  channelKey: row.channelRemoteKey,
  xmltvId: row.xmltvId,
  channelName: row.channelName,
  title: row.title,
  start: DateTime.fromMillisecondsSinceEpoch(row.startUtc, isUtc: true),
  end: DateTime.fromMillisecondsSinceEpoch(row.endUtc, isUtc: true),
);

/// [ReminderRepository] on the `reminders` table.
final class DbReminderRepository implements ReminderRepository {
  new(this._db, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _clock;

  @override
  Stream<List<Reminder>> watchAll() => _db.remindersDao.watchAll().map(
    (rows) => [for (final row in rows) _reminder(row)],
  );

  @override
  Future<Result<List<Reminder>>> all() => Result.guard(
    () async => [
      for (final row in await _db.remindersDao.all()) _reminder(row),
    ],
  );

  @override
  Future<Result<List<Reminder>>> forSource(String sourceId) => Result.guard(
    () async => [
      for (final row in await _db.remindersDao.forSource(sourceId))
        _reminder(row),
    ],
  );

  @override
  Future<Result<Reminder>> set(ReminderDraft draft) => Result.guard(
    () async => _reminder(
      await _db.remindersDao.put(
        RemindersCompanion.insert(
          sourceId: draft.sourceId,
          channelRemoteKey: draft.channelKey,
          xmltvId: draft.xmltvId,
          channelName: draft.channelName,
          title: draft.title,
          startUtc: draft.start.millisecondsSinceEpoch,
          endUtc: draft.end.millisecondsSinceEpoch,
          createdAt: _clock().toUtc(),
        ),
      ),
    ),
  );

  @override
  Future<Result<bool>> remove(int id) =>
      Result.guard(() => _db.remindersDao.remove(id));

  @override
  Future<Result<void>> move(int id, DateTime start, DateTime end) =>
      Result.guard(() async {
        final moved = await _db.remindersDao.move(
          id,
          start.millisecondsSinceEpoch,
          end.millisecondsSinceEpoch,
        );
        if (!moved) throw StorageFailure('reminder $id: another is there');
      });
}

/// [ReminderGuide] on the live guide (`epg_programs`).
final class DbReminderGuide implements ReminderGuide {
  new(this._db);

  final AppDatabase _db;

  @override
  Future<Result<GuideAnswer>> lookUp({
    required String sourceId,
    required String xmltvId,
    required String title,
    required DateTime around,
    required Duration within,
  }) => Result.guard(() async {
    final at = around.millisecondsSinceEpoch;
    // The same title, whatever its case and the space around it: guides
    // differ between refreshes in little else.
    final showings = await _db
        .customSelect(
          'SELECT start_utc, end_utc FROM epg_programs '
          'WHERE source_id = ? AND epg_channel_id = ? '
          'AND start_utc BETWEEN ? AND ? '
          'AND TRIM(title) = TRIM(?) COLLATE NOCASE '
          'ORDER BY start_utc',
          variables: [
            Variable<String>(sourceId),
            Variable<String>(xmltvId),
            Variable<int>(at - within.inMilliseconds),
            Variable<int>(at + within.inMilliseconds),
            Variable<String>(title),
          ],
        )
        .get();
    // The guide covers that moment when the channel has something
    // starting at or before it and something ending after it.
    final covers = await _db
        .customSelect(
          'SELECT '
          'EXISTS(SELECT 1 FROM epg_programs WHERE source_id = ?1 '
          'AND epg_channel_id = ?2 AND start_utc <= ?3) AND '
          'EXISTS(SELECT 1 FROM epg_programs WHERE source_id = ?1 '
          'AND epg_channel_id = ?2 AND end_utc > ?3) AS covers',
          variables: [
            Variable<String>(sourceId),
            Variable<String>(xmltvId),
            Variable<int>(at),
          ],
        )
        .getSingle();
    return GuideAnswer(
      showings: [
        for (final row in showings)
          (
            start: DateTime.fromMillisecondsSinceEpoch(
              row.read<int>('start_utc'),
              isUtc: true,
            ),
            end: DateTime.fromMillisecondsSinceEpoch(
              row.read<int>('end_utc'),
              isUtc: true,
            ),
          ),
      ],
      covers: covers.read<bool>('covers'),
    );
  });
}

/// A source's reminders in a settings file (Settings → Data): each as a
/// small map, read back tolerantly. A reminder whose programme has
/// started by the time the file is imported is left out.
final class DbReminderTransfer implements ReminderTransfer {
  new(this._db, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _clock;

  @override
  Future<List<Map<String, Object?>>> export(String sourceId) async => [
    for (final row in await _db.remindersDao.forSource(sourceId))
      {
        'channel': row.channelRemoteKey,
        'xmltv_id': row.xmltvId,
        'channel_name': row.channelName,
        'title': row.title,
        'start_ms': row.startUtc,
        'end_ms': row.endUtc,
      },
  ];

  @override
  Future<int> import(
    String sourceId,
    List<Map<String, Object?>> reminders,
  ) async {
    final now = _clock();
    var taken = 0;
    for (final reminder in reminders) {
      String? text(String key) => switch (reminder[key]) {
        final String value when value.trim().isNotEmpty => value,
        _ => null,
      };
      final channel = text('channel');
      final xmltvId = text('xmltv_id');
      final title = text('title');
      final start = reminder['start_ms'];
      final end = reminder['end_ms'];
      if (channel == null ||
          xmltvId == null ||
          title == null ||
          start is! int ||
          end is! int ||
          end <= start ||
          start <= now.millisecondsSinceEpoch) {
        continue;
      }
      await _db.remindersDao.put(
        RemindersCompanion.insert(
          sourceId: sourceId,
          channelRemoteKey: channel,
          xmltvId: xmltvId,
          channelName: text('channel_name') ?? title,
          title: title,
          startUtc: start,
          endUtc: end,
          createdAt: now.toUtc(),
        ),
      );
      taken++;
    }
    return taken;
  }
}

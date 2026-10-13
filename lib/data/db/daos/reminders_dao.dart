import 'package:drift/drift.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/db/reminder_tables.dart';

part 'reminders_dao.g.dart';

/// The `reminders` table, soonest first.
@DriftAccessor(tables: [Reminders])
class RemindersDao extends DatabaseAccessor<AppDatabase>
    with _$RemindersDaoMixin {
  new(super.attachedDatabase);

  SimpleSelectStatement<$RemindersTable, ReminderRow> get _soonestFirst =>
      select(reminders)..orderBy([
        (t) => OrderingTerm.asc(t.startUtc),
        (t) => OrderingTerm.asc(t.id),
      ]);

  Future<List<ReminderRow>> all() => _soonestFirst.get();

  Stream<List<ReminderRow>> watchAll() => _soonestFirst.watch();

  Future<List<ReminderRow>> forSource(String sourceId) =>
      (_soonestFirst..where((t) => t.sourceId.equals(sourceId))).get();

  Future<ReminderRow?> byId(int id) =>
      (select(reminders)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Sets a reminder, or leaves the one already set for that channel and
  /// start as it is but for its end and title. Returns its row.
  Future<ReminderRow> put(RemindersCompanion reminder) =>
      into(reminders).insertReturning(
        reminder,
        onConflict: DoUpdate(
          (old) => RemindersCompanion(
            endUtc: reminder.endUtc,
            title: reminder.title,
            xmltvId: reminder.xmltvId,
            channelName: reminder.channelName,
          ),
          target: [
            reminders.sourceId,
            reminders.channelRemoteKey,
            reminders.startUtc,
          ],
        ),
      );

  /// Removes it; true when it was there. A reminder is only ever shown
  /// by whoever removed it, so it can't show twice.
  Future<bool> remove(int id) async =>
      await (delete(reminders)..where((t) => t.id.equals(id))).go() > 0;

  /// Moves a reminder to its programme's new time. False when another
  /// reminder is already there (the same programme, set twice by a
  /// guide that moved): the caller removes this one.
  Future<bool> move(int id, int startUtc, int endUtc) async {
    try {
      await (update(reminders)..where((t) => t.id.equals(id))).write(
        RemindersCompanion(startUtc: Value(startUtc), endUtc: Value(endUtc)),
      );
      return true;
    } on Object {
      return false;
    }
  }
}

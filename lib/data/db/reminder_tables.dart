import 'package:drift/drift.dart';
import 'package:iptv_player/data/db/tables.dart';

/// "Remind me" on an upcoming programme (schema v10; Phase 9 decision
/// 10). Kept in the database so a reminder survives a restart; removed
/// with its source.
///
/// Keyed like every other piece of user data: by the provider's channel
/// key, never a row id, so a re-sync keeps it. [xmltvId] is the guide
/// channel the programme was on when the reminder was set: a guide
/// refresh follows the programme by it and by [title] (decision 12).
/// Times are epoch milliseconds UTC, as `epg_programs` keeps them.
@DataClassName('ReminderRow')
@TableIndex(name: 'reminders_start', columns: {#startUtc})
class Reminders extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get sourceId =>
      text().references(Sources, #id, onDelete: KeyAction.cascade)();

  /// The channel Watch plays.
  TextColumn get channelRemoteKey => text()();

  TextColumn get xmltvId => text()();

  /// The channel's name when the reminder was set: what the notification
  /// and the list say, even if the channel has since left the provider's
  /// list.
  TextColumn get channelName => text()();

  TextColumn get title => text()();

  IntColumn get startUtc => integer()();

  IntColumn get endUtc => integer()();

  DateTimeColumn get createdAt => dateTime()();

  /// One reminder per programme: the same channel at the same start.
  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {sourceId, channelRemoteKey, startUtc},
  ];
}

import 'package:iptv_player/core/result.dart';
import 'package:meta/meta.dart';

/// "Remind me" on an upcoming programme (Phase 9 decision 10): what to
/// say, when, and which channel Watch plays.
@immutable
final class Reminder {
  const new({
    required this.id,
    required this.sourceId,
    required this.channelKey,
    required this.xmltvId,
    required this.channelName,
    required this.title,
    required this.start,
    required this.end,
  });

  final int id;
  final String sourceId;

  /// The provider's key for the channel: what Watch plays.
  final String channelKey;

  /// The guide channel the programme is on: a guide refresh follows the
  /// programme by it and by [title].
  final String xmltvId;

  /// The channel's name when the reminder was set.
  final String channelName;
  final String title;
  final DateTime start;
  final DateTime end;

  /// The same programme: the same channel of the same source at the same
  /// start.
  bool isFor({
    required String sourceId,
    required String channelKey,
    required DateTime start,
  }) =>
      this.sourceId == sourceId &&
      this.channelKey == channelKey &&
      this.start.isAtSameMomentAs(start);

  Reminder movedTo(DateTime start, DateTime end) => Reminder(
    id: id,
    sourceId: sourceId,
    channelKey: channelKey,
    xmltvId: xmltvId,
    channelName: channelName,
    title: title,
    start: start,
    end: end,
  );

  @override
  bool operator ==(Object other) =>
      other is Reminder &&
      other.id == id &&
      other.sourceId == sourceId &&
      other.channelKey == channelKey &&
      other.xmltvId == xmltvId &&
      other.channelName == channelName &&
      other.title == title &&
      other.start.isAtSameMomentAs(start) &&
      other.end.isAtSameMomentAs(end);

  @override
  int get hashCode => Object.hash(
    id,
    sourceId,
    channelKey,
    xmltvId,
    title,
    start.millisecondsSinceEpoch,
  );

  @override
  String toString() => 'Reminder($id, $title on $channelName at $start)';
}

/// A reminder to set.
@immutable
final class ReminderDraft {
  const new({
    required this.sourceId,
    required this.channelKey,
    required this.xmltvId,
    required this.channelName,
    required this.title,
    required this.start,
    required this.end,
  });

  final String sourceId;
  final String channelKey;
  final String xmltvId;
  final String channelName;
  final String title;
  final DateTime start;
  final DateTime end;
}

/// Where reminders are kept. Nothing throws across it.
abstract interface class ReminderRepository {
  /// Every reminder, soonest first, again whenever one is set, moved or
  /// removed.
  Stream<List<Reminder>> watchAll();

  Future<Result<List<Reminder>>> all();

  Future<Result<List<Reminder>>> forSource(String sourceId);

  /// Sets it; setting the same programme again gives the one already
  /// set.
  Future<Result<Reminder>> set(ReminderDraft draft);

  /// Removes it. True when it was there: only whoever got true may show
  /// it, so a reminder never shows twice.
  Future<Result<bool>> remove(int id);

  /// Moves it to its programme's new time.
  Future<Result<void>> move(int id, DateTime start, DateTime end);
}

/// What the guide says about a reminder's programme after a refresh.
@immutable
final class GuideAnswer {
  const new({this.showings = const [], this.covers = false});

  /// When the guide channel shows a programme of that title near the
  /// reminder's time.
  final List<({DateTime start, DateTime end})> showings;

  /// Whether the guide has anything on that channel at the reminder's
  /// time. A guide that doesn't reach it says nothing about it.
  final bool covers;
}

/// The guide, as the reminders ask it.
abstract interface class ReminderGuide {
  /// [title] on guide channel [xmltvId] within [within] of [around], and
  /// whether the guide covers [around] on that channel.
  Future<Result<GuideAnswer>> lookUp({
    required String sourceId,
    required String xmltvId,
    required String title,
    required DateTime around,
    required Duration within,
  });
}

/// What a guide refresh does to a reminder (decision 12).
sealed class ReminderFollow {
  const new();
}

/// As it was: the programme is where it was, or the guide doesn't reach
/// that time (a guide that is missing isn't a programme cancelled).
final class ReminderKept extends ReminderFollow {
  const new();
}

/// The programme moved, and the reminder with it. [worthSaying] from
/// [sayMovesFrom] up.
final class ReminderMoved extends ReminderFollow {
  const new(this.start, this.end, {required this.worthSaying});

  final DateTime start;
  final DateTime end;
  final bool worthSaying;
}

/// The guide covers that time and no longer has the programme.
final class ReminderGone extends ReminderFollow {
  const new();
}

/// A programme found this far from where it was is still the same one.
const followWithin = Duration(hours: 12);

/// A move of this much or more is said ("… moved to 9:45 PM").
const sayMovesFrom = Duration(minutes: 5);

/// Decision 12's rule for one reminder.
ReminderFollow followReminder(Reminder reminder, GuideAnswer guide) {
  if (guide.showings.isEmpty) {
    return guide.covers ? const ReminderGone() : const ReminderKept();
  }
  // The nearest showing: a daily programme is in the guide many times.
  final nearest = guide.showings.reduce(
    (a, b) =>
        a.start.difference(reminder.start).abs() <=
            b.start.difference(reminder.start).abs()
        ? a
        : b,
  );
  final moved = nearest.start.difference(reminder.start).abs();
  if (moved > followWithin) {
    return guide.covers ? const ReminderGone() : const ReminderKept();
  }
  if (moved == Duration.zero && nearest.end.isAtSameMomentAs(reminder.end)) {
    return const ReminderKept();
  }
  return ReminderMoved(
    nearest.start,
    nearest.end,
    worthSaying: moved >= sayMovesFrom,
  );
}

/// How a reminder that is due is shown.
enum ReminderTiming {
  /// At its start: "Starting now".
  startingNow,

  /// Its start passed while the app was closed or the computer asleep,
  /// and it is still on: "On now … until 10:30 PM".
  onNow,
}

/// A reminder that is due, to show.
@immutable
final class DueReminder {
  const new(this.reminder, this.timing);

  final Reminder reminder;
  final ReminderTiming timing;

  @override
  String toString() => 'DueReminder(${reminder.title}, ${timing.name})';
}

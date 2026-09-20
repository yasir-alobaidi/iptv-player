import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:iptv_player/core/result.dart';

/// A channel the guide declares (`<channel id>` in XMLTV). Not one of the
/// provider's channels: those are matched to these (docs/02).
@immutable
final class GuideChannel {
  const new({required this.xmltvId, this.displayName, this.iconUrl});

  final String xmltvId;
  final String? displayName;
  final String? iconUrl;

  /// What Settings → Guide shows for it: its name, or its id when the
  /// file gave no `<display-name>`.
  String get label =>
      displayName?.trim().isNotEmpty ?? false ? displayName!.trim() : xmltvId;

  @override
  bool operator ==(Object other) =>
      other is GuideChannel &&
      other.xmltvId == xmltvId &&
      other.displayName == displayName &&
      other.iconUrl == iconUrl;

  @override
  int get hashCode => Object.hash(xmltvId, displayName, iconUrl);
}

/// One programme from the imported guide. [channelId] is the XMLTV
/// channel id, which is what a programme names.
@immutable
final class EpgProgramme {
  const new({
    required this.id,
    required this.channelId,
    required this.start,
    required this.end,
    required this.title,
    this.subtitle,
    this.description,
    this.category,
  });

  final int id;
  final String channelId;
  final DateTime start;
  final DateTime end;
  final String title;
  final String? subtitle;
  final String? description;
  final String? category;

  bool isOnAt(DateTime at) => !start.isAfter(at) && end.isAfter(at);

  /// 0..1 through the programme at [at].
  double progressAt(DateTime at) {
    final total = end.difference(start).inSeconds;
    if (total <= 0) return 0;
    return (at.difference(start).inSeconds / total).clamp(0, 1).toDouble();
  }

  @override
  bool operator ==(Object other) =>
      other is EpgProgramme &&
      other.id == id &&
      other.channelId == channelId &&
      other.start == start &&
      other.end == end &&
      other.title == title &&
      other.subtitle == subtitle &&
      other.description == description &&
      other.category == category;

  @override
  int get hashCode => Object.hash(
    id,
    channelId,
    start,
    end,
    title,
    subtitle,
    description,
    category,
  );
}

/// What the imported guide has for one channel around a moment. Either
/// can be missing: a gap in the guide, or a channel whose guide has run
/// out.
@immutable
final class EpgNowNext {
  const new({this.now, this.next});

  static const none = EpgNowNext();

  final EpgProgramme? now;
  final EpgProgramme? next;

  @override
  bool operator ==(Object other) =>
      other is EpgNowNext && other.now == now && other.next == next;

  @override
  int get hashCode => Object.hash(now, next);
}

/// How an import ended, as Settings → Guide shows it.
enum GuideImportOutcome { running, succeeded, failed, cancelled }

/// The failure code an import gets when the app closed before it
/// finished.
const interruptedImportCode = 'interrupted';

/// What one import read, and what it had to skip. Stored as the import's
/// `counts_json`, so it is read back from databases written by older
/// builds: every field is optional and a missing one is a zero.
@immutable
final class EpgImportCounts {
  const new({
    this.channels = 0,
    this.programmes = 0,
    this.skipped = const {},
    this.truncated = false,
    this.firstStart,
    this.lastEnd,
  });

  /// Tolerant by hard rule 1: anything unexpected reads as empty rather
  /// than throwing at a Settings page.
  factory fromJson(String? source) {
    if (source == null || source.isEmpty) return const EpgImportCounts();
    try {
      final decoded = jsonDecode(source);
      if (decoded is! Map<String, dynamic>) return const EpgImportCounts();
      final skipped = decoded['skipped'];
      return EpgImportCounts(
        channels: _int(decoded['channels']) ?? 0,
        programmes: _int(decoded['programmes']) ?? 0,
        skipped: skipped is Map<String, dynamic>
            ? {
                for (final entry in skipped.entries)
                  entry.key: ?_int(entry.value),
              }
            : const {},
        truncated: decoded['truncated'] == true,
        firstStart: _time(decoded['first_start_ms']),
        lastEnd: _time(decoded['last_end_ms']),
      );
    } on FormatException {
      return const EpgImportCounts();
    }
  }

  static int? _int(Object? value) => switch (value) {
    final int v => v,
    final num v => v.toInt(),
    final String v => int.tryParse(v),
    _ => null,
  };

  static DateTime? _time(Object? value) {
    final ms = _int(value);
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
  }

  final int channels;
  final int programmes;

  /// Why rows were dropped, by reason (`bad_date`, `no_channel`, …), for
  /// Settings → Guide and the diagnostics export.
  final Map<String, int> skipped;

  /// The file ended mid-element. What was read is kept; the import says
  /// so rather than failing (hard rule 1).
  final bool truncated;

  final DateTime? firstStart;
  final DateTime? lastEnd;

  int get skippedTotal => skipped.values.fold(0, (sum, n) => sum + n);

  String toJson() => jsonEncode({
    'channels': channels,
    'programmes': programmes,
    if (skipped.isNotEmpty) 'skipped': skipped,
    if (truncated) 'truncated': true,
    if (firstStart != null)
      'first_start_ms': firstStart!.millisecondsSinceEpoch,
    if (lastEnd != null) 'last_end_ms': lastEnd!.millisecondsSinceEpoch,
  });

  EpgImportCounts withTotals({
    required int channels,
    required int programmes,
    DateTime? firstStart,
    DateTime? lastEnd,
  }) => EpgImportCounts(
    channels: channels,
    programmes: programmes,
    skipped: skipped,
    truncated: truncated,
    firstStart: firstStart ?? this.firstStart,
    lastEnd: lastEnd ?? this.lastEnd,
  );
}

/// A source's latest import, whatever its outcome.
@immutable
final class GuideImport {
  const new({
    required this.id,
    required this.outcome,
    required this.startedAt,
    this.finishedAt,
    this.failureCode,
    this.failureStatus,
    this.counts = const EpgImportCounts(),
    this.isLive = false,
  });

  final int id;
  final GuideImportOutcome outcome;
  final DateTime startedAt;
  final DateTime? finishedAt;

  /// An `AppFailure.code`, or [interruptedImportCode]; null unless the
  /// import failed. Never raw exception text.
  final String? failureCode;
  final int? failureStatus;
  final EpgImportCounts counts;

  /// True when this import's rows are the guide being shown.
  final bool isLive;
}

/// What the guide covers for one source: Settings → Guide reads it, and
/// the Guide screen uses it to tell "no guide yet" from "no programmes
/// today".
@immutable
final class GuideCoverage {
  const new({
    this.lastImport,
    this.guideChannels = 0,
    this.programmes = 0,
    this.firstStart,
    this.lastEnd,
    this.matchedChannels = 0,
    this.totalChannels = 0,
  });

  /// The source's latest import, running or finished; null when none has
  /// ever run.
  final GuideImport? lastImport;

  /// Counts from the import whose rows are live, not from the latest one:
  /// a failed refresh leaves the old guide in place and these describe it.
  final int guideChannels;
  final int programmes;
  final DateTime? firstStart;
  final DateTime? lastEnd;

  /// The provider's channels attached to a guide channel, out of
  /// [totalChannels].
  final int matchedChannels;
  final int totalChannels;

  bool get hasGuide => programmes > 0 || guideChannels > 0;

  int get unmatchedChannels =>
      totalChannels - matchedChannels < 0 ? 0 : totalChannels - matchedChannels;

  /// True while an import is running for this source.
  bool get isImporting => lastImport?.outcome == GuideImportOutcome.running;

  /// Whether the live guide still reaches [at] — what decides between
  /// the imported guide and the panel's short EPG (decision 1).
  bool coversAt(DateTime at) =>
      lastEnd != null && lastEnd!.isAfter(at) && programmes > 0;
}

/// The user's own channel → guide-channel mapping (Settings → Guide).
@immutable
final class EpgMapping {
  const new({
    required this.channelRemoteKey,
    required this.xmltvId,
    required this.updatedAt,
  });

  final String channelRemoteKey;
  final String xmltvId;
  final DateTime updatedAt;

  @override
  bool operator ==(Object other) =>
      other is EpgMapping &&
      other.channelRemoteKey == channelRemoteKey &&
      other.xmltvId == xmltvId &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(channelRemoteKey, xmltvId, updatedAt);
}

/// The guide store: an import's life, and everything read back from it.
/// Nothing throws across this boundary.
abstract interface class EpgRepository {
  /// Opens an import and returns its id. Staged rows carry it, and the
  /// swap needs it.
  Future<Result<int>> startImport(String sourceId);

  /// Writes a batch of staged channels. One batch, never a transaction:
  /// the import runs in an isolate that can be killed (hard rule 2).
  Future<Result<void>> stageChannels(int importRun, List<GuideChannel> rows);

  Future<Result<void>> stagePrograms(int importRun, List<EpgProgramme> rows);

  /// Puts the staged rows in place as the source's guide, in one
  /// transaction, and returns what landed. Runs on the app's side, never
  /// in the import isolate.
  Future<Result<EpgImportCounts>> commitImport({
    required String sourceId,
    required int importRun,
    EpgImportCounts counts = const EpgImportCounts(),
  });

  /// Ends the import without swapping: the old guide stays.
  Future<Result<void>> abandonImport(
    int importRun, {
    required GuideImportOutcome outcome,
    AppFailure? failure,
    EpgImportCounts counts = const EpgImportCounts(),
  });

  /// Called once on launch: marks imports left running as failed and
  /// drops the rows they staged. Returns how many imports were
  /// interrupted.
  Future<Result<int>> recoverInterrupted();

  Future<Result<GuideCoverage>> coverage(String sourceId);

  Stream<GuideCoverage> watchCoverage(String sourceId);

  /// Now and next for a page of the provider's channels, by row id,
  /// through whatever the matcher attached to them.
  Future<Result<Map<int, EpgNowNext>>> nowNextForChannels(
    List<int> channelIds,
    DateTime at,
  );

  /// Every programme overlapping `[from, to)` for those channels, in
  /// start order — what the Guide grid draws a screen from.
  Future<Result<Map<int, List<EpgProgramme>>>> windowForChannels(
    List<int> channelIds,
    DateTime from,
    DateTime to,
  );

  /// The guide's own channels, for the Match… picker.
  Future<Result<List<GuideChannel>>> guideChannels(
    String sourceId, {
    String? query,
    int limit,
  });

  Future<Result<void>> setMapping({
    required String sourceId,
    required String channelRemoteKey,
    required String xmltvId,
  });

  Future<Result<void>> removeMapping({
    required String sourceId,
    required String channelRemoteKey,
  });

  Future<Result<List<EpgMapping>>> mappings(String sourceId);

  /// Drops the source's guide, for instance when its EPG URL is cleared.
  Future<Result<void>> clearGuide(String sourceId);
}

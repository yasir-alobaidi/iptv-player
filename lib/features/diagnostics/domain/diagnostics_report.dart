import 'package:iptv_player/core/app_identity.dart';
import 'package:iptv_player/core/logging/redact.dart';
import 'package:iptv_player/core/platform/last_exits.dart';
import 'package:iptv_player/core/platform/run_logs.dart';
import 'package:iptv_player/core/platform/system_facts.dart';
import 'package:iptv_player/core/player/decoder_notes.dart';
import 'package:iptv_player/core/text/format.dart';
import 'package:meta/meta.dart';

/// One source as the report shows it: what kind it is and how it is
/// doing, and nothing that says whose it is (no name, no server, no
/// username; Phase 9 decision 9).
@immutable
final class SourceFacts {
  const new({
    required this.type,
    this.accountStatus,
    this.maxConnections,
    this.channels = 0,
    this.movies = 0,
    this.series = 0,
    this.sync,
    this.guide,
    this.guideProgrammes = 0,
  });

  /// `Xtream`, `M3U URL`, `M3U file`.
  final String type;

  /// `Active`, `Expired`, as the panel words it; null for a playlist.
  final String? accountStatus;
  final int? maxConnections;
  final int channels;
  final int movies;
  final int series;

  /// The latest sync and the latest guide import; null when none ran.
  final RunFacts? sync;
  final RunFacts? guide;
  final int guideProgrammes;
}

/// How a sync or a guide import went.
@immutable
final class RunFacts {
  const new({
    required this.outcome,
    required this.startedAt,
    this.duration,
    this.skipped = 0,
    this.failure,
    this.failureStatus,
  });

  /// `succeeded`, `failed`, `cancelled`, `running`.
  final String outcome;
  final DateTime startedAt;
  final Duration? duration;

  /// Rows the provider sent that couldn't be read (hard rule 1).
  final int skipped;

  /// An `AppFailure.code`, never its text.
  final String? failure;
  final int? failureStatus;
}

/// Everything the report is written from.
@immutable
final class DiagnosticsFacts {
  const new({
    required this.now,
    this.appVersion = 'unknown',
    this.system = const SystemFacts(),
    this.player,
    this.decoders = const [],
    this.ffmpeg,
    this.encoders,
    this.sources = const [],
    this.settings = const {},
    this.libraryFolders = 0,
    this.libraryItems = 0,
    this.downloadsWaiting = 0,
    this.downloadsFinished = 0,
    this.problems = const [],
    this.homeFolder,
    this.named = const {},
    this.drawing,
    this.exits,
    this.runLogs,
  });

  final DateTime now;

  /// `0.1.0+1`.
  final String appVersion;
  final SystemFacts system;

  /// `mpv 0.34.1`; null when the player couldn't start or doesn't say.
  final String? player;
  final List<DecoderNote> decoders;

  /// FFmpeg's own first line; null when it was never looked at (nothing
  /// was cast that needed converting) or isn't there.
  final String? ffmpeg;

  /// The encoders found for casting, best first; null when not looked
  /// for yet.
  final List<String>? encoders;
  final List<SourceFacts> sources;

  /// The settings that change behaviour, as "name: value" pairs in the
  /// order they are shown.
  final Map<String, String> settings;
  final int libraryFolders;
  final int libraryItems;
  final int downloadsWaiting;
  final int downloadsFinished;

  /// The newest warnings and errors of the log, oldest first, as the
  /// file has them (already redacted when written).
  final List<String> problems;

  /// Written `~` wherever it appears.
  final String? homeFolder;

  /// What must not be named, and what is written in its place wherever
  /// it appears: each source's server (`<server>`) and its name (`Source
  /// 1`). A log line may say either; the report may not.
  final Map<String, String> named;

  /// How a TV draws the screen (ADR-058); null where it isn't known.
  final DrawingBackend? drawing;

  /// A TV's last ends Android kept, newest first (ADR-058); null where
  /// nothing keeps them (the desktop).
  final List<AppExit>? exits;

  /// A TV's own log of the run before and of this one, for the report a
  /// phone takes (ADR-059); null in the report on the screen.
  final RunLogs? runLogs;
}

/// Shorter names and hosts aren't replaced as plain text: they would
/// mask ordinary words ("TV", "a.b").
const _minNamedLength = 4;

// scheme://host[:port], the host kept apart.
final _urlHost = RegExp(
  r'\b([a-z][a-z0-9+.\-]*://)([^\s/?#"<>]+)',
  caseSensitive: false,
);

// An IPv4 address, with its port when it has one.
final _ipv4 = RegExp(r'\b(?:\d{1,3}\.){3}\d{1,3}(?::\d{1,5})?\b');

bool _isThisComputer(String host) {
  final bare = host.toLowerCase();
  return bare.startsWith('127.') ||
      bare.startsWith('localhost') ||
      bare.startsWith('[::1]') ||
      bare.startsWith('0.0.0.0');
}

/// A log line without the addresses in it: a server's or a device's
/// host becomes `<address>`. This computer's own (the relay, the fake
/// panel) stays: it names nobody, and says which part was talking.
String withoutAddresses(String line) => line
    .replaceAllMapped(
      _urlHost,
      (match) =>
          _isThisComputer(match[2]!) ? match[0]! : '${match[1]}<address>',
    )
    .replaceAllMapped(
      _ipv4,
      (match) => _isThisComputer(match[0]!) ? match[0]! : '<address>',
    );

String _plural(int count, String one, [String? many]) =>
    '${formatCount(count)} ${count == 1 ? one : many ?? '${one}s'}';

String _run(RunFacts run, DateTime now) {
  final when = formatAgo(run.startedAt, now);
  final took = run.duration == null ? null : formatDuration(run.duration!);
  final skipped = _plural(run.skipped, 'row');
  return switch (run.outcome) {
    'succeeded' => [when, ?took, '$skipped skipped'].join(', '),
    'running' => 'running, started $when',
    'cancelled' => 'cancelled $when',
    _ => [
      'failed $when',
      [
        run.failure ?? 'unknown',
        if (run.failureStatus case final status?) 'HTTP $status',
      ].join(' '),
    ].join(': '),
  };
}

/// The unexpected ends among [exits], each with its facts under it, then
/// the others on one line (ADR-059: an end the app took for its own may
/// be the one that wasn't); nothing where none are kept.
List<String> _exits(List<AppExit>? exits, DateTime now) {
  if (exits == null) return const [];
  final unexpected = [
    for (final exit in exits)
      if (exit.unexpected) exit,
  ];
  final others = [
    for (final exit in exits)
      if (!exit.unexpected)
        [
          '${formatAgo(exit.time, now)} ${exit.reason.name}',
          if (exit.byBijou) 'Back on Home',
          if (exit.importance > 0) 'importance ${exit.importance}',
          if (exit.status != 0) 'status ${exit.status}',
          ?exit.description,
        ].join(', '),
  ];
  return [
    if (unexpected.isEmpty)
      'Unexpected ends: none kept'
    else ...[
      'Unexpected ends (${unexpected.length}):',
      for (final exit in unexpected) ...[
        '  ${formatAgo(exit.time, now)}: ${exit.summary}',
        for (final line in exit.details) '    ${withoutAddresses(line)}',
      ],
    ],
    if (others.isNotEmpty)
      'Other ends: ${withoutAddresses(others.join(' · '))}',
  ];
}

/// Each run's own log, under the rest; nothing in the report on the
/// screen.
List<String> _runLogs(RunLogs? logs) {
  if (logs == null) return const [];
  List<String> part(String title, List<String> lines) => lines.isEmpty
      ? ['$title: nothing kept']
      : [
          '$title (${_plural(lines.length, 'line')}):',
          for (final line in lines) '  ${withoutAddresses(line)}',
        ];
  return [
    // None in a TV's first two runs: no line for it then.
    if (logs.older.isNotEmpty)
      ...part('The run before that, as Android logged it', logs.older),
    ...part('The run before, as Android logged it', logs.previous),
    ...part('This run so far', logs.current),
  ];
}

/// The diagnostics report (Phase 9 decision 9, sketch D), as plain text
/// to paste somewhere. It names no provider and no person: every source
/// is "Source 1", "Source 2"; a log line's addresses are `<address>`;
/// the home folder is `~`; and the whole text goes through [redact] once
/// more with [secrets] on its way out.
String buildDiagnosticsReport(
  DiagnosticsFacts facts, {
  Iterable<String> secrets = const [],
}) {
  final system = facts.system;
  final cards = system.graphics.isEmpty
      ? 'not known'
      : system.graphics.map((card) => card.line).join(' · ');
  final drawing = facts.drawing;
  final logs = facts.runLogs;
  final graphics = [
    cards,
    if (drawing != null && drawing.skia) ...[
      'drawn with Skia on OpenGL ES',
      if (drawing.since case final since?)
        'since ${formatAgo(since, facts.now)}',
      ?drawing.cause,
    ],
    // As the engine said it, in each run's own log.
    if (logs != null) ...[
      if (rendererIn(logs.current) case final renderer?) 'this run $renderer',
      if (rendererIn(logs.previous) case final renderer?)
        'the run before $renderer',
      if (rendererIn(logs.older) case final renderer?)
        'the run before that $renderer',
    ],
  ].join(' · ');
  final decoding = facts.decoders.isEmpty
      ? 'nothing played yet'
      : facts.decoders.map((note) => note.line).join(' · ');
  final encoders = switch (facts.encoders) {
    null => 'encoders not looked for yet',
    [] => 'no encoder works here',
    final found => 'encoders ${found.join(' · ')}',
  };
  final out = <String>[
    [
      '$appName ${facts.appVersion}',
      ?system.os,
      ?system.kernel,
      ?system.session,
      ?system.desktop,
    ].join(' · '),
    if (system.device case final device?) 'Device: $device',
    if (system.memory case final memory?) 'Memory: $memory',
    'Graphics: $graphics',
    'Player: ${facts.player ?? 'not available'}',
    'Decoding: $decoding',
    'Casting: ${facts.ffmpeg ?? 'FFmpeg not looked at yet'} · $encoders',
    if (facts.sources.isEmpty) 'Sources: none',
  ];

  for (final (index, source) in facts.sources.indexed) {
    final sync = source.sync;
    final guide = source.guide;
    out
      ..add(
        [
          'Source ${index + 1}: ${source.type}',
          ?source.accountStatus,
          if (source.maxConnections case final max?) _plural(max, 'connection'),
          _plural(source.channels, 'channel'),
          _plural(source.movies, 'movie'),
          '${formatCount(source.series)} series',
        ].join(' · '),
      )
      ..add('  last sync: ${sync == null ? 'never' : _run(sync, facts.now)}')
      ..add(
        guide == null
            ? '  guide: never imported'
            : '  guide: ${_plural(source.guideProgrammes, 'programme')}, '
                  'last import ${_run(guide, facts.now)}',
      );
  }

  if (facts.settings.isNotEmpty) {
    final pairs = [
      for (final MapEntry(:key, :value) in facts.settings.entries)
        '$key $value',
    ];
    out.add('Settings: ${pairs.join(' · ')}');
  }
  out
    ..add(
      'Library: ${_plural(facts.libraryFolders, 'folder')} · '
      '${_plural(facts.libraryItems, 'item')}',
    )
    ..add(
      'Downloads: ${formatCount(facts.downloadsWaiting)} waiting or '
      'running · ${formatCount(facts.downloadsFinished)} finished',
    )
    ..addAll(_exits(facts.exits, facts.now))
    ..add(
      facts.problems.isEmpty
          ? 'Recent warnings and errors: none'
          : 'Recent warnings and errors (${facts.problems.length}):',
    )
    ..addAll([for (final line in facts.problems) '  ${withoutAddresses(line)}'])
    ..addAll(_runLogs(facts.runLogs));

  var text = out.join('\n');
  final home = facts.homeFolder;
  if (home != null && home.length > 1) text = text.replaceAll(home, '~');
  // The longest first, so a name that holds another is replaced whole.
  final named = facts.named.keys.toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  for (final name in named) {
    if (name.trim().length < _minNamedLength) continue;
    text = text.replaceAll(name, facts.named[name]!);
  }
  return redact(text, secrets: secrets);
}

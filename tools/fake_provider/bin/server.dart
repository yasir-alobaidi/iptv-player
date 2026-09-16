// The fake IPTV provider (docs/06-quality.md).
//
//   dart run tools/fake_provider/bin/server.dart --port 8899
//
// Defaults resolve against the repo, so it runs from anywhere with no flags.
import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:fake_provider/profile.dart';
import 'package:fake_provider/server.dart';
import 'package:fake_provider/server_state.dart';
import 'package:path/path.dart' as p;

Future<void> main(List<String> args) async {
  final parser = ArgParser()
    ..addOption('port', abbr: 'p', defaultsTo: '8899')
    ..addOption(
      'host',
      defaultsTo: '127.0.0.1',
      help: 'Bind address. Use 0.0.0.0 to reach it from a TV on the LAN.',
    )
    ..addOption(
      'profile',
      defaultsTo: 'default',
      allowed: fakeProfiles.keys,
      help:
          'default: small · large: the docs/06 perf profile · '
          'quirky: every docs/02 quirk on',
    )
    ..addOption('samples', help: 'Media samples directory.')
    ..addOption('ffmpeg', help: 'ffmpeg binary.')
    ..addOption('run-dir', help: 'PID files and the MKV loop cache.')
    ..addOption('username', help: 'Overrides the profile.')
    ..addOption('password', help: 'Overrides the profile.')
    ..addOption('live', help: 'Channel count, overriding the profile.')
    ..addOption('movies', help: 'Movie count, overriding the profile.')
    ..addOption('series', help: 'Series count, overriding the profile.')
    ..addOption('max-connections', help: 'Overrides the profile.')
    ..addFlag('verbose', abbr: 'v', help: 'Log requests and ffmpeg stderr.')
    ..addFlag('help', abbr: 'h', negatable: false);

  final ArgResults opts;
  try {
    opts = parser.parse(args);
  } on FormatException catch (e) {
    stderr.writeln('${e.message}\n\n${parser.usage}');
    exit(64);
  }
  if (opts.flag('help')) {
    stdout.writeln('Fake IPTV provider.\n\n${parser.usage}');
    return;
  }

  final port = int.tryParse(opts.option('port')!);
  if (port == null) {
    stderr.writeln('--port must be a number');
    exit(64);
  }

  final root = _repoRoot();
  int? count(String name) {
    final raw = opts.option(name);
    return raw == null ? null : int.tryParse(raw);
  }

  final profile = fakeProfiles[opts.option('profile')]!.copyWith(
    liveCount: count('live'),
    movieCount: count('movies'),
    seriesCount: count('series'),
    maxConnections: count('max-connections'),
    username: opts.option('username'),
    password: opts.option('password'),
  );

  final samples =
      opts.option('samples') ?? p.join(root, 'tools', 'media_samples', 'out');
  final ffmpeg = opts.option('ffmpeg') ?? _bundledFfmpeg(root);
  final runDir =
      opts.option('run-dir') ??
      p.join(Directory.systemTemp.path, 'iptv_fake_provider');

  if (!Directory(samples).existsSync()) {
    stderr.writeln(
      'samples directory not found: $samples\n'
      'Generate them with tools/media_samples/generate.sh, or pass --samples.',
    );
    exit(66);
  }

  final state = FakeServerState(
    profile: profile,
    samplesDir: samples,
    ffmpegPath: ffmpeg,
    runDir: runDir,
  );

  final server = await FakeProviderServer.start(
    state: state,
    port: port,
    address: opts.option('host')!,
    verbose: opts.flag('verbose'),
  );

  stdout
    ..writeln('fake provider on ${server.url} — profile "${profile.name}"')
    ..writeln(
      '  ${profile.liveCount} channels · ${profile.movieCount} movies · '
      '${profile.seriesCount} series · '
      'max_connections ${state.maxConnections}',
    )
    ..writeln('  credentials ${profile.username} / ${profile.password}')
    ..writeln('  samples $samples')
    ..writeln('  ffmpeg  $ffmpeg')
    ..writeln('  run dir $runDir')
    ..writeln('Ctrl+C to stop.');

  // Ctrl+C has to reach close(): the ffmpeg children outlive the isolate
  // otherwise, and the next run would inherit them (hard rule 8).
  late final StreamSubscription<ProcessSignal> sigint;
  sigint = ProcessSignal.sigint.watch().listen((_) async {
    stdout.writeln('\nstopping…');
    await sigint.cancel();
    await server.close();
    exit(0);
  });
}

/// `.../tools/fake_provider/bin/server.dart` → the repo root, falling back to
/// the working directory when the script path is unusable (compiled runs).
String _repoRoot() {
  final script = Platform.script;
  if (script.scheme == 'file') {
    final dir = p.dirname(script.toFilePath());
    final root = p.normalize(p.join(dir, '..', '..', '..'));
    if (File(p.join(root, 'pubspec.yaml')).existsSync()) return root;
  }
  return Directory.current.path;
}

String _bundledFfmpeg(String root) {
  final platform = Platform.isWindows ? 'windows-x64' : 'linux-x64';
  final exe = Platform.isWindows ? 'ffmpeg.exe' : 'ffmpeg';
  final bundled = p.join(root, 'third_party', 'ffmpeg', platform, exe);
  // Fall back to PATH so a machine without third_party/ can still run the
  // API endpoints; the stream handler is the only thing that needs ffmpeg.
  return File(bundled).existsSync() ? bundled : 'ffmpeg';
}

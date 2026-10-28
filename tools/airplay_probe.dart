// Plays a URL on an AirPlay receiver with the app's own AirPlay client
// (ADR-067), to try a TV by hand before the casting screens use it.
//
//   dart run tools/airplay_probe.dart transient <host> <url> [seconds]
//       plays with transient pairing (a receiver that lets anyone play)
//   dart run tools/airplay_probe.dart pair <host> <credentials file>
//       the TV shows a code; type it here; the credentials go to the file
//   dart run tools/airplay_probe.dart play <host> <credentials file> <url>
//       [seconds]
//
// The port is 7000 unless given as host:port. The credentials file holds
// this computer's AirPlay secret key: keep it outside the repository.
import 'dart:async';
import 'dart:io';

import 'package:iptv_player/data/airplay/airplay_session.dart';
import 'package:iptv_player/data/airplay/hap_pairing.dart';

Future<void> main(List<String> args) async {
  if (args.length < 3) {
    stderr.writeln('usage: see the top of tools/airplay_probe.dart');
    exit(2);
  }
  final (host, port) = _address(args[1]);
  switch (args[0]) {
    case 'transient':
      await _play(host, port, null, args[2], _seconds(args, 3));
    case 'pair':
      await _pair(host, port, File(args[2]));
    case 'play' when args.length >= 4:
      final credentials = HapCredentials.parse(
        File(args[2]).readAsStringSync().trim(),
      );
      if (credentials == null) {
        stderr.writeln('no credentials in ${args[2]}');
        exit(1);
      }
      await _play(host, port, credentials, args[3], _seconds(args, 4));
    default:
      stderr.writeln('usage: see the top of tools/airplay_probe.dart');
      exit(2);
  }
  exit(0);
}

Future<void> _pair(String host, int port, File file) async {
  _say('pair-pin-start and pair-setup M1 to $host:$port');
  final started = await AirPlayPairing.start(host, port);
  final AirPlayPairing pairing;
  switch (started) {
    case AirPlayFailed(:final failure):
      _say('failed: $failure');
      exit(1);
    case AirPlayOk(:final value):
      pairing = value;
  }
  stdout.write('The code on the TV: ');
  final pin = stdin.readLineSync()?.trim() ?? '';
  switch (await pairing.finish(pin)) {
    case AirPlayFailed(:final failure):
      _say('failed: $failure');
      exit(1);
    case AirPlayOk(:final value):
      file.writeAsStringSync(value.serialize());
      if (!Platform.isWindows) {
        await Process.run('chmod', ['600', file.path]);
      }
      _say('paired; credentials in ${file.path}');
  }
}

Future<void> _play(
  String host,
  int port,
  HapCredentials? credentials,
  String url,
  int seconds,
) async {
  _say(
    credentials == null
        ? 'transient pairing with $host:$port'
        : 'pair-verify with $host:$port',
  );
  final clock = Stopwatch()..start();
  final connected = await AirPlaySession.connect(
    host,
    port,
    credentials: credentials,
  );
  final AirPlaySession session;
  switch (connected) {
    case AirPlayFailed(:final failure):
      _say('failed: $failure');
      exit(1);
    case AirPlayOk(:final value):
      session = value;
  }
  _say(
    'verified in ${clock.elapsedMilliseconds} ms, from ${session.localAddress}',
  );
  session.states.listen((state) => _say('state: $state'));
  final played = await session.play(url);
  _say('play: $played after ${clock.elapsedMilliseconds} ms');
  await Future<void>.delayed(Duration(seconds: seconds));
  _say('closing');
  await session.close();
}

(String, int) _address(String text) {
  final colon = text.lastIndexOf(':');
  if (colon > 0 && !text.contains(']')) {
    final port = int.tryParse(text.substring(colon + 1));
    if (port != null) return (text.substring(0, colon), port);
  }
  return (text, 7000);
}

int _seconds(List<String> args, int index) =>
    args.length > index ? int.tryParse(args[index]) ?? 30 : 30;

void _say(String line) => stdout.writeln(
  '${DateTime.now().toIso8601String().substring(11, 23)} '
  '$line',
);

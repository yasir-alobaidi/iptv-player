import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:fake_receiver/fake_receiver.dart';

/// Runs the fake Cast device until Ctrl+C. Add it in the app by its
/// address (Add device by address: `127.0.0.1:<port>`).
Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption('host', defaultsTo: '127.0.0.1')
    ..addOption('port', defaultsTo: '8010')
    ..addOption('name', defaultsTo: 'Fake TV')
    ..addOption(
      'launch-delay-ms',
      defaultsTo: '0',
      help: 'How long LAUNCH takes (Living Room TV: 3000-6000).',
    )
    ..addOption('load-delay-ms', defaultsTo: '300')
    ..addOption(
      'ffprobe',
      help:
          'Plays for real: fetches what LOAD names as the TV does, and '
          'checks it with this ffprobe.',
    )
    ..addOption(
      'device',
      allowed: ['tv4k', 'chromecast-hd', 'tv-hd-link'],
      defaultsTo: 'tv4k',
      help:
          'With --ffprobe: what it plays. A 4K HEVC TV, a 1080p H.264-only '
          'Chromecast, a 4K TV on a 1080p HDMI link.',
    )
    ..addFlag('verbose', abbr: 'v', help: 'Logs every message received.')
    ..addFlag('help', abbr: 'h', negatable: false);
  final args = parser.parse(arguments);
  if (args.flag('help')) {
    stdout.writeln(parser.usage);
    return;
  }
  final verbose = args.flag('verbose');
  final profile = switch (args.option('device')) {
    'chromecast-hd' => FakeDevice.chromecastHd,
    'tv-hd-link' => FakeDevice.tvOnHdLink,
    _ => FakeDevice.tv4k,
  };
  final ffprobe = args.option('ffprobe');
  final receiver = await FakeReceiver.start(
    device: FakeDevice(
      name: args.option('name')!,
      id: profile.id,
      hevc: profile.hevc,
      maxHeight: profile.maxHeight,
      linkHeight: profile.linkHeight,
    ),
    host: args.option('host')!,
    port: int.parse(args.option('port')!),
    launchDelay: Duration(
      milliseconds: int.parse(args.option('launch-delay-ms')!),
    ),
    loadDelay: Duration(milliseconds: int.parse(args.option('load-delay-ms')!)),
    playback: ffprobe == null ? null : FakePlayback(ffprobe: ffprobe),
    log: stdout.writeln,
  );
  if (verbose) {
    receiver.onReceived
        .where((m) => m.namespace != nsHeartbeat)
        .listen((m) => stdout.writeln('<- $m ${m.payload}'));
  }
  stdout.writeln(
    'Fake receiver "${receiver.device.name}" on '
    '${receiver.host}:${receiver.port}',
  );
  await ProcessSignal.sigint.watch().first;
  await receiver.close();
}

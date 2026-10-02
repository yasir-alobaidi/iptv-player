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
    ..addFlag('verbose', abbr: 'v', help: 'Logs every message received.')
    ..addFlag('help', abbr: 'h', negatable: false);
  final args = parser.parse(arguments);
  if (args.flag('help')) {
    stdout.writeln(parser.usage);
    return;
  }
  final verbose = args.flag('verbose');
  final receiver = await FakeReceiver.start(
    device: FakeDevice(name: args.option('name')!),
    host: args.option('host')!,
    port: int.parse(args.option('port')!),
    launchDelay: Duration(
      milliseconds: int.parse(args.option('launch-delay-ms')!),
    ),
    loadDelay: Duration(milliseconds: int.parse(args.option('load-delay-ms')!)),
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

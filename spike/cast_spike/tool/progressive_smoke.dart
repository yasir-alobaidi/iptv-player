import 'dart:io';

import 'package:cast_spike/relay.dart';

/// Local check without a TV: serves one sample as a continuous fragmented MP4
/// on 127.0.0.1, prints the URL, and runs until SIGTERM or SIGINT.
Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln(
      'usage: dart run tool/progressive_smoke.dart <sample.ts> [hvc1|hev1]',
    );
    exit(64);
  }
  final root = Directory.current.absolute.parent.parent.path;
  final ffmpeg = '$root/third_party/ffmpeg/linux-x64/ffmpeg';
  final runDir = Directory('${Directory.current.absolute.path}/results/run')
    ..createSync(recursive: true);
  final source = await SourceServer.start(
    ffmpeg,
    '$root/tools/media_samples/out',
    runDir,
  );
  final relay = await RelayServer.start(InternetAddress.loopbackIPv4, (_) {});
  print(
    relay.addProgressive(
      ffmpeg,
      progressiveArgs(
        source.url(args.first),
        videoTag: args.length > 1 ? args[1] : null,
      ),
      runDir,
      stderr.writeln,
    ),
  );
  await Future.any([
    ProcessSignal.sigterm.watch().first,
    ProcessSignal.sigint.watch().first,
  ]);
  await relay.close();
  await source.close();
  exit(0);
}

import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/launch_mark.dart';
import 'package:iptv_player/core/logging/secret_registry.dart';
import 'package:logger/logger.dart';

void main() {
  late MemoryOutput memory;
  late AppLog log;

  setUp(() {
    memory = MemoryOutput();
    log = AppLog(output: memory, secrets: SecretRegistry());
  });

  tearDown(() => log.close());

  List<String> lines() => [for (final e in memory.buffer) ...e.lines];

  test("Home's first frame is logged once, with the time since main()", () {
    LaunchMark(log, Stopwatch()..start())
      ..homeShown()
      ..homeShown();

    final logged = lines().where((l) => l.contains('[startup]')).toList();
    expect(logged, hasLength(1));
    expect(
      logged.single,
      matches(RegExp(r'\[startup\] Home is on screen, \d+ ms after main\(\)')),
    );
  });

  test('none() marks nothing', () {
    LaunchMark.none().homeShown();

    expect(lines(), isEmpty);
  });
}

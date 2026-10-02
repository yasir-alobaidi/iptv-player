import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/cast/stream_facts.dart';
import 'package:iptv_player/core/cast/stream_probe.dart';
import 'package:iptv_player/features/casting/domain/stream_facts_lookup.dart';

/// Answers what it is told, counting probes; [gate] holds them.
final class _ScriptedProbe implements StreamProbe {
  final inputs = <String>[];
  final userAgents = <String?>[];
  StreamProbeResult answer = const StreamProbed(_probed);
  Completer<void>? gate;

  @override
  Future<StreamProbeResult> probe(String input, {String? userAgent}) async {
    inputs.add(input);
    userAgents.add(userAgent);
    await gate?.future;
    return answer;
  }
}

const _probed = StreamFacts(
  origin: StreamFactsOrigin.probe,
  video: VideoFacts(codec: 'h264', height: 1080),
);
const _fromPlayer = StreamFacts(
  origin: StreamFactsOrigin.player,
  video: VideoFacts(codec: 'hevc', height: 2160),
);

CastStreamKey _live(String id) =>
    CastStreamKey(sourceId: 's1', kind: CastStreamKind.live, id: id);

void main() {
  late _ScriptedProbe probe;
  late StreamFactsLookup lookup;
  late int inputsAsked;

  Future<String> input() async {
    inputsAsked++;
    return 'http://127.0.0.1:38400/in/token';
  }

  setUp(() {
    probe = _ScriptedProbe();
    lookup = StreamFactsLookup(probe: probe, capacity: 3);
    inputsAsked = 0;
  });

  StreamFacts factsOf(StreamProbeResult result) =>
      (result as StreamProbed).facts;

  test("the player's facts first: no probe, no input opened", () async {
    final result = await lookup.factsFor(
      _live('1'),
      probeInput: input,
      fromPlayer: _fromPlayer,
    );
    expect(factsOf(result), _fromPlayer);
    expect(probe.inputs, isEmpty);
    expect(inputsAsked, 0);
  });

  test("the player's facts are remembered for the next cast", () async {
    await lookup.factsFor(
      _live('1'),
      probeInput: input,
      fromPlayer: _fromPlayer,
    );
    final again = factsOf(await lookup.factsFor(_live('1'), probeInput: input));
    expect(again.origin, StreamFactsOrigin.remembered);
    expect(again.video, _fromPlayer.video);
    expect(probe.inputs, isEmpty);
  });

  test('then ffprobe, through the input it is given, once', () async {
    final first = factsOf(
      await lookup.factsFor(
        _live('1'),
        probeInput: input,
        userAgent: 'VLC/3.0',
      ),
    );
    expect(first.origin, StreamFactsOrigin.probe);
    expect(probe.inputs, ['http://127.0.0.1:38400/in/token']);
    expect(probe.userAgents, ['VLC/3.0']);

    // Zapping back costs nothing.
    final second = factsOf(
      await lookup.factsFor(_live('1'), probeInput: input),
    );
    expect(second.origin, StreamFactsOrigin.remembered);
    expect(probe.inputs, hasLength(1));
    expect(inputsAsked, 1);
  });

  test("the player's facts replace what was remembered", () async {
    await lookup.factsFor(_live('1'), probeInput: input);
    await lookup.factsFor(
      _live('1'),
      probeInput: input,
      fromPlayer: _fromPlayer,
    );
    final now = factsOf(await lookup.factsFor(_live('1'), probeInput: input));
    expect(now.video?.codec, 'hevc');
  });

  test('keys tell sources, kinds and ids apart', () async {
    await lookup.factsFor(_live('1'), probeInput: input);
    await lookup.factsFor(
      const CastStreamKey(sourceId: 's2', kind: CastStreamKind.live, id: '1'),
      probeInput: input,
    );
    await lookup.factsFor(
      const CastStreamKey(sourceId: 's1', kind: CastStreamKind.movie, id: '1'),
      probeInput: input,
    );
    expect(probe.inputs, hasLength(3));
  });

  test('a failed probe answers why and is not remembered', () async {
    probe.answer = const StreamProbeFailed(StreamProbeFailure.timedOut);
    final failed = await lookup.factsFor(_live('1'), probeInput: input);
    expect(failed, isA<StreamProbeFailed>());

    probe.answer = const StreamProbed(_probed);
    final next = await lookup.factsFor(_live('1'), probeInput: input);
    expect(factsOf(next).origin, StreamFactsOrigin.probe);
    expect(probe.inputs, hasLength(2));
  });

  test(
    'an input that cannot be opened is a probe that could not start',
    () async {
      final result = await lookup.factsFor(
        _live('1'),
        probeInput: () async =>
            throw StateError('relay down at http://u:secret@host/'),
      );
      final failed = result as StreamProbeFailed;
      expect(failed.reason, StreamProbeFailure.couldNotStart);
      expect(failed.detail, isNot(contains('secret')));
      expect(probe.inputs, isEmpty);
    },
  );

  test('casts of one stream at once share one probe', () async {
    probe.gate = Completer<void>();
    final a = lookup.factsFor(_live('1'), probeInput: input);
    final b = lookup.factsFor(_live('1'), probeInput: input);
    final other = lookup.factsFor(_live('2'), probeInput: input);
    await pumpEventQueue();
    probe.gate!.complete();
    final results = await Future.wait([a, b, other]);
    expect(results.every((r) => r is StreamProbed), isTrue);
    expect(probe.inputs, hasLength(2));

    // And the next one is remembered, not shared.
    final later = await lookup.factsFor(_live('1'), probeInput: input);
    expect(factsOf(later).origin, StreamFactsOrigin.remembered);
  });

  test('the least recently used go first', () async {
    for (final id in ['1', '2', '3']) {
      await lookup.factsFor(_live(id), probeInput: input);
    }
    // 1 used again: 2 is now the oldest.
    await lookup.factsFor(_live('1'), probeInput: input);
    await lookup.factsFor(_live('4'), probeInput: input);
    expect(probe.inputs, hasLength(4));

    await lookup.factsFor(_live('1'), probeInput: input);
    await lookup.factsFor(_live('3'), probeInput: input);
    await lookup.factsFor(_live('4'), probeInput: input);
    expect(probe.inputs, hasLength(4));
    await lookup.factsFor(_live('2'), probeInput: input);
    expect(probe.inputs, hasLength(5));
  });

  test('forget makes the next cast ask again; remember is kept', () async {
    await lookup.factsFor(_live('1'), probeInput: input);
    lookup.forget(_live('1'));
    await lookup.factsFor(_live('1'), probeInput: input);
    expect(probe.inputs, hasLength(2));

    lookup.remember(_live('9'), _fromPlayer);
    final kept = factsOf(await lookup.factsFor(_live('9'), probeInput: input));
    expect(kept.video?.codec, 'hevc');
    expect(probe.inputs, hasLength(2));
  });
}

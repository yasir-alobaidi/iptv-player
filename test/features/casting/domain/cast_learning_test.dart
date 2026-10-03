import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/cast/cast_device.dart';
import 'package:iptv_player/core/cast/cast_device_profile.dart';
import 'package:iptv_player/core/cast/cast_plan.dart';
import 'package:iptv_player/core/cast/cast_planner.dart';
import 'package:iptv_player/core/cast/stream_facts.dart';
import 'package:iptv_player/features/casting/domain/cast_learning.dart';

import '../support/cast_fakes.dart';

/// docs/04 "Learning": what a refusal teaches, in its order.
void main() {
  CastPlan plan(
    StreamFacts facts, {
    CastLearned learned = const CastLearned(),
    bool hls = false,
    bool live = true,
    CastSettings settings = const CastSettings(),
  }) => (planCast(
    CastPlanRequest(
      facts: facts,
      source: CastSourceInfo(sourceId: 'src', live: live, hls: hls),
      device: CastDeviceProfile(model: 'Chromecast', learned: learned),
      settings: settings,
    ),
  ) as CastPlanned).plan;

  CastLesson? learn(
    StreamFacts facts, {
    CastLearned learned = const CastLearned(),
    bool hls = false,
    bool live = true,
    CastSettings settings = const CastSettings(),
  }) => learnFromRefusal(
    plan: plan(
      facts,
      learned: learned,
      hls: hls,
      live: live,
      settings: settings,
    ),
    facts: facts,
    learned: learned,
    sourceId: 'src',
  );

  test('a direct play: the relay from then on, for the source', () {
    final lesson = learn(h264Facts, hls: true)!;
    expect(lesson.kind, CastLessonKind.direct);
    expect(lesson.learned.directRefusedSources, {'src'});
    final next = plan(h264Facts, hls: true, learned: lesson.learned);
    expect(next.delivery, CastDelivery.relayHls);
  });

  test('4K copied: held at 1080p, re-encoded with the hint', () {
    final lesson = learn(hevc4kFacts)!;
    expect(lesson.kind, CastLessonKind.height);
    expect(lesson.learned.maxHeight, 1080);
    final video = plan(hevc4kFacts, learned: lesson.learned).video;
    expect(video, isA<CastVideoTranscode>());
    expect(
      (video as CastVideoTranscode).reasons.first,
      TranscodeReason.aboveLearnedHeight,
    );
  });

  test('4K re-encoded at its own height and still refused: 1080p', () {
    // An H.264-only device's re-encode keeps 2160p until the link says no.
    const learned = CastLearned(refusedCodecs: {'hevc'});
    final lesson = learn(hevc4kFacts, learned: learned)!;
    expect(lesson.kind, CastLessonKind.height);
    expect(lesson.learned.refusedCodecs, {'hevc'});
  });

  test('HEVC at 1080p: the codec', () {
    final facts = hevc4kFacts.copyWith(
      video: hevc4kFacts.video!.copyWith(width: 1920, height: 1080),
    );
    final lesson = learn(facts)!;
    expect(lesson.kind, CastLessonKind.videoCodec);
    expect(lesson.learned.refusedCodecs, {'hevc'});
    final video = plan(facts, learned: lesson.learned).video;
    expect(
      (video as CastVideoTranscode).reasons.first,
      TranscodeReason.hevcRefused,
    );
  });

  test('interlaced H.264 copied: deinterlaced from then on', () {
    final facts = h264Facts.copyWith(
      video: h264Facts.video!.copyWith(interlaced: true, fps: 25),
    );
    final lesson = learn(facts)!;
    expect(lesson.kind, CastLessonKind.interlaced);
    expect(lesson.learned.refusedInterlaced, isTrue);
    final video = plan(facts, learned: lesson.learned).video;
    expect((video as CastVideoTranscode).deinterlace, isTrue);
  });

  test('Dolby passed through: the sound codec', () {
    final facts = h264Facts.copyWith(
      audio: const [AudioFacts(index: 0, codec: 'eac3', channels: 6)],
    );
    const passthrough = CastSettings(dolbyPassthrough: true);
    final lesson = learn(facts, settings: passthrough)!;
    expect(lesson.kind, CastLessonKind.audioCodec);
    expect(lesson.learned.refusedCodecs, {'eac3'});
    final next = plan(facts, learned: lesson.learned, settings: passthrough);
    expect(next.audio, isA<CastAudioToAac>());
  });

  test('H.264 and AAC copied: nothing left to blame', () {
    expect(learn(h264Facts), isNull);
  });

  test('what was learned is not learned again', () {
    const learned = CastLearned(maxHeight: 1080, refusedCodecs: {'hevc'});
    // Re-encoded to 1080p H.264 with the sound converted: nothing more.
    expect(learn(hevc4kFacts, learned: learned), isNull);
    final direct = learn(
      h264Facts,
      hls: true,
      learned: const CastLearned(directRefusedSources: {'src'}),
    );
    expect(direct, isNull, reason: 'it is relayed already');
  });

  test('order: the height before the codec', () {
    final lesson = learn(hevc4kFacts)!;
    expect(lesson.kind, CastLessonKind.height);
    final second = learnFromRefusal(
      plan: plan(hevc4kFacts, learned: lesson.learned),
      facts: hevc4kFacts,
      learned: lesson.learned,
      sourceId: 'src',
    );
    expect(second, isNull, reason: 'a 1080p H.264 re-encode');
  });
}

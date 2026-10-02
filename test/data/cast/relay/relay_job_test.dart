import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/cast/cast_encoders.dart';
import 'package:iptv_player/core/cast/cast_plan.dart';
import 'package:iptv_player/core/cast/stream_facts.dart';
import 'package:iptv_player/data/cast/ffmpeg_binaries.dart';
import 'package:iptv_player/data/cast/relay/relay_args.dart';
import 'package:iptv_player/data/cast/relay/relay_job.dart';

/// The relay's command lines: docs/04's input options and muxers around
/// the plan's maps and codecs, with the proxy, never the provider, as the
/// input.
void main() {
  const binaries = FfmpegBinaries(
    ffmpeg: '/app/ffmpeg/ffmpeg',
    ffprobe: '/app/ffmpeg/ffprobe',
    libva: '/app/ffmpeg/libva',
  );
  const h264 = StreamFacts(
    origin: StreamFactsOrigin.probe,
    video: VideoFacts(codec: 'h264', height: 1080, fps: 50),
    audio: [AudioFacts(index: 0, codec: 'aac', channels: 2)],
  );
  const hevc = StreamFacts(
    origin: StreamFactsOrigin.probe,
    video: VideoFacts(codec: 'hevc', profile: 'Main', height: 2160, fps: 25),
    audio: [AudioFacts(index: 0, codec: 'eac3', channels: 6)],
  );
  const output = CastOutput(height: 1080);

  CastPlan plan({
    CastDelivery delivery = CastDelivery.relayHls,
    CastVideo video = const CastVideoCopy(),
    CastAudio audio = const CastAudioCopy(0),
    bool live = true,
  }) => CastPlan(
    delivery: delivery,
    video: video,
    audio: audio,
    live: live,
    output: output,
  );

  group('relayArguments', () {
    const job = RelayJob(
      ffmpeg: '/app/ffmpeg/ffmpeg',
      output: RelayOutput.hls,
      live: true,
      inputArgs: ['-hwaccel', 'cuda'],
      outputArgs: ['-map', '0:V:0', '-c:v', 'copy'],
    );
    const proxy = 'http://127.0.0.1:41235/in/9f2c';

    test("HLS: docs/04's input options, the proxy, the job, the muxer", () {
      expect(relayArguments(job, input: proxy, folder: '/r/cast-1-0'), [
        ...['-hide_banner', '-nostdin', '-nostats'],
        ...['-loglevel', 'repeat+level+info'],
        ...['-reconnect', '1', '-reconnect_streamed', '1'],
        ...['-reconnect_on_network_error', '1', '-reconnect_delay_max', '1'],
        ...['-fflags', '+genpts+discardcorrupt'],
        ...['-analyzeduration', '2000000', '-probesize', '5000000'],
        ...['-hwaccel', 'cuda'],
        ...['-i', proxy],
        ...['-map', '0:V:0', '-c:v', 'copy'],
        ...['-max_muxing_queue_size', '1024'],
        ...['-f', 'hls', '-hls_time', '2', '-hls_list_size', '6'],
        ...['-hls_flags', 'delete_segments+independent_segments+omit_endlist'],
        ...['-hls_segment_type', 'mpegts'],
        ...['-hls_segment_filename', '/r/cast-1-0/seg%05d.ts'],
        '/r/cast-1-0/index.m3u8',
      ]);
    });

    test('HLS after a restart continues its playlist', () {
      final args = relayArguments(
        job,
        input: proxy,
        folder: '/r/cast-1-0',
        append: true,
      );
      expect(
        args[args.indexOf('-hls_flags') + 1],
        'delete_segments+independent_segments+omit_endlist+append_list',
      );
    });

    test('continuous: one fragmented MP4 on standard output', () {
      const continuous = RelayJob(
        ffmpeg: '/app/ffmpeg/ffmpeg',
        output: RelayOutput.continuous,
        live: true,
      );
      final args = relayArguments(continuous, input: proxy);
      expect(args.sublist(args.length - 5), [
        ...['-f', 'mp4'],
        ...['-movflags', 'frag_keyframe+empty_moov+default_base_moof'],
        'pipe:1',
      ]);
      expect(args, isNot(contains('-hls_time')));
    });

    test("no User-Agent on the command line: the proxy sends the source's", () {
      expect(
        relayArguments(job, input: proxy, folder: '/r'),
        isNot(contains('-user_agent')),
      );
    });
  });

  group('castRelayJob', () {
    test('H.264 copied into HLS, AAC copied', () {
      final job = castRelayJob(plan: plan(), facts: h264, binaries: binaries);
      expect(job.ffmpeg, '/app/ffmpeg/ffmpeg');
      expect(job.output, RelayOutput.hls);
      expect(job.live, isTrue);
      expect(job.transcode, isFalse);
      expect(job.inputArgs, isEmpty);
      expect(job.outputArgs, [
        ...['-map', '0:V:0', '-c:v', 'copy'],
        ...['-map', '0:a:0?', '-c:a', 'copy'],
      ]);
      expect(job.environment, isEmpty);
    });

    test('HEVC copied into one continuous MP4, tagged hvc1; Dolby to AAC', () {
      final job = castRelayJob(
        plan: plan(
          delivery: CastDelivery.relayContinuous,
          audio: const CastAudioToAac(1, AudioConversionReason.dolby),
        ),
        facts: hevc,
        binaries: binaries,
      );
      expect(job.output, RelayOutput.continuous);
      expect(job.outputArgs, [
        ...['-map', '0:V:0', '-c:v', 'copy', '-tag:v', 'hvc1'],
        ...['-map', '0:a:1?', '-c:a', 'aac', '-b:a', '192k', '-ac', '2'],
      ]);
    });

    test('AAC copied into a continuous MP4 loses its ADTS headers', () {
      final job = castRelayJob(
        plan: plan(delivery: CastDelivery.relayContinuous),
        facts: h264,
        binaries: binaries,
      );
      expect(job.outputArgs, [
        ...['-map', '0:V:0', '-c:v', 'copy'],
        ...['-map', '0:a:0?', '-c:a', 'copy', '-bsf:a', 'aac_adtstoasc'],
      ]);
      final ac3 = castRelayJob(
        plan: plan(delivery: CastDelivery.relayContinuous),
        facts: hevc,
        binaries: binaries,
      );
      expect(ac3.outputArgs, isNot(contains('-bsf:a')), reason: 'E-AC-3');
      expect(
        castRelayJob(plan: plan(), facts: h264, binaries: binaries).outputArgs,
        isNot(contains('-bsf:a')),
        reason: 'MPEG-TS keeps ADTS',
      );
    });

    test('H.264 into a continuous MP4 needs no tag', () {
      final job = castRelayJob(
        plan: plan(delivery: CastDelivery.relayContinuous),
        facts: h264,
        binaries: binaries,
      );
      expect(job.outputArgs, isNot(contains('-tag:v')));
    });

    test('a radio channel: no picture; a silent one: no sound', () {
      expect(
        castRelayJob(
          plan: plan(video: const CastNoVideo()),
          facts: h264,
          binaries: binaries,
        ).outputArgs,
        ['-vn', '-map', '0:a:0?', '-c:a', 'copy'],
      );
      expect(
        castRelayJob(
          plan: plan(audio: const CastNoAudio()),
          facts: h264,
          binaries: binaries,
        ).outputArgs,
        ['-map', '0:V:0', '-c:v', 'copy', '-an'],
      );
    });

    test("a re-encode: step 4's arguments, and its environment", () {
      const transcode = CastVideoTranscode(
        height: 1080,
        bitRate: 6000000,
        reasons: [TranscodeReason.hevcRefused],
        fps: 25,
      );
      final job = castRelayJob(
        plan: plan(video: transcode),
        facts: hevc,
        binaries: binaries,
        encoder: const CastEncoder(
          CastEncoderKind.vaapi,
          device: '/dev/dri/renderD129',
          decodes: {HardwareDecode.hevc},
          bundledLibva: true,
        ),
        windows: false,
      );
      expect(job.transcode, isTrue);
      expect(job.inputArgs, [
        ...['-hwaccel', 'vaapi', '-hwaccel_device', '/dev/dri/renderD129'],
        ...['-hwaccel_output_format', 'vaapi'],
      ]);
      expect(job.outputArgs.take(4), ['-map', '0:V:0', '-vf', anything]);
      expect(job.outputArgs, containsAllInOrder(['-c:v', 'h264_vaapi']));
      expect(job.outputArgs, containsAllInOrder(['-map', '0:a:0?']));
      expect(
        job.environment['LD_LIBRARY_PATH'],
        startsWith('/app/ffmpeg/libva'),
      );
    });

    test('a file starts where it was asked to; a live channel never seeks', () {
      final file = castRelayJob(
        plan: plan(delivery: CastDelivery.relayContinuous, live: false),
        facts: h264,
        binaries: binaries,
        startAt: const Duration(minutes: 42, seconds: 10, milliseconds: 5),
      );
      expect(file.inputArgs, ['-ss', '2530.005']);
      expect(file.live, isFalse);
      final live = castRelayJob(
        plan: plan(),
        facts: h264,
        binaries: binaries,
        startAt: const Duration(minutes: 1),
      );
      expect(live.inputArgs, isEmpty);
      final start = castRelayJob(
        plan: plan(delivery: CastDelivery.relayContinuous, live: false),
        facts: h264,
        binaries: binaries,
        startAt: Duration.zero,
      );
      expect(start.inputArgs, isEmpty);
    });

    test('a direct plan, or a re-encode without an encoder, is refused', () {
      expect(
        () => castRelayJob(
          plan: plan(delivery: CastDelivery.directHls),
          facts: h264,
          binaries: binaries,
        ),
        throwsArgumentError,
      );
      expect(
        () => castRelayJob(
          plan: plan(
            video: const CastVideoTranscode(
              height: 1080,
              bitRate: 6000000,
              reasons: [TranscodeReason.codecUnsupported],
            ),
          ),
          facts: h264,
          binaries: binaries,
        ),
        throwsArgumentError,
      );
    });
  });
}

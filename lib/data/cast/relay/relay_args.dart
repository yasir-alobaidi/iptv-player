import 'dart:io';

import 'package:iptv_player/core/cast/cast_encoders.dart';
import 'package:iptv_player/core/cast/cast_plan.dart';
import 'package:iptv_player/core/cast/stream_facts.dart';
import 'package:iptv_player/data/cast/ffmpeg_binaries.dart';
import 'package:iptv_player/data/cast/ffmpeg_video_args.dart';
import 'package:iptv_player/data/cast/relay/relay_job.dart';

/// The relay's job for [plan] (docs/04's arguments): which streams it
/// takes, and what happens to each. The relay adds the input (its proxy)
/// and the muxer.
/// - The picture: `0:V:0` (never a cover picture), copied — HEVC tagged
///   `hvc1` in MP4 — or re-encoded with [encoder] (step 4's
///   `videoTranscodeArgs`, its environment with it), or left out.
/// - The sound: the plan's track (`0:a:<n>?`), copied (AAC into MP4
///   without its ADTS headers) or made AAC stereo at 192 kbps, or left
///   out.
/// - A file starts at [startAt] (`-ss` before `-i`: a seek or a resume).
///
/// Throws an [ArgumentError] for a direct plan, or a re-encode without
/// an encoder: the caller checks both.
RelayJob castRelayJob({
  required CastPlan plan,
  required StreamFacts facts,
  required FfmpegBinaries binaries,
  CastEncoder? encoder,
  Duration? startAt,
  bool? windows,
}) {
  final output = switch (plan.delivery) {
    CastDelivery.relayHls => RelayOutput.hls,
    CastDelivery.relayContinuous => RelayOutput.continuous,
    CastDelivery.directHls || CastDelivery.directFile => throw ArgumentError(
      'a direct plan has nothing to relay',
    ),
  };
  final input = <String>[
    if (!plan.live && startAt != null && startAt > Duration.zero) ...[
      '-ss',
      (startAt.inMilliseconds / 1000).toStringAsFixed(3),
    ],
  ];
  final args = <String>[];
  var environment = const <String, String>{};
  switch (plan.video) {
    case CastVideoCopy():
      args.addAll(['-map', '0:V:0', '-c:v', 'copy']);
      if (output == RelayOutput.continuous && facts.video?.codec == 'hevc') {
        args.addAll(['-tag:v', 'hvc1']);
      }
    case final CastVideoTranscode transcode:
      if (encoder == null) throw ArgumentError('a re-encode needs an encoder');
      final video = videoTranscodeArgs(
        plan: transcode,
        encoder: encoder,
        source: facts.video ?? const VideoFacts(),
        libvaEnvironment: binaries.libvaEnvironment(),
        windows: windows ?? Platform.isWindows,
      );
      input.addAll(video.input);
      args
        ..addAll(['-map', '0:V:0'])
        ..addAll(video.output);
      environment = video.environment;
    case CastNoVideo():
      args.add('-vn');
  }
  switch (plan.audio) {
    case CastAudioCopy(:final track):
      args.addAll(['-map', '0:a:$track?', '-c:a', 'copy']);
      // AAC from MPEG-TS has ADTS headers, which MP4 doesn't take; the
      // filter passes AAC that has none as it is.
      final codec = facts.audio.where((a) => a.index == track).firstOrNull;
      if (output == RelayOutput.continuous && codec?.codec == 'aac') {
        args.addAll(['-bsf:a', 'aac_adtstoasc']);
      }
    case CastAudioToAac(:final track):
      args.addAll([
        ...['-map', '0:a:$track?', '-c:a', 'aac'],
        ...['-b:a', '192k', '-ac', '2'],
      ]);
    case CastNoAudio():
      args.add('-an');
  }
  return RelayJob(
    ffmpeg: binaries.ffmpeg,
    output: output,
    live: plan.live,
    inputArgs: input,
    outputArgs: args,
    environment: environment,
    transcode: plan.video is CastVideoTranscode,
  );
}

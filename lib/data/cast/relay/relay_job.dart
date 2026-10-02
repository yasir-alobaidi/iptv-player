// Plain Dart, like everything the relay's isolate runs: the SIGKILL test
// starts the relay in a `dart run` process, which has no Flutter.
import 'package:path/path.dart' as p;

/// What the relay's FFmpeg does for one cast. The app's side builds it
/// from the plan (`castRelayJob`); the relay's isolate carries it out and
/// adds what only it knows: the input (its loopback proxy, Phase 7
/// decision 3) and the output (the session's folder, or the TV's own
/// connection).
final class RelayJob {
  const new({
    required this.ffmpeg,
    required this.output,
    required this.live,
    this.inputArgs = const [],
    this.outputArgs = const [],
    this.environment = const {},
    this.transcode = false,
    this.segmentSeconds = 2,
  });

  /// The bundled FFmpeg.
  final String ffmpeg;
  final RelayOutput output;

  /// A live channel; a file has an end.
  final bool live;

  /// Before `-i`: a re-encode's decoder options, a file's start point.
  final List<String> inputArgs;

  /// After `-i`: the maps and the codecs. The muxer is the relay's.
  final List<String> outputArgs;

  /// Added to the app's: the bundled libva for VA-API (ADR-014 step 4).
  final Map<String, String> environment;

  /// The picture is re-encoded, so an FFmpeg that fails before its first
  /// output most likely failed in the encoder.
  final bool transcode;

  /// HLS's segment length (docs/04: 2 s).
  final int segmentSeconds;

  @override
  String toString() =>
      'RelayJob(${output.name}, ${live ? 'live' : 'file'}'
      '${transcode ? ', transcode' : ''})';
}

enum RelayOutput {
  /// HLS with MPEG-TS segments in the session's folder (H.264).
  hls,

  /// One continuous fragmented MP4 on the TV's connection (HEVC,
  /// Low-latency mode, files).
  continuous,
}

/// The whole command line for [job]: docs/04's input options, [input]
/// (the proxy's URL, never the provider's), the job's own arguments, and
/// the muxer. [folder] is an HLS session's; [append] continues its
/// playlist after a restart, so the TV keeps polling the same one (its
/// numbering carries on, behind an `#EXT-X-DISCONTINUITY`).
List<String> relayArguments(
  RelayJob job, {
  required String input,
  String? folder,
  bool append = false,
}) => [
  ...['-hide_banner', '-nostdin', '-nostats'],
  // Every line with its level: warnings are logged, and the input's
  // description (info) says which streams FFmpeg really opened.
  ...['-loglevel', 'repeat+level+info'],
  // Its one peer is the app's proxy, which retries the provider itself:
  // a refused reconnect means the app is gone, and FFmpeg ends within
  // seconds rather than after docs/04's 5 s steps (16 s, measured).
  ...['-reconnect', '1', '-reconnect_streamed', '1'],
  ...['-reconnect_on_network_error', '1', '-reconnect_delay_max', '1'],
  ...['-fflags', '+genpts+discardcorrupt'],
  // 2 s of the stream, as the probe reads (ADR-014 step 3): every stream
  // of every sample found right, and the first segments a second sooner
  // than FFmpeg's own 5 s.
  ...['-analyzeduration', '2000000', '-probesize', '5000000'],
  ...job.inputArgs,
  ...['-i', input],
  ...job.outputArgs,
  ...['-max_muxing_queue_size', '1024'],
  ...switch (job.output) {
    RelayOutput.hls => [
      ...['-f', 'hls', '-hls_time', '${job.segmentSeconds}'],
      ...['-hls_list_size', '6', '-hls_flags', _hlsFlags(append: append)],
      ...['-hls_segment_type', 'mpegts'],
      ...['-hls_segment_filename', p.join(folder!, 'seg%05d.ts')],
      p.join(folder, hlsPlaylistName),
    ],
    RelayOutput.continuous => [
      ...['-f', 'mp4'],
      ...['-movflags', 'frag_keyframe+empty_moov+default_base_moof'],
      'pipe:1',
    ],
  },
];

String _hlsFlags({required bool append}) => [
  'delete_segments',
  'independent_segments',
  'omit_endlist',
  if (append) 'append_list',
].join('+');

/// The playlist FFmpeg writes in an HLS session's folder.
const hlsPlaylistName = 'index.m3u8';

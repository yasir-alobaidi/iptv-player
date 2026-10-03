import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:fake_receiver/src/fmp4_clock.dart';

/// How the fake plays what a LOAD names, when it plays for real (Phase 7
/// decision 8): it fetches the stream as the TV does and checks it with
/// ffprobe, so a test passes only when the relay sends something a TV
/// can play.
final class FakePlayback {
  const new({
    required this.ffprobe,
    this.giveUp = const Duration(seconds: 20),
    this.endDelay = const Duration(seconds: 1),
    this.refuseDelay = const Duration(seconds: 1),
    this.bufferAhead = const Duration(seconds: 30),
    this.bufferRefill = const Duration(seconds: 10),
  });

  /// Reads each segment, and the start of a continuous stream.
  final String ffprobe;

  /// How long it waits for a playlist with a segment, or a stream's
  /// first bytes; and how long a live playlist may stay unreadable.
  final Duration giveUp;

  /// A continuous stream that ended plays out what the TV holds (about
  /// 4 s on Living Room TV) before IDLE/FINISHED.
  final Duration endDelay;

  /// A picture the device refuses is refused this long after its first
  /// segment (docs/04: a TV on a 1080p HDMI link, about 1 s).
  final Duration refuseDelay;

  /// A continuous stream that is a fragmented MP4 (the relay's) is read
  /// until it holds [bufferAhead] more than has played, then not again
  /// until it holds less than [bufferRefill], as a TV's buffer reads: in
  /// bursts, and not at all while paused. A relayed file, which FFmpeg
  /// copies far faster than it plays, then waits on the TV for tens of
  /// seconds at a time. Null reads as fast as it comes.
  final Duration? bufferAhead;
  final Duration bufferRefill;
}

/// One request the fake made, as the TV makes it.
final class FakeFetch {
  const new(this.path, this.status, {this.range, this.cors = false});

  final String path;

  /// Null when nothing answered.
  final int? status;
  final String? range;

  /// The answer carried `Access-Control-Allow-Origin`.
  final bool cors;

  @override
  String toString() => '$path → ${status ?? 'no answer'}';
}

/// What ffprobe found in a segment, or at a continuous stream's start.
final class FakeMediaCheck {
  const new({
    required this.source,
    this.videoCodec,
    this.height,
    this.audioCodec,
    this.audioChannels,
    this.videoPackets = 0,
    this.audioPackets = 0,
    this.discontinuity = false,
  });

  /// The segment's URI, or `stream`.
  final String source;
  final String? videoCodec;
  final int? height;
  final String? audioCodec;
  final int? audioChannels;

  /// Frames of each read: a stream named in a header with none behind
  /// it plays nothing.
  final int videoPackets;
  final int audioPackets;

  /// The playlist marks a discontinuity before it (a relay restart).
  final bool discontinuity;

  bool get hasVideo => videoCodec != null && videoPackets > 0;

  bool get hasAudio => audioCodec != null && audioPackets > 0;

  @override
  String toString() =>
      '$source: ${videoCodec ?? 'no video'} ${height ?? ''} '
      '($videoPackets) / ${audioCodec ?? 'no audio'} ${audioChannels ?? ''} '
      '($audioPackets)';
}

/// What a [FakeWatch] tells the fake.
abstract interface class FakeWatchListener {
  /// The first segment, or the stream's start, is in: [check] says what
  /// it holds.
  void started(FakeMediaCheck check);

  /// Nothing new for a while (true), or again (false).
  void stalled({required bool stalled});

  /// A continuous stream or a playlist with an end was played out.
  void finished();

  /// How far it has played since it started: what a TV's buffer has
  /// given out. It stands still while paused.
  Duration get played;

  /// It can't play: [reason] for the log.
  void failed(String reason);

  void fetched(FakeFetch fetch);

  void checked(FakeMediaCheck check);
}

/// Fetches one LOAD's stream like the receiver: the HLS playlist polled
/// and every new segment read (with `Origin: https://www.gstatic.com`, so
/// a missing CORS header fails as it would in the TV's browser), or a
/// continuous stream read from its start with `Range: bytes=0-`.
final class FakeWatch {
  new({
    required this.url,
    required this.contentType,
    required this.playback,
    required this.listener,
  });

  final Uri url;
  final String contentType;
  final FakePlayback playback;
  final FakeWatchListener listener;

  final _client = HttpClient()..userAgent = _userAgent;
  var _cancelled = false;
  Directory? _scratch;

  static const _userAgent =
      'Mozilla/5.0 (X11; Linux armv7l) AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/114.0.0.0 Safari/537.36 CrKey/1.56.500000 DeviceType/AndroidTV';

  bool get _hls => contentType.contains('mpegurl');

  void start() => unawaited(_run());

  void cancel() {
    _cancelled = true;
    _client.close(force: true);
    // A test that closes the fake may end before this watch does: its
    // files go now, not when it gets to its end.
    try {
      _scratch?.deleteSync(recursive: true);
    } on FileSystemException {
      // Gone already.
    }
  }

  Future<void> _run() async {
    try {
      _scratch = await Directory.systemTemp.createTemp('fake_receiver');
      if (_hls) {
        await _watchHls();
      } else {
        await _watchStream();
      }
    } on Object catch (error) {
      if (!_cancelled) listener.failed('$error');
    } finally {
      _client.close(force: true);
      try {
        await _scratch?.delete(recursive: true);
      } on FileSystemException {
        // Gone already.
      }
    }
  }

  Future<void> _watchHls() async {
    int? next;
    var started = false;
    var stalled = false;
    var lastNew = DateTime.now();
    var lastRead = DateTime.now();
    int? lastSequence;
    while (!_cancelled) {
      final playlist = await _text(url);
      final now = DateTime.now();
      if (playlist == null) {
        if (now.difference(lastRead) > playback.giveUp) {
          return listener.failed('the playlist went unreadable');
        }
        await _pause(const Duration(milliseconds: 500));
        continue;
      }
      lastRead = now;
      final media = _MediaPlaylist.parse(playlist);
      if (lastSequence != null && media.sequence < lastSequence) {
        return listener.failed(
          'the playlist went back: sequence ${media.sequence} after '
          '$lastSequence',
        );
      }
      lastSequence = media.sequence;
      // The TV starts near the live edge: the last three segments.
      next ??= media.sequence + max(0, media.segments.length - 3);
      var any = false;
      for (final (i, segment) in media.segments.indexed) {
        final number = media.sequence + i;
        if (number < next! || _cancelled) continue;
        next = number + 1;
        any = true;
        final check = await _checkSegment(
          url.resolve(segment.uri),
          segment.uri,
          discontinuity: segment.discontinuity,
        );
        if (check == null) continue;
        listener.checked(check);
        if (!started) {
          started = true;
          listener.started(check);
        }
      }
      if (!started && now.difference(lastNew) > playback.giveUp) {
        return listener.failed('no segment in the playlist');
      }
      if (any) {
        lastNew = DateTime.now();
        if (stalled) listener.stalled(stalled: stalled = false);
      } else if (started &&
          !stalled &&
          DateTime.now().difference(lastNew) > media.target * 3) {
        listener.stalled(stalled: stalled = true);
      }
      if (media.ended && started) {
        await _pause(playback.endDelay);
        if (!_cancelled) listener.finished();
        return;
      }
      await _pause(
        Duration(milliseconds: max(500, media.target.inMilliseconds ~/ 2)),
      );
    }
  }

  Future<void> _watchStream() async {
    final request = await _client.getUrl(url);
    request.headers
      ..set('Origin', 'https://www.gstatic.com')
      ..set(HttpHeaders.rangeHeader, 'bytes=0-');
    final response = await request.close().timeout(playback.giveUp);
    final cors = response.headers.value('access-control-allow-origin') != null;
    listener.fetched(
      FakeFetch(url.path, response.statusCode, range: 'bytes=0-', cors: cors),
    );
    if (response.statusCode != 200 && response.statusCode != 206) {
      await response.drain<void>().catchError((Object _) {});
      return listener.failed('HTTP ${response.statusCode}');
    }
    if (!cors) return listener.failed('no CORS header');
    final head = File('${_scratch!.path}/stream.mp4');
    final sink = head.openWrite();
    final clock = Fmp4Clock();
    var bytes = 0;
    var started = false;
    var full = false;
    final done = Completer<void>();
    late StreamSubscription<List<int>> body;

    /// What it holds and hasn't played yet; null when it can't tell.
    Duration? held() => switch (clock.media) {
      final media? when started => media - listener.played,
      _ => null,
    };

    // The buffer, filled in bursts (FakePlayback.bufferAhead).
    final ahead = playback.bufferAhead;
    final refill = ahead == null
        ? null
        : Timer.periodic(const Duration(milliseconds: 100), (_) {
            final holds = held();
            if (full && (holds == null || holds < playback.bufferRefill)) {
              full = false;
              body.resume();
            }
          });
    body = response.listen(
      (chunk) {
        bytes += chunk.length;
        clock.add(chunk);
        if (!started && bytes <= 4 << 20) sink.add(chunk);
        if (!started && bytes >= 256 << 10) {
          started = true;
          body.pause();
          unawaited(
            _startStream(sink, head).whenComplete(() {
              if (!_cancelled) body.resume();
            }),
          );
        }
        final holds = held();
        if (ahead != null && !full && holds != null && holds >= ahead) {
          full = true;
          body.pause();
        }
      },
      onDone: () => done.isCompleted ? null : done.complete(),
      onError: (Object _) => done.isCompleted ? null : done.complete(),
      cancelOnError: true,
    );
    await done.future;
    refill?.cancel();
    await body.cancel();
    if (_cancelled) return;
    if (!started) {
      if (bytes == 0) return listener.failed('the stream had no bytes');
      started = true;
      await _startStream(sink, head);
    }
    // The TV plays out what it holds, then says FINISHED.
    while (!_cancelled && (held() ?? Duration.zero) > Duration.zero) {
      await _pause(const Duration(milliseconds: 100));
    }
    await _pause(playback.endDelay);
    if (!_cancelled) listener.finished();
  }

  Future<void> _startStream(IOSink sink, File head) async {
    await sink.flush();
    await sink.close();
    final check = await _probe(head, 'stream');
    if (_cancelled) return;
    listener
      ..checked(check)
      ..started(check);
  }

  Future<FakeMediaCheck?> _checkSegment(
    Uri uri,
    String name, {
    required bool discontinuity,
  }) async {
    final bytes = await _bytes(uri);
    if (bytes == null || _cancelled) return null;
    final file = File('${_scratch!.path}/segment.ts');
    await file.writeAsBytes(bytes, flush: true);
    final check = await _probe(file, name);
    return FakeMediaCheck(
      source: name,
      videoCodec: check.videoCodec,
      height: check.height,
      audioCodec: check.audioCodec,
      audioChannels: check.audioChannels,
      videoPackets: check.videoPackets,
      audioPackets: check.audioPackets,
      discontinuity: discontinuity,
    );
  }

  Future<FakeMediaCheck> _probe(File file, String name) async {
    final result = await Process.run(playback.ffprobe, [
      ...['-v', 'error', '-of', 'json', '-count_packets'],
      ...[
        '-show_entries',
        'stream=codec_type,codec_name,height,channels,nb_read_packets',
      ],
      file.path,
    ]);
    String? videoCodec;
    int? height;
    String? audioCodec;
    int? channels;
    var videoPackets = 0;
    var audioPackets = 0;
    int packets(Map<Object?, Object?> stream) =>
        int.tryParse('${stream['nb_read_packets']}') ?? 0;
    try {
      final streams = (jsonDecode('${result.stdout}') as Map)['streams'];
      for (final stream in streams is List ? streams : const []) {
        if (stream is! Map) continue;
        switch (stream['codec_type']) {
          case 'video' when videoCodec == null:
            videoCodec = '${stream['codec_name']}';
            height = stream['height'] is int ? stream['height'] as int : null;
            videoPackets = packets(stream);
          case 'audio' when audioCodec == null:
            audioCodec = '${stream['codec_name']}';
            channels = stream['channels'] is int
                ? stream['channels'] as int
                : null;
            audioPackets = packets(stream);
        }
      }
    } on Object {
      // Nothing readable: no streams.
    }
    return FakeMediaCheck(
      source: name,
      videoCodec: videoCodec,
      height: height,
      audioCodec: audioCodec,
      audioChannels: channels,
      videoPackets: videoPackets,
      audioPackets: audioPackets,
    );
  }

  Future<String?> _text(Uri uri) async {
    final bytes = await _bytes(uri);
    return bytes == null ? null : utf8.decode(bytes, allowMalformed: true);
  }

  Future<Uint8List?> _bytes(Uri uri) async {
    if (_cancelled) return null;
    try {
      final request = await _client.getUrl(uri);
      request.headers.set('Origin', 'https://www.gstatic.com');
      final response = await request.close().timeout(
        const Duration(seconds: 10),
      );
      final cors =
          response.headers.value('access-control-allow-origin') != null;
      listener.fetched(FakeFetch(uri.path, response.statusCode, cors: cors));
      final builder = BytesBuilder(copy: false);
      await response.forEach(builder.add).timeout(const Duration(seconds: 20));
      // The TV's browser drops an answer without CORS, whatever it holds.
      if (response.statusCode != 200 || !cors) return null;
      return builder.takeBytes();
    } on Object {
      if (!_cancelled) listener.fetched(FakeFetch(uri.path, null));
      return null;
    }
  }

  Future<void> _pause(Duration duration) async {
    if (!_cancelled) await Future<void>.delayed(duration);
  }
}

final class _Segment {
  const new(this.uri, {required this.discontinuity});

  final String uri;
  final bool discontinuity;
}

final class _MediaPlaylist {
  const new(this.sequence, this.segments, this.target, {required this.ended});

  /// Tolerant: FFmpeg 4.4 writes `#EXT-X-PROGRAM-DATE-TIME` between a
  /// segment's `#EXTINF` and its URI after a restart.
  factory parse(String text) {
    var sequence = 0;
    var target = const Duration(seconds: 2);
    var ended = false;
    var discontinuity = false;
    var inSegment = false;
    final segments = <_Segment>[];
    for (final raw in const LineSplitter().convert(text)) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      if (line.startsWith('#EXT-X-MEDIA-SEQUENCE:')) {
        sequence = int.tryParse(line.substring(22)) ?? 0;
      } else if (line.startsWith('#EXT-X-TARGETDURATION:')) {
        final seconds = int.tryParse(line.substring(22)) ?? 2;
        target = Duration(seconds: max(1, seconds));
      } else if (line == '#EXT-X-DISCONTINUITY') {
        discontinuity = true;
      } else if (line == '#EXT-X-ENDLIST') {
        ended = true;
      } else if (line.startsWith('#EXTINF')) {
        inSegment = true;
      } else if (!line.startsWith('#') && inSegment) {
        segments.add(_Segment(line, discontinuity: discontinuity));
        discontinuity = false;
        inSegment = false;
      }
    }
    return _MediaPlaylist(sequence, segments, target, ended: ended);
  }

  final int sequence;
  final List<_Segment> segments;
  final Duration target;
  final bool ended;
}

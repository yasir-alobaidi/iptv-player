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

  /// Where in the media it is: where it started, what it has played
  /// since, and where a SEEK put it.
  Duration get position;

  /// It can't play: [reason] for the log.
  void failed(String reason);

  void fetched(FakeFetch fetch);

  void checked(FakeMediaCheck check);
}

/// Fetches one LOAD's stream like the receiver: the HLS playlist polled
/// and every new segment read (with `Origin: https://www.gstatic.com`, so
/// a missing CORS header fails as it would in the TV's browser), or a
/// continuous stream read from its start with `Range: bytes=0-`. A file
/// with a length (a direct play) is read as it plays, and a SEEK in it is
/// a new request with `Range` at the byte that time is at.
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

  /// Where a SEEK asked to go, until the file's reader has gone there.
  Duration? _seekTo;

  void start() => unawaited(_run());

  /// The sender's SEEK. In a file with a length the TV asks for the bytes
  /// at that time; any other stream has only what it is sent.
  // A command, as the receiver's other ones are: not a property of it.
  // ignore: use_setters_to_change_properties
  void seek(Duration to) => _seekTo = to;

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
    if (_fileSize(response) case final size?) {
      return await _watchFile(response, size);
    }
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

  /// The whole length of a file that was answered with one: the total in
  /// `Content-Range`, else `Content-Length` of an answer that takes
  /// ranges. Null for a stream with no end in sight (the relay's).
  static int? _fileSize(HttpClientResponse response) {
    final range = response.headers.value(HttpHeaders.contentRangeHeader);
    final total = range == null
        ? null
        : int.tryParse(range.split('/').last.trim());
    if (total != null && total > 0) return total;
    final ranges = response.headers.value(HttpHeaders.acceptRangesHeader);
    return ranges == 'bytes' && response.contentLength > 0
        ? response.contentLength
        : null;
  }

  /// What a player needs of a file's start: its index, when that is at
  /// the front.
  static const int _headBytes = 4 << 20;

  /// A file with a length (a direct play, docs/04 "Direct file"), read as
  /// a TV reads one. Its head is probed for what it holds and how long it
  /// is. Then it is read in bursts, [FakePlayback.bufferAhead] past where
  /// it plays, and not at all while paused. A SEEK, or a start past 0:00,
  /// is a new request with `Range` at the byte that time is at (Phase 0
  /// saw the TV do so). FINISHED comes once it has played to its end.
  Future<void> _watchFile(HttpClientResponse first, int size) async {
    final head = File('${_scratch!.path}/stream.mp4');
    IOSink? sink = head.openWrite();
    var offset = 0;
    var wanted = min(size, _headBytes);
    var ended = false;
    var holding = false;
    StreamSubscription<List<int>>? body;

    void read(HttpClientResponse response, int from) {
      offset = from;
      ended = false;
      holding = false;
      // Cancelled as `body`, by the next request or at the end.
      // ignore: cancel_subscriptions
      late final StreamSubscription<List<int>> reading;
      reading = body = response.listen(
        (chunk) {
          sink?.add(chunk);
          offset += chunk.length;
          if (offset >= wanted && !holding) {
            holding = true;
            reading.pause();
          }
        },
        onDone: () => ended = true,
        onError: (Object _) => ended = true,
        cancelOnError: true,
      );
    }

    read(first, 0);
    while (!_cancelled && !ended && offset < wanted) {
      await _pause(const Duration(milliseconds: 20));
    }
    if (_cancelled) return;
    final started = sink;
    sink = null;
    await _startStream(started, head);
    final length = await _length(head);
    if (_cancelled) return;

    if (length == null || length <= Duration.zero) {
      // Its index isn't at the front: read to its end, as before.
      wanted = size;
      if (holding) body?.resume();
      while (!_cancelled && !ended) {
        await _pause(const Duration(milliseconds: 50));
      }
      await _pause(playback.endDelay);
      if (!_cancelled) listener.finished();
      return;
    }

    int byteOf(Duration at) => max(
      0,
      min(size - 1, (size * at.inMicroseconds / length.inMicroseconds).floor()),
    );
    // A LOAD that starts past 0:00 jumps there once the index is read.
    if (listener.position > const Duration(seconds: 1)) {
      _seekTo ??= listener.position;
    }
    final ahead = playback.bufferAhead;
    while (!_cancelled) {
      final to = _seekTo;
      _seekTo = null;
      if (to != null) {
        await body?.cancel();
        final from = byteOf(to);
        final request = await _client.getUrl(url);
        request.headers
          ..set('Origin', 'https://www.gstatic.com')
          ..set(HttpHeaders.rangeHeader, 'bytes=$from-');
        final response = await request.close().timeout(playback.giveUp);
        final cors =
            response.headers.value('access-control-allow-origin') != null;
        listener.fetched(
          FakeFetch(
            url.path,
            response.statusCode,
            range: 'bytes=$from-',
            cors: cors,
          ),
        );
        if (response.statusCode != HttpStatus.partialContent) {
          await response.drain<void>().catchError((Object _) {});
          return listener.failed(
            'HTTP ${response.statusCode} to a Range request',
          );
        }
        wanted = from;
        read(response, from);
      }
      final at = listener.position;
      if (at + const Duration(milliseconds: 200) >= length) break;
      wanted = ahead == null ? size : min(size, byteOf(at + ahead) + 1);
      if (holding && offset < wanted) {
        holding = false;
        body?.resume();
      }
      if (ended && offset < size && offset < wanted) {
        return listener.failed('the file ended at $offset of $size bytes');
      }
      await _pause(const Duration(milliseconds: 100));
    }
    await body?.cancel();
    if (_cancelled) return;
    await _pause(playback.endDelay);
    if (!_cancelled) listener.finished();
  }

  /// How long ffprobe says [file] is, when its index is in what was read.
  Future<Duration?> _length(File file) async {
    final result = await Process.run(playback.ffprobe, [
      ...['-v', 'error', '-show_entries', 'format=duration'],
      ...['-of', 'default=nw=1:nk=1', file.path],
    ]);
    final seconds = double.tryParse('${result.stdout}'.trim());
    return seconds == null || !seconds.isFinite || seconds <= 0
        ? null
        : Duration(microseconds: (seconds * 1e6).round());
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

// FNV-1a's 64-bit constants: this code only ever runs on the Dart VM,
// where an int is 64 bits.
// ignore_for_file: avoid_js_rounded_ints

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:iptv_player/data/providers/provider_http.dart';

/// Why a picture didn't come. It never names the URL (hard rule 3: a
/// panel's artwork URL can carry a token), and nothing shows it: the
/// stand-in stays.
final class ArtworkUnavailable implements Exception {
  const new(this.reason);

  final String reason;

  @override
  String toString() => 'ArtworkUnavailable: $reason';
}

/// The app's own picture cache (Phase 5 decision 6): files in [directory]
/// named by a hash of the URL, fetched at most [concurrency] at a time —
/// the newest request first, and the oldest waiting ones dropped past
/// [maxWaiting], which are posters the grid scrolled away from before
/// their turn — and kept under [maxBytes] by [sweep], least recently used
/// first. A failed URL isn't asked for again for [retryFailedAfter].
final class ArtworkCache {
  new({
    required this.directory,
    this.userAgent = defaultUserAgent,
    this.maxBytes = 500 * 1024 * 1024,
    this.concurrency = 6,
    this.maxWaiting = 96,
    this.maxFileBytes = 10 * 1024 * 1024,
    this.retryFailedAfter = const Duration(minutes: 10),
    this.sweepAfterWriting = 50 * 1024 * 1024,
    this.timeout = const Duration(seconds: 30),
    HttpClient? client,
    DateTime Function()? clock,
  }) : _http = client ?? _client(userAgent),
       _clock = clock ?? DateTime.now;

  final Directory directory;
  final String userAgent;
  final int maxBytes;
  final int concurrency;
  final int maxWaiting;

  /// Bigger answers are no poster: they are refused rather than kept.
  final int maxFileBytes;
  final Duration retryFailedAfter;

  /// A sweep runs after this much has been written since the last one.
  final int sweepAfterWriting;

  /// For the whole answer, as a watchdog on silence.
  final Duration timeout;

  final HttpClient _http;
  final DateTime Function() _clock;

  final _inFlight = <String, Future<Uint8List>>{};
  final _failed = <String, DateTime>{};

  /// Newest last: the next to start is taken from the end.
  final _waiting = <_Job>[];
  var _running = 0;
  var _writtenSinceSweep = 0;
  Future<int>? _sweeping;

  /// The folder's size as the last sweep left it, plus what was written
  /// since; unknown until a sweep ran.
  int? _knownBytes;

  static HttpClient _client(String userAgent) => HttpClient()
    ..userAgent = userAgent
    ..connectionTimeout = const Duration(seconds: 15)
    ..idleTimeout = const Duration(seconds: 15);

  /// [url]'s bytes, from disk or the network. Throws [ArtworkUnavailable].
  Future<Uint8List> bytes(String url) {
    final failedAt = _failed[url];
    if (failedAt != null && _clock().difference(failedAt) < retryFailedAfter) {
      return Future.error(const ArtworkUnavailable('failed a moment ago'));
    }
    // Not `remove`: it returns this future, which would wait for itself.
    return _inFlight[url] ??= _bytes(url)
        .whenComplete(() => _inFlight.removeWhere((k, _) => k == url));
  }

  /// Where [url] is kept.
  File fileFor(String url) =>
      File('${directory.path}${Platform.pathSeparator}${artworkName(url)}');

  /// Drops [url]'s file, say one that no longer decodes: the next ask
  /// fetches it again.
  Future<void> forget(String url) async {
    try {
      await fileFor(url).delete();
    } on FileSystemException {
      // Already gone.
    }
  }

  /// Deletes the least recently used files until the folder is under
  /// [maxBytes] (to 90 % of it, so the next picture doesn't start another
  /// sweep), and `.part` files a killed download left behind. Runs in an
  /// isolate; one at a time. Completes with how many files went.
  Future<int> sweep() => _sweeping ??= _sweep();

  Future<int> _sweep() async {
    _writtenSinceSweep = 0;
    try {
      final swept = await _sweepInIsolate(
        directory.path,
        maxBytes,
        _clock().millisecondsSinceEpoch,
      );
      _knownBytes = swept.bytes + _writtenSinceSweep;
      return swept.removed;
    } finally {
      _sweeping = null;
    }
  }

  void close() {
    _http.close(force: true);
    for (final job in _waiting) {
      job.done.completeError(const ArtworkUnavailable('closed'));
    }
    _waiting.clear();
  }

  Future<Uint8List> _bytes(String url) async {
    final file = fileFor(url);
    try {
      final bytes = await file.readAsBytes();
      // The sweep reads a file's age as its last use.
      unawaited(file.setLastModified(_clock()).then((_) {}, onError: (_) {}));
      return bytes;
    } on FileSystemException {
      // Not cached yet.
    }
    final job = _Job(url);
    _waiting.add(job);
    while (_waiting.length > maxWaiting) {
      _waiting
          .removeAt(0)
          .done
          .completeError(const ArtworkUnavailable('dropped: never reached'));
    }
    _pump();
    return await job.done.future;
  }

  void _pump() {
    while (_running < concurrency && _waiting.isNotEmpty) {
      unawaited(_run(_waiting.removeLast()));
    }
  }

  Future<void> _run(_Job job) async {
    _running++;
    try {
      final bytes = await _download(job.url).timeout(
        timeout,
        onTimeout: () => throw const ArtworkUnavailable('timed out'),
      );
      await _store(job.url, bytes);
      job.done.complete(bytes);
    } on Object catch (error) {
      _failed[job.url] = _clock();
      job.done.completeError(
        error is ArtworkUnavailable
            ? error
            // Never the error itself: dart:io's can quote the URL.
            : ArtworkUnavailable(error.runtimeType.toString()),
      );
    } finally {
      _running--;
      _pump();
    }
  }

  Future<Uint8List> _download(String url) async {
    final request = await _http.getUrl(Uri.parse(url));
    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) {
      await response.drain<void>().then((_) {}, onError: (_) {});
      throw ArtworkUnavailable('HTTP ${response.statusCode}');
    }
    final length = response.contentLength;
    if (length > maxFileBytes) {
      await response.drain<void>().then((_) {}, onError: (_) {});
      throw const ArtworkUnavailable('too big');
    }
    final builder = BytesBuilder(copy: false);
    await for (final chunk in response) {
      builder.add(chunk);
      if (builder.length > maxFileBytes) {
        throw const ArtworkUnavailable('too big');
      }
    }
    final bytes = builder.takeBytes();
    if (!looksLikeImage(bytes)) {
      // A panel's "404" page served with a 200, say.
      throw const ArtworkUnavailable('not a picture');
    }
    return bytes;
  }

  /// Written as `.part` and renamed once whole, so a file under its final
  /// name is always complete (hard rule 11's rule, applied here too).
  Future<void> _store(String url, Uint8List bytes) async {
    try {
      await directory.create(recursive: true);
      final file = fileFor(url);
      final part = File('${file.path}.part');
      await part.writeAsBytes(bytes, flush: true);
      await part.rename(file.path);
    } on FileSystemException {
      // A full or read-only disk: the picture still shows, uncached.
      return;
    }
    _writtenSinceSweep += bytes.length;
    final known = _knownBytes == null ? null : _knownBytes! + bytes.length;
    _knownBytes = known;
    // Past the cap by what the last sweep left, or, before any sweep ran,
    // after every [sweepAfterWriting].
    if ((known != null && known > maxBytes) ||
        _writtenSinceSweep >= sweepAfterWriting) {
      unawaited(sweep());
    }
  }
}

final class _Job {
  new(this.url);

  final String url;
  final done = Completer<Uint8List>();
}

/// The file name for [url]: two 64-bit FNV-1a hashes of its bytes, as 32
/// hex digits — no new dependency, and a clash between two URLs a cache
/// ever holds is out of reach.
String artworkName(String url) {
  final bytes = utf8.encode(url);
  String hash(int basis) {
    var h = basis;
    for (final b in bytes) {
      h ^= b;
      h *= 0x100000001b3;
    }
    // Two unsigned halves: a VM int is signed, and its hex would be too.
    return (h >>> 32).toRadixString(16).padLeft(8, '0') +
        (h & 0xffffffff).toRadixString(16).padLeft(8, '0');
  }

  // FNV's own offset basis, and the same one with its halves swapped.
  return hash(0xcbf29ce484222325) + hash(0x84222325cbf29ce4);
}

/// JPEG, PNG, GIF, WebP or BMP, by their first bytes.
bool looksLikeImage(Uint8List bytes) {
  bool starts(List<int> magic, [int at = 0]) {
    if (bytes.length < at + magic.length) return false;
    for (var i = 0; i < magic.length; i++) {
      if (bytes[at + i] != magic[i]) return false;
    }
    return true;
  }

  return starts(const [0xFF, 0xD8, 0xFF]) ||
      starts(const [0x89, 0x50, 0x4E, 0x47]) ||
      starts(const [0x47, 0x49, 0x46, 0x38]) ||
      (starts(const [0x52, 0x49, 0x46, 0x46]) &&
          starts(const [0x57, 0x45, 0x42, 0x50], 8)) ||
      starts(const [0x42, 0x4D]);
}

/// Built here, at the top level, so the closure sent to the isolate
/// carries these three values and nothing of its caller.
Future<ArtworkSweep> _sweepInIsolate(String path, int maxBytes, int nowMs) =>
    Isolate.run(() => sweepArtwork(path, maxBytes, nowMs));

/// What a sweep did: the files it deleted, and the bytes left.
typedef ArtworkSweep = ({int removed, int bytes});

/// [ArtworkCache.sweep]'s work, synchronous, for the isolate.
ArtworkSweep sweepArtwork(String path, int maxBytes, int nowMs) {
  final directory = Directory(path);
  if (!directory.existsSync()) return (removed: 0, bytes: 0);
  final files = <(File, int, int)>[];
  var total = 0;
  var removed = 0;
  for (final entity in directory.listSync(followLinks: false)) {
    if (entity is! File) continue;
    final FileStat stat;
    try {
      stat = entity.statSync();
    } on FileSystemException {
      continue;
    }
    final age = nowMs - stat.modified.millisecondsSinceEpoch;
    if (entity.path.endsWith('.part')) {
      // Being written right now, unless a killed download left it.
      if (age > const Duration(minutes: 10).inMilliseconds) {
        removed += _delete(entity);
      }
      continue;
    }
    files.add((entity, stat.size, stat.modified.millisecondsSinceEpoch));
    total += stat.size;
  }
  if (total <= maxBytes) return (removed: removed, bytes: total);
  files.sort((a, b) => a.$3.compareTo(b.$3));
  final target = maxBytes * 9 ~/ 10;
  for (final (file, size, _) in files) {
    if (total <= target) break;
    final gone = _delete(file);
    total -= gone * size;
    removed += gone;
  }
  return (removed: removed, bytes: total);
}

int _delete(File file) {
  try {
    file.deleteSync();
    return 1;
  } on FileSystemException {
    return 0;
  }
}

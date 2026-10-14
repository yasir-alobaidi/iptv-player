// Plain Dart, like everything the relay's isolate runs.
import 'dart:typed_data';

/// The relay's continuous stream of a file, on the file's own clock
/// (docs/04 "The TV's own bar").
///
/// FFmpeg's fragmented MP4 says nothing of the file's length (its `moov`
/// goes out before any picture: `empty_moov`), and counts from 0 wherever
/// it started. A TV then shows as the length what it has read so far,
/// growing as it plays, and 0:00 after every seek or resume. This writes
/// [length] into the header (`mvhd`, each `tkhd` and `mdhd`, and an
/// `mehd`) and counts every fragment (`tfdt`) from [start], where the
/// stream begins in the file: the TV's time and length are the film's.
/// The index FFmpeg writes at the end (`mfra`), which would still count
/// from 0, is left out; a TV reading a stream never seeks with it.
///
/// Fed FFmpeg's output in chunks of any size. `moov` and each `moof`
/// (a few hundred bytes) are held until whole; the pictures and the sound
/// (`mdat`) go on as they come, and a chunk wholly inside them, as most
/// are, is passed on as it is rather than copied.
final class Fmp4Timeline {
  new({required this.start, this.length});

  final Duration start;

  /// Null leaves the header's length as FFmpeg wrote it.
  final Duration? length;

  final _head = BytesBuilder();
  _Mode _mode = _Mode.header;
  int _left = 0;
  String _type = '';
  BytesBuilder? _held;

  /// Each track's timescale, from `moov`.
  final _timescales = <int, int>{};

  /// The movie's timescale, from `mvhd`.
  int _movieScale = 0;

  /// Bytes added to `moov` (its `mehd`): an absolute data offset after it
  /// moves by as much.
  int _added = 0;

  /// What to send on for [chunk]: nothing while a box is held, more than
  /// [chunk] when one is finished.
  List<int> add(List<int> chunk) {
    if (_mode == _Mode.through) return chunk;
    final out = BytesBuilder(copy: false);
    var at = 0;
    while (at < chunk.length) {
      switch (_mode) {
        case _Mode.header:
          at = _readHeader(chunk, at, out);
        case _Mode.pass || _Mode.skip:
          final take = _take(chunk, at);
          if (_mode == _Mode.pass) out.add(_view(chunk, at, take));
          at += take;
          _left -= take;
          if (_left == 0) _mode = _Mode.header;
        case _Mode.hold:
          final take = _take(chunk, at);
          _held!.add(_view(chunk, at, take));
          at += take;
          _left -= take;
          if (_left == 0) {
            out.add(_rewrite(_type, _held!.takeBytes()));
            _held = null;
            _mode = _Mode.header;
          }
        case _Mode.through:
          out.add(_view(chunk, at, chunk.length - at));
          at = chunk.length;
      }
    }
    return out.takeBytes();
  }

  /// What is still held when FFmpeg's output ends: a box it never
  /// finished, sent on as it is.
  List<int> close() {
    final out = BytesBuilder(copy: false)
      ..add(_head.takeBytes())
      ..add(_held?.takeBytes() ?? const []);
    _held = null;
    _mode = _Mode.through;
    return out.takeBytes();
  }

  int _take(List<int> chunk, int at) =>
      _left < chunk.length - at ? _left : chunk.length - at;

  /// A box's 8 bytes (16 with a 64-bit size), across chunks if need be;
  /// then what happens to the box.
  int _readHeader(List<int> chunk, int at, BytesBuilder out) {
    var i = at;
    while (i < chunk.length) {
      _head.addByte(chunk[i++]);
      final read = _head.length;
      if (read < 8) continue;
      final head = _head.toBytes();
      final data = ByteData.sublistView(head);
      final size = data.getUint32(0);
      if (size == 1 && read < 16) continue;
      _head.clear();
      _type = String.fromCharCodes(head.sublist(4, 8));
      final whole = size == 1 ? data.getUint64(8) : size;
      if (size == 0 || whole < read) {
        // To the end of the stream, or not an MP4 as expected: the rest
        // goes on untouched.
        out.add(head);
        _mode = _Mode.through;
        return i;
      }
      _left = whole - read;
      if (_type == 'moov' || _type == 'moof') {
        _held = BytesBuilder()..add(head);
        _mode = _Mode.hold;
      } else {
        _mode = _type == 'mfra' ? _Mode.skip : _Mode.pass;
        if (_mode == _Mode.pass) out.add(head);
      }
      if (_left == 0) {
        if (_mode == _Mode.hold) {
          out.add(_rewrite(_type, _held!.takeBytes()));
          _held = null;
        }
        _mode = _Mode.header;
      }
      return i;
    }
    return i;
  }

  Uint8List _rewrite(String type, Uint8List box) =>
      type == 'moov' ? _movie(box) : _fragment(box);

  Uint8List _movie(Uint8List moov) {
    final data = ByteData.sublistView(moov);
    final length = this.length;
    _Box? mvex;
    for (final child in _children(data, _Box.whole(data))) {
      switch (child.type) {
        case 'mvhd' when child.holds(data, v0: 20, v1: 32):
          final v1 = child.v1(data);
          _movieScale = data.getUint32(child.body + (v1 ? 20 : 12));
          if (length != null) {
            final at = child.body + (v1 ? 24 : 16);
            _setTime(data, at, v1, length, _movieScale);
          }
        case 'trak':
          _track(data, child, length);
        case 'mvex':
          mvex = child;
      }
    }
    if (length == null || mvex == null || _movieScale <= 0) return moov;
    for (final child in _children(data, mvex)) {
      if (child.type != 'mehd') continue;
      if (child.holds(data, v0: 8, v1: 12)) {
        _setTime(data, child.body + 4, child.v1(data), length, _movieScale);
      }
      return moov;
    }
    // None: one goes first in `mvex`, and both sizes grow by it.
    final mehd = ByteData(20)
      ..setUint32(0, 20)
      ..setUint32(4, 0x6d656864) // 'mehd'
      ..setUint32(8, 0x01000000) // version 1, no flags
      ..setUint64(12, _ticks(length, _movieScale));
    final at = mvex.body;
    final grown = Uint8List(moov.length + 20)
      ..setRange(0, at, moov)
      ..setRange(at, at + 20, mehd.buffer.asUint8List())
      ..setRange(at + 20, moov.length + 20, moov, at);
    final sizes = ByteData.sublistView(grown);
    _grow(sizes, 0);
    _grow(sizes, mvex.start);
    _added += 20;
    return grown;
  }

  void _track(ByteData data, _Box trak, Duration? length) {
    int? id;
    for (final child in _children(data, trak)) {
      if (child.type == 'tkhd' && child.holds(data, v0: 24, v1: 36)) {
        final v1 = child.v1(data);
        id = data.getUint32(child.body + (v1 ? 20 : 12));
        if (length != null && _movieScale > 0) {
          _setTime(data, child.body + (v1 ? 28 : 20), v1, length, _movieScale);
        }
      }
      if (child.type != 'mdia') continue;
      for (final media in _children(data, child)) {
        if (media.type != 'mdhd' || !media.holds(data, v0: 20, v1: 32)) {
          continue;
        }
        final v1 = media.v1(data);
        final scale = data.getUint32(media.body + (v1 ? 20 : 12));
        if (id != null) _timescales[id] = scale;
        if (length != null) {
          _setTime(data, media.body + (v1 ? 24 : 16), v1, length, scale);
        }
      }
    }
  }

  Uint8List _fragment(Uint8List moof) {
    final data = ByteData.sublistView(moof);
    for (final traf in _children(data, _Box.whole(data))) {
      if (traf.type != 'traf') continue;
      int? scale;
      for (final child in _children(data, traf)) {
        if (child.type == 'tfhd' && child.holds(data, v0: 8, v1: 8)) {
          scale = _timescales[data.getUint32(child.body + 4)];
          // base-data-offset-present: an offset from the stream's first
          // byte, which `mehd` moved.
          final based = data.getUint32(child.body) & 1 != 0;
          if (based && _added > 0 && child.holds(data, v0: 16, v1: 16)) {
            final at = child.body + 8;
            data.setUint64(at, data.getUint64(at) + _added);
          }
        }
        if (child.type != 'tfdt' || !child.holds(data, v0: 8, v1: 12)) {
          continue;
        }
        if (scale == null || scale <= 0) continue;
        final shift = _ticks(start, scale);
        if (shift == 0) continue;
        final at = child.body + 4;
        if (child.v1(data)) {
          data.setUint64(at, data.getUint64(at) + shift);
        } else {
          final moved = data.getUint32(at) + shift;
          if (moved <= 0xFFFFFFFF) data.setUint32(at, moved);
        }
      }
    }
    return moof;
  }

  static void _setTime(
    ByteData data,
    int at,
    bool v1,
    Duration length,
    int scale,
  ) {
    final ticks = _ticks(length, scale);
    if (v1) {
      data.setUint64(at, ticks);
    } else {
      data.setUint32(at, ticks > 0xFFFFFFFF ? 0xFFFFFFFF : ticks);
    }
  }

  static int _ticks(Duration time, int scale) =>
      (time.inMicroseconds * scale + 500000) ~/ 1000000;

  static void _grow(ByteData data, int at) {
    final size = data.getUint32(at);
    if (size == 1) {
      data.setUint64(at + 8, data.getUint64(at + 8) + 20);
    } else {
      data.setUint32(at, size + 20);
    }
  }

  /// [parent]'s child boxes, each where its header and its body start.
  static Iterable<_Box> _children(ByteData data, _Box parent) sync* {
    var at = parent.body;
    while (at + 8 <= parent.end) {
      final size = data.getUint32(at);
      final header = size == 1 ? 16 : 8;
      final whole = size == 1 ? data.getUint64(at + 8) : size;
      if (whole < header || at + whole > parent.end) return;
      yield _Box(
        type: String.fromCharCodes([
          for (var i = 4; i < 8; i++) data.getUint8(at + i),
        ]),
        start: at,
        body: at + header,
        end: at + whole,
      );
      at += whole;
    }
  }

  static Uint8List _view(List<int> chunk, int at, int length) =>
      chunk is Uint8List
      ? Uint8List.sublistView(chunk, at, at + length)
      : Uint8List.fromList(chunk.sublist(at, at + length));
}

enum _Mode {
  /// Reading a top-level box's header.
  header,

  /// A box sent on as it comes.
  pass,

  /// A box held until whole (`moov`, `moof`).
  hold,

  /// A box left out (`mfra`).
  skip,

  /// Everything from here on sent untouched.
  through,
}

final class _Box {
  const new({
    required this.type,
    required this.start,
    required this.body,
    required this.end,
  });

  /// A held top-level box: its own header first.
  factory whole(ByteData data) {
    final size = data.getUint32(0);
    return _Box(
      type: '',
      start: 0,
      body: size == 1 ? 16 : 8,
      end: data.lengthInBytes,
    );
  }

  final String type;
  final int start;
  final int body;
  final int end;

  /// Its version is 1 (64-bit times).
  bool v1(ByteData data) => data.getUint8(body) == 1;

  /// Its body is long enough for its fields: [v0] bytes in version 0,
  /// [v1] in version 1. One that isn't is left as it came.
  bool holds(ByteData data, {required int v0, required int v1}) =>
      body < end && body + (this.v1(data) ? v1 : v0) <= end;
}

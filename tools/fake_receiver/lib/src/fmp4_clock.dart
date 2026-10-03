import 'dart:typed_data';

/// How far into its media a fragmented MP4 has got, read as it arrives
/// in chunks of any size: each track's timescale from `moov`, then each
/// fragment's start from `moof/traf/tfdt`. The relay's continuous stream
/// is one (docs/04), so the fake knows how much it holds, as a TV's
/// buffer does.
final class Fmp4Clock {
  final _timescales = <int, int>{};
  final _header = BytesBuilder();
  BytesBuilder? _box;
  String _type = '';
  int _left = 0;
  bool _endless = false;
  Duration? _first;
  final _newest = <int, Duration>{};

  /// The newest fragment's start, from the first one's, in the track that
  /// is furthest behind (what plays is what every track has); null until
  /// a fragment came (a file that isn't fragmented never says).
  Duration? get media {
    final first = _first;
    if (first == null || _newest.isEmpty) return null;
    return _newest.values.reduce((a, b) => a < b ? a : b) - first;
  }

  void add(List<int> chunk) {
    var at = 0;
    while (at < chunk.length && !_endless) {
      if (_left == 0) {
        at = _readHeader(chunk, at);
        continue;
      }
      final take = _left < chunk.length - at ? _left : chunk.length - at;
      _box?.add(chunk.sublist(at, at + take));
      _left -= take;
      at += take;
      if (_left == 0) _finishBox();
    }
  }

  /// A box's 8 bytes (16 with a 64-bit size), across chunks if need be.
  int _readHeader(List<int> chunk, int at) {
    var i = at;
    while (i < chunk.length) {
      _header.addByte(chunk[i++]);
      final length = _header.length;
      if (length < 8) continue;
      final head = ByteData.sublistView(_header.toBytes());
      final size = head.getUint32(0);
      if (size == 1 && length < 16) continue;
      _type = String.fromCharCodes(_header.toBytes().sublist(4, 8));
      final whole = size == 1 ? head.getUint64(8) : size;
      _header.clear();
      if (size == 0) {
        // To the end of the stream: nothing after it to read.
        _endless = true;
        return chunk.length;
      }
      _left = whole - length;
      _box = _type == 'moov' || _type == 'moof' ? BytesBuilder() : null;
      if (_left <= 0) {
        _left = 0;
        _finishBox();
      }
      return i;
    }
    return i;
  }

  void _finishBox() {
    final box = _box?.takeBytes();
    _box = null;
    if (box == null) return;
    if (_type == 'moov') _readMovie(box);
    if (_type == 'moof') _readFragment(box);
  }

  void _readMovie(Uint8List moov) {
    for (final trak in _children(moov, 'trak')) {
      final tkhd = _children(trak, 'tkhd').firstOrNull;
      final mdhd = _children(
        _children(trak, 'mdia').firstOrNull,
        'mdhd',
      ).firstOrNull;
      if (tkhd == null || mdhd == null) continue;
      // Version 1 has 64-bit times before the id and the timescale.
      final track = _uint32(tkhd, tkhd[0] == 1 ? 20 : 12);
      final timescale = _uint32(mdhd, mdhd[0] == 1 ? 20 : 12);
      if (track != null && timescale != null && timescale > 0) {
        _timescales[track] = timescale;
      }
    }
  }

  void _readFragment(Uint8List moof) {
    for (final traf in _children(moof, 'traf')) {
      final tfhd = _children(traf, 'tfhd').firstOrNull;
      final tfdt = _children(traf, 'tfdt').firstOrNull;
      if (tfhd == null || tfdt == null) continue;
      final track = _uint32(tfhd, 4);
      final timescale = _timescales[track];
      if (track == null || timescale == null) continue;
      final data = ByteData.sublistView(tfdt);
      if (tfdt.length < (tfdt[0] == 1 ? 12 : 8)) continue;
      final decode = tfdt[0] == 1 ? data.getUint64(4) : data.getUint32(4);
      final start = Duration(microseconds: decode * 1000000 ~/ timescale);
      if (_first == null || start < _first!) _first = start;
      final newest = _newest[track];
      if (newest == null || start > newest) _newest[track] = start;
    }
  }

  /// The payloads of [parent]'s child boxes of [type].
  static List<Uint8List> _children(Uint8List? parent, String type) {
    if (parent == null) return const [];
    final found = <Uint8List>[];
    final data = ByteData.sublistView(parent);
    var at = 0;
    while (at + 8 <= parent.length) {
      final size = data.getUint32(at);
      final name = String.fromCharCodes(parent.sublist(at + 4, at + 8));
      if (size < 8 || at + size > parent.length) break;
      if (name == type) found.add(parent.sublist(at + 8, at + size));
      at += size;
    }
    return found;
  }

  static int? _uint32(Uint8List bytes, int at) =>
      at + 4 <= bytes.length ? ByteData.sublistView(bytes).getUint32(at) : null;
}

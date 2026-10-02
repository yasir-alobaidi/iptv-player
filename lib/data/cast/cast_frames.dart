import 'dart:typed_data';

/// The largest message a Cast device sends or takes: 64 KiB of protobuf
/// (Chromium's `kMaxMessageSize`).
const castMaxFrame = 65536;

/// Splits the bytes a Cast connection receives into messages: each is a
/// 4-byte big-endian length, then that many bytes of protobuf. A message
/// may arrive across several reads, or several in one.
///
/// A length past [maxFrame] can't be a Cast message, and nothing after it
/// can be trusted to start where a message starts: the reader stops
/// ([failed]) and returns nothing more.
final class CastFrameReader {
  new({this.maxFrame = castMaxFrame});

  final int maxFrame;
  final _pending = BytesBuilder(copy: false);
  var _failed = false;

  /// True once a length past [maxFrame] arrived.
  bool get failed => _failed;

  /// Adds [bytes] and returns every message they complete, in order.
  List<Uint8List> add(List<int> bytes) {
    if (_failed) return const [];
    _pending.add(bytes);
    final data = _pending.takeBytes();
    final frames = <Uint8List>[];
    var offset = 0;
    while (data.length - offset >= 4) {
      final length = ByteData.sublistView(
        data,
        offset,
        offset + 4,
      ).getUint32(0);
      if (length > maxFrame) {
        _failed = true;
        return frames;
      }
      if (data.length - offset - 4 < length) break;
      frames.add(Uint8List.sublistView(data, offset + 4, offset + 4 + length));
      offset += 4 + length;
    }
    if (offset < data.length) {
      _pending.add(Uint8List.sublistView(data, offset));
    }
    return frames;
  }
}

/// [body] with its 4-byte big-endian length in front.
Uint8List castFrame(List<int> body) {
  final frame = Uint8List(4 + body.length);
  ByteData.sublistView(frame).setUint32(0, body.length);
  frame.setRange(4, frame.length, body);
  return frame;
}

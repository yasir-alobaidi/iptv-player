// Plain Dart: the relay's proxy runs it on every live MPEG-TS stream.
import 'dart:typed_data';

/// One stream of an MPEG-TS program: its PID and its type (ISO 13818-1:
/// 0x1b H.264, 0x24 HEVC, 0x02 MPEG-2 video, 0x0f AAC, 0x03/0x04 MPEG
/// audio, 0x81 AC-3…).
typedef TsStream = ({int pid, int type});

/// Watches a live MPEG-TS stream's program map, and tells when it changes:
/// a channel that switches codec mid-stream keeps its PIDs and changes
/// their types, which FFmpeg, copying, never says (the plan's Risks; seen
/// with the fake panel's `codec_switch_after_s`).
///
/// It reads only the packets of the PAT and the PMT, and only a section
/// that fits in one packet (a PMT always has, in every stream seen). A
/// stream that loses its packet alignment finds it again.
final class TsProgramWatch {
  new(this._onChange);

  final void Function(List<TsStream> before, List<TsStream> after) _onChange;

  /// The program's streams as last seen; null before its first PMT.
  List<TsStream>? streams;

  int? _pmtPid;
  final _partial = Uint8List(_size);
  int _have = 0;

  static const _size = 188;
  static const _sync = 0x47;

  /// A new connection: what is left of the last one is no packet.
  void restart() => _have = 0;

  void add(List<int> chunk) {
    var at = 0;
    if (_have > 0) {
      final need = _size - _have;
      if (chunk.length < need) {
        _partial.setRange(_have, _have + chunk.length, chunk);
        _have += chunk.length;
        return;
      }
      _partial.setRange(_have, _size, chunk);
      _have = 0;
      at = need;
      if (_partial[0] == _sync) _packet(_partial, 0);
    }
    while (at < chunk.length) {
      if (chunk[at] != _sync) {
        // Lost: the next sync byte with another a packet later.
        final next = _resync(chunk, at + 1);
        if (next < 0) return;
        at = next;
        continue;
      }
      if (chunk.length - at < _size) {
        _partial.setRange(0, chunk.length - at, chunk, at);
        _have = chunk.length - at;
        return;
      }
      _packet(chunk, at);
      at += _size;
    }
  }

  static int _resync(List<int> chunk, int from) {
    for (var i = from; i < chunk.length; i++) {
      if (chunk[i] != _sync) continue;
      if (i + _size >= chunk.length || chunk[i + _size] == _sync) return i;
    }
    return -1;
  }

  void _packet(List<int> packet, int at) {
    final pid = ((packet[at + 1] & 0x1f) << 8) | packet[at + 2];
    if (pid != 0 && pid != _pmtPid) return;
    final unitStart = packet[at + 1] & 0x40 != 0;
    if (!unitStart) return;
    final control = (packet[at + 3] >> 4) & 0x3;
    if (control == 0 || control == 2) return;
    var payload = at + 4;
    if (control == 3) payload += 1 + packet[at + 4];
    final end = at + _size;
    if (payload >= end) return;
    // The pointer field, then the section.
    final section = payload + 1 + packet[payload];
    if (section + 3 > end) return;
    final length = ((packet[section + 1] & 0x0f) << 8) | packet[section + 2];
    // Whole in this packet, CRC excluded.
    final sectionEnd = section + 3 + length - 4;
    if (sectionEnd > end || length < 9) return;
    if (pid == 0 && packet[section] == 0x00) {
      for (var i = section + 8; i + 4 <= sectionEnd; i += 4) {
        final program = (packet[i] << 8) | packet[i + 1];
        if (program == 0) continue;
        _pmtPid = ((packet[i + 2] & 0x1f) << 8) | packet[i + 3];
        return;
      }
    } else if (pid == _pmtPid && packet[section] == 0x02) {
      if (section + 12 > sectionEnd) return;
      final info = ((packet[section + 10] & 0x0f) << 8) | packet[section + 11];
      final found = <TsStream>[];
      var i = section + 12 + info;
      while (i + 5 <= sectionEnd) {
        final type = packet[i];
        final stream = ((packet[i + 1] & 0x1f) << 8) | packet[i + 2];
        final described = ((packet[i + 3] & 0x0f) << 8) | packet[i + 4];
        found.add((pid: stream, type: type));
        i += 5 + described;
      }
      found.sort((a, b) => a.pid.compareTo(b.pid));
      final before = streams;
      streams = found;
      if (before != null && !_same(before, found)) _onChange(before, found);
    }
  }

  static bool _same(List<TsStream> a, List<TsStream> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

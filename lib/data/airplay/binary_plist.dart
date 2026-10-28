import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:meta/meta.dart';

/// A keyed archive's pointer to one of its objects (a binary plist UID).
@immutable
final class PlistUid {
  const new(this.value);

  final int value;

  @override
  bool operator ==(Object other) => other is PlistUid && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'PlistUid($value)';
}

/// What reading a binary plist gave.
sealed class PlistReadResult {
  const new();
}

/// The plist's root [value]: a `Map<String, Object?>` (keys in the
/// file's order), `List<Object?>`, `String`, `int`, `double`, `bool`,
/// `Uint8List`, `DateTime` (UTC), [PlistUid], or null.
final class PlistRead extends PlistReadResult {
  const new(this.value);

  final Object? value;
}

/// The bytes are not a binary plist this reader can trust; [reason] says
/// why, for logs.
final class PlistUnreadable extends PlistReadResult {
  const new(this.reason);

  final String reason;

  @override
  String toString() => 'PlistUnreadable($reason)';
}

/// The `Content-Type` of a binary plist body.
const binaryPlistContentType = 'application/x-apple-binary-plist';

/// Reads an Apple binary plist (`bplist00`), as Python's `plistlib`
/// reads one. Tolerant (hard rule 1): anything malformed — a bad header
/// or trailer, an offset or length past the end, an object that contains
/// itself, nesting past 512 levels, a number too large for an `int` —
/// gives [PlistUnreadable], never a throw. A dictionary key that isn't a
/// string is skipped; a set reads as a list.
PlistReadResult readBinaryPlist(List<int> bytes) {
  final data = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
  try {
    return PlistRead(_PlistReader(data).read());
  } on _Unreadable catch (unreadable) {
    return PlistUnreadable(unreadable.reason);
  } on Object catch (error) {
    // A bound this reader failed to check: still never the caller's crash.
    return PlistUnreadable('unexpected: ${error.runtimeType}');
  }
}

/// The root dictionary of a binary plist; null when [bytes] are unreadable
/// or their root is something else.
Map<String, Object?>? readBinaryPlistDict(List<int> bytes) =>
    switch (readBinaryPlist(bytes)) {
      PlistRead(value: final Map<String, Object?> dict) => dict,
      _ => null,
    };

/// [value] as an Apple binary plist (`bplist00`), laid out as Python's
/// `plistlib.dumps(value, fmt=FMT_BINARY, sort_keys=sortKeys)` lays it
/// out: objects depth first, a dictionary's keys before its values, equal
/// strings, numbers, dates and data written once, integers in the fewest
/// of 1, 2, 4 or 8 bytes (negative ones in 8), doubles in 8.
///
/// Takes what [readBinaryPlist] gives: a `Map` with `String` keys (in
/// its own order unless [sortKeys]), `List`, `String`, `int`, `double`,
/// `bool`, `Uint8List` (data), `DateTime`, [PlistUid] and null. Anything
/// else is the caller's mistake: an [ArgumentError].
Uint8List writeBinaryPlist(Object? value, {bool sortKeys = false}) =>
    _PlistWriter(sortKeys: sortKeys).write(value);

/// 2001-01-01 00:00 UTC in microseconds since 1970: a binary plist
/// date is seconds from there.
final int _epoch2001 = DateTime.utc(2001).microsecondsSinceEpoch;

const _maxDepth = 512;

final class _Unreadable implements Exception {
  const new(this.reason);

  final String reason;
}

final class _PlistReader {
  new(this._bytes);

  final Uint8List _bytes;
  late final ByteData _view = ByteData.sublistView(_bytes);
  late final int _refSize;
  late final int _limit;
  late final List<int> _offsets;
  late final List<Object?> _objects;
  late final List<bool> _decoded;
  final _inProgress = <int>{};
  var _depth = 0;

  Object? read() {
    const magic = 'bplist00';
    if (_bytes.length < magic.length + 32 + 1) {
      throw const _Unreadable('too short');
    }
    for (var i = 0; i < magic.length; i++) {
      if (_bytes[i] != magic.codeUnitAt(i)) {
        throw const _Unreadable('not a bplist00');
      }
    }
    final trailer = _bytes.length - 32;
    final offsetSize = _bytes[trailer + 6];
    _refSize = _bytes[trailer + 7];
    final count = _uint(trailer + 8, 8);
    final top = _uint(trailer + 16, 8);
    final tableOffset = _uint(trailer + 24, 8);
    if (offsetSize < 1 || offsetSize > 8 || _refSize < 1 || _refSize > 8) {
      throw const _Unreadable('bad trailer sizes');
    }
    if (count < 1 || count > _bytes.length || top < 0 || top >= count) {
      throw const _Unreadable('bad object count');
    }
    if (tableOffset < magic.length ||
        tableOffset > trailer ||
        count * offsetSize > trailer - tableOffset) {
      throw const _Unreadable('bad offset table');
    }
    _limit = trailer;
    _offsets = [
      for (var i = 0; i < count; i++)
        _uint(tableOffset + i * offsetSize, offsetSize),
    ];
    for (final offset in _offsets) {
      if (offset < magic.length || offset >= tableOffset) {
        throw const _Unreadable('object offset out of range');
      }
    }
    _objects = List<Object?>.filled(count, null);
    _decoded = List<bool>.filled(count, false);
    return _object(top);
  }

  Object? _object(int ref) {
    if (ref < 0 || ref >= _offsets.length) {
      throw const _Unreadable('reference out of range');
    }
    if (_decoded[ref]) return _objects[ref];
    if (!_inProgress.add(ref)) {
      throw const _Unreadable('object contains itself');
    }
    if (++_depth > _maxDepth) throw const _Unreadable('nested too deep');
    final value = _parse(_offsets[ref]);
    _depth--;
    _inProgress.remove(ref);
    _objects[ref] = value;
    _decoded[ref] = true;
    return value;
  }

  Object? _parse(int offset) {
    final marker = _bytes[offset];
    final low = marker & 0x0F;
    switch (marker >> 4) {
      case 0x0:
        return switch (marker) {
          0x00 => null,
          0x08 => false,
          0x09 => true,
          0x0F => Uint8List(0),
          _ => throw const _Unreadable('unknown marker'),
        };
      case 0x1:
        return _int(offset + 1, low);
      case 0x2:
        return switch (low) {
          2 => _view.getFloat32(_need(offset + 1, 4)),
          3 => _view.getFloat64(_need(offset + 1, 8)),
          _ => throw const _Unreadable('bad real size'),
        };
      case 0x3:
        if (marker != 0x33) throw const _Unreadable('bad date');
        return _date(_view.getFloat64(_need(offset + 1, 8)));
      case 0x4:
        final (length, start) = _size(offset, low);
        return Uint8List.fromList(
          _bytes.sublist(_need(start, length), start + length),
        );
      case 0x5:
        final (length, start) = _size(offset, low);
        return String.fromCharCodes(
          _bytes.sublist(_need(start, length), start + length),
        );
      case 0x6:
        final (units, start) = _size(offset, low);
        if (units > (_limit - start) ~/ 2) throw const _Unreadable('past end');
        _need(start, units * 2);
        return String.fromCharCodes([
          for (var i = 0; i < units; i++) _view.getUint16(start + i * 2),
        ]);
      case 0x8:
        if (low > 7) throw const _Unreadable('bad UID size');
        return PlistUid(_uint(_need(offset + 1, low + 1), low + 1));
      case 0xA:
      case 0xC:
        final (length, start) = _size(offset, low);
        final refs = _refs(start, length);
        return [for (final ref in refs) _object(ref)];
      case 0xD:
        final (length, start) = _size(offset, low);
        final keys = _refs(start, length);
        final values = _refs(start + length * _refSize, length);
        final dict = <String, Object?>{};
        for (var i = 0; i < length; i++) {
          final key = _object(keys[i]);
          final value = _object(values[i]);
          if (key is String) dict[key] = value;
        }
        return dict;
      default:
        throw const _Unreadable('unknown marker');
    }
  }

  /// An integer of `1 << power` bytes at [start]: unsigned below 8 bytes,
  /// signed at 8 and 16 (16 only when it fits an `int`).
  int _int(int start, int power) {
    if (power > 4) throw const _Unreadable('bad integer size');
    final length = 1 << power;
    _need(start, length);
    if (length <= 4) return _uint(start, length);
    if (length == 8) return _view.getInt64(start);
    final high = _view.getInt64(start);
    final low = _view.getInt64(start + 8);
    if ((high == 0 && low >= 0) || (high == -1 && low < 0)) return low;
    throw const _Unreadable('integer too large');
  }

  DateTime _date(double seconds) {
    if (!seconds.isFinite || seconds.abs() > 8e12) {
      throw const _Unreadable('bad date');
    }
    return DateTime.fromMicrosecondsSinceEpoch(
      _epoch2001 + (seconds * 1e6).round(),
      isUtc: true,
    );
  }

  /// The length a marker's low nibble gives, and where the object's
  /// content starts: past a following integer object when the nibble is
  /// 0xF (as `plistlib`, only that integer's size bits are read).
  (int, int) _size(int offset, int low) {
    if (low != 0x0F) return (low, offset + 1);
    final power = _bytes[_need(offset + 1, 1)] & 0x3;
    final bytes = 1 << power;
    final length = _uint(_need(offset + 2, bytes), bytes);
    if (length < 0) throw const _Unreadable('bad length');
    return (length, offset + 2 + bytes);
  }

  List<int> _refs(int start, int count) {
    if (count > (_limit - start) ~/ _refSize) {
      throw const _Unreadable('past end');
    }
    _need(start, count * _refSize);
    return [
      for (var i = 0; i < count; i++) _uint(start + i * _refSize, _refSize),
    ];
  }

  /// [start], once `length` bytes from it are known to lie before the
  /// trailer.
  int _need(int start, int length) {
    if (start < 0 || length < 0 || start > _limit - length) {
      throw const _Unreadable('past end');
    }
    return start;
  }

  /// A big-endian unsigned number of [length] bytes (1 to 8); one of 8
  /// bytes with the top bit set comes out negative, which every caller
  /// refuses.
  int _uint(int start, int length) {
    var value = 0;
    for (var i = 0; i < length; i++) {
      value = (value << 8) | _bytes[start + i];
    }
    return value;
  }
}

final class _PlistWriter {
  new({required this.sortKeys});

  final bool sortKeys;
  final _objects = <Object?>[];
  final _scalarRefs = <(String, Object), int>{};
  final _containerRefs = LinkedHashMap<Object?, int>.identity();

  Uint8List write(Object? root) {
    _flatten(root);
    final refSize = _sizeFor(_objects.length);
    final out = BytesBuilder(copy: false)..add(ascii.encode('bplist00'));
    final offsets = <int>[];
    for (final object in _objects) {
      offsets.add(out.length);
      _writeObject(out, object, refSize);
    }
    final tableOffset = out.length;
    final offsetSize = _sizeFor(tableOffset);
    for (final offset in offsets) {
      out.add(_uintBytes(offset, offsetSize));
    }
    final trailer = ByteData(32)
      ..setUint8(6, offsetSize)
      ..setUint8(7, refSize)
      ..setUint64(8, _objects.length)
      ..setUint64(16, _ref(root))
      ..setUint64(24, tableOffset);
    out.add(trailer.buffer.asUint8List());
    return out.takeBytes();
  }

  void _flatten(Object? value) {
    final key = _scalarKey(value);
    if (key != null) {
      if (_scalarRefs.containsKey(key)) return;
      _scalarRefs[key] = _objects.length;
      _objects.add(value);
      return;
    }
    if (_containerRefs.containsKey(value)) return;
    _containerRefs[value] = _objects.length;
    _objects.add(value);
    switch (value) {
      case Map<Object?, Object?>():
        final entries = _entries(value);
        for (final entry in entries) {
          _flatten(entry.key);
        }
        for (final entry in entries) {
          _flatten(entry.value);
        }
      case List<Object?>():
        value.forEach(_flatten);
      case null || PlistUid():
        break;
      default:
        throw ArgumentError.value(value, 'value', 'not a plist type');
    }
  }

  List<MapEntry<String, Object?>> _entries(Map<Object?, Object?> map) {
    final entries = [
      for (final MapEntry(:key, :value) in map.entries)
        if (key is String)
          MapEntry(key, value)
        else
          throw ArgumentError.value(key, 'key', 'plist keys must be strings'),
    ];
    if (sortKeys) entries.sort((a, b) => a.key.compareTo(b.key));
    return entries;
  }

  int _ref(Object? value) {
    final key = _scalarKey(value);
    return key != null ? _scalarRefs[key]! : _containerRefs[value]!;
  }

  void _writeObject(BytesBuilder out, Object? value, int refSize) {
    switch (value) {
      case null:
        out.addByte(0x00);
      case false:
        out.addByte(0x08);
      case true:
        out.addByte(0x09);
      case final int number:
        if (number < 0) {
          out
            ..addByte(0x13)
            ..add((ByteData(8)..setInt64(0, number)).buffer.asUint8List());
        } else {
          final size = number < 1 << 8
              ? 1
              : number < 1 << 16
              ? 2
              : number < 1 << 32
              ? 4
              : 8;
          out
            ..addByte(0x10 | _log2(size))
            ..add(_uintBytes(number, size));
        }
      case final double number:
        out
          ..addByte(0x23)
          ..add((ByteData(8)..setFloat64(0, number)).buffer.asUint8List());
      case final DateTime date:
        final seconds =
            (date.toUtc().microsecondsSinceEpoch - _epoch2001) / 1e6;
        out
          ..addByte(0x33)
          ..add((ByteData(8)..setFloat64(0, seconds)).buffer.asUint8List());
      case final Uint8List data:
        _writeSize(out, 0x40, data.length);
        out.add(data);
      case final String text:
        if (text.codeUnits.every((unit) => unit < 0x80)) {
          _writeSize(out, 0x50, text.length);
          out.add(text.codeUnits);
        } else {
          _writeSize(out, 0x60, text.length);
          final utf16 = ByteData(text.length * 2);
          for (var i = 0; i < text.length; i++) {
            utf16.setUint16(i * 2, text.codeUnitAt(i));
          }
          out.add(utf16.buffer.asUint8List());
        }
      case PlistUid(value: final uid):
        if (uid < 0) throw ArgumentError.value(uid, 'uid', 'must be positive');
        final size = uid < 1 << 8
            ? 1
            : uid < 1 << 16
            ? 2
            : uid < 1 << 32
            ? 4
            : 8;
        out
          ..addByte(0x80 | (size - 1))
          ..add(_uintBytes(uid, size));
      case final List<Object?> list:
        _writeSize(out, 0xA0, list.length);
        for (final item in list) {
          out.add(_uintBytes(_ref(item), refSize));
        }
      case final Map<Object?, Object?> map:
        final entries = _entries(map);
        _writeSize(out, 0xD0, entries.length);
        for (final entry in entries) {
          out.add(_uintBytes(_ref(entry.key), refSize));
        }
        for (final entry in entries) {
          out.add(_uintBytes(_ref(entry.value), refSize));
        }
      default:
        throw ArgumentError.value(value, 'value', 'not a plist type');
    }
  }

  void _writeSize(BytesBuilder out, int marker, int size) {
    if (size < 15) {
      out.addByte(marker | size);
      return;
    }
    final bytes = _sizeFor(size);
    out
      ..addByte(marker | 0x0F)
      ..addByte(0x10 | _log2(bytes))
      ..add(_uintBytes(size, bytes));
  }

  /// The key a scalar is shared under (Python's `(type(value), value)`);
  /// null for a container, [PlistUid] or null, which are shared only when
  /// they are the same object.
  static (String, Object)? _scalarKey(Object? value) => switch (value) {
    final bool flag => ('bool', flag),
    final int number => ('int', number),
    final double number => ('real', number),
    final String text => ('string', text),
    final DateTime date => ('date', date.toUtc().microsecondsSinceEpoch),
    final Uint8List data => ('data', String.fromCharCodes(data)),
    _ => null,
  };

  static int _sizeFor(int count) => count < 1 << 8
      ? 1
      : count < 1 << 16
      ? 2
      : count < 1 << 32
      ? 4
      : 8;

  static int _log2(int size) => switch (size) {
    1 => 0,
    2 => 1,
    4 => 2,
    _ => 3,
  };

  static Uint8List _uintBytes(int value, int size) {
    final bytes = Uint8List(size);
    var rest = value;
    for (var i = size - 1; i >= 0; i--) {
      bytes[i] = rest & 0xFF;
      rest >>= 8;
    }
    return bytes;
  }
}

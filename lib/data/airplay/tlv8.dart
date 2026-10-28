import 'dart:math';
import 'dart:typed_data';

/// The item types of HAP's TLV8 pairing messages (HAP spec, table 5-6);
/// [name] and [flags] are Apple's own, as pyatv's `hap_tlv8.TlvValue`.
abstract final class TlvType {
  static const method = 0x00;
  static const identifier = 0x01;
  static const salt = 0x02;
  static const publicKey = 0x03;
  static const proof = 0x04;
  static const encryptedData = 0x05;

  /// Which message of the exchange this is: 1 for M1 … 6 for M6 (pyatv
  /// calls it `SeqNo`).
  static const state = 0x06;
  static const error = 0x07;

  /// Seconds to wait before trying again, with [TlvErrorCode.backOff].
  static const backOff = 0x08;
  static const certificate = 0x09;
  static const signature = 0x0A;
  static const permissions = 0x0B;
  static const fragmentData = 0x0C;
  static const fragmentLast = 0x0D;

  /// An OPACK dictionary with the controller's name, in pair-setup's M5.
  static const name = 0x11;
  static const flags = 0x13;

  /// An empty item between two items of the same type in a list.
  static const separator = 0xFF;
}

/// The values of a [TlvType.method] item.
abstract final class TlvMethod {
  static const pairSetup = 0x00;
  static const pairSetupWithAuth = 0x01;
  static const pairVerify = 0x02;
  static const addPairing = 0x03;
  static const removePairing = 0x04;
  static const listPairings = 0x05;
}

/// The values of a [TlvType.error] item.
abstract final class TlvErrorCode {
  static const unknown = 0x01;

  /// The setup code (PIN) or a signature was wrong.
  static const authentication = 0x02;

  /// Too many attempts: wait the [TlvType.backOff] seconds first.
  static const backOff = 0x03;

  /// The device has as many pairings as it keeps.
  static const maxPeers = 0x04;

  /// The device has refused too many wrong codes.
  static const maxTries = 0x05;

  /// The device can't pair now (already paired, or pairing is off).
  static const unavailable = 0x06;

  /// The device is pairing with someone else.
  static const busy = 0x07;
}

/// The bits of a [TlvType.flags] item.
abstract final class TlvFlags {
  /// Transient pair-setup: M1 … M4 only, keys from the SRP session key.
  static const transient = 0x10;
}

/// [items] as TLV8 bytes, in the map's order. A value over 255 bytes is
/// split into consecutive items of the same type, 255 bytes each but the
/// last; an empty value is one item of length 0.
Uint8List writeTlv8(Map<int, List<int>> items) => writeTlv8Items([
  for (final MapEntry(:key, :value) in items.entries) (key, value),
]);

/// [items] as TLV8 bytes, in order, as [writeTlv8] writes them. For a
/// list that repeats a type: put a [TlvType.separator] item with an empty
/// value between two items of the same type, or they read back as one.
Uint8List writeTlv8Items(Iterable<(int, List<int>)> items) {
  final out = BytesBuilder(copy: false);
  for (final (type, value) in items) {
    if (value.isEmpty) {
      out.add([type & 0xFF, 0]);
      continue;
    }
    for (var start = 0; start < value.length; start += 255) {
      final end = min(start + 255, value.length);
      out
        ..addByte(type & 0xFF)
        ..addByte(end - start)
        ..add(value.sublist(start, end));
    }
  }
  return out.takeBytes();
}

/// The items of a TLV8 message by type, as pyatv's `read_tlv`: every item
/// of a type is joined onto the first (a value over 255 bytes comes as
/// several). Tolerant (hard rule 1): an item cut short at the end is
/// dropped, never thrown.
Map<int, Uint8List> readTlv8(List<int> bytes) {
  final joined = <int, BytesBuilder>{};
  _scan(bytes, (type, value) {
    joined.putIfAbsent(type, () => BytesBuilder(copy: false)).add(value);
  });
  return {
    for (final MapEntry(:key, :value) in joined.entries) key: value.takeBytes(),
  };
}

/// The items of a TLV8 message in order, consecutive items of the same
/// type joined into one (HAP's fragments of a long value);
/// [TlvType.separator] items are kept, so a list's entries stay apart.
/// Tolerant as [readTlv8].
List<(int, Uint8List)> readTlv8Items(List<int> bytes) {
  final items = <(int, Uint8List)>[];
  int? lastType;
  BytesBuilder? last;
  void flush() {
    if (lastType != null && last != null) {
      items.add((lastType!, last!.takeBytes()));
    }
  }

  _scan(bytes, (type, value) {
    if (type == lastType && type != TlvType.separator) {
      last!.add(value);
      return;
    }
    flush();
    lastType = type;
    last = BytesBuilder(copy: false)..add(value);
  });
  flush();
  return items;
}

/// A little-endian unsigned number in a TLV8 value (a state, an error
/// code, back-off seconds); null for an empty or over-long value.
int? readTlvInt(List<int>? value) {
  if (value == null || value.isEmpty || value.length > 7) return null;
  var result = 0;
  for (var i = value.length - 1; i >= 0; i--) {
    result = (result << 8) | (value[i] & 0xFF);
  }
  return result;
}

/// A short summary of a TLV8 message for logs, as pyatv's `stringify`:
/// the method, state, error and back-off are spelled out; every other
/// item only by its length, so no key, proof or PIN-derived value is ever
/// written out (hard rule 3).
String describeTlv8(Map<int, List<int>> items) => [
  for (final MapEntry(key: type, :value) in items.entries)
    switch (type) {
      TlvType.method => 'Method=${_name(value, _methodNames)}',
      TlvType.state => 'State=${_stateName(value)}',
      TlvType.error => 'Error=${_name(value, _errorNames)}',
      TlvType.backOff => 'BackOff=${readTlvInt(value) ?? '?'}s',
      _ => '${_typeNames[type] ?? _hex(type)}=${value.length}bytes',
    },
].join(', ');

void _scan(List<int> bytes, void Function(int type, List<int> value) onItem) {
  var offset = 0;
  while (bytes.length - offset >= 2) {
    final type = bytes[offset] & 0xFF;
    final length = bytes[offset + 1] & 0xFF;
    final start = offset + 2;
    if (bytes.length - start < length) return;
    onItem(type, bytes.sublist(start, start + length));
    offset = start + length;
  }
}

String _name(List<int> value, Map<int, String> names) {
  final number = readTlvInt(value);
  if (number == null) return '?';
  return names[number] ?? _hex(number);
}

String _stateName(List<int> value) {
  final number = readTlvInt(value);
  if (number == null) return '?';
  return number >= 1 && number <= 6 ? 'M$number' : _hex(number);
}

String _hex(int value) => '0x${value.toRadixString(16)}';

const Map<int, String> _methodNames = {
  TlvMethod.pairSetup: 'PairSetup',
  TlvMethod.pairSetupWithAuth: 'PairSetupWithAuth',
  TlvMethod.pairVerify: 'PairVerify',
  TlvMethod.addPairing: 'AddPairing',
  TlvMethod.removePairing: 'RemovePairing',
  TlvMethod.listPairings: 'ListPairings',
};

const Map<int, String> _errorNames = {
  TlvErrorCode.unknown: 'Unknown',
  TlvErrorCode.authentication: 'Authentication',
  TlvErrorCode.backOff: 'BackOff',
  TlvErrorCode.maxPeers: 'MaxPeers',
  TlvErrorCode.maxTries: 'MaxTries',
  TlvErrorCode.unavailable: 'Unavailable',
  TlvErrorCode.busy: 'Busy',
};

const Map<int, String> _typeNames = {
  TlvType.identifier: 'Identifier',
  TlvType.salt: 'Salt',
  TlvType.publicKey: 'PublicKey',
  TlvType.proof: 'Proof',
  TlvType.encryptedData: 'EncryptedData',
  TlvType.certificate: 'Certificate',
  TlvType.signature: 'Signature',
  TlvType.permissions: 'Permissions',
  TlvType.fragmentData: 'FragmentData',
  TlvType.fragmentLast: 'FragmentLast',
  TlvType.name: 'Name',
  TlvType.flags: 'Flags',
  TlvType.separator: 'Separator',
};

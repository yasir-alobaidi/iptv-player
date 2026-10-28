import 'dart:typed_data';

import 'package:iptv_player/data/cast/cast_txt.dart';
import 'package:meta/meta.dart';

/// The DNS-SD service type AirPlay receivers announce.
const airPlayServiceType = '_airplay._tcp';

/// The 64 feature bits of an AirPlay receiver's TXT `features`; the
/// names are pyatv's `AirPlayFlags` (from emanuelecozzi.net's AirPlay 2
/// notes).
@immutable
final class AirPlayFeatures {
  const new(this.value);

  /// `features` as one number: "0xLOW" or "0xLOW,0xHIGH", HIGH the top
  /// 32 bits. Tolerant (hard rule 1): anything else is no features.
  ///
  /// Unlike pyatv, which joins the two hex strings as text (so a LOW
  /// written with fewer than 8 digits slides HIGH down — the Hisense
  /// Roku's "0x7F8AD0,0x38BCF46" among them), HIGH is shifted by 32.
  factory parse(String? text) {
    final match = RegExp(
      r'^0x([0-9a-f]{1,8})(?:,0x([0-9a-f]{1,8}))?$',
      caseSensitive: false,
    ).firstMatch(text?.trim() ?? '');
    if (match == null) return const AirPlayFeatures(0);
    final low = int.parse(match.group(1)!, radix: 16);
    final high = int.parse(match.group(2) ?? '0', radix: 16);
    return AirPlayFeatures(high << 32 | low);
  }

  final int value;

  /// Whether bit [bit] (0 … 63) is set.
  bool has(int bit) => bit >= 0 && bit < 64 && (value >> bit) & 1 == 1;

  bool get videoV1 => has(0);
  bool get videoHttpLiveStreams => has(4);
  bool get screen => has(7);
  bool get audio => has(9);
  bool get authentication4 => has(14);
  bool get videoPlayQueue => has(33);
  bool get unifiedMediaControl => has(38);
  bool get systemPairing => has(43);
  bool get hkPairingAndAccessControl => has(46);
  bool get coreUtilsPairingAndEncryption => has(48);
  bool get airPlayVideoV2 => has(49);
  bool get unifiedPairSetupAndMfi => has(51);

  @override
  bool operator ==(Object other) =>
      other is AirPlayFeatures && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() {
    final bits = BigInt.from(value).toUnsigned(64);
    return 'AirPlayFeatures(0x${bits.toRadixString(16)})';
  }
}

/// What an `_airplay._tcp` service says about its receiver: [name] is
/// the DNS-SD instance name, the rest its TXT record.
@immutable
final class AirPlayDeviceInfo {
  const new({
    required this.name,
    this.model,
    this.manufacturer,
    this.deviceId,
    this.features = const AirPlayFeatures(0),
    this.statusFlags = 0,
    this.publicKey,
    this.pairingId,
    this.sourceVersion,
    this.passwordFlag = false,
    this.accessControl,
  });

  /// [txt] read tolerantly (hard rule 1): keys without case, `features`
  /// else `ft`, `sf` else `flags` (as pyatv, an empty one skipped); a
  /// value that doesn't parse is absent (or 0), never a throw.
  factory fromTxt({required String name, required Map<String, String> txt}) {
    final lower = {
      for (final MapEntry(:key, :value) in txt.entries)
        key.trim().toLowerCase(): value.trim(),
    };
    String? text(String key) => cleanCastText(lower[key]);
    String? either(String first, String second) =>
        (lower[first]?.isNotEmpty ?? false) ? lower[first] : lower[second];
    return AirPlayDeviceInfo(
      name: cleanCastText(name) ?? text('model') ?? 'AirPlay device',
      model: text('model'),
      manufacturer: text('manufacturer'),
      deviceId: text('deviceid'),
      features: AirPlayFeatures.parse(either('features', 'ft')),
      statusFlags: _hexFlags(either('sf', 'flags')),
      publicKey: _hexBytes(lower['pk']),
      pairingId: text('pi'),
      sourceVersion: text('srcvers'),
      passwordFlag: (lower['pw'] ?? '').toLowerCase() == 'true',
      accessControl: int.tryParse(lower['acl'] ?? ''),
    );
  }

  final String name;
  final String? model;
  final String? manufacturer;

  /// TXT `deviceid`, a MAC-like "D1:3C:2C:48:B5:B5".
  final String? deviceId;
  final AirPlayFeatures features;

  /// TXT `sf` (or `flags`): the receiver's status bits.
  final int statusFlags;

  /// TXT `pk`: the receiver's 32-byte Ed25519 public key, when it gave a
  /// readable one.
  final Uint8List? publicKey;

  /// TXT `pi`: the receiver's pairing identifier.
  final String? pairingId;

  /// TXT `srcvers`: the AirPlay version it runs ("377.40.00").
  final String? sourceVersion;

  /// TXT `pw` is "true".
  final bool passwordFlag;

  /// TXT `acl`: 1 limits pairing to the receiver's own people (pyatv
  /// then calls pairing disabled).
  final int? accessControl;

  /// Status bit 0x8: a PIN every time.
  static const pinRequiredFlag = 0x8;

  /// Status bit 0x80: a password (pyatv's `PASSWORD_BIT`).
  static const passwordFlagBit = 0x80;

  /// Status bit 0x200: a PIN the first time (pyatv's
  /// `LEGACY_PAIRING_BIT`).
  static const oneTimePairingFlag = 0x200;

  /// Whether pairing with a PIN comes first (pyatv's mandatory pairing).
  bool get needsPin =>
      statusFlags & (pinRequiredFlag | oneTimePairingFlag) != 0;

  /// Whether it asks for a password (pyatv's `is_password_required`).
  bool get needsPassword => passwordFlag || statusFlags & passwordFlagBit != 0;

  /// Whether pairing is limited to the receiver's own people.
  bool get pairingDisabled => accessControl == 1;

  /// AirPlay 2 (pyatv's guess): unified media control or CoreUtils
  /// pairing and encryption.
  bool get usesAirPlay2 =>
      features.unifiedMediaControl || features.coreUtilsPairingAndEncryption;

  /// Whether it takes a video URL to play.
  bool get playsVideoUrls =>
      features.videoV1 ||
      features.videoHttpLiveStreams ||
      features.videoPlayQueue ||
      features.airPlayVideoV2;

  /// Whether transient pairing (no PIN, nothing kept) is worth a try
  /// when there are no stored credentials (pyatv's
  /// `extract_credentials`).
  bool get supportsTransientPairing =>
      features.systemPairing || features.coreUtilsPairingAndEncryption;

  @override
  String toString() =>
      'AirPlayDeviceInfo($name, ${model ?? '?'}, $features, '
      'flags 0x${statusFlags.toRadixString(16)})';
}

/// A hex number with or without "0x"; 0 when it isn't one.
int _hexFlags(String? text) {
  var hex = text?.trim().toLowerCase() ?? '';
  if (hex.startsWith('0x')) hex = hex.substring(2);
  if (!RegExp(r'^[0-9a-f]{1,15}$').hasMatch(hex)) return 0;
  return int.parse(hex, radix: 16);
}

/// Hex digits as bytes; null when they aren't an even count of them.
Uint8List? _hexBytes(String? text) {
  final hex = text?.trim() ?? '';
  if (hex.isEmpty ||
      hex.length.isOdd ||
      !RegExp(r'^[0-9a-fA-F]+$').hasMatch(hex)) {
    return null;
  }
  return Uint8List.fromList([
    for (var i = 0; i < hex.length; i += 2)
      int.parse(hex.substring(i, i + 2), radix: 16),
  ]);
}

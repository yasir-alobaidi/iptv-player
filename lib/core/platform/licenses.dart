import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'licenses.g.dart';

/// Everything one package (or font, or program) is licensed under.
@immutable
final class PackageLicenses {
  const new(this.package, this.entries);

  final String package;
  final List<LicenseEntry> entries;

  /// The licence texts, one after the other. Worked out when asked for:
  /// only the package being read pays for its paragraphs.
  String get text => [
    for (final entry in entries)
      [for (final paragraph in entry.paragraphs) paragraph.text].join('\n\n'),
  ].join('\n\n${'─' * 24}\n\n');
}

/// The licences Flutter's registry holds — every package's, and what
/// bootstrap added for the bundled fonts, FFmpeg and mpv — by package,
/// A to Z. Flutter parses its own file off the UI isolate.
Future<List<PackageLicenses>> collectLicenses() async {
  final byPackage = <String, List<LicenseEntry>>{};
  await for (final entry in LicenseRegistry.licenses) {
    for (final package in entry.packages) {
      (byPackage[package] ??= []).add(entry);
    }
  }
  final names = byPackage.keys.toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return [for (final name in names) PackageLicenses(name, byPackage[name]!)];
}

/// Read when the Licences dialog opens; let go when it closes.
@riverpod
Future<List<PackageLicenses>> licenses(Ref ref) => collectLicenses();

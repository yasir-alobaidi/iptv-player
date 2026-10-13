import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The app's version, as the build wrote it (`pubspec.yaml`'s `version:`
/// split at the `+`).
@immutable
final class AppVersion {
  const new({required this.version, required this.build});

  /// Tolerant: anything missing reads as unknown.
  factory fromJson(Object? json) {
    if (json is! Map) return unknown;
    String text(Object? value) => value is String ? value.trim() : '';
    return AppVersion(
      version: text(json['version']),
      build: text(json['build_number']),
    );
  }

  /// A build that says nothing (a test run, a damaged bundle).
  static const unknown = AppVersion(version: '', build: '');

  /// `0.1.0`; empty when unknown.
  final String version;

  /// `1`; empty when unknown.
  final String build;

  bool get isKnown => version.isNotEmpty;

  /// `0.1.0 (build 1)`, as About shows it.
  String get label => switch ((version, build)) {
    ('', _) => 'version unknown',
    (final v, '') => v,
    (final v, final b) => '$v (build $b)',
  };

  /// `0.1.0+1`, as a report writes it.
  String get short => switch ((version, build)) {
    ('', _) => 'unknown',
    (final v, '') => v,
    (final v, final b) => '$v+$b',
  };

  @override
  bool operator ==(Object other) =>
      other is AppVersion && other.version == version && other.build == build;

  @override
  int get hashCode => Object.hash(version, build);

  @override
  String toString() => 'AppVersion($short)';
}

/// Reads the version file every Flutter build puts beside the app's
/// assets (`version.json`), so no package and no platform call is needed.
/// A bundle without it gives [AppVersion.unknown], never an error.
Future<AppVersion> readAppVersion(AssetBundle bundle) async {
  try {
    return AppVersion.fromJson(
      jsonDecode(await bundle.loadString('version.json')),
    );
  } on Object {
    return AppVersion.unknown;
  }
}

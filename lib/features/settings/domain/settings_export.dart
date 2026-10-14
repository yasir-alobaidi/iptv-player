import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:iptv_player/core/app_identity.dart';
import 'package:meta/meta.dart';

/// The settings file's format, written by this version. A file with a
/// higher number was made by a newer app and is refused, not guessed at.
const settingsExportFormat = 1;

/// What marks a file as ours: the format's own mark, from before the
/// app had its name, kept so that every file made since still imports.
const settingsExportApp = 'iptv-player';

/// `bijou-settings-2026-10-13.json`, the name Export suggests.
String settingsExportFileName(DateTime now) {
  final day = now.toLocal();
  String two(int value) => '$value'.padLeft(2, '0');
  return '$appFileSlug-settings-${day.year}-${two(day.month)}-'
      '${two(day.day)}.json';
}

/// How a source is recognized on another computer (Phase 9 decision 6):
/// a fingerprint of its type, its server and its username. The file never
/// holds the server or the username themselves — an address is half of a
/// credential in a file that may be copied anywhere.
///
/// [server] is the Xtream server, a playlist URL's origin, or a playlist
/// file's name without its folder (paths differ between computers).
String sourceFingerprint({
  required String type,
  required String server,
  required String? username,
}) {
  final normalized = server.trim().toLowerCase().replaceAll(RegExp(r'/+$'), '');
  return sha256
      .convert(utf8.encode('$type\n$normalized\n${username?.trim() ?? ''}'))
      .toString();
}

/// One favorite, by what it points at.
@immutable
final class ExportedFavorite {
  const new({
    required this.type,
    required this.key,
    this.group,
    this.order,
    this.addedAt,
  });

  /// `live`, `movie`, `series` or `episode`.
  final String type;
  final String key;

  /// The name of the favorites group it is in; null is none.
  final String? group;
  final int? order;
  final DateTime? addedAt;

  Map<String, Object?> toJson() => {
    'type': type,
    'key': key,
    'group': ?group,
    'order': ?order,
    if (addedAt case final at?) 'added_at': at.toUtc().toIso8601String(),
  };
}

@immutable
final class ExportedFavoriteGroup {
  const new({required this.name, this.order = 0, this.collapsed = false});

  final String name;
  final int order;
  final bool collapsed;

  Map<String, Object?> toJson() => {
    'name': name,
    'order': order,
    'collapsed': collapsed,
  };
}

/// A category as the user left it: every category of a source is in the
/// file, so the ones picked by hand come out the same on the other side.
@immutable
final class ExportedCategory {
  const new({
    required this.kind,
    required this.key,
    this.hidden = false,
    this.name,
    this.order,
  });

  /// `live`, `movie` or `series`.
  final String kind;
  final String key;
  final bool hidden;

  /// The user's rename; null keeps the provider's name.
  final String? name;

  /// The user's order; null follows the provider's.
  final int? order;

  Map<String, Object?> toJson() => {
    'kind': kind,
    'key': key,
    'hidden': hidden,
    'name': ?name,
    'order': ?order,
  };
}

/// A channel the user hid or renamed. Channels left alone aren't listed.
@immutable
final class ExportedChannel {
  const new({required this.key, this.hidden = false, this.name});

  final String key;
  final bool hidden;
  final String? name;

  Map<String, Object?> toJson() => {
    'key': key,
    'hidden': hidden,
    'name': ?name,
  };
}

/// A channel the user attached to a guide channel by hand.
@immutable
final class ExportedGuideMatch {
  const new({required this.channel, required this.xmltvId});

  final String channel;
  final String xmltvId;

  Map<String, Object?> toJson() => {'channel': channel, 'xmltv_id': xmltvId};
}

/// One source's choices. [name] is the user's own label for it, so a
/// source that isn't on the other computer can be named there.
@immutable
final class ExportedSource {
  const new({
    required this.name,
    required this.type,
    required this.fingerprint,
    this.favorites = const [],
    this.favoriteGroups = const [],
    this.categories = const [],
    this.channels = const [],
    this.guideMatches = const [],
    this.reminders = const [],
  });

  final String name;
  final String type;
  final String fingerprint;
  final List<ExportedFavorite> favorites;
  final List<ExportedFavoriteGroup> favoriteGroups;
  final List<ExportedCategory> categories;
  final List<ExportedChannel> channels;
  final List<ExportedGuideMatch> guideMatches;

  /// Reminders, each as its own map: their shape belongs to the
  /// reminders' own code (Phase 9 step 5), which reads them tolerantly.
  final List<Map<String, Object?>> reminders;

  int get hiddenCategories => categories.where((c) => c.hidden).length;

  int get renamedCategories => categories.where((c) => c.name != null).length;

  int get hiddenChannels => channels.where((c) => c.hidden).length;

  int get renamedChannels => channels.where((c) => c.name != null).length;

  Map<String, Object?> toJson() => {
    'name': name,
    'type': type,
    'fingerprint': fingerprint,
    'favorite_groups': [for (final g in favoriteGroups) g.toJson()],
    'favorites': [for (final f in favorites) f.toJson()],
    'categories': [for (final c in categories) c.toJson()],
    'channels': [for (final c in channels) c.toJson()],
    'guide_matches': [for (final m in guideMatches) m.toJson()],
    'reminders': reminders,
  };
}

/// The whole file: the settings pages' values, and each source's choices.
@immutable
final class SettingsExport {
  const new({
    required this.exportedAt,
    this.appVersion = '',
    this.settings = const {},
    this.sources = const [],
  });

  final DateTime exportedAt;
  final String appVersion;

  /// By page: `appearance`, `playback`, `guide`, `cast`, `downloads`.
  /// Each value is that page's own JSON, read tolerantly by its own code.
  final Map<String, Object?> settings;
  final List<ExportedSource> sources;

  Map<String, Object?> toJson() => {
    'app': settingsExportApp,
    'format': settingsExportFormat,
    'exported_at': exportedAt.toUtc().toIso8601String(),
    'app_version': appVersion,
    'settings': settings,
    'sources': [for (final source in sources) source.toJson()],
  };

  /// The file's text, indented: it is small, and a person may read it.
  String encode() => const JsonEncoder.withIndent('  ').convert(toJson());
}

/// The settings pages a file may carry. Anything else under `settings`
/// is from a newer version and is skipped.
const exportedSettingsPages = [
  'appearance',
  'playback',
  'guide',
  'cast',
  'downloads',
];

/// Why a file can't be imported at all.
enum SettingsFileProblem {
  /// Not JSON, or JSON cut short.
  damaged,

  /// JSON, but not a file this app wrote.
  notOurs,

  /// Written by a newer version of the app.
  newer,
}

/// A file that was refused, and why.
final class SettingsFileRefused implements Exception {
  const new(this.problem, {this.format});

  final SettingsFileProblem problem;

  /// The file's format number, when [problem] is
  /// [SettingsFileProblem.newer].
  final int? format;

  @override
  String toString() => 'SettingsFileRefused(${problem.name})';
}

/// Reads a settings file's [text]. Throws [SettingsFileRefused] when the
/// file as a whole can't be used; anything inside it that is unknown or
/// malformed is skipped, never fatal (hard rule 1's spirit: a bad row is
/// not a bad file).
SettingsExport parseSettingsExport(String text) {
  final Object? decoded;
  try {
    decoded = jsonDecode(text);
  } on FormatException {
    throw const SettingsFileRefused(SettingsFileProblem.damaged);
  }
  if (decoded is! Map || decoded['app'] != settingsExportApp) {
    throw const SettingsFileRefused(SettingsFileProblem.notOurs);
  }
  final format = decoded['format'];
  if (format is! int || format < 1) {
    throw const SettingsFileRefused(SettingsFileProblem.notOurs);
  }
  if (format > settingsExportFormat) {
    throw SettingsFileRefused(SettingsFileProblem.newer, format: format);
  }

  final rawSettings = decoded['settings'];
  final settings = <String, Object?>{
    if (rawSettings is Map)
      for (final page in exportedSettingsPages)
        if (rawSettings[page] is Map) page: rawSettings[page],
  };
  final rawSources = decoded['sources'];
  return SettingsExport(
    exportedAt: _date(decoded['exported_at']) ?? DateTime.utc(1970),
    appVersion: _text(decoded['app_version']) ?? '',
    settings: settings,
    sources: [
      if (rawSources is List)
        for (final raw in rawSources) ?_source(raw),
    ],
  );
}

String? _text(Object? value) {
  if (value is! String) return null;
  final text = value.trim();
  return text.isEmpty ? null : text;
}

int? _int(Object? value) => value is int ? value : null;

DateTime? _date(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;

List<T> _list<T>(Object? value, T? Function(Map<Object?, Object?>) read) => [
  if (value is List)
    for (final item in value)
      if (item is Map) ?read(item),
];

ExportedSource? _source(Object? raw) {
  if (raw is! Map) return null;
  final type = _text(raw['type']);
  final fingerprint = _text(raw['fingerprint']);
  if (type == null || fingerprint == null) return null;
  return ExportedSource(
    name: _text(raw['name']) ?? 'A source',
    type: type,
    fingerprint: fingerprint,
    favoriteGroups: _list(raw['favorite_groups'], (m) {
      final name = _text(m['name']);
      if (name == null) return null;
      return ExportedFavoriteGroup(
        name: name,
        order: _int(m['order']) ?? 0,
        collapsed: m['collapsed'] == true,
      );
    }),
    favorites: _list(raw['favorites'], (m) {
      final type = _text(m['type']);
      final key = _text(m['key']);
      if (type == null || key == null) return null;
      return ExportedFavorite(
        type: type,
        key: key,
        group: _text(m['group']),
        order: _int(m['order']),
        addedAt: _date(m['added_at']),
      );
    }),
    categories: _list(raw['categories'], (m) {
      final kind = _text(m['kind']);
      final key = _text(m['key']);
      if (kind == null || key == null) return null;
      return ExportedCategory(
        kind: kind,
        key: key,
        hidden: m['hidden'] == true,
        name: _text(m['name']),
        order: _int(m['order']),
      );
    }),
    channels: _list(raw['channels'], (m) {
      final key = _text(m['key']);
      if (key == null) return null;
      return ExportedChannel(
        key: key,
        hidden: m['hidden'] == true,
        name: _text(m['name']),
      );
    }),
    guideMatches: _list(raw['guide_matches'], (m) {
      final channel = _text(m['channel']);
      final xmltvId = _text(m['xmltv_id']);
      if (channel == null || xmltvId == null) return null;
      return ExportedGuideMatch(channel: channel, xmltvId: xmltvId);
    }),
    reminders: _list(
      raw['reminders'],
      (m) => {
        for (final MapEntry(:key, :value) in m.entries)
          if (key is String) key: value,
      },
    ),
  );
}

import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:drift/drift.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/db/user_tables.dart';
import 'package:iptv_player/data/settings/settings_repository.dart';
import 'package:iptv_player/features/settings/domain/settings_export.dart';
import 'package:iptv_player/features/settings/domain/settings_transfer.dart';
import 'package:iptv_player/features/sources/domain/source.dart';
import 'package:meta/meta.dart';

/// The settings table's key for each page a file carries.
const Map<String, String> _pageKeys = {
  'appearance': SettingsKeys.appearance,
  'playback': SettingsKeys.playback,
  'guide': SettingsKeys.guide,
  'cast': SettingsKeys.cast,
  'downloads': SettingsKeys.downloads,
};

/// What a page's value must not carry from one computer to another: the
/// download folder is a path on this one.
const Map<String, List<String>> _leftOut = {
  'downloads': ['folder'],
};

/// A reminder's part in a settings file (Phase 9 step 5 gives the real
/// one). Kept behind an interface so this file needn't know the
/// reminders' tables.
abstract interface class ReminderTransfer {
  /// [sourceId]'s reminders, each as a JSON map.
  Future<List<Map<String, Object?>>> export(String sourceId);

  /// Adds [reminders] to [sourceId]; returns how many were taken. Runs
  /// inside the import's transaction.
  Future<int> import(String sourceId, List<Map<String, Object?>> reminders);
}

/// [SettingsTransfer] on the app's database.
///
/// The database's work runs on drift's own isolate; the file is encoded,
/// written, read and parsed in another (hard rule 2). An import is one
/// transaction: it applies whole or not at all.
final class DbSettingsTransfer implements SettingsTransfer {
  new(
    this._db, {
    this.appVersion = '',
    this.reminders,
    DateTime Function()? clock,
    this.beforeCommit,
  }) : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final String appVersion;
  final ReminderTransfer? reminders;
  final DateTime Function() _clock;

  /// Called inside the import's transaction, after everything is
  /// written: a test throws here to prove nothing is kept.
  @visibleForTesting
  final void Function()? beforeCommit;

  static String _fingerprint(SourceRow source) => sourceFingerprint(
    type: source.type.name,
    // A playlist file is the same playlist whatever folder it is in,
    // and on whichever system: the name after the last slash of either
    // kind (the file may move from Linux to Windows).
    server: source.type == SourceType.m3uFile
        ? source.url.split(RegExp(r'[/\\]')).last
        : source.url,
    username: source.username,
  );

  @override
  Future<Result<ExportSummary>> exportTo(String path) => Result.guard(() async {
    final file = await _gather();
    final text = file.encode();
    final bytes = await _writeInIsolate(path, text);
    return ExportSummary(
      path: path,
      sources: file.sources.length,
      favorites: file.sources.fold(0, (sum, s) => sum + s.favorites.length),
      bytes: bytes,
    );
  });

  Future<SettingsExport> _gather() async {
    final stored = await _db.settingsDao.readAll();
    final settings = <String, Object?>{};
    for (final MapEntry(key: page, value: key) in _pageKeys.entries) {
      final text = stored[key];
      if (text == null) continue;
      try {
        final value = jsonDecode(text);
        if (value is! Map) continue;
        settings[page] = {
          for (final MapEntry(:key, :value) in value.entries)
            if (!(_leftOut[page]?.contains(key) ?? false)) key: value,
        };
      } on FormatException {
        // A damaged value isn't worth carrying to another computer.
      }
    }
    final sources = await _db.sourcesDao.all();
    return SettingsExport(
      exportedAt: _clock(),
      appVersion: appVersion,
      settings: settings,
      sources: [for (final source in sources) await _gatherSource(source)],
    );
  }

  Future<ExportedSource> _gatherSource(SourceRow source) async {
    final id = source.id;
    final groups =
        await (_db.select(_db.favoriteGroups)
              ..where((t) => t.sourceId.equals(id))
              ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
            .get();
    final groupNames = {for (final group in groups) group.id: group.name};
    final favorites =
        await (_db.select(_db.favorites)
              ..where((t) => t.sourceId.equals(id))
              ..orderBy([
                (t) => OrderingTerm.asc(t.sortOrder.isNull()),
                (t) => OrderingTerm.asc(t.sortOrder),
                (t) => OrderingTerm.asc(t.addedAt),
              ]))
            .get();
    final categories =
        await (_db.select(_db.categories)
              ..where((t) => t.sourceId.equals(id))
              ..orderBy([
                (t) => OrderingTerm.asc(t.kind),
                (t) => OrderingTerm.asc(t.position),
              ]))
            .get();
    final channels =
        await (_db.select(_db.channels)..where(
              (t) =>
                  t.sourceId.equals(id) &
                  (t.isHidden.equals(true) | t.displayName.isNotNull()),
            ))
            .get();
    final mappings = await _db.epgDao.mappingsFor(id);
    return ExportedSource(
      name: source.name,
      type: source.type.name,
      fingerprint: _fingerprint(source),
      favoriteGroups: [
        for (final group in groups)
          ExportedFavoriteGroup(
            name: group.name,
            order: group.sortOrder,
            collapsed: group.collapsed,
          ),
      ],
      favorites: [
        for (final favorite in favorites)
          ExportedFavorite(
            type: favorite.itemType.name,
            key: favorite.remoteKey,
            group: groupNames[favorite.groupId],
            order: favorite.sortOrder,
            addedAt: favorite.addedAt,
          ),
      ],
      categories: [
        for (final category in categories)
          ExportedCategory(
            kind: category.kind.name,
            key: category.remoteKey,
            hidden: category.isHidden,
            name: category.displayName,
            order: category.sortOrder,
          ),
      ],
      channels: [
        for (final channel in channels)
          ExportedChannel(
            key: channel.remoteKey,
            hidden: channel.isHidden,
            name: channel.displayName,
          ),
      ],
      guideMatches: [
        for (final mapping in mappings)
          ExportedGuideMatch(
            channel: mapping.channelRemoteKey,
            xmltvId: mapping.xmltvId,
          ),
      ],
      reminders: await reminders?.export(id) ?? const [],
    );
  }

  @override
  Future<SettingsFileRead> read(String path) async {
    final SettingsExport file;
    try {
      file = await _readInIsolate(path);
    } on SettingsFileRefused catch (refused) {
      return SettingsFileUnusable(refused.problem, format: refused.format);
    } on Object catch (error) {
      return SettingsFileUnread(AppFailure.fromError(error));
    }
    final List<SourceRow> here;
    try {
      here = await _db.sourcesDao.all();
    } on Object catch (error) {
      return SettingsFileUnread(StorageFailure('$error'));
    }
    final byFingerprint = <String, SourceRow>{};
    for (final source in here) {
      // The first in the user's order, should two be the same account.
      byFingerprint.putIfAbsent(_fingerprint(source), () => source);
    }
    return SettingsFileReadable(
      ImportPlan(
        path: path,
        file: file,
        sources: [
          // The fingerprint holds the type, so a match is the same kind
          // of source.
          for (final exported in file.sources)
            ImportSourcePlan(
              exported: exported,
              sourceId: byFingerprint[exported.fingerprint]?.id,
              sourceName: byFingerprint[exported.fingerprint]?.name,
            ),
        ],
      ),
    );
  }

  @override
  Future<Result<ImportSummary>> apply(ImportPlan plan) => Result.guard(
    () => _db.transaction(() async {
      final pages = await _applySettings(plan.file.settings);
      var favorites = 0;
      var categories = 0;
      var channels = 0;
      var matches = 0;
      var reminded = 0;
      var notHere = 0;
      for (final source in plan.here) {
        final id = source.sourceId!;
        final exported = source.exported;
        favorites += await _applyFavorites(id, exported);
        final (taken, missing) = await _applyCategories(id, exported);
        categories += taken;
        notHere += missing;
        final (changed, gone) = await _applyChannels(id, exported);
        channels += changed;
        notHere += gone;
        matches += await _applyMatches(id, exported);
        if (reminders case final reminders?) {
          reminded += await reminders.import(id, exported.reminders);
        }
      }
      beforeCommit?.call();
      return ImportSummary(
        settingsPages: pages,
        sources: plan.here.length,
        skippedSources: plan.missing.length,
        favorites: favorites,
        categories: categories,
        channels: channels,
        guideMatches: matches,
        reminders: reminded,
        notHere: notHere,
      );
    }),
  );

  /// Replaces each page the file carries; what a page leaves out (the
  /// download folder) keeps this computer's value.
  Future<List<String>> _applySettings(Map<String, Object?> settings) async {
    final replaced = <String>[];
    for (final MapEntry(key: page, :value) in settings.entries) {
      final key = _pageKeys[page];
      if (key == null || value is! Map) continue;
      final next = Map<String, Object?>.of(value.cast<String, Object?>());
      final kept = _leftOut[page];
      if (kept != null) {
        Object? mine;
        try {
          final text = await _db.settingsDao.read(key);
          mine = text == null ? null : jsonDecode(text);
        } on FormatException {
          mine = null;
        }
        for (final field in kept) {
          next.remove(field);
          if (mine is Map && mine.containsKey(field)) {
            next[field] = mine[field];
          }
        }
      }
      await _db.settingsDao.write(key, jsonEncode(next));
      replaced.add(page);
    }
    return replaced;
  }

  Future<int> _applyFavorites(String sourceId, ExportedSource exported) async {
    // Groups first, by name: a favorite names its group.
    final groups = await (_db.select(
      _db.favoriteGroups,
    )..where((t) => t.sourceId.equals(sourceId))).get();
    final groupIds = {for (final group in groups) group.name: group.id};
    for (final group in exported.favoriteGroups) {
      final held = groupIds[group.name];
      if (held == null) {
        groupIds[group.name] = await _db
            .into(_db.favoriteGroups)
            .insert(
              FavoriteGroupsCompanion.insert(
                sourceId: sourceId,
                name: group.name,
                sortOrder: Value(group.order),
                collapsed: Value(group.collapsed),
              ),
            );
      } else {
        await (_db.update(
          _db.favoriteGroups,
        )..where((t) => t.id.equals(held))).write(
          FavoriteGroupsCompanion(
            sortOrder: Value(group.order),
            collapsed: Value(group.collapsed),
          ),
        );
      }
    }
    var taken = 0;
    for (final favorite in exported.favorites) {
      final type = UserItemType.values
          .where((t) => t.name == favorite.type && t != UserItemType.local)
          .firstOrNull;
      if (type == null) continue;
      final groupId = favorite.group == null ? null : groupIds[favorite.group];
      final held =
          await (_db.select(_db.favorites)..where(
                (t) =>
                    t.itemType.equalsValue(type) &
                    t.sourceId.equals(sourceId) &
                    t.remoteKey.equals(favorite.key),
              ))
              .getSingleOrNull();
      if (held == null) {
        await _db
            .into(_db.favorites)
            .insert(
              FavoritesCompanion.insert(
                itemType: type,
                sourceId: Value(sourceId),
                remoteKey: favorite.key,
                groupId: Value(groupId),
                sortOrder: Value(favorite.order),
                addedAt: favorite.addedAt ?? _clock(),
              ),
            );
      } else {
        // The file's place and group: it is the user's own arrangement.
        await (_db.update(
          _db.favorites,
        )..where((t) => t.id.equals(held.id))).write(
          FavoritesCompanion(
            groupId: Value(groupId),
            sortOrder: Value(favorite.order),
          ),
        );
      }
      taken++;
    }
    return taken;
  }

  /// Every category the file names and this source has takes the file's
  /// hidden flag, rename and place. Returns (taken, not here).
  Future<(int, int)> _applyCategories(
    String sourceId,
    ExportedSource exported,
  ) async {
    final held = await (_db.select(
      _db.categories,
    )..where((t) => t.sourceId.equals(sourceId))).get();
    final ids = {
      for (final category in held)
        (category.kind.name, category.remoteKey): category.id,
    };
    var taken = 0;
    var missing = 0;
    for (final category in exported.categories) {
      final id = ids[(category.kind, category.key)];
      if (id == null) {
        missing++;
        continue;
      }
      await (_db.update(_db.categories)..where((t) => t.id.equals(id))).write(
        CategoriesCompanion(
          isHidden: Value(category.hidden),
          displayName: Value(category.name),
          sortOrder: Value(category.order),
        ),
      );
      taken++;
    }
    return (taken, missing);
  }

  /// The channels the file lists (those hidden or renamed) take its
  /// values; channels it doesn't list are left as they are here.
  Future<(int, int)> _applyChannels(
    String sourceId,
    ExportedSource exported,
  ) async {
    var changed = 0;
    var missing = 0;
    for (final channel in exported.channels) {
      final rows =
          await (_db.update(_db.channels)..where(
                (t) =>
                    t.sourceId.equals(sourceId) &
                    t.remoteKey.equals(channel.key),
              ))
              .write(
                ChannelsCompanion(
                  isHidden: Value(channel.hidden),
                  displayName: Value(channel.name),
                ),
              );
      if (rows == 0) {
        missing++;
      } else {
        changed++;
      }
    }
    return (changed, missing);
  }

  Future<int> _applyMatches(String sourceId, ExportedSource exported) async {
    final now = _clock();
    for (final match in exported.guideMatches) {
      await _db.epgDao.setMapping(sourceId, match.channel, match.xmltvId, now);
    }
    return exported.guideMatches.length;
  }
}

/// Built here, at the top level, so the closure sent to the isolate
/// carries the path and the text and nothing of its caller: a method's
/// closure would carry the database with it, which can't be sent.
Future<int> _writeInIsolate(String path, String text) =>
    Isolate.run(() => _write(path, text));

Future<SettingsExport> _readInIsolate(String path) =>
    Isolate.run(() => _read(path));

/// Written beside the file, then renamed over it: a crash part-way never
/// leaves half a file under the name the user chose.
int _write(String path, String text) {
  File('$path.part')
    ..writeAsStringSync(text, flush: true)
    ..renameSync(path);
  return File(path).lengthSync();
}

/// Bigger than any real export by far: a file that size isn't ours, and
/// reading it whole would only waste memory.
const int _maxFileBytes = 64 * 1024 * 1024;

SettingsExport _read(String path) {
  final file = File(path);
  if (file.lengthSync() > _maxFileBytes) {
    throw const SettingsFileRefused(SettingsFileProblem.notOurs);
  }
  final String text;
  try {
    text = utf8.decode(file.readAsBytesSync());
  } on FormatException {
    throw const SettingsFileRefused(SettingsFileProblem.damaged);
  }
  return parseSettingsExport(text);
}

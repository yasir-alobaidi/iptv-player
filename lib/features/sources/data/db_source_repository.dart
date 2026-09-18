import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/secret_registry.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/core/secure/credential_store.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/db/daos/sources_dao.dart';
import 'package:iptv_player/features/sources/domain/source.dart';

/// Secure-store keys for sources start with this, which is how orphans
/// are told apart from anything else the app may keep there later.
const sourceSecretPrefix = 'source.';

/// [SourceRepository] over the `sources` table and a [CredentialStore].
///
/// What goes where (hard rule 3):
/// - the database gets the source with playlist and EPG URLs cut down to
///   their origin, the Xtream server without credentials, the Xtream
///   username, and `credential_ref`, the secure-store key;
/// - the secure store gets one JSON document per source holding the
///   password and the real playlist and EPG URLs. Playlist and EPG URLs go
///   there whole, whatever they look like: a token in a path is as secret
///   as `password=`, and no pattern can recognize every panel's.
///
/// Every secret the repository handles is also added to the
/// [SecretRegistry], so a log line that quotes one is masked even where
/// no pattern would catch it.
final class DbSourceRepository implements SourceRepository {
  new({
    required AppDatabase database,
    required this._store,
    required this._secrets,
    required this._log,
    DateTime Function()? clock,
    String Function()? newId,
  }) : _db = database,
       _clock = clock ?? _utcNow,
       _newId = newId ?? _randomId;

  final AppDatabase _db;
  final CredentialStore _store;
  final SecretRegistry _secrets;
  final AppLog _log;
  final DateTime Function() _clock;
  final String Function() _newId;

  static const _tag = 'sources';

  SourcesDao get _dao => _db.sourcesDao;

  @override
  Stream<List<Source>> watchAll() =>
      _dao.watchAll().map((rows) => rows.map(_toSource).toList());

  @override
  Future<Result<List<Source>>> all() =>
      _guard('list', () async => (await _dao.all()).map(_toSource).toList());

  @override
  Future<Result<Source?>> byId(String id) => _guard('read', () async {
    final row = await _dao.byId(id);
    return row == null ? null : _toSource(row);
  });

  @override
  Future<Result<Source>> add(SourceDraft draft) async {
    final problem = _validate(draft, requirePassword: true);
    if (problem != null) return Err(InvalidInputFailure(problem));

    final id = _newId();
    final secret = _SourceSecret.from(draft);
    final ref = secret.isEmpty ? null : '$sourceSecretPrefix$id';
    _register(draft.username, secret);

    // The secret first: a source row whose secret never got written would
    // be a source that can't sign in.
    if (ref != null) {
      final written = await _store.write(ref, secret.encode());
      if (written case Err(:final failure)) return Err(failure);
    }

    final now = _clock();
    final inserted = await _guard('add', () async {
      await _dao.upsert(
        SourcesCompanion.insert(
          id: id,
          type: draft.type,
          name: draft.name.trim(),
          url: _storedUrl(draft),
          username: Value(_blankToNull(draft.username)),
          credentialRef: Value(ref),
          epgUrl: Value(_maskedOrNull(draft.epgUrl)),
          userAgent: Value(_blankToNull(draft.userAgent)),
          liveFormat: Value(draft.liveFormat),
          epgOffsetMinutes: Value(draft.epgOffsetMinutes),
          refreshHours: Value(draft.refreshHours),
          maxConnectionsOverride: Value(draft.maxConnectionsOverride),
          sortOrder: Value(await _dao.nextSortOrder()),
          createdAt: now,
          updatedAt: now,
        ),
      );
      return _toSource((await _dao.byId(id))!);
    });

    if (inserted.isOk) {
      _log.info(_tag, 'Added source $id (${draft.type.name})');
    } else if (ref != null) {
      await _deleteSecret(ref, id);
    }
    return inserted;
  }

  @override
  Future<Result<Source>> update(String id, SourceDraft draft) async {
    final problem = _validate(draft, requirePassword: false);
    if (problem != null) return Err(InvalidInputFailure(problem));

    final existing = await _guard('read', () => _dao.byId(id));
    final row = existing.valueOrNull;
    if (row == null) {
      return Err(existing.failureOrNull ?? NotFoundFailure('source $id'));
    }
    if (row.type != draft.type) {
      return Err(InvalidInputFailure('a source cannot change its type'));
    }

    final previous = await _readSecret(row);
    if (previous case Err(:final failure)) return Err(failure);
    final old = previous.valueOrNull!;

    // A blank password in the form means "keep the one I have".
    final secret = _SourceSecret.from(draft, keepPassword: old.password);
    if (draft.type == SourceType.xtream && secret.password == null) {
      return Err(InvalidInputFailure('password'));
    }
    _register(draft.username, secret);

    final ref = secret.isEmpty ? null : '$sourceSecretPrefix$id';
    if (ref != null) {
      final written = await _store.write(ref, secret.encode());
      if (written case Err(:final failure)) return Err(failure);
    }

    final updated = await _guard('update', () async {
      await _dao.patch(
        id,
        SourcesCompanion(
          name: Value(draft.name.trim()),
          url: Value(_storedUrl(draft)),
          username: Value(_blankToNull(draft.username)),
          credentialRef: Value(ref),
          epgUrl: Value(_maskedOrNull(draft.epgUrl)),
          userAgent: Value(_blankToNull(draft.userAgent)),
          liveFormat: Value(draft.liveFormat),
          epgOffsetMinutes: Value(draft.epgOffsetMinutes),
          refreshHours: Value(draft.refreshHours),
          maxConnectionsOverride: Value(draft.maxConnectionsOverride),
          updatedAt: Value(_clock()),
        ),
      );
      return _toSource((await _dao.byId(id))!);
    });

    if (updated.isOk) {
      // An edit that no longer needs a secret (an EPG override removed
      // from a playlist file) leaves none behind.
      if (ref == null && row.credentialRef != null) {
        await _deleteSecret(row.credentialRef!, id);
      }
      _log.info(_tag, 'Updated source $id');
    } else if (ref != null && row.credentialRef != null) {
      // Put the old secret back, so the row and its secret still agree.
      await _store.write(row.credentialRef!, old.encode());
    }
    return updated;
  }

  @override
  Future<Result<void>> remove(String id) async {
    final existing = await _guard('read', () => _dao.byId(id));
    if (existing case Err(:final failure)) return Err(failure);
    final row = existing.valueOrNull;
    if (row == null) return const Ok(null);

    // The row first: once it is gone the source is gone for the user,
    // and its catalogue with it (foreign keys cascade). A secret the
    // keyring won't delete right now is pruned after the next sync.
    final removed = await _guard('remove', () => _dao.remove(id));
    if (removed.isOk) {
      _log.info(_tag, 'Removed source $id');
      if (row.credentialRef case final ref?) await _deleteSecret(ref, id);
    }
    // Secrets stay in the SecretRegistry for the rest of the session:
    // another source may share the value, and over-masking a log is
    // harmless where under-masking is not.
    return removed;
  }

  @override
  Future<Result<void>> reorder(List<String> idsInOrder) =>
      _guard('reorder', () async {
        await _db.transaction(() async {
          for (final (index, id) in idsInOrder.indexed) {
            await _dao.patch(id, SourcesCompanion(sortOrder: Value(index)));
          }
        });
      });

  @override
  Future<Result<SourceCredentials>> credentialsFor(String id) async {
    final existing = await _guard('read', () => _dao.byId(id));
    final row = existing.valueOrNull;
    if (row == null) {
      return Err(existing.failureOrNull ?? NotFoundFailure('source $id'));
    }
    final stored = await _readSecret(row);
    if (stored case Err(:final failure)) return Err(failure);
    final secret = stored.valueOrNull!;

    if (row.type == SourceType.xtream && secret.password == null) {
      // The keyring was reset or the entry deleted by hand: the user has
      // to type the password again.
      return Err(AuthFailure('no stored password for source $id'));
    }
    if (row.type == SourceType.m3uUrl && secret.url == null) {
      return Err(AuthFailure('no stored playlist URL for source $id'));
    }
    _register(row.username, secret);
    return Ok(
      SourceCredentials(
        url: secret.url ?? row.url,
        username: row.username,
        password: secret.password,
        epgUrl: secret.epgUrl ?? row.epgUrl,
      ),
    );
  }

  @override
  Future<Result<int>> pruneOrphanedSecrets() async {
    final listed = await _store.keys();
    if (listed case Err(:final failure)) return Err(failure);
    final rows = await _guard('list', _dao.all);
    if (rows case Err(:final failure)) return Err(failure);

    final inUse = {for (final row in rows.valueOrNull!) row.credentialRef};
    final orphans = listed.valueOrNull!
        .where((key) => key.startsWith(sourceSecretPrefix))
        .where((key) => !inUse.contains(key))
        .toList();
    for (final key in orphans) {
      final deleted = await _store.delete(key);
      if (deleted case Err(:final failure)) return Err(failure);
    }
    if (orphans.isNotEmpty) {
      _log.info(_tag, 'Pruned ${orphans.length} orphaned source secret(s)');
    }
    return Ok(orphans.length);
  }

  Future<Result<_SourceSecret>> _readSecret(SourceRow row) async {
    final ref = row.credentialRef;
    if (ref == null) return const Ok(_SourceSecret());
    final read = await _store.read(ref);
    return read.map(_SourceSecret.decode);
  }

  Future<void> _deleteSecret(String ref, String id) async {
    final deleted = await _store.delete(ref);
    if (deleted case Err(:final failure)) {
      _log.warning(
        _tag,
        'Could not delete the secret of source $id; it is pruned after the '
        'next sync (${failure.code})',
      );
    }
  }

  void _register(String? username, _SourceSecret secret) {
    for (final value in [
      username,
      secret.password,
      secret.url,
      secret.epgUrl,
      ..._credentialQueryValues(secret.url),
      ..._credentialQueryValues(secret.epgUrl),
    ]) {
      if (value != null) _secrets.add(value);
    }
  }

  Future<Result<T>> _guard<T>(String what, Future<T> Function() body) async {
    try {
      return Ok(await body());
    } on Object catch (error) {
      return Err(StorageFailure('$what source: $error'));
    }
  }

  static Source _toSource(SourceRow row) => Source(
    id: row.id,
    type: row.type,
    name: row.name,
    displayUrl: row.url,
    username: row.username,
    epgUrlDisplay: row.epgUrl,
    userAgent: row.userAgent,
    liveFormat: row.liveFormat,
    epgOffsetMinutes: row.epgOffsetMinutes,
    refreshHours: row.refreshHours,
    maxConnectionsOverride: row.maxConnectionsOverride,
    expiresAt: row.expiresAt,
    lastSyncedAt: row.lastSyncedAt,
    sortOrder: row.sortOrder,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
  );
}

/// What the `sources` row holds in its `url` column.
String _storedUrl(SourceDraft draft) => switch (draft.type) {
  SourceType.xtream => normalizeServerUrl(draft.url)!,
  SourceType.m3uUrl => displayOrigin(draft.url),
  SourceType.m3uFile => draft.url.trim(),
};

/// The display form of a playlist or EPG URL: its origin and an
/// ellipsis, `http://lists.example/…`. Not `redact()`: a token in a path
/// (`/p/9c2e81d4/list.m3u`) matches no pattern, so a masked URL can still
/// carry the secret, and only dropping everything after the host is sure.
String displayOrigin(String url) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null || uri.host.isEmpty) return '…';
  final port = uri.hasPort ? ':${uri.port}' : '';
  return '${uri.scheme}://${uri.host}$port/…';
}

/// The server part of an Xtream URL: scheme, host, port and any base path,
/// without user-info, query or fragment, and without a trailing slash.
/// `http://` is assumed when no scheme is given. Null when there is no
/// usable host, or the scheme is not http(s).
String? normalizeServerUrl(String input) {
  var text = input.trim();
  if (text.isEmpty) return null;
  if (!text.contains('://')) text = 'http://$text';
  final uri = Uri.tryParse(text);
  if (uri == null || uri.host.isEmpty) return null;
  if (uri.scheme != 'http' && uri.scheme != 'https') return null;
  final path = uri.path.replaceAll(RegExp(r'/+$'), '');
  return Uri(
    scheme: uri.scheme,
    host: uri.host,
    port: uri.hasPort ? uri.port : null,
    path: path,
  ).toString();
}

/// Why [draft] can't be saved, naming the field; null when it can.
String? _validate(SourceDraft draft, {required bool requirePassword}) {
  final name = draft.name.trim();
  if (name.isEmpty || name.length > 200) return 'name';
  if (draft.refreshHours < 1) return 'refresh hours';
  if (draft.epgOffsetMinutes.abs() > 24 * 60) return 'EPG offset';
  if ((draft.maxConnectionsOverride ?? 1) < 1) return 'connection limit';
  switch (draft.type) {
    case SourceType.xtream:
      if (normalizeServerUrl(draft.url) == null) return 'server';
      if (_blankToNull(draft.username) == null) return 'username';
      if (requirePassword && _blankToNull(draft.password) == null) {
        return 'password';
      }
    case SourceType.m3uUrl:
      final uri = Uri.tryParse(draft.url.trim());
      if (uri == null ||
          uri.host.isEmpty ||
          (uri.scheme != 'http' && uri.scheme != 'https')) {
        return 'playlist URL';
      }
    case SourceType.m3uFile:
      if (draft.url.trim().isEmpty) return 'file';
  }
  return null;
}

String? _blankToNull(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

String? _maskedOrNull(String? url) {
  final value = _blankToNull(url);
  return value == null ? null : displayOrigin(value);
}

/// Values of query parameters that look like credentials, so they are
/// masked wherever else they turn up (a stream URL in a different shape).
Iterable<String> _credentialQueryValues(String? url) {
  if (url == null) return const [];
  final uri = Uri.tryParse(url);
  if (uri == null) return const [];
  const names = {'username', 'user', 'password', 'pass', 'token', 'key'};
  return [
    for (final MapEntry(:key, :value) in uri.queryParameters.entries)
      if (names.contains(key.toLowerCase()) && value.isNotEmpty) value,
  ];
}

/// The JSON document kept in the secure store for one source.
final class _SourceSecret {
  const new({this.password, this.url, this.epgUrl});

  factory from(SourceDraft draft, {String? keepPassword}) => _SourceSecret(
    password: draft.type == SourceType.xtream
        ? _blankToNull(draft.password) ?? keepPassword
        : null,
    url: draft.type == SourceType.m3uUrl ? draft.url.trim() : null,
    epgUrl: _blankToNull(draft.epgUrl),
  );

  /// A missing or unreadable document reads as empty rather than failing:
  /// the caller then reports the missing value it actually needed.
  factory decode(String? json) {
    if (json == null) return const _SourceSecret();
    try {
      final map = jsonDecode(json);
      if (map is! Map<String, Object?>) return const _SourceSecret();
      String? field(String key) =>
          map[key] is String ? map[key]! as String : null;
      return _SourceSecret(
        password: field('password'),
        url: field('url'),
        epgUrl: field('epgUrl'),
      );
    } on FormatException {
      return const _SourceSecret();
    }
  }

  final String? password;
  final String? url;
  final String? epgUrl;

  bool get isEmpty => password == null && url == null && epgUrl == null;

  String encode() =>
      jsonEncode({'password': ?password, 'url': ?url, 'epgUrl': ?epgUrl});
}

DateTime _utcNow() => DateTime.now().toUtc();

final _random = Random.secure();

/// 128 random bits as hex: unique without coordination, and meaningless,
/// so an id in a log says nothing about the source.
String _randomId() => [
  for (var i = 0; i < 16; i++)
    _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
].join();

import 'package:drift/drift.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/db/user_tables.dart';
import 'package:iptv_player/features/live_tv/domain/channels.dart';

/// [ChannelRepository] over the `channels` table, its categories and the
/// favorites. Every list query is one SQL statement, so a 50,000-channel
/// source costs one indexed scan, never a Dart-side filter.
final class DbChannelRepository implements ChannelRepository {
  new(this._db, {this._clock = DateTime.now});

  final AppDatabase _db;
  final DateTime Function() _clock;

  static const _select =
      'c.id, c.source_id, c.remote_key, c.name, c.display_name, c.number, '
      'c.logo_url, c.category_id, c.epg_key, c.archive_days, c.is_hidden, '
      'f.id IS NOT NULL AS is_favorite';

  @override
  Stream<int> watchCount(ChannelQuery query) {
    final (where, variables) = _where(query);
    return _db
        .customSelect(
          'SELECT COUNT(*) AS n ${_from()} $where',
          variables: variables,
          readsFrom: _tables,
        )
        .watchSingle()
        .map((row) => row.read<int>('n'));
  }

  Set<ResultSetImplementation<dynamic, dynamic>> get _tables => {
    _db.channels,
    _db.categories,
    _db.favorites,
  };

  @override
  Future<Result<List<ChannelItem>>> range(
    ChannelQuery query,
    int offset,
    int limit,
  ) => Result.guard(() async {
    final (where, variables) = _where(query);
    final rows = await _db
        .customSelect(
          'SELECT $_select ${_from()} $where ${_order(query.sort)} '
          'LIMIT ? OFFSET ?',
          variables: [
            ...variables,
            Variable.withInt(limit),
            Variable.withInt(offset),
          ],
          readsFrom: _tables,
        )
        .get();
    return [for (final row in rows) _item(row)];
  });

  @override
  Future<Result<int?>> indexOf(ChannelQuery query, int id) =>
      Result.guard(() async {
        final (where, variables) = _where(query);
        final row = await _db
            .customSelect(
              'SELECT i FROM (SELECT c.id AS id, '
              'ROW_NUMBER() OVER (${_order(query.sort)}) - 1 AS i '
              '${_from()} $where) WHERE id = ?',
              variables: [...variables, Variable.withInt(id)],
              readsFrom: _tables,
            )
            .getSingleOrNull();
        return row?.read<int>('i');
      });

  @override
  Future<Result<ChannelItem?>> byNumber(String sourceId, int number) => _one(
    'c.source_id = ? AND c.number = ? AND c.is_hidden = 0',
    [Variable.withString(sourceId), Variable.withInt(number)],
  );

  @override
  Future<Result<ChannelItem?>> byRemoteKey(String sourceId, String remoteKey) =>
      _one('c.source_id = ? AND c.remote_key = ?', [
        Variable.withString(sourceId),
        Variable.withString(remoteKey),
      ]);

  Future<Result<ChannelItem?>> _one(
    String condition,
    List<Variable<Object>> variables,
  ) => Result.guard(() async {
    final row = await _db
        .customSelect(
          'SELECT $_select ${_from()} WHERE $condition '
          'ORDER BY c.position, c.id LIMIT 1',
          variables: variables,
          readsFrom: _tables,
        )
        .getSingleOrNull();
    return row == null ? null : _item(row);
  });

  @override
  Future<Result<void>> setFavorite(ChannelItem channel, {required bool on}) =>
      Result.guard(
        () => on
            ? _db.favoritesDao.add(
                UserItemType.live,
                channel.sourceId,
                channel.remoteKey,
                _clock(),
              )
            : _db.favoritesDao.remove(
                UserItemType.live,
                channel.sourceId,
                channel.remoteKey,
              ),
      );

  @override
  Future<Result<void>> setHidden(int id, {required bool hidden}) =>
      Result.guard(() => _db.channelsDao.setHidden(id, hidden: hidden));

  @override
  Future<Result<void>> rename(int id, String? name) =>
      Result.guard(() => _db.channelsDao.rename(id, name));

  static String _from() =>
      'FROM channels c '
      'LEFT JOIN categories k ON k.id = c.category_id '
      "LEFT JOIN favorites f ON f.item_type = 'live' "
      'AND f.source_id = c.source_id AND f.remote_key = c.remote_key';

  static (String, List<Variable<Object>>) _where(ChannelQuery query) {
    final clauses = <String>['c.source_id = ?'];
    final variables = <Variable<Object>>[Variable.withString(query.sourceId)];
    if (!query.showHidden) clauses.add('c.is_hidden = 0');
    switch (query.filter) {
      case AllChannels():
        clauses.add('(k.id IS NULL OR k.is_hidden = 0)');
      case FavoriteChannels():
        clauses.add('f.id IS NOT NULL');
      case CategoryChannels(:final categoryId):
        clauses.add('c.category_id = ?');
        variables.add(Variable.withInt(categoryId));
      case UncategorizedChannels():
        clauses.add('k.id IS NULL');
    }
    final text = query.text.trim();
    if (text.isNotEmpty) {
      clauses.add(r"COALESCE(c.display_name, c.name) LIKE ? ESCAPE '\'");
      final escaped = text
          .replaceAll(r'\', r'\\')
          .replaceAll('%', r'\%')
          .replaceAll('_', r'\_');
      variables.add(Variable.withString('%$escaped%'));
    }
    return ('WHERE ${clauses.join(' AND ')}', variables);
  }

  static String _order(ChannelSort sort) => switch (sort) {
    ChannelSort.number =>
      'ORDER BY c.number IS NULL, c.number, c.position, c.id',
    ChannelSort.name =>
      'ORDER BY COALESCE(c.display_name, c.name) COLLATE NOCASE, c.id',
  };

  static ChannelItem _item(QueryRow row) {
    final display = row.read<String?>('display_name');
    final name = row.read<String>('name');
    return ChannelItem(
      id: row.read<int>('id'),
      sourceId: row.read<String>('source_id'),
      remoteKey: row.read<String>('remote_key'),
      name: display ?? name,
      providerName: display == null ? null : name,
      number: row.read<int?>('number'),
      logoUrl: row.read<String?>('logo_url'),
      categoryId: row.read<int?>('category_id'),
      epgKey: row.read<String?>('epg_key'),
      archiveDays: row.read<int>('archive_days'),
      isHidden: row.read<bool>('is_hidden'),
      isFavorite: row.read<bool>('is_favorite'),
    );
  }
}

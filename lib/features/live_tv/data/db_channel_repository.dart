import 'package:drift/drift.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/db/user_tables.dart';
import 'package:iptv_player/features/live_tv/domain/channel_names.dart';
import 'package:iptv_player/features/live_tv/domain/channels.dart';

/// `channels c` as a `ChannelItem` reads it, with its favorite `f` (a
/// `LEFT JOIN favorites f` on the channel's source and remote key). Shared
/// by every query that lists channels (Live TV, search).
const channelColumns =
    'c.id, c.source_id, c.remote_key, c.name, c.display_name, '
    'c.clean_name, c.quality, c.number, c.logo_url, c.category_id, '
    'c.epg_key, c.archive_days, c.is_hidden, '
    'f.id IS NOT NULL AS is_favorite, f.group_id AS favorite_group_id';

/// The name a channel is shown by, and so sorted and filtered by
/// ([ChannelItem.name]'s order).
const channelShownName = 'COALESCE(c.display_name, c.clean_name, c.name)';

/// A row of [channelColumns].
ChannelItem channelFromRow(QueryRow row) {
  final display = row.read<String?>('display_name');
  final provider = row.read<String>('name');
  final name = display ?? row.read<String?>('clean_name') ?? provider;
  return ChannelItem(
    id: row.read<int>('id'),
    sourceId: row.read<String>('source_id'),
    remoteKey: row.read<String>('remote_key'),
    name: name,
    providerName: name == provider ? null : provider,
    isRenamed: display != null,
    quality: ChannelQuality.fromStored(row.read<String?>('quality')),
    number: row.read<int?>('number'),
    logoUrl: row.read<String?>('logo_url'),
    categoryId: row.read<int?>('category_id'),
    epgKey: row.read<String?>('epg_key'),
    archiveDays: row.read<int>('archive_days'),
    isHidden: row.read<bool>('is_hidden'),
    isFavorite: row.read<bool>('is_favorite'),
    favoriteGroupId: row.read<int?>('favorite_group_id'),
  );
}

/// [ChannelRepository] over the `channels` table, its categories and the
/// favorites. Every list query is one SQL statement, so a 50,000-channel
/// source costs one indexed scan, never a Dart-side filter.
final class DbChannelRepository implements ChannelRepository {
  new(this._db, {this._clock = DateTime.now});

  final AppDatabase _db;
  final DateTime Function() _clock;

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
    _db.favoriteGroups,
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
          'SELECT $channelColumns ${_from()} $where ${_order(query)} '
          'LIMIT ? OFFSET ?',
          variables: [
            ...variables,
            Variable.withInt(limit),
            Variable.withInt(offset),
          ],
          readsFrom: _tables,
        )
        .get();
    return [for (final row in rows) channelFromRow(row)];
  });

  @override
  Future<Result<int?>> indexOf(ChannelQuery query, int id) =>
      Result.guard(() async {
        final (where, variables) = _where(query);
        final row = await _db
            .customSelect(
              'SELECT i FROM (SELECT c.id AS id, '
              'ROW_NUMBER() OVER (${_order(query)}) - 1 AS i '
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
          'SELECT $channelColumns ${_from()} WHERE $condition '
          'ORDER BY c.position, c.id LIMIT 1',
          variables: variables,
          readsFrom: _tables,
        )
        .getSingleOrNull();
    return row == null ? null : channelFromRow(row);
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
      'AND f.source_id = c.source_id AND f.remote_key = c.remote_key '
      'LEFT JOIN favorite_groups fg ON fg.id = f.group_id';

  static (String, List<Variable<Object>>) _where(ChannelQuery query) {
    final clauses = <String>['c.source_id = ?'];
    final variables = <Variable<Object>>[Variable.withString(query.sourceId)];
    if (!query.showHidden && query.filter is! HiddenChannels) {
      clauses.add('c.is_hidden = 0');
    }
    switch (query.filter) {
      case AllChannels():
        clauses.add('(k.id IS NULL OR k.is_hidden = 0)');
      case FavoriteChannels():
        clauses.add('f.id IS NOT NULL');
      case FavoriteGroupChannels(:final groupId):
        clauses.add('f.group_id = ?');
        variables.add(Variable.withInt(groupId));
      case CategoryChannels(:final categoryId):
        clauses.add('c.category_id = ?');
        variables.add(Variable.withInt(categoryId));
      case UncategorizedChannels():
        clauses.add('k.id IS NULL');
      case HiddenChannels():
        clauses.add('c.is_hidden = 1');
    }
    final text = query.text.trim();
    if (text.isNotEmpty) {
      clauses.add("$channelShownName LIKE ? ESCAPE '\\'");
      final escaped = text
          .replaceAll(r'\', r'\\')
          .replaceAll('%', r'\%')
          .replaceAll('_', r'\_');
      variables.add(Variable.withString('%$escaped%'));
    }
    return ('WHERE ${clauses.join(' AND ')}', variables);
  }

  /// The favorites' "number" order is the user's: the groups in their
  /// order, the ones in no group last, and in each its channels in their
  /// place (the ones from before v7, with none, by when they were added).
  static String _order(ChannelQuery query) => switch (query.sort) {
    ChannelSort.number when isFavoritesFilter(query.filter) =>
      'ORDER BY fg.id IS NULL, fg.sort_order, fg.id, '
          'f.sort_order IS NULL, f.sort_order, f.added_at, f.id',
    ChannelSort.number =>
      'ORDER BY c.number IS NULL, c.number, c.position, c.id',
    ChannelSort.name => 'ORDER BY $channelShownName COLLATE NOCASE, c.id',
  };
}

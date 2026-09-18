import 'package:drift/drift.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/db/catalogue_tables.dart';

part 'channels_dao.g.dart';

@DriftAccessor(tables: [Channels])
class ChannelsDao extends DatabaseAccessor<AppDatabase>
    with _$ChannelsDaoMixin {
  new(super.attachedDatabase);

  /// One batch is one transaction; the sync engine hands in ~5,000 rows
  /// at a time (docs/02). Only provider-owned columns are rewritten on a
  /// conflict, so the user's rename and hidden flag survive.
  Future<void> upsertAll(List<ChannelsCompanion> rows) => batch(
    (b) => b.insertAll(
      channels,
      rows,
      onConflict: DoUpdate<$ChannelsTable, ChannelRow>.withExcluded(
        (old, excluded) => ChannelsCompanion.custom(
          categoryId: excluded.categoryId,
          number: excluded.number,
          name: excluded.name,
          logoUrl: excluded.logoUrl,
          epgKey: excluded.epgKey,
          archiveDays: excluded.archiveDays,
          streamUrl: excluded.streamUrl,
          extrasJson: excluded.extrasJson,
          addedAt: excluded.addedAt,
          position: excluded.position,
          seenRun: excluded.seenRun,
        ),
        target: [channels.sourceId, channels.remoteKey],
      ),
    ),
  );

  /// Deletes the source's channels that sync run [runId] did not see.
  Future<int> sweep(String sourceId, int runId) =>
      (delete(channels)..where(
            (t) =>
                t.sourceId.equals(sourceId) &
                (t.seenRun.isNull() | t.seenRun.equals(runId).not()),
          ))
          .go();

  Future<int> countFor(String sourceId) {
    final total = channels.id.count();
    return (selectOnly(channels)
          ..addColumns([total])
          ..where(channels.sourceId.equals(sourceId)))
        .map((row) => row.read(total) ?? 0)
        .getSingle();
  }

  Future<ChannelRow?> byRemoteKey(String sourceId, String remoteKey) =>
      (select(channels)..where(
            (t) => t.sourceId.equals(sourceId) & t.remoteKey.equals(remoteKey),
          ))
          .getSingleOrNull();

  Future<void> setHidden(int id, {required bool hidden}) =>
      (update(channels)..where((t) => t.id.equals(id))).write(
        ChannelsCompanion(isHidden: Value(hidden)),
      );

  /// Null or blank restores the provider's name.
  Future<void> rename(int id, String? displayName) {
    final trimmed = displayName?.trim();
    return (update(channels)..where((t) => t.id.equals(id))).write(
      ChannelsCompanion(
        displayName: Value(trimmed == null || trimmed.isEmpty ? null : trimmed),
      ),
    );
  }
}

import 'package:drift/drift.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/db/epg_tables.dart';

part 'maintenance_dao.g.dart';

/// The database's pages, as SQLite counts them: `pages` of `pageSize`
/// bytes, `freePages` of them used by nothing (what a compaction gives
/// back), and the `file` they are in; null for an in-memory database.
typedef DatabasePages = ({
  int pageSize,
  int pages,
  int freePages,
  String? file,
});

/// The tidy-up's own statements (ADR-031): the guide's run records cut
/// back, and the file measured and compacted. Its own DAO rather than the
/// guide's: nothing here is the guide's business but the one delete.
@DriftAccessor(tables: [EpgImports, EpgChannelsStaging, EpgProgramsStaging])
class MaintenanceDao extends DatabaseAccessor<AppDatabase>
    with _$MaintenanceDaoMixin {
  new(super.attachedDatabase);

  /// Keeps each source's [kept] newest guide imports, and, older than
  /// those, every one still read or pointed at: the live one (Settings →
  /// Guide's counts, the guide's own cache), one still running, and one
  /// whose staged rows are still there (they reference it, and would go
  /// with it). Returns how many went.
  Future<int> pruneGuideImports({required int kept}) => customUpdate(
    'DELETE FROM epg_imports WHERE id IN (SELECT id FROM (SELECT id, '
    'ROW_NUMBER() OVER (PARTITION BY source_id ORDER BY id DESC) AS n '
    'FROM epg_imports) WHERE n > ?) '
    "AND is_live = 0 AND outcome != 'running' "
    'AND NOT EXISTS (SELECT 1 FROM epg_channels_staging c '
    'WHERE c.import_run = epg_imports.id) '
    'AND NOT EXISTS (SELECT 1 FROM epg_programs_staging p '
    'WHERE p.import_run = epg_imports.id)',
    variables: [Variable.withInt(kept)],
    updates: {epgImports},
    updateKind: UpdateKind.delete,
  );

  Future<DatabasePages> pages() async {
    final row = await customSelect(
      'SELECT p.page_size, c.page_count, f.freelist_count, '
      "(SELECT file FROM pragma_database_list WHERE name = 'main') AS file "
      'FROM pragma_page_size() p, pragma_page_count() c, '
      'pragma_freelist_count() f',
    ).getSingle();
    final file = row.readNullable<String>('file');
    return (
      pageSize: row.read<int>('page_size'),
      pages: row.read<int>('page_count'),
      freePages: row.read<int>('freelist_count'),
      file: file == null || file.isEmpty ? null : file,
    );
  }

  /// Whether an imported guide is in place, any source's: its next
  /// import takes up again about a guide's worth of the free pages.
  Future<bool> hasGuide() async {
    final row = await customSelect(
      'SELECT EXISTS (SELECT 1 FROM epg_programs) AS has_guide',
    ).getSingle();
    return row.read<bool>('has_guide');
  }

  /// Rewrites the file without its free pages, on the writing connection:
  /// every write waits meanwhile, so the caller runs it only when nothing
  /// else is at work.
  Future<void> vacuum() => customStatement('VACUUM');

  /// Copies the write-ahead log into the file and cuts it to nothing.
  /// False when something kept it from finishing.
  ///
  /// On the writing connection, queued behind the writes under way: as a
  /// select it would go to a reader (the read pool), and there it gave
  /// up at once beside a write, or held the log's lock while a write
  /// failed with "database is locked".
  Future<bool> truncateLog() => attachedDatabase.exclusively(() async {
    final row = await customSelect('PRAGMA wal_checkpoint(TRUNCATE)')
        .getSingle();
    return row.read<int>('busy') == 0;
  });
}

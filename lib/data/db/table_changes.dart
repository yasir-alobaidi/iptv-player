import 'package:drift/drift.dart';

/// Emits once at once, then whenever any of [tables] changes: a query
/// stream, so drift runs one read for a burst of writes and catches up
/// after its listener was paused (a screen out of view).
///
/// The query names its tables. drift shares query streams by their SQL
/// and variables alone, so every plain `SELECT 1` was one stream watching
/// the tables of whichever was made first — Home's favorite channels
/// missed a channel hidden elsewhere.
Stream<void> tableChanges(
  DatabaseConnectionUser db,
  Set<ResultSetImplementation<dynamic, dynamic>> tables,
) {
  final names = [for (final table in tables) table.entityName]..sort();
  return db
      .customSelect(
        "SELECT '${names.join(',')}' AS watching",
        readsFrom: tables,
      )
      .watch();
}

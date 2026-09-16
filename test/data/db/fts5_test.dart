import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/data/db/app_database.dart';

/// Phase 6's search is FTS5, and sqlite3_flutter_libs is end-of-life
/// (ADR-002): we rely on the binaries the `sqlite3` package ships being
/// built with `SQLITE_ENABLE_FTS5`. This fails loudly if that changes,
/// rather than in Phase 6.
void main() {
  test('the bundled sqlite has FTS5 compiled in', () async {
    final database = AppDatabase.memory();
    addTearDown(database.close);

    await database.customStatement(
      'CREATE VIRTUAL TABLE fts_probe USING fts5(body)',
    );
    await database.customStatement(
      "INSERT INTO fts_probe(body) VALUES ('Sky Sports Ultra HD')",
    );

    final matches = await database
        .customSelect(
          "SELECT body FROM fts_probe WHERE fts_probe MATCH 'sports'",
        )
        .get();

    expect(matches, hasLength(1));
  });
}

import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/data/db/app_database.dart';

import 'generated/schema.dart';

/// Guards the committed `drift_schemas/app/drift_schema_v1.json` dump
/// against a table changed without a version bump. Every schema change
/// from here on adds a version, a migration, and a case below
/// (docs/02-providers-and-data.md).
void main() {
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  test('the live schema still matches the committed v1 dump', () async {
    final connection = await verifier.startAt(1);
    final database = AppDatabase(connection);
    addTearDown(database.close);

    await verifier.migrateAndValidate(database, 1);
  });
}

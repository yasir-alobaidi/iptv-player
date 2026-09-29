// Phase 6 step 8's review of a real panel's names (plan decision 2): the
// panel in ~/.config/iptv-player-dev/real_provider.json synced into a
// throwaway database — the catalogue's API calls only, never a stream —
// then, in build/real_provider_run/names/:
//
// - channels.tsv: every channel's provider name, the name shown and its
//   badge, and a line of counts;
// - channels_changed.txt: the ones cleanup changed, for reading through;
// - movies.txt: how many movie names carry which kind of tag, with
//   examples of each — whether movies need a cleanup of their own.
//
// Never run without the user's go-ahead (their plan allows one
// connection, and a sync is theirs to allow):
//
//     flutter test --tags real_provider --run-skipped \
//       test/tools/real_panel_names_test.dart
@Tags(['real_provider'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/secret_registry.dart';
import 'package:iptv_player/core/secure/credential_store.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/sync/sync_engine.dart';
import 'package:iptv_player/features/sources/data/db_source_repository.dart';
import 'package:iptv_player/features/sources/domain/source.dart';
import 'package:logger/logger.dart';

final _login = File(
  Platform.environment['IPTV_REAL_PROVIDER'] ??
      '${Platform.environment['HOME']}/.config/iptv-player-dev/real_provider.json',
);

void main() {
  setUpAll(() => HttpOverrides.global = null);

  test(
    "the cleanup over a real panel's channel names, and its movie names",
    () async {
      final login = jsonDecode(_login.readAsStringSync()) as Map;
      final directory = await Directory.systemTemp.createTemp('real_names');
      addTearDown(() => directory.delete(recursive: true));
      final db = AppDatabase(await openAppDatabase(directory));
      addTearDown(db.close);
      final secrets = SecretRegistry();
      final log = AppLog(output: _Silent(), secrets: secrets);
      addTearDown(log.close);
      final sources = DbSourceRepository(
        database: db,
        store: InMemoryCredentialStore(),
        secrets: secrets,
        log: log,
      );
      final source = (await sources.add(
        SourceDraft(
          type: SourceType.xtream,
          name: 'Real panel',
          url: '${login['server']}',
          username: '${login['username']}',
          password: '${login['password']}',
        ),
      )).valueOrNull!;
      final engine = SyncEngine(database: db, sources: sources, log: log);
      addTearDown(engine.dispose);
      final synced = await engine.sync(source.id);
      expect(synced.isOk, isTrue, reason: '${synced.failureOrNull}');

      final out = Directory('build/real_provider_run/names')
        ..createSync(recursive: true);

      // ── Channels: the provider's name, the name shown, the badge.
      final channels = await db
          .customSelect(
            'SELECT name, clean_name, quality FROM channels '
            'WHERE source_id = ? ORDER BY position, id',
            variables: [Variable.withString(source.id)],
          )
          .get();
      var changed = 0;
      var badged = 0;
      var unchanged = 0;
      final table = StringBuffer('provider\tshown\tbadge\n');
      final diff = StringBuffer();
      for (final row in channels) {
        final provider = row.read<String>('name');
        final shown = row.read<String?>('clean_name') ?? provider;
        final badge = row.read<String?>('quality') ?? '';
        table.writeln('$provider\t$shown\t$badge');
        if (badge.isNotEmpty) badged++;
        if (shown == provider) {
          unchanged++;
        } else {
          changed++;
          diff.writeln(
            '$provider  →  $shown${badge.isEmpty ? '' : '  [$badge]'}',
          );
        }
      }
      final counts =
          '${channels.length} channels: $changed changed, $unchanged as '
          'the provider wrote them, $badged with a badge';
      File('${out.path}/channels.tsv').writeAsStringSync('$table# $counts\n');
      File('${out.path}/channels_changed.txt').writeAsStringSync('$diff');

      // ── Movies: which kinds of tag their names carry.
      final movies = [
        for (final row
            in await db
                .customSelect(
                  'SELECT name FROM movies WHERE source_id = ? ORDER BY id',
                  variables: [Variable.withString(source.id)],
                )
                .get())
          row.read<String>('name'),
      ];
      final kinds = <String, RegExp>{
        'a leading country or language tag (UK: / |EN| / [FR] / EN -)': RegExp(
          r'^\s*(\|[^|]{1,6}\||\[[^\]]{1,6}\]|[A-Z]{2,3}\s*[:|]|[A-Z]{2,3}\s+-\s)',
        ),
        'a resolution or quality tag (HD, FHD, 4K, 1080p, …)': RegExp(
          r'\b(SD|HD|FHD|UHD|4K|480p|576p|720p|1080p|2160p|ᴴᴰ|ᶠᴴᴰ|⁴ᴷ)\b',
          caseSensitive: false,
        ),
        'a release name (dots for spaces)': RegExp(r'\w\.\w+\.\w'),
        'the year in parentheses': RegExp(r'\((19|20)\d\d\)'),
        'the year after a dash (– 2019)': RegExp(r'\s[-–]\s(19|20)\d\d\s*$'),
        'a codec or source (x264, HEVC, WEB-DL, BluRay)': RegExp(
          r'\b(x26[45]|h\.?26[45]|hevc|web-?dl|web-?rip|blu-?ray|bdrip|hdrip|dvdrip)\b',
          caseSensitive: false,
        ),
        'an HTML entity (&amp; …)': RegExp(r'&[a-z]+;|&#\d+;'),
      };
      final report = StringBuffer(
        '${movies.length} movies. Names by kind of tag (a name can have '
        'several):\n\n',
      );
      for (final MapEntry(key: kind, value: pattern) in kinds.entries) {
        final hits = movies.where(pattern.hasMatch).toList();
        report
          ..writeln('## $kind: ${hits.length}')
          ..writeAll([for (final name in hits.take(25)) '  $name\n'])
          ..writeln();
      }
      report
        ..writeln('## 40 names picked evenly through the list')
        ..writeAll([
          for (var i = 0; i < 40 && movies.isNotEmpty; i++)
            '  ${movies[i * movies.length ~/ 40]}\n',
        ]);
      File('${out.path}/movies.txt').writeAsStringSync('$report');

      // The run's summary, for whoever ran it.
      // ignore: avoid_print
      print('$counts; ${movies.length} movies. See ${out.path}/.');
    },
    timeout: const Timeout(Duration(minutes: 5)),
    skip: _login.existsSync() ? false : 'no login file',
  );
}

class _Silent extends LogOutput {
  @override
  void output(OutputEvent event) {}
}

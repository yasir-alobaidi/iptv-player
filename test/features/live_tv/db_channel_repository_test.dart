import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/features/live_tv/data/db_channel_repository.dart';
import 'package:iptv_player/features/live_tv/domain/channels.dart';
import 'package:iptv_player/features/sources/domain/categories.dart';
import 'package:iptv_player/features/sources/domain/source.dart';

void main() {
  late AppDatabase db;
  late DbChannelRepository repo;
  late int sports;
  late int news;
  final t0 = DateTime.utc(2026, 9, 19);

  setUp(() async {
    db = AppDatabase.memory();
    repo = DbChannelRepository(db, clock: () => t0);
    for (final id in ['src', 'other']) {
      await db
          .into(db.sources)
          .insert(
            SourcesCompanion.insert(
              id: id,
              type: SourceType.xtream,
              name: id,
              url: 'http://$id.test',
              createdAt: t0,
              updatedAt: t0,
            ),
          );
    }
    sports = await db
        .into(db.categories)
        .insert(
          CategoriesCompanion.insert(
            sourceId: 'src',
            kind: CatalogueKind.live,
            remoteKey: '1',
            name: 'Sports',
          ),
        );
    news = await db
        .into(db.categories)
        .insert(
          CategoriesCompanion.insert(
            sourceId: 'src',
            kind: CatalogueKind.live,
            remoteKey: '2',
            name: 'News',
            isHidden: const Value(true),
          ),
        );
    ChannelsCompanion row(
      String key,
      String name, {
      int? number,
      int? category,
      int position = 0,
      String source = 'src',
    }) => ChannelsCompanion.insert(
      sourceId: source,
      remoteKey: key,
      name: name,
      number: Value(number),
      categoryId: Value(category),
      position: Value(position),
    );
    await db.channelsDao.upsertAll([
      row('a', 'Arena Sports 2', number: 202, category: sports, position: 1),
      row('b', 'Arena Sports 1', number: 201, category: sports, position: 2),
      row('c', 'World News', number: 301, category: news, position: 3),
      row('d', 'Zebra TV', position: 4),
      row('e', 'alpha_50%', number: 5, position: 5),
      row('x', 'Other source', number: 1, source: 'other'),
    ]);
  });
  tearDown(() => db.close());

  Future<List<String>> keys(ChannelQuery query) async => [
    for (final c in (await repo.range(query, 0, 100)).valueOrNull!) c.remoteKey,
  ];

  test('All leaves out hidden categories; numbers first, then order', () async {
    const query = ChannelQuery(sourceId: 'src');
    expect(await keys(query), ['e', 'b', 'a', 'd']);
    expect(await repo.watchCount(query).first, 4);
  });

  test('a category, and the uncategorized', () async {
    expect(
      await keys(ChannelQuery(sourceId: 'src', filter: CategoryChannels(news))),
      ['c'],
    );
    expect(
      await keys(
        const ChannelQuery(sourceId: 'src', filter: UncategorizedChannels()),
      ),
      ['e', 'd'],
    );
  });

  test('sort by name ignores case', () async {
    expect(
      await keys(const ChannelQuery(sourceId: 'src', sort: ChannelSort.name)),
      ['e', 'b', 'a', 'd'],
    );
  });

  test(
    'the text filter matches anywhere and takes % and _ literally',
    () async {
      expect(await keys(const ChannelQuery(sourceId: 'src', text: 'sports')), [
        'b',
        'a',
      ]);
      expect(await keys(const ChannelQuery(sourceId: 'src', text: '_50%')), [
        'e',
      ]);
      expect(await keys(const ChannelQuery(sourceId: 'src', text: '%')), ['e']);
    },
  );

  test(
    'favorites: set, listed whatever their category, and counted live',
    () async {
      const favorites = ChannelQuery(
        sourceId: 'src',
        filter: FavoriteChannels(),
      );
      final counts = <int>[];
      final watching = repo.watchCount(favorites).listen(counts.add);
      addTearDown(watching.cancel);
      final c = (await repo.byRemoteKey('src', 'c')).valueOrNull!;

      await repo.setFavorite(c, on: true);
      await pumpEventQueue();

      expect(await keys(favorites), ['c']);
      expect(
        (await repo.byRemoteKey('src', 'c')).valueOrNull!.isFavorite,
        isTrue,
      );
      expect(counts.last, 1);

      await repo.setFavorite(c, on: false);
      await pumpEventQueue();
      expect(counts.last, 0);
    },
  );

  test('a hidden channel is left out unless asked for', () async {
    final b = (await repo.byRemoteKey('src', 'b')).valueOrNull!;
    await repo.setHidden(b.id, hidden: true);

    expect(await keys(const ChannelQuery(sourceId: 'src')), ['e', 'a', 'd']);
    expect(await keys(const ChannelQuery(sourceId: 'src', showHidden: true)), [
      'e',
      'b',
      'a',
      'd',
    ]);
    expect((await repo.byNumber('src', 201)).valueOrNull, isNull);
  });

  test('rename shows the new name and keeps the provider name', () async {
    final a = (await repo.byRemoteKey('src', 'a')).valueOrNull!;
    await repo.rename(a.id, '  My sports ');

    final renamed = (await repo.byRemoteKey('src', 'a')).valueOrNull!;
    expect(renamed.name, 'My sports');
    expect(renamed.providerName, 'Arena Sports 2');
  });

  test('indexOf, byNumber', () async {
    const query = ChannelQuery(sourceId: 'src');
    final a = (await repo.byRemoteKey('src', 'a')).valueOrNull!;
    final c = (await repo.byRemoteKey('src', 'c')).valueOrNull!;

    expect((await repo.indexOf(query, a.id)).valueOrNull, 2);
    expect((await repo.indexOf(query, c.id)).valueOrNull, isNull);
    expect((await repo.byNumber('src', 202)).valueOrNull?.remoteKey, 'a');
    expect((await repo.byNumber('src', 999)).valueOrNull, isNull);
  });

  test('a window of a large list', () async {
    await db.channelsDao.upsertAll([
      for (var i = 0; i < 2000; i++)
        ChannelsCompanion.insert(
          sourceId: 'other',
          remoteKey: 'k$i',
          name: 'Ch $i',
          number: Value(i + 10),
        ),
    ]);
    const query = ChannelQuery(sourceId: 'other');

    final window = (await repo.range(query, 1000, 50)).valueOrNull!;

    expect(window, hasLength(50));
    expect(window.first.number, 1009);
    expect(await repo.watchCount(query).first, 2001);
  });
}

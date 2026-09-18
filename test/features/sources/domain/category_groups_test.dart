import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/features/sources/domain/categories.dart';
import 'package:iptv_player/features/sources/domain/category_groups.dart';

void main() {
  group('categoryTag', () {
    for (final (name, code, rest) in [
      ('UK | Sports', 'UK', 'Sports'),
      ('UK: News', 'UK', 'News'),
      ('US - Movies', 'US', 'Movies'),
      ('|AR| MBC', 'AR', 'MBC'),
      ('[FR] Cinéma', 'FR', 'Cinéma'),
      ('(DE) Kinder', 'DE', 'Kinder'),
      ('USA ▎ Local', 'USA', 'Local'),
      ('EX-YU • Sport', 'EX-YU', 'Sport'),
      ('UK|Kids', 'UK', 'Kids'),
      ('TR » Ulusal', 'TR', 'Ulusal'),
    ]) {
      test('"$name" → $code / $rest', () {
        final tag = categoryTag(name);
        expect(tag?.code, code);
        expect(tag?.rest, rest);
      });
    }

    for (final name in [
      'Sports',
      'TV Shows',
      '4K | Sports',
      'uk | sports',
      'UK |',
      'ABCD | Too long',
      '',
    ]) {
      test('"$name" has no tag', () => expect(categoryTag(name), isNull));
    }
  });

  CategoryChoice c(int id, String name, {bool hidden = false, int n = 10}) =>
      CategoryChoice(id: id, name: name, isHidden: hidden, itemCount: n);

  test('clusters by tag in first-use order, untagged last', () {
    final groups = groupCategories([
      c(1, 'Music'),
      c(2, 'US | News'),
      c(3, 'UK | Sports'),
      c(4, 'US | Sports'),
      c(5, 'UK | News'),
      c(6, 'Regional'),
    ]);

    expect(
      [for (final g in groups) g.label],
      ['United States', 'United Kingdom', untaggedGroupLabel],
    );
    expect(
      [for (final e in groups[0].entries) e.shortName],
      ['News', 'Sports'],
    );
    expect(groups[2].code, isNull);
    expect(
      [for (final e in groups[2].entries) e.shortName],
      ['Music', 'Regional'],
    );
  });

  test('a tag only one category uses is no cluster', () {
    final groups = groupCategories([
      c(1, 'VIP | Everything'),
      c(2, 'UK | Sports'),
      c(3, 'UK | News'),
    ]);

    expect(groups.map((g) => g.label), ['United Kingdom', untaggedGroupLabel]);
    expect(groups.last.entries.single.shortName, 'VIP | Everything');
  });

  test('an unknown tag is its own label', () {
    final groups = groupCategories([c(1, 'XY | One'), c(2, 'XY | Two')]);
    expect(groups.single.label, 'XY');
  });

  test('counts what is on', () {
    final group = groupCategories([
      c(1, 'UK | A', n: 5),
      c(2, 'UK | B', hidden: true, n: 7),
    ]).single;

    expect(group.visibleCount, 1);
    expect(group.itemCount, 12);
    expect(group.visibleItemCount, 5);
  });

  test('CategoryList counts the uncategorized as always shown', () {
    final list = CategoryList(
      categories: [c(1, 'A', n: 5), c(2, 'B', hidden: true, n: 7)],
      uncategorized: 3,
    );
    expect(list.visibleCount, 1);
    expect(list.itemCount, 15);
    expect(list.visibleItemCount, 8);
  });
}

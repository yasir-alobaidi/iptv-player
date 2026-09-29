import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/features/favorites/domain/favorite_layout.dart';
import 'package:iptv_player/features/favorites/domain/favorites.dart';
import 'package:iptv_player/features/live_tv/domain/channels.dart';

ChannelItem _c(int id, [int? group]) => ChannelItem(
  id: id,
  sourceId: 's',
  remoteKey: '$id',
  name: 'C$id',
  isFavorite: true,
  favoriteGroupId: group,
);

FavoriteGroup _g(int id, {bool collapsed = false}) =>
    FavoriteGroup(id: id, sourceId: 's', name: 'G$id', collapsed: collapsed);

String _show(List<FavoriteEntry> entries) => [
  for (final e in entries)
    switch (e) {
      FavoriteHeader(:final group) => '[${group?.name ?? '-'}]',
      FavoriteChannel(:final channel) => channel.name,
    },
].join(' ');

void main() {
  final groups = [_g(1), _g(2)];
  final channels = [_c(10, 1), _c(11, 1), _c(20, 2), _c(30), _c(31)];

  group('favoriteEntries', () {
    test('groups, then Ungrouped once a group exists', () {
      expect(
        _show(favoriteEntries(groups, channels)),
        '[G1] C10 C11 [G2] C20 [-] C30 C31',
      );
    });

    test('no group: no headers; a collapsed group: its header only', () {
      expect(_show(favoriteEntries(const [], [_c(1), _c(2)])), 'C1 C2');
      expect(
        _show(favoriteEntries([_g(1, collapsed: true), _g(2)], channels)),
        '[G1] [G2] C20 [-] C30 C31',
      );
    });

    test('an empty group still shows; no Ungrouped header with none', () {
      expect(
        _show(favoriteEntries([_g(1), _g(3)], [_c(10, 1)])),
        '[G1] C10 [G3]',
      );
    });
  });

  group('keyboardMove', () {
    FavoritePlace? move(int id, {required bool down}) => keyboardMove(
      groups,
      channels,
      channels.firstWhere((c) => c.id == id),
      down: down,
    );

    test('along a group', () {
      expect(move(10, down: true), (groupId: 1, index: 1));
      expect(move(11, down: false), (groupId: 1, index: 0));
      expect(move(31, down: false), (groupId: null, index: 0));
    });

    test("past a group's edge into the next, or the one before's end", () {
      expect(move(11, down: true), (groupId: 2, index: 0));
      expect(move(20, down: true), (groupId: null, index: 0));
      expect(move(30, down: false), (groupId: 2, index: 1));
      expect(move(20, down: false), (groupId: 1, index: 2));
    });

    test('nowhere past either end', () {
      expect(move(10, down: false), isNull);
      expect(move(31, down: true), isNull);
    });
  });

  group('dropPlace', () {
    final entries = favoriteEntries(groups, channels);
    // [G1] C10 C11 [G2] C20 [-] C30 C31
    int at(String name) => entries.indexWhere(
      (e) => e is FavoriteChannel && e.channel.name == name,
    );

    test('within a group', () {
      expect(dropPlace(entries, at('C10'), 2), (groupId: 1, index: 1));
    });

    test('takes the group of the header above where it lands', () {
      // C10 dropped just under [G2]'s header.
      expect(dropPlace(entries, at('C10'), 3), (groupId: 2, index: 0));
      // C31 dropped between C10 and C11.
      expect(dropPlace(entries, at('C31'), 2), (groupId: 1, index: 1));
      // C20 dropped at the very end.
      expect(dropPlace(entries, at('C20'), entries.length - 1), (
        groupId: null,
        index: 2,
      ));
    });

    test('above the first header: the first group, at its start', () {
      expect(dropPlace(entries, at('C30'), 0), (groupId: 1, index: 0));
    });

    test('no groups: its place in the one list', () {
      final flat = favoriteEntries(const [], [_c(1), _c(2), _c(3)]);
      expect(dropPlace(flat, 0, 2), (groupId: null, index: 2));
    });
  });
}

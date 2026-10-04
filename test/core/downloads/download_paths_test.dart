import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/downloads/download_paths.dart';
import 'package:iptv_player/core/downloads/download_task.dart';
import 'package:iptv_player/core/library/library_item.dart';

void main() {
  const folder = '/home/me/Videos/IPTV Player';

  DownloadRequest movie(String title, {int? year, String? ext = 'mkv'}) =>
      DownloadRequest(
        sourceId: 's',
        type: VodType.movie,
        remoteKey: '1',
        title: title,
        year: year,
        extension: ext,
      );

  DownloadRequest episode(
    String title, {
    String? show = 'Glass Tide',
    int season = 2,
    int number = 4,
  }) => DownloadRequest(
    sourceId: 's',
    type: VodType.episode,
    remoteKey: '9',
    title: title,
    showTitle: show,
    season: season,
    episode: number,
    extension: 'mp4',
  );

  group("docs/09's layout", () {
    test('a movie in its own folder, named with its year', () {
      expect(
        downloadTarget(folder, movie('Copper Hollow', year: 2025)),
        '$folder/Movies/Copper Hollow (2025)/Copper Hollow (2025).mkv',
      );
      expect(
        downloadTarget(folder, movie('Copper Hollow')),
        '$folder/Movies/Copper Hollow/Copper Hollow.mkv',
      );
    });

    test('an episode under its show and season', () {
      expect(
        downloadTarget(folder, episode('Undertow')),
        '$folder/Series/Glass Tide/Season 02/Glass Tide - S02E04 - Undertow.mp4',
      );
    });

    test('an episode whose title says nothing goes without it', () {
      for (final title in ['', 'Episode 4', 'E04', 'ep 4', '  episode 04 ']) {
        expect(
          downloadTarget(folder, episode(title)),
          '$folder/Series/Glass Tide/Season 02/Glass Tide - S02E04.mp4',
          reason: title,
        );
      }
      expect(
        downloadTarget(folder, episode('Episode 5')),
        '$folder/Series/Glass Tide/Season 02/Glass Tide - S02E04 - '
        'Episode 5.mp4',
      );
    });

    test("the extension is the provider's, else mp4", () {
      for (final (ext, want) in [
        ('MKV', 'mkv'),
        ('.avi', 'avi'),
        (null, 'mp4'),
        ('', 'mp4'),
        ('m/k v', 'mp4'),
        ('toolongext', 'mp4'),
      ]) {
        expect(
          downloadTarget(folder, movie('A', ext: ext)),
          endsWith('/A.$want'),
          reason: '$ext',
        );
      }
    });
  });

  group('safe names (docs/09)', () {
    test('characters Windows refuses are dropped', () {
      expect(
        safeName(r'Who: The <Story> of "A/B\C" | Why? *'),
        'Who The Story of ABC Why',
      );
      expect(safeName('Tab\there\u0001\u007f'), 'Tabhere');
    });

    test('no trailing dots or spaces; spaces collapsed', () {
      expect(safeName('  Mr. Robot...  '), 'Mr. Robot');
      expect(safeName('A    B'), 'A B');
    });

    test(
      'reserved names get an underscore, whatever the case or extension',
      () {
        for (final (name, want) in [
          ('CON', 'CON_'),
          ('nul', 'nul_'),
          ('Com1', 'Com1_'),
          ('LPT9.mkv', 'LPT9_.mkv'),
          ('Console', 'Console'),
          ('COM10', 'COM10'),
        ]) {
          expect(safeName(name), want, reason: name);
        }
      },
    );

    test('empty or all refused becomes Untitled', () {
      expect(safeName(''), 'Untitled');
      expect(safeName('???'), 'Untitled');
      expect(safeName('...'), 'Untitled');
    });

    test('at most 120 characters, counting letters not bytes', () {
      expect(safeName('a' * 300), 'a' * 120);
      final accents = 'é' * 130;
      expect(safeName(accents).runes.length, 120);
      final emoji = '\u{1F3AC}' * 130;
      expect(safeName(emoji).runes.length, 120);
    });
  });

  test('on Windows the whole path stays within 240 characters', () {
    final longTitle = 'A Very Long Title That Goes On ' * 6;
    final path = downloadTarget(
      r'C:\Users\someone\Videos\IPTV Player',
      DownloadRequest(
        sourceId: 's',
        type: VodType.episode,
        remoteKey: '1',
        title: longTitle,
        showTitle: longTitle,
        season: 1,
        episode: 1,
        extension: 'mkv',
      ),
      windows: true,
    );
    expect(path.length, lessThanOrEqualTo(windowsPathLimit));
    expect(path, startsWith(r'C:\Users\someone\Videos\IPTV Player\Series\'));
    expect(path, endsWith('.mkv'));
    // Linux leaves it alone.
    expect(
      downloadTarget(folder, movie(longTitle)).length,
      greaterThan(windowsPathLimit),
    );
  });

  test('a name taken gets (2), (3) …', () {
    final taken = {'/v/A.mkv', '/v/A (2).mkv', '/v/noext'};
    expect(freeName('/v/B.mkv', taken.contains), '/v/B.mkv');
    expect(freeName('/v/A.mkv', taken.contains), '/v/A (3).mkv');
    expect(freeName('/v/noext', taken.contains), '/v/noext (2)');
    expect(
      freeName('/v.d/x', {'/v.d/x'}.contains),
      '/v.d/x (2)',
      reason: "a dot in a folder's name isn't an extension",
    );
  });
}

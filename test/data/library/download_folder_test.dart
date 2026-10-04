import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/downloads/download_settings.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/db/db_providers.dart';
import 'package:iptv_player/data/library/download_folder.dart';
import 'package:iptv_player/data/settings/settings_repository.dart';
import 'package:iptv_player/features/downloads/data/download_providers.dart';

void main() {
  group("the system's Videos folder from user-dirs.dirs", () {
    const home = '/home/me';

    test(r'reads XDG_VIDEOS_DIR with $HOME expanded', () {
      expect(
        videosFromUserDirs(
          '# written by xdg-user-dirs-update\n'
          'XDG_DESKTOP_DIR="\$HOME/Desktop"\n'
          'XDG_VIDEOS_DIR="\$HOME/Vidéos"\n',
          home: home,
        ),
        '/home/me/Vidéos',
      );
    });

    test('takes an absolute path as it is, and tidies it', () {
      expect(
        videosFromUserDirs('XDG_VIDEOS_DIR="/media/data/Video/"', home: home),
        '/media/data/Video',
      );
    });

    test('nothing when it is missing, empty, relative, or the home folder '
        '(turned off)', () {
      for (final contents in [
        '',
        r'XDG_MUSIC_DIR="$HOME/Music"',
        'XDG_VIDEOS_DIR=""',
        'XDG_VIDEOS_DIR="Videos"',
        r'XDG_VIDEOS_DIR="$HOME/"',
        r'XDG_VIDEOS_DIR="$HOME"',
      ]) {
        expect(
          videosFromUserDirs(contents, home: home),
          isNull,
          reason: contents,
        );
      }
    });
  });

  test(
    'downloads go to the chosen folder, else Videos + IPTV Player',
    () async {
      Future<String> videos() async => '/home/me/Videos';
      expect(
        await downloadFolderPath(videos: videos),
        '/home/me/Videos/IPTV Player',
      );
      expect(
        await downloadFolderPath(chosen: '/media/data/Films', videos: videos),
        '/media/data/Films',
      );
    },
  );

  group('the download folder in the library', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase.memory());
    tearDown(() => db.close());

    test('is registered once, called Downloads; a new one takes over and '
        'the old stays', () async {
      final at = DateTime.utc(2026, 10, 4);
      for (var i = 0; i < 2; i++) {
        expect(
          (await registerDownloadFolder(
            db.libraryDao,
            '/home/me/Videos/IPTV Player',
            now: at,
          )).isOk,
          isTrue,
        );
      }
      await registerDownloadFolder(db.libraryDao, '/media/films', now: at);
      final folders = await db.libraryDao.folders();
      expect(
        [for (final f in folders) (f.path, f.label, f.isDownloadFolder)],
        [
          ('/media/films', 'Downloads', true),
          ('/home/me/Videos/IPTV Player', 'Downloads', false),
        ],
      );
    });
  });

  group('the download folder provider', () {
    late AppDatabase db;
    late ProviderContainer container;
    setUp(() {
      db = AppDatabase.memory();
      container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          systemVideosProvider.overrideWith((ref) async => '/home/me/Videos'),
        ],
      );
    });
    tearDown(() async {
      container.dispose();
      await db.close();
    });

    test('is Videos + IPTV Player until a folder is chosen', () async {
      expect(
        await container.read(downloadFolderProvider.future),
        '/home/me/Videos/IPTV Player',
      );
      await container
          .read(downloadSettingsControllerProvider.notifier)
          .update(const DownloadSettings(folder: '/media/films'));
      expect(
        await container.read(downloadFolderProvider.future),
        '/media/films',
      );
    });

    test(
      'reads a stored choice even before the settings have loaded',
      () async {
        await SettingsRepository(db).writeValue(
          SettingsKeys.downloads,
          const DownloadSettings(folder: '/media/films').toJson(),
        );
        expect(
          await container.read(downloadFolderProvider.future),
          '/media/films',
        );
      },
    );
  });
}

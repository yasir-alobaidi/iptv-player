// The coordinator's futures run on the test's clock; pumps drive them.
// ignore_for_file: unawaited_futures

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/core/library/library_item.dart';
import 'package:iptv_player/core/platform/form_factor.dart';
import 'package:iptv_player/core/player/player_engine.dart';
import 'package:iptv_player/core/player/player_providers.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/design/tokens.dart';
import 'package:iptv_player/features/playback/data/playback_providers.dart';
import 'package:iptv_player/features/playback/domain/playable.dart';
import 'package:iptv_player/features/playback/domain/playback.dart';
import 'package:iptv_player/features/playback/domain/playback_state.dart';
import 'package:iptv_player/features/playback/presentation/player_surface.dart';
import 'package:iptv_player/features/vod/domain/titles.dart';

import '../../design/design_harness.dart';
import 'support/playback_fakes.dart';

// The opening screen (the user: "anything will work slowly then add a nice
// loading screen for it so the user wont get board"): what the full-screen
// player shows from the moment a film, an episode or a channel is asked
// for until its picture comes.

const _poster = 'https://img.example.com/harbor-poster.jpg';
const _backdrop = 'https://img.example.com/glass-tide-backdrop.jpg';

const _film = MovieItem(
  id: 1,
  sourceId: 'src',
  remoteKey: 'm1',
  name: 'The Quiet Harbor',
  ext: 'mkv',
  posterUrl: _poster,
);

const _bareFilm = MovieItem(
  id: 2,
  sourceId: 'src',
  remoteKey: 'm2',
  name: 'Paper Lanterns',
  ext: 'mkv',
);

const _show = SeriesItem(
  id: 1,
  sourceId: 'src',
  remoteKey: 's1',
  name: 'Glass Tide',
  posterUrl: 'https://img.example.com/glass-tide-poster.jpg',
  backdropUrl: _backdrop,
);

const _episode = EpisodeItem(
  id: 205,
  sourceId: 'src',
  seriesKey: 's1',
  remoteKey: 'e25',
  season: 2,
  episode: 5,
  title: 'Northbound',
  ext: 'mp4',
);

LibraryItem _video({String? artworkPath}) => LibraryItem(
  id: 7,
  folderId: 1,
  relPath: 'Paper Kites (2019).mkv',
  sizeBytes: 1,
  modifiedAt: DateTime(2026),
  quickHash: 'hash-kites',
  kind: LibraryKind.movie,
  title: 'Paper Kites',
  year: 2019,
  addedAt: DateTime(2026),
  artworkPath: artworkPath,
);

const _slowLine = 'Your provider is slow to answer. Still trying…';

/// What the coordinator says reaches the screen: with nothing animating,
/// the state lands a frame after it was said.
Future<void> deliver(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

void main() {
  final picture = find.byKey(const ValueKey('fake-video'));
  final spinner = find.byType(CircularProgressIndicator);
  final logo = find.byType(ChannelLogo);

  Future<void> pumpSurface(
    WidgetTester tester,
    Rig rig, {
    bool compact = false,
    bool reduceMotion = false,
    FormFactor formFactor = FormFactor.desktop,
  }) => pumpDesign(
    tester,
    reduceMotion: reduceMotion,
    ProviderScope(
      overrides: [
        playerEngineProvider.overrideWithValue(rig.engine),
        playbackCoordinatorProvider.overrideWithValue(rig.coordinator),
        playbackSettingsStoreProvider.overrideWithValue(const _Stored()),
        formFactorProvider.overrideWithValue(formFactor),
      ],
      child: SizedBox(
        width: compact ? 640 : 800,
        height: compact ? 360 : 500,
        child: PlayerSurface(compact: compact),
      ),
    ),
  );

  /// Where an artwork picture's bytes come from: its URL, or its file.
  String? source(ImageProvider image) => switch (image) {
    ResizeImage(:final imageProvider) => source(imageProvider),
    NetworkImage(:final url) => url,
    FileImage(:final file) => file.path,
    _ => null,
  };

  /// The pictures drawn in the surface, by where they come from.
  List<String?> artwork(WidgetTester tester) => [
    for (final image in tester.widgetList<Image>(find.byType(Image)))
      source(image.image),
  ];

  /// A blur over the artwork: a poster or a frame is drawn soft.
  bool blurred(WidgetTester tester) => tester
      .widgetList<ImageFiltered>(find.byType(ImageFiltered))
      .any((filter) => filter.enabled);

  Color dim(WidgetTester tester) {
    final tokens = tester.element(find.byType(PlayerSurface)).tokens;
    return tokens.colors.video.withValues(alpha: tokens.player.openingDim);
  }

  bool dimmed(WidgetTester tester) => tester
      .widgetList<ColoredBox>(find.byType(ColoredBox))
      .any((box) => box.color == dim(tester));

  Future<void> stop(WidgetTester tester, Rig rig) async {
    rig.coordinator.stop();
    await deliver(tester);
  }

  group('a film or an episode', () {
    testWidgets('its poster fills the picture, soft and dimmed, under its '
        'title, a spinner and "Preparing…"; the picture takes it all away '
        'at once', (tester) async {
      final rig = Rig();
      await pumpSurface(tester, rig);
      rig.coordinator.playVod(const PlayableMovie(_film));
      await deliver(tester);
      expect(rig.state, isA<PlaybackOpening>());

      expect(artwork(tester), [_poster]);
      expect(blurred(tester), isTrue);
      expect(dimmed(tester), isTrue);
      expect(find.text('The Quiet Harbor'), findsOneWidget);
      expect(spinner, findsOneWidget);
      expect(find.text('Preparing…'), findsOneWidget);

      rig.engine.firstFrame();
      await deliver(tester);
      expect(picture, findsOneWidget);
      expect(artwork(tester), isEmpty);
      expect(find.text('The Quiet Harbor'), findsNothing);
      expect(find.text('Preparing…'), findsNothing);
      expect(spinner, findsNothing);
      await stop(tester, rig);
    });

    testWidgets("an episode: the series' backdrop as it is, the series' name "
        'and "S2 · E5 · Northbound"', (tester) async {
      final rig = Rig();
      await pumpSurface(tester, rig);
      rig.coordinator.playVod(const PlayableEpisode(_show, _episode));
      await deliver(tester);

      expect(artwork(tester), [_backdrop]);
      expect(blurred(tester), isFalse);
      expect(dimmed(tester), isTrue);
      expect(find.text('Glass Tide'), findsOneWidget);
      expect(find.text('S2 · E5 · Northbound'), findsOneWidget);
      expect(find.text('Preparing…'), findsOneWidget);
      await stop(tester, rig);
    });

    testWidgets("with no artwork, the app's own dark surface; nothing is "
        'fetched for it', (tester) async {
      final rig = Rig();
      await pumpSurface(tester, rig);
      rig.coordinator.playVod(const PlayableMovie(_bareFilm));
      await deliver(tester);

      expect(artwork(tester), isEmpty);
      final bg = tester.element(find.byType(PlayerSurface)).tokens.colors.bg;
      expect(
        tester
            .widgetList<ColoredBox>(find.byType(ColoredBox))
            .map((box) => box.color),
        contains(bg),
      );
      expect(find.text('Paper Lanterns'), findsOneWidget);
      expect(find.text('Preparing…'), findsOneWidget);
      await stop(tester, rig);
    });

    testWidgets('a video of the library: the picture it has on this '
        'computer, its title and year', (tester) async {
      final rig = Rig();
      await pumpSurface(tester, rig);
      rig.coordinator.playVod(
        PlayableLibraryItem(_video(artworkPath: '/videos/kites-poster.jpg')),
      );
      await deliver(tester);

      expect(artwork(tester), ['/videos/kites-poster.jpg']);
      expect(find.text('Paper Kites'), findsOneWidget);
      expect(find.text('2019'), findsOneWidget);
      await stop(tester, rig);
    });

    testWidgets('on a TV the poster is soft without a blur filter: decoded a '
        'few pixels wide and stretched (docs/07)', (tester) async {
      final rig = Rig();
      await pumpSurface(tester, rig, formFactor: FormFactor.tv);
      rig.coordinator.playVod(const PlayableMovie(_film));
      await deliver(tester);

      expect(artwork(tester), [_poster]);
      expect(blurred(tester), isFalse);
      final image = tester.widget<Image>(find.byType(Image)).image;
      final element = tester.element(find.byType(PlayerSurface));
      final width =
          element.tokens.player.openingTvSoftWidth *
          MediaQuery.devicePixelRatioOf(element);
      expect((image as ResizeImage).width, width.ceil());
      await stop(tester, rig);
    });

    testWidgets('"Preparing…" until 4 s, then "Still connecting…", and from '
        '12 s that the provider is slow; a new open starts again', (
      tester,
    ) async {
      final rig = Rig();
      await pumpSurface(tester, rig);
      rig.coordinator.playVod(const PlayableMovie(_film));
      await deliver(tester);

      await tester.pump(const Duration(milliseconds: 3990));
      expect(find.text('Preparing…'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 10));
      expect(find.text('Preparing…'), findsNothing);
      expect(find.text('Still connecting…'), findsOneWidget);
      await tester.pump(const Duration(seconds: 8));
      expect(find.text('Still connecting…'), findsNothing);
      expect(find.text(_slowLine), findsOneWidget);
      expect(spinner, findsOneWidget);

      // Another film: its own open, its own clock.
      rig.coordinator.playVod(const PlayableMovie(_bareFilm));
      await deliver(tester);
      expect(find.text('Paper Lanterns'), findsOneWidget);
      expect(find.text('Preparing…'), findsOneWidget);
      expect(find.text(_slowLine), findsNothing);
      await tester.pump(const Duration(seconds: 4));
      expect(find.text('Still connecting…'), findsOneWidget);
      await stop(tester, rig);
    });

    testWidgets('a video of the library says it is the file that is slow, '
        'not a provider', (tester) async {
      final rig = Rig();
      await pumpSurface(tester, rig);
      rig.coordinator.playVod(PlayableLibraryItem(_video()));
      await deliver(tester);

      await tester.pump(const Duration(seconds: 4));
      expect(find.text('Still opening…'), findsOneWidget);
      await tester.pump(const Duration(seconds: 8));
      expect(
        find.text('This file is slow to open. Still trying…'),
        findsOneWidget,
      );
      expect(find.text(_slowLine), findsNothing);
      await stop(tester, rig);
    });

    testWidgets('a failure: the failure card as it was, and the opening '
        'screen gone', (tester) async {
      final rig = Rig();
      await pumpSurface(tester, rig);
      rig.prober.next = const PlaybackProblem(PlaybackProblemKind.offline);
      rig.coordinator.playVod(const PlayableMovie(_film));
      await deliver(tester);
      rig.engine.fail();
      await deliver(tester);
      expect(rig.state, isA<PlaybackFailed>());

      expect(find.byType(PlaybackFailureCard), findsOneWidget);
      expect(find.text('No longer available'), findsOneWidget);
      expect(artwork(tester), isEmpty);
      expect(find.text('The Quiet Harbor'), findsNothing);
      expect(find.text('Preparing…'), findsNothing);
      expect(spinner, findsNothing);

      // Retry opens it again, on its artwork.
      await tester.tap(find.text('Retry'));
      await deliver(tester);
      expect(rig.state, isA<PlaybackOpening>());
      expect(artwork(tester), [_poster]);
      expect(find.text('Preparing…'), findsOneWidget);
      await stop(tester, rig);
    });

    testWidgets('reconnecting before its first picture keeps its artwork '
        'and title under the pill, without a second spinner', (tester) async {
      final rig = Rig();
      await pumpSurface(tester, rig);
      rig.coordinator.playVod(const PlayableMovie(_film));
      await deliver(tester);

      // A file gets 30 s for its first frame.
      await tester.pump(const Duration(seconds: 30));
      expect(rig.state, isA<PlaybackReconnecting>());
      expect(find.byType(ReconnectingPill), findsOneWidget);
      expect(artwork(tester), [_poster]);
      expect(find.text('The Quiet Harbor'), findsOneWidget);
      expect(find.text(_slowLine), findsNothing);
      // The pill's own.
      expect(spinner, findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      rig.engine.firstFrame();
      await deliver(tester);
      expect(picture, findsOneWidget);
      expect(artwork(tester), isEmpty);
      expect(find.text('The Quiet Harbor'), findsNothing);
      await stop(tester, rig);
    });
  });

  group('a channel', () {
    testWidgets('a quick zap shows nothing new: the spinner alone, then its '
        'logo and name after 0.6 s; a zap starts that over', (tester) async {
      final rig = Rig();
      await pumpSurface(tester, rig);
      rig.coordinator.playLive(channel(1));
      await deliver(tester);

      expect(spinner, findsOneWidget);
      expect(logo, findsNothing);
      expect(find.text('Channel 1'), findsNothing);
      expect(artwork(tester), isEmpty);
      await tester.pump(const Duration(milliseconds: 599));
      expect(logo, findsNothing);
      await tester.pump(const Duration(milliseconds: 1));
      expect(logo, findsOneWidget);
      expect(find.text('Channel 1'), findsOneWidget);
      expect(spinner, findsOneWidget);
      // No line yet: a channel's first seconds say nothing.
      expect(find.text('Preparing…'), findsNothing);

      rig.coordinator.playLive(channel(2));
      await deliver(tester);
      expect(logo, findsNothing);
      expect(find.text('Channel 2'), findsNothing);
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Channel 2'), findsOneWidget);

      // Its picture: all gone.
      rig.engine.firstFrame();
      await deliver(tester);
      expect(picture, findsOneWidget);
      expect(logo, findsNothing);
      expect(find.text('Channel 2'), findsNothing);
      expect(spinner, findsNothing);
      await stop(tester, rig);
    });

    testWidgets('"Still connecting…" from 4 s, and from 12 s that the '
        'provider is slow (Stable gives an open 20 s)', (tester) async {
      final rig = Rig(
        settings: () => const PlaybackSettings(preset: BufferPreset.stable),
      );
      await pumpSurface(tester, rig);
      rig.coordinator.playLive(channel(1));
      await deliver(tester);

      await tester.pump(const Duration(milliseconds: 3990));
      expect(find.text('Still connecting…'), findsNothing);
      await tester.pump(const Duration(milliseconds: 10));
      expect(find.text('Still connecting…'), findsOneWidget);
      await tester.pump(const Duration(seconds: 8));
      expect(rig.state, isA<PlaybackOpening>());
      expect(find.text(_slowLine), findsOneWidget);
      expect(find.text('Channel 1'), findsOneWidget);
      await stop(tester, rig);
    });

    testWidgets('reconnecting before any picture: its logo and name stay '
        'under the pill, with no line of their own', (tester) async {
      final rig = Rig();
      await pumpSurface(tester, rig);
      rig.coordinator.playLive(channel(1));
      await deliver(tester);

      // Balanced gives an open 12 s.
      await tester.pump(const Duration(seconds: 12));
      expect(rig.state, isA<PlaybackReconnecting>());
      expect(find.byType(ReconnectingPill), findsOneWidget);
      expect(logo, findsOneWidget);
      expect(find.text('Channel 1'), findsOneWidget);
      expect(find.text(_slowLine), findsNothing);
      expect(find.text('Still connecting…'), findsNothing);
      expect(spinner, findsOneWidget);
      await stop(tester, rig);
    });
  });

  testWidgets('on a TV, a film on its own layer behind the app: the '
      'opening screen covers the old frame, and nothing at all is painted '
      'once its picture shows', (tester) async {
    final rig = Rig();
    rig.engine.pictureBehindApp.value = true;
    await pumpSurface(tester, rig, formFactor: FormFactor.tv);
    rig.coordinator.playVod(const PlayableMovie(_film));
    await deliver(tester);
    expect(artwork(tester), [_poster]);
    expect(find.text('The Quiet Harbor'), findsOneWidget);

    rig.engine.firstFrame();
    await deliver(tester);
    final surface = find.descendant(
      of: find.byType(PlayerSurface),
      matching: find.byType(ColoredBox),
    );
    expect(tester.widget<ColoredBox>(surface.first).color, Colors.transparent);
    // Nothing painted but the picture's own view (the fake one has a
    // background; the TV's layer is behind it).
    final ownView = find.descendant(
      of: picture,
      matching: find.byType(ColoredBox),
    );
    expect(
      tester
          .widgetList<ColoredBox>(surface)
          .where((box) => box.color != Colors.transparent)
          .toSet()
          .difference(tester.widgetList<ColoredBox>(ownView).toSet()),
      isEmpty,
    );
    expect(artwork(tester), isEmpty);
    expect(find.text('The Quiet Harbor'), findsNothing);
    await stop(tester, rig);
  });

  testWidgets("the preview pane keeps today's spinner alone: no room there", (
    tester,
  ) async {
    final rig = Rig(
      settings: () => const PlaybackSettings(preset: BufferPreset.stable),
    );
    await pumpSurface(tester, rig, compact: true);
    rig.coordinator.playVod(const PlayableMovie(_film));
    await deliver(tester);
    expect(spinner, findsOneWidget);
    expect(artwork(tester), isEmpty);
    expect(find.text('The Quiet Harbor'), findsNothing);
    expect(find.text('Preparing…'), findsNothing);

    rig.coordinator.playLive(channel(1));
    await deliver(tester);
    await tester.pump(const Duration(seconds: 13));
    expect(rig.state, isA<PlaybackOpening>());
    expect(spinner, findsOneWidget);
    expect(logo, findsNothing);
    expect(find.text('Channel 1'), findsNothing);
    expect(find.text(_slowLine), findsNothing);
    await stop(tester, rig);
  });

  group('reduce motion', () {
    testWidgets('nothing fades or turns: the artwork and the name are there '
        'at once, the spinner is the still loading icon', (tester) async {
      final rig = Rig();
      await pumpSurface(tester, rig, reduceMotion: true);
      rig.coordinator.playVod(const PlayableMovie(_film));
      await deliver(tester);
      expect(artwork(tester), [_poster]);
      expect(spinner, findsNothing);
      expect(
        tester
            .widgetList<AppIcon>(find.byType(AppIcon))
            .where((icon) => icon.icon == AppIcons.loading),
        hasLength(1),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(SchedulerBinding.instance.transientCallbackCount, 0);

      rig.coordinator.playLive(channel(1));
      await deliver(tester);
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Channel 1'), findsOneWidget);
      expect(
        find.ancestor(
          of: find.text('Channel 1'),
          matching: find.byType(Opacity),
        ),
        findsNothing,
      );
      expect(SchedulerBinding.instance.transientCallbackCount, 0);
      await stop(tester, rig);
    });

    testWidgets("with motion a channel's name fades in", (tester) async {
      final rig = Rig();
      await pumpSurface(tester, rig);
      rig.coordinator.playLive(channel(1));
      await deliver(tester);
      await tester.pump(const Duration(milliseconds: 600));
      final fade = find.ancestor(
        of: find.text('Channel 1'),
        matching: find.byType(Opacity),
      );
      expect(tester.widget<Opacity>(fade.first).opacity, lessThan(1));
      await tester.pump(const Duration(seconds: 1));
      expect(tester.widget<Opacity>(fade.first).opacity, 1);
      await stop(tester, rig);
    });
  });
}

final class _Stored implements PlaybackSettingsStore {
  const new();

  @override
  Future<Result<PlaybackSettings>> load() async => const Ok(PlaybackSettings());

  @override
  Future<Result<void>> save(PlaybackSettings settings) async => const Ok(null);
}

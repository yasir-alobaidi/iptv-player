import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/cast/cast_plan.dart';
import 'package:iptv_player/core/library/library_item.dart';
import 'package:iptv_player/features/casting/domain/casting_state.dart';
import 'package:iptv_player/features/playback/domain/playable.dart';
import 'package:iptv_player/features/vod/domain/titles.dart';
import 'package:path/path.dart' as p;

import '../../data/cast/relay/relay_rig.dart';
import 'support/cast_e2e_rig.dart';

/// Phase 8 step 7, decision 12: files on this computer cast through the
/// app, with no provider in it. An MP4 the TV can play is served to it as
/// it is, and the TV seeks in it by itself; anything else goes through
/// the relay, whose FFmpeg reads the file; a title that was downloaded
/// casts from its file.
void main() {
  setUpAll(() => HttpOverrides.global = null);

  late CastE2E rig;

  tearDown(() => rig.close());

  /// A film of the user's own: [sample] of the media samples.
  LibraryItem own(String sample) {
    final file = File(p.join(samples.path, sample));
    return LibraryItem(
      id: 1,
      folderId: 1,
      relPath: 'Paper Kites (2019)/$sample',
      sizeBytes: file.lengthSync(),
      modifiedAt: DateTime.utc(2026),
      quickHash: 'hash-$sample',
      kind: LibraryKind.movie,
      title: 'Paper Kites',
      year: 2019,
      addedAt: DateTime.utc(2026),
      path: file.path,
    );
  }

  String? skipWithout(String sample) =>
      relaySkip(const []) ??
      (File(p.join(samples.path, sample)).existsSync()
          ? null
          : 'no $sample sample');

  /// The requests the TV made for the file itself.
  List<String?> ranges() => [
    for (final fetch in rig.tv.fetches)
      if (fetch.path.endsWith('/media.mp4')) fetch.range,
  ];

  test(
    'an MP4 of your own goes to the TV as it is: read from this computer '
    "with Range, a seek is the TV's own, its place is kept, and the "
    'provider is never asked',
    () async {
      const mp4 = 'vod_h264_aac_10min.mp4';
      const from = Duration(seconds: 20);
      const seekTo = Duration(seconds: 70);
      rig = await CastE2E.start();
      final item = own(mp4);
      rig.resolver.files[item.quickHash] = item.path!;
      await rig.coordinator.connect(rig.device);
      await rig.phase(CastPhase.idle);

      unawaited(rig.playback.playVod(PlayableLibraryItem(item), from: from));
      await rig.tvPlaying(checks: 1);
      await rig.phase(CastPhase.playing);

      final plan = rig.state.plan!;
      expect(plan.delivery, CastDelivery.directFile);
      expect(plan.video, isA<CastVideoCopy>());
      expect(plan.audio, isA<CastAudioCopy>());
      final url = Uri.parse(rig.tv.loaded!['contentId']! as String);
      expect(url.path, matches(r'^/f/[^/]+/media\.mp4$'));
      expect(rig.tv.loaded!['contentType'], 'video/mp4');
      expect(rig.tv.checks.last.videoCodec, 'h264');
      expect(rig.tv.checks.last.audioCodec, 'aac');
      // It started at its place: the index first, then the bytes there.
      await until(() => ranges().length >= 2, what: 'the jump to its place');
      expect(ranges().first, 'bytes=0-');
      expect(ranges()[1], matches(r'^bytes=[1-9]\d*-$'));
      expect(rig.coordinator.timeline.position, greaterThanOrEqualTo(from));
      expect(rig.coordinator.timeline.duration, isNotNull);
      // No FFmpeg, no provider: the file and the TV.
      expect(rig.running, isEmpty);
      expect(rig.resolver.resolved, isEmpty);
      expect(rig.panel.state.activeStreams, 0);

      // A seek: the same LOAD, a new Range request further in.
      final loads = rig.tv.requests('LOAD').length;
      await rig.playback.seek(seekTo);
      await until(() => ranges().length >= 3, what: "the TV's seek");
      int at(String? range) =>
          int.parse(RegExp(r'^bytes=(\d+)-$').firstMatch(range!)![1]!);
      expect(at(ranges()[2]), greaterThan(at(ranges()[1])));
      expect(rig.tv.requests('LOAD'), hasLength(loads), reason: 'no new LOAD');
      expect(rig.tv.requests('SEEK'), hasLength(1));
      await until(
        () => rig.tv.playerState == 'PLAYING',
        what: 'playing after the seek',
      );
      expect(rig.coordinator.timeline.position, greaterThanOrEqualTo(seekTo));

      await rig.coordinator.disconnect();
      expect(rig.progress.lastPosition, greaterThanOrEqualTo(seekTo));
      expect(rig.progress.saves.last.ref, PlayableLibraryItem(item).vodRef);
      // Its URL is gone with the cast: not served, or nothing listening.
      try {
        final gone = await (await HttpClient().getUrl(url)).close();
        expect(gone.statusCode, HttpStatus.notFound);
        await gone.drain<void>();
      } on SocketException {
        // The relay's server closed with its last route.
      }
    },
    skip: skipWithout('vod_h264_aac_10min.mp4'),
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'a Matroska file with AC-3 goes through the relay, which reads the '
    'file itself: no proxy, no provider; a seek starts it again there',
    () async {
      const mkv = 'vod_h264_ac3_10min.mkv';
      const seekTo = Duration(seconds: 60);
      rig = await CastE2E.start();
      final item = own(mkv);
      rig.resolver.files[item.quickHash] = item.path!;
      await rig.coordinator.connect(rig.device);
      await rig.phase(CastPhase.idle);

      unawaited(rig.playback.playVod(PlayableLibraryItem(item)));
      await rig.tvPlaying(checks: 1);
      await rig.phase(CastPhase.playing);
      final plan = rig.state.plan!;
      expect(plan.delivery, CastDelivery.relayContinuous);
      expect(plan.video, isA<CastVideoCopy>());
      expect(plan.audio, isA<CastAudioToAac>());
      expect(rig.tv.checks.last.videoCodec, 'h264');
      expect(rig.tv.checks.last.audioCodec, 'aac');
      expect(rig.resolver.resolved, isEmpty);
      expect(rig.panel.state.activeStreams, 0);
      expect(rig.running, hasLength(1));

      final first = rig.tv.loaded!['contentId'];
      await rig.playback.seek(seekTo);
      await until(
        () => (rig.tv.loaded?['contentId'] ?? first) != first,
        what: 'the LOAD after the seek',
      );
      final checked = rig.tv.checks.length;
      await rig.tvPlaying(after: checked, checks: 1);
      await rig.phase(CastPhase.playing);
      expect(rig.coordinator.timeline.position, greaterThanOrEqualTo(seekTo));

      await rig.coordinator.disconnect();
      expect(rig.progress.lastPosition, greaterThanOrEqualTo(seekTo));
      await until(() => rig.running.isEmpty, what: 'no FFmpeg left');
      expect(rig.resolver.resolved, isEmpty);
    },
    skip: skipWithout('vod_h264_ac3_10min.mkv'),
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'a movie that was downloaded casts from its file: the provider gives '
    "no stream, and a TV that can't take the provider's own file directly "
    'takes this one',
    () async {
      const mp4 = 'vod_h264_aac_10min.mp4';
      rig = await CastE2E.start();
      // The provider lists it as Matroska; the download was kept as MP4.
      const movie = MovieItem(
        id: 100001,
        sourceId: 'panel',
        remoteKey: '100001',
        name: 'Movie 100001',
        ext: 'mkv',
        runtime: Duration(minutes: 10),
      );
      rig.resolver.files['100001'] = p.join(samples.path, mp4);
      await rig.coordinator.connect(rig.device);
      await rig.phase(CastPhase.idle);

      unawaited(rig.playback.playVod(const PlayableMovie(movie)));
      await rig.tvPlaying(checks: 1);
      await rig.phase(CastPhase.playing);

      expect(rig.state.plan!.delivery, CastDelivery.directFile);
      expect(
        Uri.parse(rig.tv.loaded!['contentId']! as String).path,
        endsWith('/media.mp4'),
      );
      expect(rig.resolver.resolved, isEmpty, reason: 'no provider URL built');
      expect(rig.panel.state.activeStreams, 0);
      // Nothing was learned about the provider from a file on disk.
      expect(
        rig.devices.devices['fake-tv']?.learned.directRefusedSources ?? {},
        isEmpty,
      );
      await rig.coordinator.disconnect();
      // Its place is the title's, shared with streaming it.
      expect(rig.progress.saves.last.ref, const PlayableMovie(movie).vodRef);
    },
    skip: skipWithout('vod_h264_aac_10min.mp4'),
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

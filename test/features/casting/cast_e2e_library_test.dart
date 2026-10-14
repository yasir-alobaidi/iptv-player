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
/// casts from its file. A file's text subtitles reach the TV as WebVTT.
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

  /// The cues of a subtitle sample: one every 10 s of the samples' length,
  /// which is 10 minutes here and 2 on CI.
  int cuesOf(String sample) =>
      File(p.join(samples.path, sample))
          .readAsLinesSync()
          .where((line) => line.contains('-->'))
          .length;

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
      expect(rig.relaying, hasLength(1));

      final first = rig.tv.loaded!['contentId'];
      await rig.playback.seek(seekTo);
      await until(
        () => (rig.tv.loaded?['contentId'] ?? first) != first,
        what: 'the LOAD after the seek',
      );
      final checked = rig.tv.checks.length;
      await rig.tvPlaying(after: checked, checks: 1);
      await rig.phase(CastPhase.playing);
      // Its place is where the picture is: the copied stream starts at
      // the key frame at or before the place asked for (every 2 s here).
      const keyFrame = Duration(seconds: 2, milliseconds: 200);
      expect(
        rig.coordinator.timeline.position,
        greaterThanOrEqualTo(seekTo - keyFrame),
      );

      await rig.coordinator.disconnect();
      expect(
        rig.progress.lastPosition,
        greaterThanOrEqualTo(seekTo - keyFrame),
      );
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

  test(
    'the MP4 made beside a relayed film: once it is whole, a seek loads '
    'it and the relay stops; the TV seeks in it by itself after that, to '
    'the very place, and its subtitles keep their own times',
    () async {
      const mkv = 'vod_h264_ac3_10min.mkv';
      rig = await CastE2E.start();
      final item = own(mkv);
      rig.resolver
        ..files[item.quickHash] = item.path!
        ..beside[item.path!] = [
          p.join(samples.path, 'vod_h264_ac3_10min.en.srt'),
        ];
      await rig.coordinator.connect(rig.device);
      await rig.phase(CastPhase.idle);

      unawaited(rig.playback.playVod(PlayableLibraryItem(item)));
      await rig.tvPlaying(checks: 1);
      await rig.phase(CastPhase.playing);
      expect(rig.state.plan!.delivery, CastDelivery.relayContinuous);
      final relayed = rig.tv.loaded!['contentId']! as String;
      expect(Uri.parse(relayed).path, startsWith('/p/'));
      // Its sound is converted at some 50 times its speed: a 10-minute
      // sample in about 11 s here.
      await until(
        () => rig.mp4Ready,
        within: const Duration(seconds: 90),
        what: 'the MP4',
      );
      expect(rig.tv.loaded!['contentId'], relayed, reason: 'not interrupted');

      // 67 s is between two key frames (66 and 68 s).
      const first = Duration(seconds: 67);
      await rig.playback.seek(first);
      await until(
        () => (rig.tv.loaded?['contentId'] ?? relayed) != relayed,
        what: 'the LOAD of the MP4',
      );
      final mp4 = Uri.parse(rig.tv.loaded!['contentId']! as String);
      expect(mp4.path, matches(r'^/f/[^/]+/media\.mp4$'));
      expect(rig.tv.loaded!['contentType'], 'video/mp4');
      final checked = rig.tv.checks.length;
      await rig.tvPlaying(after: checked, checks: 1);
      await rig.phase(CastPhase.playing);
      expect(rig.tv.checks.last.videoCodec, 'h264');
      expect(rig.tv.checks.last.audioCodec, 'aac');
      await until(() => rig.running.isEmpty, what: 'the relay stopped');
      // The place asked for itself, not the key frame before it.
      expect(rig.coordinator.timeline.position, greaterThanOrEqualTo(first));
      await until(
        () => rig.tv.textTracks.isNotEmpty,
        what: 'its subtitle read by the TV',
      );
      final track = rig.tv.textTracks.single;
      expect(track.problem, isNull, reason: '$track');
      expect(track.firstCue, Duration.zero);
      expect(track.cues, cuesOf('vod_h264_ac3_10min.en.srt'));
      expect(rig.tv.activeTrackIds, [1]);

      // A second seek is the TV's own: a Range request, no LOAD. (100 s
      // is inside CI's 2-minute sample too.)
      const second = Duration(seconds: 100);
      final loads = rig.tv.requests('LOAD').length;
      final fetches = ranges().length;
      await rig.playback.seek(second);
      await until(
        () => ranges().length > fetches,
        what: "the TV's own seek in the MP4",
      );
      expect(rig.tv.requests('SEEK'), hasLength(1));
      expect(rig.tv.requests('LOAD'), hasLength(loads));
      expect(rig.running, isEmpty, reason: 'no FFmpeg for a seek');
      await until(
        () => rig.tv.playerState == 'PLAYING',
        what: 'playing after the seek',
      );
      expect(rig.coordinator.timeline.position, greaterThanOrEqualTo(second));

      await rig.coordinator.disconnect();
      expect(rig.progress.lastPosition, greaterThanOrEqualTo(second));
      expect(rig.sessionFolders, isEmpty, reason: 'the MP4 went with the cast');
    },
    skip: skipWithout('vod_h264_ac3_10min.mkv'),
    timeout: const Timeout(Duration(minutes: 3)),
  );

  group('subtitles (docs/04 "Subtitles")', () {
    const srt = 'vod_h264_ac3_10min.en.srt';

    /// Until the TV has fetched and read [count] text tracks.
    Future<void> tracksRead(int count) => until(
      () => rig.tv.textTracks.length >= count,
      what: '$count text track(s) read by the TV (${rig.tv.textTracks})',
    );

    test(
      'a subtitle file beside a Matroska film, through the relay: the TV '
      'reads it as WebVTT and shows it from the start; the stream is on '
      "the film's own clock, its whole length and its time the film's, so "
      "after a seek the cues keep the film's times; S turns it off",
      () async {
        const mkv = 'vod_h264_ac3_10min.mkv';
        rig = await CastE2E.start();
        final item = own(mkv);
        rig.resolver
          ..files[item.quickHash] = item.path!
          ..beside[item.path!] = [p.join(samples.path, srt)];
        await rig.coordinator.connect(rig.device);
        await rig.phase(CastPhase.idle);

        unawaited(rig.playback.playVod(PlayableLibraryItem(item)));
        await rig.tvPlaying(checks: 1);
        await rig.phase(CastPhase.playing);
        expect(rig.state.plan!.delivery, CastDelivery.relayContinuous);
        await tracksRead(1);
        final whole = rig.tv.textTracks.single;
        expect(whole.problem, isNull, reason: '$whole');
        expect(whole.id, 1);
        expect(whole.language, 'en');
        expect(whole.name, 'English');
        expect(whole.url.path, matches(r'^/f/[^/]+/media\.vtt$'));
        expect(whole.cues, cuesOf(srt));
        expect(whole.firstCue, Duration.zero);
        expect(whole.firstText, 'External English subtitle 1 at 0 s');
        expect(rig.tv.activeTrackIds, [1], reason: 'a file beside the video');
        expect(rig.state.subtitle, 1);
        expect(rig.state.subtitles.single.beside, isTrue);
        // What the TV's own bar shows: the film's length from the first
        // picture, not what it has read so far (the Bedroom TV, 2026-10).
        final stream = rig.tv.checks.last;
        expect(stream.length!.inMilliseconds, _tenMinutes);
        expect(stream.start!.inMilliseconds, inInclusiveRange(0, 200));

        // A seek to 67 s: this file has a key frame every 2 s, so the
        // copied stream starts at 66 s, which is the TV's time there.
        final first = rig.tv.loaded!['contentId'];
        await rig.playback.seek(const Duration(seconds: 67));
        await until(
          () => (rig.tv.loaded?['contentId'] ?? first) != first,
          what: 'the LOAD after the seek',
        );
        await tracksRead(1);
        final moved = rig.tv.textTracks.single;
        expect(moved.problem, isNull, reason: '$moved');
        expect(moved.url, isNot(whole.url));
        expect(moved.cues, whole.cues, reason: "the film's own times");
        expect(moved.firstText, whole.firstText);
        expect(rig.tv.activeTrackIds, [1], reason: 'the choice is kept');
        expect(
          (rig.tv.requests('LOAD').last.payload['currentTime']! as num) * 1000,
          inInclusiveRange(65800, 66200),
          reason: 'from the key frame at 66 s, not from 67 s',
        );
        await until(
          () => rig.tv.checks.last.start! > const Duration(seconds: 1),
          what: "the TV's check of the stream after the seek",
        );
        final after = rig.tv.checks.last;
        expect(after.length!.inMilliseconds, _tenMinutes);
        expect(after.start!.inMilliseconds, inInclusiveRange(65800, 66200));
        await until(
          () => rig.tv.playerState == 'PLAYING',
          what: 'playing after the seek',
        );
        await rig.phase(CastPhase.playing);
        expect(
          rig.coordinator.timeline.position,
          greaterThanOrEqualTo(const Duration(seconds: 65, milliseconds: 800)),
        );

        await rig.coordinator.setSubtitle(null);
        expect(rig.tv.activeTrackIds, isEmpty);
        expect(rig.state.subtitle, isNull);
        expect(rig.tv.requests('EDIT_TRACKS_INFO'), hasLength(1));

        await rig.coordinator.disconnect();
        await until(() => rig.running.isEmpty, what: 'no FFmpeg left');
        expect(rig.sessionFolders, isEmpty, reason: 'its WebVTT files too');
      },
      skip: skipWithout('vod_h264_ac3_10min.mkv'),
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test(
      "a film's own text tracks: each reaches the TV, and Preferred "
      'subtitles decide which shows; another is a switch away',
      () async {
        const mkv = 'vod_hevc_eac3_subs.mkv';
        rig = await CastE2E.start();
        rig.subtitleLanguages.addAll(['fr', 'de']);
        final item = own(mkv);
        rig.resolver.files[item.quickHash] = item.path!;
        await rig.coordinator.connect(rig.device);
        await rig.phase(CastPhase.idle);

        unawaited(rig.playback.playVod(PlayableLibraryItem(item)));
        await rig.tvPlaying(checks: 1);
        await rig.phase(CastPhase.playing);
        await tracksRead(2);
        final tracks = [...rig.tv.textTracks]
          ..sort((a, b) => a.id.compareTo(b.id));
        expect([for (final t in tracks) t.problem], [null, null]);
        expect(
          [for (final t in tracks) (t.id, t.language, t.name)],
          [(1, 'en', 'English'), (2, 'de', 'German')],
        );
        expect(tracks.every((t) => t.cues > 0), isTrue);
        expect(rig.tv.activeTrackIds, [2], reason: 'German is preferred');
        expect(rig.state.subtitle, 2);

        await rig.coordinator.setSubtitle(1);
        expect(rig.tv.activeTrackIds, [1]);
        expect(rig.tv.requests('LOAD'), hasLength(1), reason: 'no new LOAD');
        await rig.coordinator.disconnect();
        await until(() => rig.running.isEmpty, what: 'no FFmpeg left');
      },
      skip: skipWithout('vod_hevc_eac3_subs.mkv'),
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test(
      'an MP4 the TV plays itself, from its place: the cues keep the '
      "file's own times",
      () async {
        const mp4 = 'vod_h264_aac_10min.mp4';
        rig = await CastE2E.start();
        final item = own(mp4);
        rig.resolver
          ..files[item.quickHash] = item.path!
          // Not named after the video: it says no language.
          ..beside[item.path!] = [p.join(samples.path, srt)];
        await rig.coordinator.connect(rig.device);
        await rig.phase(CastPhase.idle);

        unawaited(
          rig.playback.playVod(
            PlayableLibraryItem(item),
            from: const Duration(seconds: 30),
          ),
        );
        await rig.tvPlaying(checks: 1);
        await rig.phase(CastPhase.playing);
        expect(rig.state.plan!.delivery, CastDelivery.directFile);
        await tracksRead(1);
        final track = rig.tv.textTracks.single;
        expect(track.problem, isNull, reason: '$track');
        expect(track.language, isNull);
        expect(track.name, 'Subtitles 1');
        expect(track.firstCue, Duration.zero);
        expect(track.cues, cuesOf(srt));
        expect(rig.tv.activeTrackIds, [1]);
        expect(rig.running, isEmpty, reason: 'the WebVTT is made by then');
        await rig.coordinator.disconnect();
      },
      skip: skipWithout('vod_h264_aac_10min.mp4'),
      timeout: const Timeout(Duration(minutes: 2)),
    );
  });
}

/// Ten minutes as a TV's demuxer reads the header: the film's length, or
/// as much more as its first picture is shown late (80 ms in this file,
/// counted or not depending on how much of the stream was read).
final Matcher _tenMinutes = inInclusiveRange(600000, 600200);

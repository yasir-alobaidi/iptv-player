import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/player/player_engine.dart';
import 'package:iptv_player/features/playback/domain/playable.dart';
import 'package:iptv_player/features/playback/domain/playback_state.dart';
import 'package:iptv_player/features/playback/domain/remote_playback.dart';
import 'package:iptv_player/features/playback/domain/source_connections.dart';

import 'support/playback_fakes.dart';

final class _Remote implements RemotePlayback {
  final calls = <String>[];

  @override
  String get deviceName => 'Living Room TV';

  @override
  Future<void> play(Playable item, {Duration? from}) async =>
      calls.add('play ${item.remoteKey} ${from?.inSeconds}');

  @override
  Future<void> retry() async => calls.add('retry');

  @override
  Future<void> seek(Duration position) async =>
      calls.add('seek ${position.inSeconds}');

  @override
  Future<void> setPaused({required bool paused}) async =>
      calls.add('paused $paused');
}

/// Phase 7 decision 2, the playback coordinator's side: while a cast
/// session is on, what the screens play goes to the device.
void main() {
  late Rig rig;
  late _Remote remote;

  setUp(() {
    rig = Rig();
    remote = _Remote();
  });

  test('nothing playing: nothing handed over', () async {
    expect(await rig.coordinator.castStarted(remote), isNull);
    expect(rig.coordinator.casting, isTrue);
    expect(rig.state, isA<PlaybackIdle>());
  });

  test('a channel playing: handed over with what the player knew', () async {
    await rig.coordinator.playLive(channel(1));
    rig.engine
      ..info = const StreamInfo(videoCodec: 'h264', height: 1080)
      ..firstFrame()
      ..emit(
        const PlayerTracks(
          audio: [MediaTrack(id: '1')],
          subtitles: [],
          audioId: '1',
        ),
      );
    final handover = (await rig.coordinator.castStarted(remote))!;
    expect(handover.item, PlayableChannel(channel(1)));
    expect(handover.position, isNull);
    expect(handover.info!.height, 1080);
    expect(handover.tracks!.audioId, '1');
    expect(rig.engine.calls.last, 'stop');
    expect(rig.coordinator.connections.held('src'), 0);
    final state = rig.state as PlaybackCasting;
    expect(state.item, PlayableChannel(channel(1)));
    expect(state.deviceName, 'Living Room TV');
    expect(state.channel, channel(1), reason: 'Live TV still sees it');
  });

  test('a movie playing: its place handed over, and saved', () async {
    await rig.coordinator.playVod(PlayableMovie(movie(1)));
    rig.engine
      ..firstFrame()
      ..progress(const Duration(minutes: 7));
    final handover = (await rig.coordinator.castStarted(remote))!;
    expect(handover.position, const Duration(minutes: 7));
    expect(rig.progress.lastPosition, const Duration(minutes: 7));
  });

  test('a channel still opening: handed over without facts', () async {
    unawaited(rig.coordinator.playLive(channel(1)));
    await Future<void>.delayed(Duration.zero);
    final handover = (await rig.coordinator.castStarted(remote))!;
    expect(handover.info, isNull);
    expect(handover.item, PlayableChannel(channel(1)));
  });

  test('while casting, plays go to the device, never the player', () async {
    await rig.coordinator.castStarted(remote);
    await rig.coordinator.playLive(channel(2));
    await rig.coordinator.playVod(
      PlayableMovie(movie(3)),
      from: const Duration(minutes: 4),
    );
    expect(remote.calls, ['play k2 null', 'play m3 240']);
    expect(rig.engine.opened, isEmpty);
    expect((rig.state as PlaybackCasting).item, PlayableMovie(movie(3)));
    expect(rig.coordinator.previous, isNull);
  });

  test('retry, seek and pause go to the device too', () async {
    await rig.coordinator.castStarted(remote);
    await rig.coordinator.playVod(PlayableMovie(movie(3)));
    await rig.coordinator.retry();
    await rig.coordinator.seek(const Duration(seconds: 90));
    await rig.coordinator.setPaused(paused: true);
    expect(remote.calls.skip(1), ['retry', 'seek 90', 'paused true']);
  });

  test("a screen's stop leaves the cast alone", () async {
    await rig.coordinator.castStarted(remote);
    await rig.coordinator.playLive(channel(2));
    await rig.coordinator.stop();
    expect(rig.state, isA<PlaybackCasting>());
    expect(rig.engine.calls.where((c) => c == 'stop'), hasLength(1));
  });

  test('what the cast shows, the screens follow', () async {
    await rig.coordinator.castStarted(remote);
    rig.coordinator.castShows(PlayableChannel(channel(5)));
    expect(rig.state.channel, channel(5));
    rig.coordinator.castShows(null);
    expect(rig.state, isA<PlaybackIdle>());
  });

  test('the cast ended: idle, and the next play is here', () async {
    await rig.coordinator.castStarted(remote);
    await rig.coordinator.playLive(channel(2));
    rig.coordinator.castEnded();
    expect(rig.state, isA<PlaybackIdle>());
    expect(rig.coordinator.casting, isFalse);
    await rig.coordinator.playLive(channel(3));
    expect(rig.engine.opened.single.url, contains('k3'));
  });

  test("a one-connection source: the player waits for the cast's "
      'connection to close', () async {
    final connections = rig.coordinator.connections
      ..set('src', StreamHolder.cast, 1);
    final playing = rig.coordinator.playLive(channel(1));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(rig.engine.opened, isEmpty);
    connections.set('src', StreamHolder.cast, 0);
    await playing;
    expect(rig.engine.opened, hasLength(1));
    expect(connections.held('src'), 1);
  });
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:fake_receiver/src/cast_wire.dart';
import 'package:fake_receiver/src/fake_playback.dart';
import 'package:fake_receiver/src/test_certificate.dart';

const nsConnection = 'urn:x-cast:com.google.cast.tp.connection';
const nsHeartbeat = 'urn:x-cast:com.google.cast.tp.heartbeat';
const nsReceiver = 'urn:x-cast:com.google.cast.receiver';
const nsMedia = 'urn:x-cast:com.google.cast.media';
const nsMultizone = 'urn:x-cast:com.google.cast.multizone';

/// The device itself, as a source and a destination.
const receiverId = 'receiver-0';

/// Google's Default Media Receiver.
const defaultMediaReceiver = 'CC1AD845';

/// Who the fake says it is.
final class FakeDevice {
  const new({
    this.name = 'Fake TV',
    this.id = 'fa4e7ec0000000000000000000000001',
    this.capabilities = 458757,
    this.multizone = true,
    this.fixedVolume = true,
    this.hevc = true,
    this.maxHeight = 2160,
    this.linkHeight,
  });

  /// Living Room TV as found: 4K, HEVC (Chromecast with Google TV 4K).
  static const tv4k = FakeDevice();

  /// A 1080p Chromecast that plays H.264 only.
  static const chromecastHd = FakeDevice(
    name: 'Fake Chromecast',
    id: 'fa4e7ec0000000000000000000000002',
    hevc: false,
    maxHeight: 1080,
  );

  /// A 4K TV whose HDMI link runs at 1080p (Input Signal Plus off): it
  /// refuses anything taller with a bare LOAD_FAILED (docs/04).
  static const tvOnHdLink = FakeDevice(
    name: 'Fake TV on an HD link',
    id: 'fa4e7ec0000000000000000000000003',
    linkHeight: 1080,
  );

  /// The friendly name (TXT `fn`, MULTIZONE_STATUS `name`).
  final String name;

  /// 32 hex digits, as discovery's TXT `id` has it.
  final String id;

  /// What Living Room TV's MULTIZONE_STATUS says: bit 0 is video out.
  final int capabilities;

  /// Answers the multizone GET_STATUS, as Living Room TV does.
  final bool multizone;

  /// Its volume follows the TV's own (`controlType: fixed`), as Living
  /// Room TV's does: SET_VOLUME changes nothing.
  final bool fixedVolume;

  /// Plays HEVC. Without, an HEVC picture is refused (with [FakePlayback]).
  final bool hevc;

  /// The tallest picture it plays.
  final int maxHeight;

  /// The HDMI link's height, when it is less than the device's: taller
  /// pictures are refused as by [maxHeight].
  final int? linkHeight;

  /// Why it won't play [check]'s picture, or null.
  String? refuses(FakeMediaCheck check) {
    final height = check.height ?? 0;
    if (check.videoCodec == 'hevc' && !hevc) return 'HEVC';
    if (height > maxHeight) return '${height}p';
    if (linkHeight case final link? when height > link) return '${height}p';
    if (!check.hasVideo && !check.hasAudio) return 'nothing to play';
    return null;
  }

  /// [id] as a UUID, which MULTIZONE_STATUS sends.
  String get uuid =>
      '${id.substring(0, 8)}-${id.substring(8, 12)}-${id.substring(12, 16)}-'
      '${id.substring(16, 20)}-${id.substring(20)}';
}

/// A message the fake received.
final class FakeReceived {
  const new({
    required this.source,
    required this.destination,
    required this.namespace,
    required this.payload,
  });

  final String source;
  final String destination;
  final String namespace;
  final Map<String, Object?> payload;

  String? get type => payload['type']?.toString();

  int? get requestId => switch (payload['requestId']) {
    final int id => id,
    final String id => int.tryParse(id),
    _ => null,
  };

  @override
  String toString() => '${namespace.split('.').last} $type to $destination';
}

/// An app running on the fake.
final class FakeApp {
  const new({
    required this.appId,
    required this.sessionId,
    required this.displayName,
  });

  final String appId;
  final String sessionId;
  final String displayName;

  /// What the app's messages go to: its session id, as on the TV.
  String get transportId => sessionId;
}

/// A Cast device on 127.0.0.1 for tests (Phase 7 decision 8): Cast v2 over
/// TLS with a test-only certificate, the receiver, media and multizone
/// namespaces, the heartbeat, and a media session whose position runs
/// with the clock. It plays nothing yet: fetching the stream and checking
/// it with ffprobe come with the relay (step 5).
///
/// Like a device, it takes a destination's messages only after the sender
/// CONNECTed to it, sends a RECEIVER_STATUS and a MEDIA_STATUS to every
/// sender on each change, leaves `media` out of those, and answers a LOAD
/// it can't play with a MEDIA_STATUS first and a LOAD_FAILED after.
///
/// Faults: [silent], [heartbeat], [dropConnections], [refuseConnections],
/// [refuseLoads], [refuseLaunch], [startOtherApp], the remote's
/// [remotePause], [remotePlay] and [remoteBack], and raw bytes or JSON
/// sent to every sender ([sendRaw], [sendJson]).
final class FakeReceiver {
  new _(
    this._server,
    this.device, {
    required this.launchDelay,
    required this.loadDelay,
    required this.pingEvery,
    this.playback,
    this.log,
  });

  /// Starts on [host]:[port] (0 picks a free port). [receiverRunning]
  /// starts it with the Default Media Receiver already up.
  static Future<FakeReceiver> start({
    FakeDevice device = FakeDevice.tv4k,
    String host = '127.0.0.1',
    int port = 0,
    Duration launchDelay = Duration.zero,
    Duration loadDelay = const Duration(milliseconds: 100),
    Duration? pingEvery = const Duration(seconds: 5),
    bool receiverRunning = false,
    FakePlayback? playback,
    void Function(String line)? log,
  }) async {
    final context = SecurityContext()
      ..useCertificateChainBytes(utf8.encode(testCertificate))
      ..usePrivateKeyBytes(utf8.encode(testPrivateKey));
    final server = await SecureServerSocket.bind(host, port, context);
    final receiver = FakeReceiver._(
      server,
      device,
      launchDelay: launchDelay,
      loadDelay: loadDelay,
      pingEvery: pingEvery,
      playback: playback,
      log: log,
    );
    if (receiverRunning) receiver._app = receiver._newDefaultMediaReceiver();
    server.listen(
      receiver._accept,
      // A client that fails the handshake is its own problem.
      onError: (Object error) => log?.call('handshake failed: $error'),
    );
    return receiver;
  }

  final SecureServerSocket _server;
  final FakeDevice device;
  final Duration launchDelay;
  final Duration loadDelay;
  final Duration? pingEvery;

  /// Fetches and checks what LOAD names, as a TV does; null pretends to
  /// play anything.
  final FakePlayback? playback;
  final void Function(String line)? log;

  final _fetches = <FakeFetch>[];
  final _checks = <FakeMediaCheck>[];
  final _checksStream = StreamController<FakeMediaCheck>.broadcast();

  final _senders = <_Sender>[];
  final _received = <FakeReceived>[];
  final _receivedStream = StreamController<FakeReceived>.broadcast();
  final _clock = Stopwatch()..start();
  final _random = Random();

  FakeApp? _app;
  _Media? _media;
  var _mediaIds = 0;
  var _volume = 1.0;
  var _muted = false;
  Timer? _launching;
  Timer? _loading;
  Timer? _finishing;

  /// Answers nothing at all, and sends no PINGs.
  bool silent = false;

  /// Answers PINGs and sends its own. False stops the heartbeat only.
  bool heartbeat = true;

  /// Closes every new connection at once, as an unreachable device would.
  bool refuseConnections = false;

  /// Answers LAUNCH with LAUNCH_ERROR.
  bool refuseLaunch = false;

  bool Function(Map<String, Object?> media)? _refuse;

  /// Every message received, heartbeats included, in order.
  List<FakeReceived> get received => List.unmodifiable(_received);

  Stream<FakeReceived> get onReceived => _receivedStream.stream;

  String get host => _server.address.address;

  int get port => _server.port;

  /// Open connections from senders.
  int get connections => _senders.length;

  /// What runs: the Default Media Receiver, another app, or nothing.
  FakeApp? get app => _app;

  /// The `media` of the LOAD playing now; null with no media session.
  Map<String, Object?>? get loaded => _media?.media;

  /// IDLE, BUFFERING, PLAYING or PAUSED; null with no media session.
  String? get playerState => _media?.state;

  /// Where the media session is now, in seconds.
  double? get position => _media == null ? null : _positionOf(_media!);

  /// Every request made for the media, in order ([playback] only).
  List<FakeFetch> get fetches => List.unmodifiable(_fetches);

  /// What ffprobe found in each segment, or at the start of a continuous
  /// stream ([playback] only).
  List<FakeMediaCheck> get checks => List.unmodifiable(_checks);

  Stream<FakeMediaCheck> get onChecked => _checksStream.stream;

  /// The messages received of [type] (on any namespace).
  List<FakeReceived> requests(String type) =>
      _received.where((m) => m.type == type).toList();

  /// The next message of [type] to arrive.
  Future<FakeReceived> next(String type) =>
      onReceived.firstWhere((m) => m.type == type);

  /// LOADs whose `media` [test] matches are refused with LOAD_FAILED;
  /// null refuses none.
  // ignore: use_setters_to_change_properties
  void refuseLoads(bool Function(Map<String, Object?> media)? test) =>
      _refuse = test;

  /// Closes every sender's connection, as a Wi-Fi blip does; what runs
  /// keeps running.
  void dropConnections() {
    for (final sender in [..._senders]) {
      sender.destroy();
    }
    _senders.clear();
  }

  /// Another app takes the device: the receiver closes, [name] runs.
  void startOtherApp({String appId = '233637DE', String name = 'YouTube'}) {
    _closeApp(announce: false);
    _app = FakeApp(appId: appId, sessionId: _uuid(), displayName: name);
    _broadcastReceiverStatus();
  }

  /// The TV's remote pauses what plays.
  void remotePause() => _setState('PAUSED');

  /// The TV's remote plays again.
  void remotePlay() => _setState('PLAYING');

  /// The TV's remote goes Back: the receiver closes.
  void remoteBack() => _closeApp();

  /// [bytes] as they are, to every sender.
  void sendRaw(List<int> bytes) {
    for (final sender in _senders) {
      sender.write(bytes);
    }
  }

  /// [payload] on [namespace] from [source], to every sender.
  void sendJson(
    String namespace,
    Map<String, Object?> payload, {
    String source = receiverId,
  }) {
    for (final sender in _senders) {
      for (final id in sender.sources) {
        sender.send(
          WireMessage.json(
            sourceId: source,
            destinationId: id,
            namespace: namespace,
            payload: payload,
          ),
        );
      }
    }
  }

  Future<void> close() async {
    _launching?.cancel();
    _loading?.cancel();
    _finishing?.cancel();
    _media?.watch?.cancel();
    dropConnections();
    await _server.close();
    await _receivedStream.close();
    await _checksStream.close();
  }

  void _accept(SecureSocket socket) {
    if (refuseConnections) {
      socket.destroy();
      return;
    }
    final sender = _Sender(socket);
    _senders.add(sender);
    socket.listen(
      (data) => _onData(sender, data),
      onError: (Object _) => _gone(sender),
      onDone: () => _gone(sender),
    );
    if (pingEvery case final every?) {
      sender.pinger = Timer.periodic(every, (_) {
        if (silent || !heartbeat) return;
        for (final id in sender.sources) {
          sender.send(
            WireMessage.json(
              sourceId: receiverId,
              destinationId: id,
              namespace: nsHeartbeat,
              payload: const {'type': 'PING'},
            ),
          );
        }
      });
    }
  }

  void _gone(_Sender sender) {
    sender.destroy();
    _senders.remove(sender);
  }

  void _onData(_Sender sender, Uint8List data) {
    final frames = sender.splitter.add(data);
    if (frames == null) {
      log?.call('a frame over 64 KiB: closing that connection');
      _gone(sender);
      return;
    }
    for (final body in frames) {
      final WireMessage message;
      try {
        message = WireMessage.decode(body);
      } on FormatException catch (error) {
        log?.call('not a CastMessage: $error');
        continue;
      }
      final payload = message.payload;
      if (payload == null) continue;
      final received = FakeReceived(
        source: message.sourceId,
        destination: message.destinationId,
        namespace: message.namespace,
        payload: payload,
      );
      _received.add(received);
      if (!_receivedStream.isClosed) _receivedStream.add(received);
      _handle(sender, received);
    }
  }

  void _handle(_Sender sender, FakeReceived m) {
    if (m.namespace == nsConnection) {
      switch (m.type) {
        case 'CONNECT':
          sender.connections.add((m.source, m.destination));
        case 'CLOSE':
          sender.connections.remove((m.source, m.destination));
      }
      return;
    }
    // A device takes a destination's messages only on a virtual
    // connection to it.
    if (!sender.connections.contains((m.source, m.destination))) {
      log?.call('dropped $m: no CONNECT to ${m.destination}');
      return;
    }
    if (silent) return;
    switch (m.namespace) {
      case nsHeartbeat:
        if (m.type == 'PING' && heartbeat) {
          _reply(sender, m, nsHeartbeat, {'type': 'PONG'}, withId: false);
        }
      case nsReceiver when m.destination == receiverId:
        _onReceiver(sender, m);
      case nsMultizone when m.destination == receiverId:
        if (m.type == 'GET_STATUS' && device.multizone) {
          _reply(sender, m, nsMultizone, {
            'type': 'MULTIZONE_STATUS',
            'status': {
              'devices': [
                {
                  'capabilities': device.capabilities,
                  'deviceId': device.uuid,
                  'name': device.name,
                  'volume': {'level': _volume, 'muted': _muted},
                },
              ],
              'isMultichannel': false,
            },
          });
        }
      case nsMedia
          when _app?.appId == defaultMediaReceiver &&
              m.destination == _app!.transportId:
        _onMedia(sender, m);
    }
  }

  void _onReceiver(_Sender sender, FakeReceived m) {
    switch (m.type) {
      case 'GET_STATUS':
        _reply(sender, m, nsReceiver, _receiverStatus());
      case 'LAUNCH':
        final appId = m.payload['appId']?.toString();
        if (refuseLaunch || appId != defaultMediaReceiver) {
          _reply(sender, m, nsReceiver, {
            'type': 'LAUNCH_ERROR',
            'reason': refuseLaunch ? 'NOT_ALLOWED' : 'NOT_FOUND',
          });
          return;
        }
        sender.send(
          WireMessage.json(
            sourceId: receiverId,
            destinationId: m.source,
            namespace: nsReceiver,
            payload: {
              'type': 'LAUNCH_STATUS',
              'launchRequestId': m.requestId,
              'status': 'USER_ALLOWED',
            },
          ),
        );
        if (_app?.appId == defaultMediaReceiver) {
          _reply(sender, m, nsReceiver, _receiverStatus());
          return;
        }
        _launching?.cancel();
        _launching = Timer(launchDelay, () {
          _closeApp(announce: false);
          _app = _newDefaultMediaReceiver();
          _reply(sender, m, nsReceiver, _receiverStatus());
          _broadcastReceiverStatus();
        });
      case 'STOP':
        final sessionId = m.payload['sessionId']?.toString();
        if (_app == null ||
            (sessionId != null && sessionId != _app!.sessionId)) {
          _reply(sender, m, nsReceiver, {
            'type': 'INVALID_REQUEST',
            'reason': 'INVALID_SESSION_ID',
          });
          return;
        }
        _closeApp();
        _reply(sender, m, nsReceiver, _receiverStatus());
      case 'SET_VOLUME':
        final volume = m.payload['volume'];
        if (volume is Map<String, Object?> && !device.fixedVolume) {
          if (volume['level'] case final num level) {
            _volume = level.toDouble().clamp(0, 1).toDouble();
          }
          if (volume['muted'] case final bool muted) _muted = muted;
        }
        _reply(sender, m, nsReceiver, _receiverStatus());
        _broadcastReceiverStatus();
      default:
        _reply(sender, m, nsReceiver, {
          'type': 'INVALID_REQUEST',
          'reason': 'INVALID_COMMAND',
        });
    }
  }

  void _onMedia(_Sender sender, FakeReceived m) {
    final media = _media;
    switch (m.type) {
      case 'GET_STATUS':
        _reply(sender, m, nsMedia, {
          'type': 'MEDIA_STATUS',
          'status': [?(media == null ? null : _mediaStatus(media, full: true))],
        });
        return;
      case 'LOAD':
        _load(sender, m);
        return;
    }
    final id = m.payload['mediaSessionId'];
    if (media == null || media.ended || id != media.sessionId) {
      _reply(sender, m, nsMedia, {
        'type': 'INVALID_REQUEST',
        'reason': 'INVALID_MEDIA_SESSION_ID',
      });
      return;
    }
    switch (m.type) {
      case 'PLAY':
        _setState('PLAYING', reply: (sender, m));
      case 'PAUSE':
        _setState('PAUSED', reply: (sender, m));
      case 'SEEK':
        final to = m.payload['currentTime'];
        if (to is num) {
          media
            ..position = to.toDouble()
            ..since = _now;
        }
        final next = switch (m.payload['resumeState']) {
          'PLAYBACK_START' => 'PLAYING',
          'PLAYBACK_PAUSE' => 'PAUSED',
          _ => media.state,
        };
        _setState(next, reply: (sender, m), force: true);
      case 'STOP':
        _end('CANCELLED', reply: (sender, m));
      default:
        _reply(sender, m, nsMedia, {
          'type': 'INVALID_REQUEST',
          'reason': 'INVALID_COMMAND',
        });
    }
  }

  void _load(_Sender sender, FakeReceived m) {
    final media = m.payload['media'];
    if (media is! Map<String, Object?> || media['contentId'] is! String) {
      _reply(sender, m, nsMedia, {
        'type': 'INVALID_REQUEST',
        'reason': 'INVALID_PARAMS',
      });
      return;
    }
    _loading?.cancel();
    _finishing?.cancel();
    _media?.watch?.cancel();
    if (_media case final previous? when previous.loading) {
      final requester = previous.requester;
      if (requester != null) {
        _reply(requester.$1, requester.$2, nsMedia, {'type': 'LOAD_CANCELLED'});
      }
    }
    final start = m.payload['currentTime'];
    final session = _Media(
      sessionId: ++_mediaIds,
      media: media,
      position: start is num ? start.toDouble() : 0,
      since: _now,
      requester: (sender, m),
    );
    _media = session;
    _reply(sender, m, nsMedia, {
      'type': 'MEDIA_STATUS',
      'status': [_mediaStatus(session, full: true)],
    });
    final autoplay = m.payload['autoplay'] != false;
    final play = playback;
    if (play != null && !(_refuse?.call(media) ?? false)) {
      final url = Uri.tryParse('${media['contentId']}');
      if (url == null || !url.hasScheme) {
        _refuseLoad(session, sender, m);
        return;
      }
      session.watch = FakeWatch(
        url: url,
        contentType: '${media['contentType'] ?? ''}',
        playback: play,
        listener: _Watching(this, session, sender, m, autoplay: autoplay),
      )..start();
      return;
    }
    _loading = Timer(loadDelay, () {
      if (!identical(_media, session)) return;
      session
        ..loading = false
        ..requester = null;
      if (_refuse?.call(media) ?? false) {
        _reply(sender, m, nsMedia, {
          'type': 'LOAD_FAILED',
          'severity': 2,
          'itemId': 1,
        });
        _end('ERROR');
        return;
      }
      _setState('BUFFERING');
      _setState(autoplay ? 'PLAYING' : 'PAUSED');
    });
  }

  /// Moves the media session to [state] and tells every sender; the
  /// sender of [reply] gets it as the answer to its request.
  void _setState(
    String state, {
    (_Sender, FakeReceived)? reply,
    bool force = false,
  }) {
    final media = _media;
    if (media == null || media.ended) return;
    if (media.state == state && !force && reply == null) return;
    media
      ..position = _positionOf(media)
      ..since = _now
      ..state = state;
    _finishing?.cancel();
    final duration = _durationOf(media);
    if (state == 'PLAYING' && duration != null) {
      final left = duration - media.position;
      _finishing = Timer(
        Duration(microseconds: max(0, (left * 1e6).round())),
        () => _end('FINISHED'),
      );
    }
    _tellMedia(media, reply);
  }

  /// A LOAD refused: LOAD_FAILED as its second answer, then IDLE/ERROR.
  void _refuseLoad(_Media session, _Sender sender, FakeReceived m) {
    if (!identical(_media, session)) return;
    session
      ..loading = false
      ..requester = null;
    _reply(sender, m, nsMedia, {
      'type': 'LOAD_FAILED',
      'severity': 2,
      'itemId': 1,
    });
    _end('ERROR');
  }

  /// Ends the media session: IDLE with [reason], then no session.
  void _end(String reason, {(_Sender, FakeReceived)? reply}) {
    final media = _media;
    if (media == null) return;
    _finishing?.cancel();
    media.watch?.cancel();
    media
      ..position = _positionOf(media)
      ..since = _now
      ..state = 'IDLE'
      ..loading = false
      ..idleReason = reason
      ..done = true;
    _tellMedia(media, reply);
    _media = null;
  }

  void _tellMedia(_Media media, (_Sender, FakeReceived)? reply) {
    if (reply != null) {
      _reply(reply.$1, reply.$2, nsMedia, {
        'type': 'MEDIA_STATUS',
        'status': [_mediaStatus(media)],
      });
    }
    final app = _app;
    if (app == null) return;
    _broadcast(app.transportId, nsMedia, {
      'type': 'MEDIA_STATUS',
      'status': [_mediaStatus(media)],
    }, except: reply?.$1);
  }

  void _closeApp({bool announce = true}) {
    final app = _app;
    if (app == null) return;
    _loading?.cancel();
    _finishing?.cancel();
    _media?.watch?.cancel();
    _media = null;
    _app = null;
    for (final sender in _senders) {
      for (final (source, destination) in [...sender.connections]) {
        if (destination != app.transportId) continue;
        sender
          ..connections.remove((source, destination))
          ..send(
            WireMessage.json(
              sourceId: app.transportId,
              destinationId: source,
              namespace: nsConnection,
              payload: const {'type': 'CLOSE'},
            ),
          );
      }
    }
    if (announce) _broadcastReceiverStatus();
  }

  void _broadcastReceiverStatus() =>
      _broadcast(receiverId, nsReceiver, _receiverStatus());

  void _reply(
    _Sender sender,
    FakeReceived request,
    String namespace,
    Map<String, Object?> payload, {
    bool withId = true,
  }) {
    if (silent) return;
    sender.send(
      WireMessage.json(
        sourceId: request.destination,
        destinationId: request.source,
        namespace: namespace,
        payload: {...payload, if (withId) 'requestId': request.requestId ?? 0},
      ),
    );
  }

  /// To every sender on a virtual connection to [from].
  void _broadcast(
    String from,
    String namespace,
    Map<String, Object?> payload, {
    _Sender? except,
  }) {
    if (silent) return;
    for (final sender in _senders) {
      if (identical(sender, except)) continue;
      for (final (source, destination) in sender.connections) {
        if (destination != from) continue;
        sender.send(
          WireMessage.json(
            sourceId: from,
            destinationId: source,
            namespace: namespace,
            payload: {...payload, 'requestId': 0},
          ),
        );
      }
    }
  }

  Map<String, Object?> _receiverStatus() => {
    'type': 'RECEIVER_STATUS',
    'status': {
      if (_app case final app?)
        'applications': [
          {
            'appId': app.appId,
            'appType': 'WEB',
            'displayName': app.displayName,
            'iconUrl': '',
            'isIdleScreen': false,
            'launchedFromCloud': false,
            'namespaces': [
              {'name': nsMedia},
            ],
            'senderConnected': _senders.isNotEmpty,
            'sessionId': app.sessionId,
            'statusText': app.displayName,
            'transportId': app.transportId,
            'universalAppId': app.appId,
          },
        ],
      'isActiveInput': true,
      'isStandBy': false,
      'userEq': <String, Object?>{},
      'volume': {
        'controlType': device.fixedVolume ? 'fixed' : 'attenuation',
        'level': _volume,
        'muted': _muted,
        'stepInterval': 0.04,
      },
    },
  };

  /// A media status as the TV sends one; `media` only in answers to LOAD
  /// and GET_STATUS ([full]), as the TV leaves it out of the rest.
  Map<String, Object?> _mediaStatus(_Media media, {bool full = false}) => {
    'mediaSessionId': media.sessionId,
    'playbackRate': 1,
    'playerState': media.state,
    'currentTime': _positionOf(media),
    'supportedMediaCommands': 274447,
    'volume': {'level': 1, 'muted': false},
    if (media.state == 'IDLE' && media.idleReason != null)
      'idleReason': media.idleReason,
    if (full) 'media': media.media,
    if (media.loading)
      'extendedStatus': {
        'playerState': 'LOADING',
        'media': media.media,
        'mediaSessionId': media.sessionId,
      },
    'currentItemId': 1,
    'repeatMode': 'REPEAT_OFF',
  };

  FakeApp _newDefaultMediaReceiver() {
    final id = _uuid();
    return FakeApp(
      appId: defaultMediaReceiver,
      sessionId: id,
      displayName: 'Default Media Receiver',
    );
  }

  double get _now => _clock.elapsedMicroseconds / 1e6;

  double _positionOf(_Media media) {
    final position = media.state == 'PLAYING'
        ? media.position + (_now - media.since)
        : media.position;
    final duration = _durationOf(media);
    return duration == null ? position : min(position, duration);
  }

  double? _durationOf(_Media media) {
    if (media.media['streamType'] == 'LIVE') return null;
    final duration = media.media['duration'];
    return duration is num && duration > 0 ? duration.toDouble() : null;
  }

  String _uuid() {
    String hex(int n) =>
        [for (var i = 0; i < n; i++) _random.nextInt(16).toRadixString(16)]
            .join();
    return '${hex(8)}-${hex(4)}-4${hex(3)}-a${hex(3)}-${hex(12)}';
  }
}

final class _Sender {
  new(this._socket) {
    // Writes to a socket that broke fail here; the reading side reports
    // the break.
    _socket.done.ignore();
  }

  final SecureSocket _socket;
  final splitter = FrameSplitter();

  /// Virtual connections: (sender's source id, destination).
  final connections = <(String, String)>{};
  Timer? pinger;
  var _closed = false;

  /// The source ids this sender connected to the device with.
  Iterable<String> get sources => {
    for (final (source, destination) in connections)
      if (destination == receiverId) source,
  };

  void send(WireMessage message) => write(frame(message.encode()));

  void write(List<int> bytes) {
    if (_closed) return;
    try {
      _socket.add(bytes);
    } on Object {
      // Gone; the reading side reports it.
    }
  }

  void destroy() {
    _closed = true;
    pinger?.cancel();
    _socket.destroy();
  }
}

final class _Media {
  new({
    required this.sessionId,
    required this.media,
    required this.position,
    required this.since,
    this.requester,
  });

  final int sessionId;
  final Map<String, Object?> media;

  /// The position at [since] (seconds on the fake's clock).
  double position;
  double since;
  String state = 'IDLE';
  bool loading = true;
  String? idleReason;

  /// Who sent the LOAD, while it loads: a newer LOAD cancels it.
  (_Sender, FakeReceived)? requester;

  /// Ended: STOP, LOAD_FAILED or played to its end.
  bool done = false;

  /// Fetching the stream ([FakeReceiver.playback]).
  FakeWatch? watch;

  bool get ended => done;
}

/// One LOAD's stream, as the fake plays it: the media session follows
/// what was really fetched.
final class _Watching implements FakeWatchListener {
  new(
    this._fake,
    this._session,
    this._sender,
    this._load, {
    required this.autoplay,
  });

  final FakeReceiver _fake;
  final _Media _session;
  final _Sender _sender;
  final FakeReceived _load;
  final bool autoplay;

  bool get _current => identical(_fake._media, _session) && !_session.done;

  /// Where the media session was when the stream started.
  double? _from;

  @override
  Duration get played => switch (_from) {
    final from? => Duration(
      microseconds: ((_fake._positionOf(_session) - from) * 1e6).round(),
    ),
    null => Duration.zero,
  };

  @override
  void fetched(FakeFetch fetch) => _fake._fetches.add(fetch);

  @override
  void checked(FakeMediaCheck check) {
    _fake._checks.add(check);
    _fake.log?.call('checked $check');
    if (!_fake._checksStream.isClosed) _fake._checksStream.add(check);
  }

  @override
  void started(FakeMediaCheck check) {
    if (!_current) return;
    final refused = _fake.device.refuses(check);
    if (refused != null) {
      _fake.log?.call('refusing $refused');
      Timer(_fake.playback!.refuseDelay, () {
        if (_current) _fake._refuseLoad(_session, _sender, _load);
      });
      return;
    }
    _session
      ..loading = false
      ..requester = null;
    _fake
      .._setState('BUFFERING')
      .._setState(autoplay ? 'PLAYING' : 'PAUSED');
    _from = _fake._positionOf(_session);
  }

  @override
  void stalled({required bool stalled}) {
    if (!_current || _session.loading || _session.state == 'PAUSED') return;
    _fake._setState(stalled ? 'BUFFERING' : 'PLAYING');
  }

  @override
  void finished() {
    if (_current && !_session.loading) _fake._end('FINISHED');
  }

  @override
  void failed(String reason) {
    if (!_current) return;
    _fake.log?.call('playback failed: $reason');
    if (_session.loading) {
      _fake._refuseLoad(_session, _sender, _load);
    } else {
      _fake._end('ERROR');
    }
  }
}

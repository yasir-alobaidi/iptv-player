import 'dart:async';
import 'dart:math';

import 'package:fake_async/fake_async.dart';
import 'package:fake_receiver/fake_receiver.dart'
    show WireMessage, frame, payloadBinary;
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/secret_registry.dart';
import 'package:iptv_player/data/cast/cast_channel.dart';
import 'package:logger/logger.dart';

import 'cast_test_support.dart';

void main() {
  late PipeTransport pipe;
  late CastChannel channel;
  late List<CastMessageIn> heard;

  /// Runs [body] under fake time with a fresh channel on a pipe.
  void run(void Function(FakeAsync async) body) => fakeAsync((async) {
    pipe = PipeTransport();
    channel = CastChannel(pipe);
    heard = [];
    channel.messages.listen(heard.add);
    body(async);
    if (channel.isOpen) channel.destroy('test over');
    async.flushMicrotasks();
  });

  test('sends a CastMessage protoc would read: version 0, sender-0, JSON', () {
    run((async) {
      channel.send(castReceiverId, CastNamespace.receiver, {'type': 'X'});
      final message = pipe.sent.single;
      expect(message.protocolVersion, 0);
      expect(message.sourceId, 'sender-0');
      expect(message.destinationId, castReceiverId);
      expect(message.namespace, CastNamespace.receiver);
      expect(message.payloadType, 0);
      expect(message.payload, {'type': 'X'});
    });
  });

  test('connectTo opens each virtual connection once', () {
    run((async) {
      channel
        ..connectTo(castReceiverId)
        ..connectTo(castReceiverId)
        ..connectTo('app-1');
      expect(
        [for (final m in pipe.sentOn(CastNamespace.connection)) m['type']],
        ['CONNECT', 'CONNECT'],
      );
      expect(channel.isConnectedTo('app-1'), isTrue);
    });
  });

  group('requests', () {
    test('the answer is the message with the same request id', () {
      run((async) {
        CastMessageIn? answer;
        unawaited(
          channel
              .request(castReceiverId, CastNamespace.receiver, {
                'type': 'GET_STATUS',
              })
              .then((m) => answer = m),
        );
        final id = pipe.sentOn(CastNamespace.receiver).single['requestId'];
        pipe
          ..deliver(CastNamespace.receiver, {
            'type': 'RECEIVER_STATUS',
            'requestId': 0,
          })
          ..deliver(CastNamespace.receiver, {
            'type': 'RECEIVER_STATUS',
            'requestId': 99,
          });
        async.flushMicrotasks();
        expect(answer, isNull);
        pipe.deliver(CastNamespace.receiver, {
          'type': 'RECEIVER_STATUS',
          'requestId': '$id',
          'mine': true,
        });
        async.flushMicrotasks();
        expect(answer?.payload['mine'], isTrue);
        // Every message is heard too, answers included.
        expect(heard, hasLength(3));
      });
    });

    test('ids go up from 1', () {
      run((async) {
        for (var i = 0; i < 3; i++) {
          unawaited(channel.request(castReceiverId, 'ns', {'type': 'T'}));
        }
        expect([for (final m in pipe.sentOn('ns')) m['requestId']], [1, 2, 3]);
      });
    });

    test('no answer within the timeout is null', () {
      run((async) {
        var done = false;
        CastMessageIn? answer;
        unawaited(
          channel
              .request(castReceiverId, 'ns', {
                'type': 'T',
              }, timeout: const Duration(seconds: 2))
              .then((m) {
                answer = m;
                done = true;
              }),
        );
        async.elapse(const Duration(milliseconds: 1999));
        expect(done, isFalse);
        async.elapse(const Duration(milliseconds: 1));
        expect(done, isTrue);
        expect(answer, isNull);
        // A late answer is only heard.
        pipe.deliver('ns', {'type': 'LATE', 'requestId': 1});
        async.flushMicrotasks();
        expect(heard.single.type, 'LATE');
      });
    });

    test('a channel that closes answers every pending request with null', () {
      run((async) {
        final answers = <CastMessageIn?>[];
        for (var i = 0; i < 2; i++) {
          unawaited(
            channel.request(castReceiverId, 'ns', {}).then(answers.add),
          );
        }
        pipe.end();
        async.flushMicrotasks();
        expect(answers, [null, null]);
        expect(channel.isOpen, isFalse);
      });
    });

    test('a closed channel sends nothing and answers null at once', () {
      run((async) {
        channel.destroy('gone');
        CastMessageIn? answer = const CastMessageIn(
          source: '',
          namespace: '',
          payload: {},
        );
        unawaited(
          channel.request(castReceiverId, 'ns', {}).then((m) => answer = m),
        );
        async.flushMicrotasks();
        expect(answer, isNull);
        expect(channel.send(castReceiverId, 'ns', {}), isFalse);
        expect(pipe.sent, isEmpty);
      });
    });
  });

  group('heartbeat', () {
    test("answers the device's PING with PONG, to its source", () {
      run((async) {
        pipe.deliver(CastNamespace.heartbeat, {'type': 'PING'}, source: 'x');
        async.flushMicrotasks();
        final pong = pipe.sent.single;
        expect(pong.destinationId, 'x');
        expect(pong.payload, {'type': 'PONG'});
        // Heartbeats aren't passed on.
        expect(heard, isEmpty);
      });
    });

    test('PINGs every 5 s and stays open while the device answers', () {
      run((async) {
        for (var i = 0; i < 12; i++) {
          async.elapse(const Duration(seconds: 5));
          pipe.deliver(CastNamespace.heartbeat, {'type': 'PONG'});
          async.flushMicrotasks();
        }
        expect(pipe.sentOn(CastNamespace.heartbeat), hasLength(12));
        expect(channel.isOpen, isTrue);
      });
    });

    test('three intervals with nothing heard lose the channel', () {
      run((async) {
        String? reason;
        unawaited(channel.closed.then((r) => reason = r));
        async.elapse(const Duration(seconds: 14));
        expect(channel.isOpen, isTrue);
        async.elapse(const Duration(seconds: 1));
        expect(channel.isOpen, isFalse);
        expect(reason, contains('heartbeat'));
        expect(pipe.destroyed, isTrue);
      });
    });

    test('any message counts as heard', () {
      run((async) {
        for (var i = 0; i < 10; i++) {
          async.elapse(const Duration(seconds: 4));
          pipe.deliver(CastNamespace.media, {'type': 'MEDIA_STATUS'});
          async.flushMicrotasks();
        }
        expect(channel.isOpen, isTrue);
      });
    });
  });

  group('tolerant reading', () {
    test('skips what is not a CastMessage, binary, or not a JSON object', () {
      run((async) {
        pipe
          ..deliverBytes(frame([0xff, 0xff, 0xff]))
          ..deliverBytes(
            frame(
              const WireMessage(
                sourceId: 'a',
                destinationId: 'b',
                namespace: 'ns',
                payloadType: payloadBinary,
                payloadBinary: [1, 2],
              ).encode(),
            ),
          )
          ..deliverBytes(
            frame(
              const WireMessage(
                sourceId: 'a',
                destinationId: 'b',
                namespace: 'ns',
                payloadUtf8: '{not json',
              ).encode(),
            ),
          )
          ..deliverBytes(
            frame(
              const WireMessage(
                sourceId: 'a',
                destinationId: 'b',
                namespace: 'ns',
                payloadUtf8: '[1, 2]',
              ).encode(),
            ),
          )
          ..deliver('urn:x-cast:com.example.unknown', {'type': 'WHATEVER'});
        async.flushMicrotasks();
        expect(channel.isOpen, isTrue);
        expect(heard.single.namespace, 'urn:x-cast:com.example.unknown');
      });
    });

    test('a message split byte by byte, and two in one read', () {
      run((async) {
        final one = frame(
          WireMessage.json(
            sourceId: 'r',
            destinationId: 'sender-0',
            namespace: 'ns',
            payload: {'type': 'ONE'},
          ).encode(),
        );
        for (final byte in one) {
          pipe.deliverBytes([byte]);
        }
        pipe.deliverBytes([...one, ...one]);
        async.flushMicrotasks();
        expect([for (final m in heard) m.type], ['ONE', 'ONE', 'ONE']);
      });
    });

    test('a length past 64 KiB closes the channel', () {
      run((async) {
        String? reason;
        unawaited(channel.closed.then((r) => reason = r));
        pipe
          ..deliver('ns', {'type': 'BEFORE'})
          ..deliverBytes([0x00, 0x01, 0x00, 0x01, 1, 2, 3]);
        async.flushMicrotasks();
        expect(heard.single.type, 'BEFORE');
        expect(reason, contains('64 KiB'));
      });
    });

    test('nothing is heard after the channel closed', () {
      run((async) {
        channel.destroy('closed');
        pipe.deliver('ns', {'type': 'AFTER'});
        async.flushMicrotasks();
        expect(heard, isEmpty);
      });
    });

    test("the device's CLOSE ends that virtual connection", () {
      run((async) {
        channel.connectTo('app-1');
        pipe.deliver(CastNamespace.connection, {
          'type': 'CLOSE',
        }, source: 'app-1');
        async.flushMicrotasks();
        expect(channel.isConnectedTo('app-1'), isFalse);
        expect(heard.single.type, 'CLOSE');
      });
    });

    test('fuzz: random bytes never throw or leave the channel stuck', () {
      final random = Random(16);
      for (var round = 0; round < 300; round++) {
        run((async) {
          for (var read = 0; read < 6; read++) {
            final body = [
              for (var i = 0; i < random.nextInt(60); i++) random.nextInt(256),
            ];
            pipe.deliverBytes(random.nextBool() ? frame(body) : body);
          }
          async.flushMicrotasks();
        });
      }
    });
  });

  test("a LOAD's URL is never logged (hard rule 3)", () {
    fakeAsync((async) {
      final output = MemoryOutput();
      final pipe = PipeTransport();
      final channel = CastChannel(
        pipe,
        log: AppLog(
          output: output,
          secrets: SecretRegistry(),
          level: Level.debug,
        ),
      );
      const url = 'http://panel.example:8080/live/someone/hunter2/1.m3u8';
      channel.send('app', CastNamespace.media, {
        'type': 'LOAD',
        'media': {'contentId': url},
      });
      pipe.deliver(CastNamespace.media, {
        'type': 'MEDIA_STATUS',
        'status': [
          {
            'mediaSessionId': 1,
            'media': {'contentId': url},
          },
        ],
      }, source: 'app');
      async.flushMicrotasks();
      final lines = [for (final e in output.buffer) ...e.lines];
      expect(lines, isNotEmpty);
      expect(lines.join('\n'), isNot(contains('hunter2')));
      expect(lines.join('\n'), isNot(contains('someone')));
      channel.destroy('done');
      async.flushMicrotasks();
    });
  });

  group('closing', () {
    test('close sends CLOSE to each virtual connection, newest first', () {
      run((async) {
        channel
          ..connectTo(castReceiverId)
          ..connectTo('app-1');
        unawaited(channel.close());
        async.flushMicrotasks();
        final closes = [
          for (final m in pipe.sent)
            if (m.payload?['type'] == 'CLOSE') m.destinationId,
        ];
        expect(closes, ['app-1', castReceiverId]);
        expect(pipe.closed, isTrue);
        expect(pipe.destroyed, isFalse);
        expect(channel.isOpen, isFalse);
      });
    });

    test('the connection breaking closes the channel with the reason', () {
      run((async) {
        String? reason;
        unawaited(channel.closed.then((r) => reason = r));
        pipe.fail(const SocketExceptionStandIn());
        async.flushMicrotasks();
        expect(reason, contains('broke'));
      });
    });

    test('the device closing the connection closes the channel', () {
      run((async) {
        String? reason;
        unawaited(channel.closed.then((r) => reason = r));
        pipe.end();
        async.flushMicrotasks();
        expect(reason, contains('device closed'));
      });
    });
  });
}

final class SocketExceptionStandIn implements Exception {
  const new();
}

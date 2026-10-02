import 'dart:io';

import 'package:fake_receiver/fake_receiver.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/cast/cast_device.dart';
import 'package:iptv_player/core/cast/cast_discovery.dart';
import 'package:iptv_player/data/cast/cast_connection_check.dart';

/// The check with a short timeout, so silence costs half a second.
CastConnectionCheck _check() =>
    CastConnectionCheck(timeout: const Duration(milliseconds: 500));

final class _Scripted implements CastAddressCheck {
  new(this.answer);

  final CastAddressAnswer answer;
  int asked = 0;

  @override
  Future<CastAddressAnswer> check(CastAddress address) async {
    asked++;
    return answer;
  }
}

void main() {
  late FakeReceiver fake;

  Future<void> startFake([FakeDevice device = FakeDevice.tv4k]) async =>
      fake = await FakeReceiver.start(device: device, pingEvery: null);

  CastAddress address() => CastAddress(fake.host, fake.port);

  tearDown(() => fake.close());

  test('names the device and gives its id from MULTIZONE_STATUS', () async {
    await startFake();
    final answer = await _check().check(address());
    final device = (answer as CastDeviceAnswered).device;
    expect(
      device,
      CastDevice(
        id: 'fa4e7ec0000000000000000000000001',
        name: 'Fake TV',
        host: '127.0.0.1',
        port: fake.port,
        capabilities: 458757,
        manual: true,
      ),
    );
    // Asked the status only: nothing launched, and it let go.
    expect(fake.requests('LAUNCH'), isEmpty);
    expect(fake.app, isNull);
  });

  test('says what runs, as discovery does with TXT rs', () async {
    fake = await FakeReceiver.start(pingEvery: null, receiverRunning: true);
    final answer = await _check().check(address());
    expect(
      (answer as CastDeviceAnswered).device.status,
      'Default Media Receiver',
    );
  });

  test('a device without multizone is named by its address', () async {
    await startFake(const FakeDevice(multizone: false));
    final answer = await _check().check(address());
    final device = (answer as CastDeviceAnswered).device;
    expect(device.name, '127.0.0.1:${fake.port}');
    expect(device.id, 'address:127.0.0.1:${fake.port}');
    expect(device.capabilities, isNull);
  });

  test('a speaker is audio only', () async {
    await startFake(const FakeDevice(name: 'Kitchen speaker', capabilities: 4));
    final answer = await _check().check(address());
    expect((answer as CastAudioOnlyAnswered).name, 'Kitchen speaker');
  });

  test('silence, or nothing listening, is no answer', () async {
    await startFake();
    fake.silent = true;
    expect(await _check().check(address()), isA<CastNoAnswer>());
    final closed = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = closed.port;
    await closed.close();
    expect(
      await _check().check(CastAddress('127.0.0.1', port)),
      isA<CastNoAnswer>(),
    );
  });

  group('checks in turn', () {
    setUp(startFake);

    test('the first answer wins; the rest are not asked', () async {
      final first = _Scripted(const CastAudioOnlyAnswered('Speaker'));
      final second = _Scripted(const CastNoAnswer());
      final answer = await CastAddressChecks([first, second])
          .check(const CastAddress('10.0.0.5'));
      expect(answer, isA<CastAudioOnlyAnswered>());
      expect(second.asked, 0);
    });

    test('no answer falls through to the next', () async {
      final first = _Scripted(const CastNoAnswer());
      final answer = await CastAddressChecks([first, _check()])
          .check(address());
      expect(first.asked, 1);
      expect((answer as CastDeviceAnswered).device.name, 'Fake TV');
      expect(
        await const CastAddressChecks([]).check(address()),
        isA<CastNoAnswer>(),
      );
    });
  });
}

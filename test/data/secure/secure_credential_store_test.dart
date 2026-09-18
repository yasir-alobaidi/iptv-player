import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/data/secure/secure_credential_store.dart';

/// A keyring that refuses everything, the way libsecret does when no
/// secret service is running or the user dismisses the unlock prompt.
final class _RefusingStorage extends FlutterSecureStorage {
  const new();

  static final _refusal = PlatformException(
    code: 'Libsecret error',
    message: 'Failed to unlock the keyring',
    // Some plugins echo the call's arguments back here.
    details: {'key': 'source.1', 'value': 'hunter2-secret'},
  );

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) => throw _refusal;

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) => throw _refusal;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('over the plugin', () {
    late SecureCredentialStore store;

    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
      store = SecureCredentialStore();
    });

    test('writes, reads, lists and deletes', () async {
      expect(
        await store.write('source.a', '{"password":"x"}'),
        isA<Ok<void>>(),
      );

      expect((await store.read('source.a')).valueOrNull, '{"password":"x"}');
      expect((await store.keys()).valueOrNull, {'source.a'});

      expect(await store.delete('source.a'), isA<Ok<void>>());
      expect((await store.read('source.a')).valueOrNull, isNull);
    });

    test('deleting a key that is not there succeeds', () async {
      expect(await store.delete('source.missing'), isA<Ok<void>>());
    });
  });

  group('a keyring that refuses', () {
    final store = SecureCredentialStore(const _RefusingStorage());

    test('fails as secure storage, never as a throw', () async {
      final read = await store.read('source.1');
      final write = await store.write('source.1', 'hunter2-secret');

      expect(read.failureOrNull, isA<SecureStorageFailure>());
      expect(write.failureOrNull, isA<SecureStorageFailure>());
    });

    test("the failure names the problem, not the plugin's echoed "
        'arguments', () async {
      final failure = (await store.write(
        'source.1',
        'hunter2-secret',
      )).failureOrNull!;

      expect(failure.detail, contains('Failed to unlock the keyring'));
      expect(failure.detail, isNot(contains('hunter2')));
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/core/secure/credential_store.dart';

void main() {
  test('the in-memory store round-trips', () async {
    final store = InMemoryCredentialStore();

    await store.write('k', 'v');

    expect((await store.read('k')).valueOrNull, 'v');
    expect((await store.keys()).valueOrNull, {'k'});
    await store.delete('k');
    expect(store.values, isEmpty);
  });

  test('a locked in-memory store fails like a locked keyring', () async {
    final store = InMemoryCredentialStore()..locked = true;

    expect((await store.read('k')).failureOrNull, isA<SecureStorageFailure>());
    expect(
      (await store.write('k', 'v')).failureOrNull,
      isA<SecureStorageFailure>(),
    );
    expect(
      (await store.delete('k')).failureOrNull,
      isA<SecureStorageFailure>(),
    );
    expect((await store.keys()).failureOrNull, isA<SecureStorageFailure>());
  });
}

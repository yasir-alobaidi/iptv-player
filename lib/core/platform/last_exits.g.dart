// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'last_exits.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// `bootstrap()` gives a TV's (`AndroidLastExits`).

@ProviderFor(lastExits)
final lastExitsProvider = LastExitsProvider._();

/// `bootstrap()` gives a TV's (`AndroidLastExits`).

final class LastExitsProvider
    extends
        $FunctionalProvider<LastExitsSource, LastExitsSource, LastExitsSource>
    with $Provider<LastExitsSource> {
  /// `bootstrap()` gives a TV's (`AndroidLastExits`).
  LastExitsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'lastExitsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$lastExitsHash();

  @$internal
  @override
  $ProviderElement<LastExitsSource> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  LastExitsSource create(Ref ref) {
    return lastExits(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LastExitsSource value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LastExitsSource>(value),
    );
  }
}

String _$lastExitsHash() => r'556e6e62a047967453357bb5fda01b2026705a03';

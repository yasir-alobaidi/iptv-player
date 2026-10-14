// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'network_status.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The system's word on the network. Nothing here; `bootstrap()` gives it
/// the system's (`platformSystemNetwork`).

@ProviderFor(systemNetwork)
final systemNetworkProvider = SystemNetworkProvider._();

/// The system's word on the network. Nothing here; `bootstrap()` gives it
/// the system's (`platformSystemNetwork`).

final class SystemNetworkProvider
    extends $FunctionalProvider<SystemNetwork, SystemNetwork, SystemNetwork>
    with $Provider<SystemNetwork> {
  /// The system's word on the network. Nothing here; `bootstrap()` gives it
  /// the system's (`platformSystemNetwork`).
  SystemNetworkProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'systemNetworkProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$systemNetworkHash();

  @$internal
  @override
  $ProviderElement<SystemNetwork> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SystemNetwork create(Ref ref) {
    return systemNetwork(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SystemNetwork value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SystemNetwork>(value),
    );
  }
}

String _$systemNetworkHash() => r'685d64bd78759a60764a07bb97e8a03b5dff11aa';

/// Whether the app is offline: the system's word, with the sources'
/// answers as the fallback; playback reports those
/// (`playbackReachabilityProvider`).

@ProviderFor(networkStatus)
final networkStatusProvider = NetworkStatusProvider._();

/// Whether the app is offline: the system's word, with the sources'
/// answers as the fallback; playback reports those
/// (`playbackReachabilityProvider`).

final class NetworkStatusProvider
    extends $FunctionalProvider<NetworkStatus, NetworkStatus, NetworkStatus>
    with $Provider<NetworkStatus> {
  /// Whether the app is offline: the system's word, with the sources'
  /// answers as the fallback; playback reports those
  /// (`playbackReachabilityProvider`).
  NetworkStatusProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'networkStatusProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$networkStatusHash();

  @$internal
  @override
  $ProviderElement<NetworkStatus> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  NetworkStatus create(Ref ref) {
    return networkStatus(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NetworkStatus value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NetworkStatus>(value),
    );
  }
}

String _$networkStatusHash() => r'f8dd03ddce7561671bdebd3180576a7547a8183b';

/// Whether the app is offline, as it changes: what "You're offline" on
/// every screen reads (the shell's banner, the Guide's line), so no
/// screen works it out from its own last failure.

@ProviderFor(appOffline)
final appOfflineProvider = AppOfflineProvider._();

/// Whether the app is offline, as it changes: what "You're offline" on
/// every screen reads (the shell's banner, the Guide's line), so no
/// screen works it out from its own last failure.

final class AppOfflineProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, Stream<bool>>
    with $FutureModifier<bool>, $StreamProvider<bool> {
  /// Whether the app is offline, as it changes: what "You're offline" on
  /// every screen reads (the shell's banner, the Guide's line), so no
  /// screen works it out from its own last failure.
  AppOfflineProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appOfflineProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appOfflineHash();

  @$internal
  @override
  $StreamProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<bool> create(Ref ref) {
    return appOffline(ref);
  }
}

String _$appOfflineHash() => r'fc578f12743473776446c575cf633bf3a6d65100';

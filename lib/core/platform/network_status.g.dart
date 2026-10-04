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

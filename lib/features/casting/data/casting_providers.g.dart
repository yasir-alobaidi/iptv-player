// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'casting_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(castDeviceStore)
final castDeviceStoreProvider = CastDeviceStoreProvider._();

final class CastDeviceStoreProvider
    extends
        $FunctionalProvider<CastDeviceStore, CastDeviceStore, CastDeviceStore>
    with $Provider<CastDeviceStore> {
  CastDeviceStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'castDeviceStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$castDeviceStoreHash();

  @$internal
  @override
  $ProviderElement<CastDeviceStore> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  CastDeviceStore create(Ref ref) {
    return castDeviceStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CastDeviceStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CastDeviceStore>(value),
    );
  }
}

String _$castDeviceStoreHash() => r'e6c1bf3ec511de3d12d1f248282c8d5b06bc71da';

/// The device's mDNS port first (its name and model, ADR-014), then a
/// Cast connection for one that ignores it.

@ProviderFor(castAddressCheck)
final castAddressCheckProvider = CastAddressCheckProvider._();

/// The device's mDNS port first (its name and model, ADR-014), then a
/// Cast connection for one that ignores it.

final class CastAddressCheckProvider
    extends
        $FunctionalProvider<
          CastAddressCheck,
          CastAddressCheck,
          CastAddressCheck
        >
    with $Provider<CastAddressCheck> {
  /// The device's mDNS port first (its name and model, ADR-014), then a
  /// Cast connection for one that ignores it.
  CastAddressCheckProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'castAddressCheckProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$castAddressCheckHash();

  @$internal
  @override
  $ProviderElement<CastAddressCheck> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  CastAddressCheck create(Ref ref) {
    return castAddressCheck(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CastAddressCheck value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CastAddressCheck>(value),
    );
  }
}

String _$castAddressCheckHash() => r'b2e152540865f26610629f850e59bd8693ce35a6';

/// bonsoir and multicast_dns side by side (Phase 7 decision 6).

@ProviderFor(castDiscovery)
final castDiscoveryProvider = CastDiscoveryProvider._();

/// bonsoir and multicast_dns side by side (Phase 7 decision 6).

final class CastDiscoveryProvider
    extends $FunctionalProvider<CastDiscovery, CastDiscovery, CastDiscovery>
    with $Provider<CastDiscovery> {
  /// bonsoir and multicast_dns side by side (Phase 7 decision 6).
  CastDiscoveryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'castDiscoveryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$castDiscoveryHash();

  @$internal
  @override
  $ProviderElement<CastDiscovery> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  CastDiscovery create(Ref ref) {
    return castDiscovery(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CastDiscovery value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CastDiscovery>(value),
    );
  }
}

String _$castDiscoveryHash() => r'165ebd4f88aec7c435991a8f2abc30bf9d11b12c';

/// The Cast devices on the network and the ones added by address.
/// Discovery runs only while something shows them.

@ProviderFor(castDevices)
final castDevicesProvider = CastDevicesProvider._();

/// The Cast devices on the network and the ones added by address.
/// Discovery runs only while something shows them.

final class CastDevicesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<CastDevice>>,
          List<CastDevice>,
          Stream<List<CastDevice>>
        >
    with $FutureModifier<List<CastDevice>>, $StreamProvider<List<CastDevice>> {
  /// The Cast devices on the network and the ones added by address.
  /// Discovery runs only while something shows them.
  CastDevicesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'castDevicesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$castDevicesHash();

  @$internal
  @override
  $StreamProviderElement<List<CastDevice>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<CastDevice>> create(Ref ref) {
    return castDevices(ref);
  }
}

String _$castDevicesHash() => r'ab3934d44cdc3480df63de9e7a7e4eefa44a477e';

/// Our own Cast v2 client (docs/04).

@ProviderFor(castReceivers)
final castReceiversProvider = CastReceiversProvider._();

/// Our own Cast v2 client (docs/04).

final class CastReceiversProvider
    extends $FunctionalProvider<CastReceivers, CastReceivers, CastReceivers>
    with $Provider<CastReceivers> {
  /// Our own Cast v2 client (docs/04).
  CastReceiversProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'castReceiversProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$castReceiversHash();

  @$internal
  @override
  $ProviderElement<CastReceivers> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  CastReceivers create(Ref ref) {
    return castReceivers(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CastReceivers value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CastReceivers>(value),
    );
  }
}

String _$castReceiversHash() => r'0cc828b349476f3509d08347b59ab750c13465ea';

/// The bundled FFmpeg and ffprobe; null when this build has none.

@ProviderFor(ffmpegBinaries)
final ffmpegBinariesProvider = FfmpegBinariesProvider._();

/// The bundled FFmpeg and ffprobe; null when this build has none.

final class FfmpegBinariesProvider
    extends
        $FunctionalProvider<FfmpegBinaries?, FfmpegBinaries?, FfmpegBinaries?>
    with $Provider<FfmpegBinaries?> {
  /// The bundled FFmpeg and ffprobe; null when this build has none.
  FfmpegBinariesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'ffmpegBinariesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$ffmpegBinariesHash();

  @$internal
  @override
  $ProviderElement<FfmpegBinaries?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  FfmpegBinaries? create(Ref ref) {
    return ffmpegBinaries(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FfmpegBinaries? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FfmpegBinaries?>(value),
    );
  }
}

String _$ffmpegBinariesHash() => r'2c8b15637c48c2cf58a1aba365fe3fdb0b72c358';

@ProviderFor(castReadiness)
final castReadinessProvider = CastReadinessProvider._();

final class CastReadinessProvider
    extends $FunctionalProvider<CastReadiness, CastReadiness, CastReadiness>
    with $Provider<CastReadiness> {
  CastReadinessProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'castReadinessProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$castReadinessHash();

  @$internal
  @override
  $ProviderElement<CastReadiness> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  CastReadiness create(Ref ref) {
    return castReadiness(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CastReadiness value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CastReadiness>(value),
    );
  }
}

String _$castReadinessHash() => r'776336fc1d67db549842eba96e82196e4f532348';

/// The bundled ffprobe under the process supervisor (docs/04).

@ProviderFor(streamProbe)
final streamProbeProvider = StreamProbeProvider._();

/// The bundled ffprobe under the process supervisor (docs/04).

final class StreamProbeProvider
    extends $FunctionalProvider<StreamProbe, StreamProbe, StreamProbe>
    with $Provider<StreamProbe> {
  /// The bundled ffprobe under the process supervisor (docs/04).
  StreamProbeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'streamProbeProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$streamProbeHash();

  @$internal
  @override
  $ProviderElement<StreamProbe> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  StreamProbe create(Ref ref) {
    return streamProbe(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(StreamProbe value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<StreamProbe>(value),
    );
  }
}

String _$streamProbeHash() => r'f1db79b84d20aefee7cd6ad1ad73d48beba1c824';

/// A cast's facts, cheapest first; remembered for the app's run (Phase 7
/// decision 4).

@ProviderFor(streamFactsLookup)
final streamFactsLookupProvider = StreamFactsLookupProvider._();

/// A cast's facts, cheapest first; remembered for the app's run (Phase 7
/// decision 4).

final class StreamFactsLookupProvider
    extends
        $FunctionalProvider<
          StreamFactsLookup,
          StreamFactsLookup,
          StreamFactsLookup
        >
    with $Provider<StreamFactsLookup> {
  /// A cast's facts, cheapest first; remembered for the app's run (Phase 7
  /// decision 4).
  StreamFactsLookupProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'streamFactsLookupProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$streamFactsLookupHash();

  @$internal
  @override
  $ProviderElement<StreamFactsLookup> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  StreamFactsLookup create(Ref ref) {
    return streamFactsLookup(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(StreamFactsLookup value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<StreamFactsLookup>(value),
    );
  }
}

String _$streamFactsLookupHash() => r'ac3046409205a750fc9788d23c5cc297290324fb';

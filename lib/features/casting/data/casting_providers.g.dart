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

/// Where casting keeps its own files. `bootstrap()` points it into the
/// app's own folder; this is the fallback when it has none.

@ProviderFor(castFolder)
final castFolderProvider = CastFolderProvider._();

/// Where casting keeps its own files. `bootstrap()` points it into the
/// app's own folder; this is the fallback when it has none.

final class CastFolderProvider
    extends $FunctionalProvider<Directory, Directory, Directory>
    with $Provider<Directory> {
  /// Where casting keeps its own files. `bootstrap()` points it into the
  /// app's own folder; this is the fallback when it has none.
  CastFolderProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'castFolderProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$castFolderHash();

  @$internal
  @override
  $ProviderElement<Directory> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Directory create(Ref ref) {
    return castFolder(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Directory value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Directory>(value),
    );
  }
}

String _$castFolderHash() => r'8aef71c94265809af952681c927a06bcdb799ba2';

/// The encoders a re-encode can use (Phase 7 step 4), found once per
/// FFmpeg and remembered.

@ProviderFor(castEncoderDetection)
final castEncoderDetectionProvider = CastEncoderDetectionProvider._();

/// The encoders a re-encode can use (Phase 7 step 4), found once per
/// FFmpeg and remembered.

final class CastEncoderDetectionProvider
    extends
        $FunctionalProvider<
          CastEncoderDetection,
          CastEncoderDetection,
          CastEncoderDetection
        >
    with $Provider<CastEncoderDetection> {
  /// The encoders a re-encode can use (Phase 7 step 4), found once per
  /// FFmpeg and remembered.
  CastEncoderDetectionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'castEncoderDetectionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$castEncoderDetectionHash();

  @$internal
  @override
  $ProviderElement<CastEncoderDetection> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CastEncoderDetection create(Ref ref) {
    return castEncoderDetection(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CastEncoderDetection value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CastEncoderDetection>(value),
    );
  }
}

String _$castEncoderDetectionHash() =>
    r'b81569f22ca469f743113a01f0af69bf67e464f3';

/// Where the relay keeps its sessions' segments. `bootstrap()` points it
/// into the app's cache folder; this is the fallback when it has none.

@ProviderFor(relayFolder)
final relayFolderProvider = RelayFolderProvider._();

/// Where the relay keeps its sessions' segments. `bootstrap()` points it
/// into the app's cache folder; this is the fallback when it has none.

final class RelayFolderProvider
    extends $FunctionalProvider<Directory, Directory, Directory>
    with $Provider<Directory> {
  /// Where the relay keeps its sessions' segments. `bootstrap()` points it
  /// into the app's cache folder; this is the fallback when it has none.
  RelayFolderProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'relayFolderProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$relayFolderHash();

  @$internal
  @override
  $ProviderElement<Directory> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Directory create(Ref ref) {
    return relayFolder(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Directory value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Directory>(value),
    );
  }
}

String _$relayFolderHash() => r'df0fb27423157e733546f2ce6c809d955c3f1a84';

/// The relay (Phase 7 step 5): its isolate starts with the first cast or
/// probe, and stops with the app.

@ProviderFor(castRelay)
final castRelayProvider = CastRelayProvider._();

/// The relay (Phase 7 step 5): its isolate starts with the first cast or
/// probe, and stops with the app.

final class CastRelayProvider
    extends $FunctionalProvider<CastRelay, CastRelay, CastRelay>
    with $Provider<CastRelay> {
  /// The relay (Phase 7 step 5): its isolate starts with the first cast or
  /// probe, and stops with the app.
  CastRelayProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'castRelayProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$castRelayHash();

  @$internal
  @override
  $ProviderElement<CastRelay> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  CastRelay create(Ref ref) {
    return castRelay(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CastRelay value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CastRelay>(value),
    );
  }
}

String _$castRelayHash() => r'05adf9ebd69f6808860eec67bf511256ca46bbc7';

/// Settings → Casting (sketch C): Dolby passthrough, Low-latency mode,
/// Smooth interlaced. The defaults at once, the stored choices as soon as
/// they are read; a change is saved and applies to the next cast.

@ProviderFor(CastSettingsController)
final castSettingsControllerProvider = CastSettingsControllerProvider._();

/// Settings → Casting (sketch C): Dolby passthrough, Low-latency mode,
/// Smooth interlaced. The defaults at once, the stored choices as soon as
/// they are read; a change is saved and applies to the next cast.
final class CastSettingsControllerProvider
    extends $NotifierProvider<CastSettingsController, CastSettings> {
  /// Settings → Casting (sketch C): Dolby passthrough, Low-latency mode,
  /// Smooth interlaced. The defaults at once, the stored choices as soon as
  /// they are read; a change is saved and applies to the next cast.
  CastSettingsControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'castSettingsControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$castSettingsControllerHash();

  @$internal
  @override
  CastSettingsController create() => CastSettingsController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CastSettings value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CastSettings>(value),
    );
  }
}

String _$castSettingsControllerHash() =>
    r'37313874078fc0c9e683d51b86dc8a816de21c0a';

/// Settings → Casting (sketch C): Dolby passthrough, Low-latency mode,
/// Smooth interlaced. The defaults at once, the stored choices as soon as
/// they are read; a change is saved and applies to the next cast.

abstract class _$CastSettingsController extends $Notifier<CastSettings> {
  CastSettings build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<CastSettings, CastSettings>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<CastSettings, CastSettings>,
              CastSettings,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Whether this computer has an address on a network a TV could be on
/// (not only loopback): the picker says so when it hasn't.

@ProviderFor(castNetworkAvailable)
final castNetworkAvailableProvider = CastNetworkAvailableProvider._();

/// Whether this computer has an address on a network a TV could be on
/// (not only loopback): the picker says so when it hasn't.

final class CastNetworkAvailableProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, FutureOr<bool>>
    with $FutureModifier<bool>, $FutureProvider<bool> {
  /// Whether this computer has an address on a network a TV could be on
  /// (not only loopback): the picker says so when it hasn't.
  CastNetworkAvailableProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'castNetworkAvailableProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$castNetworkAvailableHash();

  @$internal
  @override
  $FutureProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<bool> create(Ref ref) {
    return castNetworkAvailable(ref);
  }
}

String _$castNetworkAvailableHash() =>
    r'9a3d2417b35af1fcc550092ad5ec876133c0fc92';

/// The TV's picture, from the app's artwork cache. `bootstrap()` points it
/// at the cache; without one there is none.

@ProviderFor(castPictures)
final castPicturesProvider = CastPicturesProvider._();

/// The TV's picture, from the app's artwork cache. `bootstrap()` points it
/// at the cache; without one there is none.

final class CastPicturesProvider
    extends $FunctionalProvider<CastPictures, CastPictures, CastPictures>
    with $Provider<CastPictures> {
  /// The TV's picture, from the app's artwork cache. `bootstrap()` points it
  /// at the cache; without one there is none.
  CastPicturesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'castPicturesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$castPicturesHash();

  @$internal
  @override
  $ProviderElement<CastPictures> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  CastPictures create(Ref ref) {
    return castPictures(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CastPictures value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CastPictures>(value),
    );
  }
}

String _$castPicturesHash() => r'cc011a914b9f46564c206e2a3b285fc2742c5154';

/// What runs before the first relay start: on Windows, the dialog that
/// explains the firewall prompt which follows (step 7). Null: nothing.

@ProviderFor(relayFirewallNotice)
final relayFirewallNoticeProvider = RelayFirewallNoticeProvider._();

/// What runs before the first relay start: on Windows, the dialog that
/// explains the firewall prompt which follows (step 7). Null: nothing.

final class RelayFirewallNoticeProvider
    extends
        $FunctionalProvider<
          RelayFirewallNotice?,
          RelayFirewallNotice?,
          RelayFirewallNotice?
        >
    with $Provider<RelayFirewallNotice?> {
  /// What runs before the first relay start: on Windows, the dialog that
  /// explains the firewall prompt which follows (step 7). Null: nothing.
  RelayFirewallNoticeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'relayFirewallNoticeProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$relayFirewallNoticeHash();

  @$internal
  @override
  $ProviderElement<RelayFirewallNotice?> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  RelayFirewallNotice? create(Ref ref) {
    return relayFirewallNotice(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RelayFirewallNotice? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RelayFirewallNotice?>(value),
    );
  }
}

String _$relayFirewallNoticeHash() =>
    r'afe099dc9cb73bda856dca46e74cc2358712683f';

/// The cast session (Phase 7 step 6): the playback coordinator hands it
/// every play while it is on.

@ProviderFor(castCoordinator)
final castCoordinatorProvider = CastCoordinatorProvider._();

/// The cast session (Phase 7 step 6): the playback coordinator hands it
/// every play while it is on.

final class CastCoordinatorProvider
    extends
        $FunctionalProvider<CastCoordinator, CastCoordinator, CastCoordinator>
    with $Provider<CastCoordinator> {
  /// The cast session (Phase 7 step 6): the playback coordinator hands it
  /// every play while it is on.
  CastCoordinatorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'castCoordinatorProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$castCoordinatorHash();

  @$internal
  @override
  $ProviderElement<CastCoordinator> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  CastCoordinator create(Ref ref) {
    return castCoordinator(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CastCoordinator value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CastCoordinator>(value),
    );
  }
}

String _$castCoordinatorHash() => r'8cc71bf44c1e6739227a9f7e280943b0a9a3b52c';

/// Whether Windows' firewall prompt has been explained before the first
/// relay start (Phase 7 step 7): once is enough.

@ProviderFor(castFirewallNoticeStore)
final castFirewallNoticeStoreProvider = CastFirewallNoticeStoreProvider._();

/// Whether Windows' firewall prompt has been explained before the first
/// relay start (Phase 7 step 7): once is enough.

final class CastFirewallNoticeStoreProvider
    extends
        $FunctionalProvider<
          CastFirewallNoticeStore,
          CastFirewallNoticeStore,
          CastFirewallNoticeStore
        >
    with $Provider<CastFirewallNoticeStore> {
  /// Whether Windows' firewall prompt has been explained before the first
  /// relay start (Phase 7 step 7): once is enough.
  CastFirewallNoticeStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'castFirewallNoticeStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$castFirewallNoticeStoreHash();

  @$internal
  @override
  $ProviderElement<CastFirewallNoticeStore> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CastFirewallNoticeStore create(Ref ref) {
    return castFirewallNoticeStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CastFirewallNoticeStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CastFirewallNoticeStore>(value),
    );
  }
}

String _$castFirewallNoticeStoreHash() =>
    r'75be1b25a2e96139aa033990df9f387a8fca1ade';

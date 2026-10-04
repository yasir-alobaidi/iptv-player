// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'platform_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Holds sleep off while the computer serves a cast (Phase 7 decision 7),
/// and Phase 8's downloads.

@ProviderFor(sleepInhibitor)
final sleepInhibitorProvider = SleepInhibitorProvider._();

/// Holds sleep off while the computer serves a cast (Phase 7 decision 7),
/// and Phase 8's downloads.

final class SleepInhibitorProvider
    extends $FunctionalProvider<SleepInhibitor, SleepInhibitor, SleepInhibitor>
    with $Provider<SleepInhibitor> {
  /// Holds sleep off while the computer serves a cast (Phase 7 decision 7),
  /// and Phase 8's downloads.
  SleepInhibitorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sleepInhibitorProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sleepInhibitorHash();

  @$internal
  @override
  $ProviderElement<SleepInhibitor> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SleepInhibitor create(Ref ref) {
    return sleepInhibitor(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SleepInhibitor value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SleepInhibitor>(value),
    );
  }
}

String _$sleepInhibitorHash() => r'd3907199311fd54bce41cd43e35b8c113c693a84';

/// The one hold the cast and the downloads share (Phase 8 step 3): the
/// computer sleeps again only when neither needs it awake.

@ProviderFor(sharedSleep)
final sharedSleepProvider = SharedSleepProvider._();

/// The one hold the cast and the downloads share (Phase 8 step 3): the
/// computer sleeps again only when neither needs it awake.

final class SharedSleepProvider
    extends $FunctionalProvider<SharedSleep, SharedSleep, SharedSleep>
    with $Provider<SharedSleep> {
  /// The one hold the cast and the downloads share (Phase 8 step 3): the
  /// computer sleeps again only when neither needs it awake.
  SharedSleepProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sharedSleepProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sharedSleepHash();

  @$internal
  @override
  $ProviderElement<SharedSleep> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SharedSleep create(Ref ref) {
    return sharedSleep(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SharedSleep value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SharedSleep>(value),
    );
  }
}

String _$sharedSleepHash() => r'44d2cc48259dc645e71228fe29cdae537096623d';

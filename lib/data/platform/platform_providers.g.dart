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

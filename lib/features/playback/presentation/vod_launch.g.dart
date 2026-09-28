// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vod_launch.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Starts a movie or an episode full screen: Play, Resume and Continue on
/// the details pages, Home's cards (Phase 5 step 7).

@ProviderFor(vodLauncher)
final vodLauncherProvider = VodLauncherProvider._();

/// Starts a movie or an episode full screen: Play, Resume and Continue on
/// the details pages, Home's cards (Phase 5 step 7).

final class VodLauncherProvider
    extends $FunctionalProvider<VodLauncher, VodLauncher, VodLauncher>
    with $Provider<VodLauncher> {
  /// Starts a movie or an episode full screen: Play, Resume and Continue on
  /// the details pages, Home's cards (Phase 5 step 7).
  VodLauncherProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'vodLauncherProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$vodLauncherHash();

  @$internal
  @override
  $ProviderElement<VodLauncher> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  VodLauncher create(Ref ref) {
    return vodLauncher(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VodLauncher value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VodLauncher>(value),
    );
  }
}

String _$vodLauncherHash() => r'59136ba39cdc2c42349f4295b512057436383dc7';

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'guide_match_request.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// A channel whose Match… picker Settings → Guide opens as soon as it
/// shows: set by the Live TV preview's "Match to a guide channel".

@ProviderFor(GuideMatchRequest)
final guideMatchRequestProvider = GuideMatchRequestProvider._();

/// A channel whose Match… picker Settings → Guide opens as soon as it
/// shows: set by the Live TV preview's "Match to a guide channel".
final class GuideMatchRequestProvider
    extends $NotifierProvider<GuideMatchRequest, int?> {
  /// A channel whose Match… picker Settings → Guide opens as soon as it
  /// shows: set by the Live TV preview's "Match to a guide channel".
  GuideMatchRequestProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'guideMatchRequestProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$guideMatchRequestHash();

  @$internal
  @override
  GuideMatchRequest create() => GuideMatchRequest();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int?>(value),
    );
  }
}

String _$guideMatchRequestHash() => r'011453f8bbfa4f98e0b945d6f2a89e7f0a4c2f38';

/// A channel whose Match… picker Settings → Guide opens as soon as it
/// shows: set by the Live TV preview's "Match to a guide channel".

abstract class _$GuideMatchRequest extends $Notifier<int?> {
  int? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<int?, int?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<int?, int?>,
              int?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

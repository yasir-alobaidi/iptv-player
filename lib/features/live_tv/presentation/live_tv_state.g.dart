// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'live_tv_state.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(LiveTvController)
final liveTvControllerProvider = LiveTvControllerProvider._();

final class LiveTvControllerProvider
    extends $NotifierProvider<LiveTvController, LiveTvView?> {
  LiveTvControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'liveTvControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$liveTvControllerHash();

  @$internal
  @override
  LiveTvController create() => LiveTvController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LiveTvView? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LiveTvView?>(value),
    );
  }
}

String _$liveTvControllerHash() => r'49037e25809ab43e2f794d58b7b857c2198634d8';

abstract class _$LiveTvController extends $Notifier<LiveTvView?> {
  LiveTvView? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<LiveTvView?, LiveTvView?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<LiveTvView?, LiveTvView?>,
              LiveTvView?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

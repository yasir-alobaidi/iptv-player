// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'casting_view_state.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The cast as it changes, for the screens.

@ProviderFor(castingState)
final castingStateProvider = CastingStateProvider._();

/// The cast as it changes, for the screens.

final class CastingStateProvider
    extends
        $FunctionalProvider<
          AsyncValue<CastingState>,
          CastingState,
          Stream<CastingState>
        >
    with $FutureModifier<CastingState>, $StreamProvider<CastingState> {
  /// The cast as it changes, for the screens.
  CastingStateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'castingStateProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$castingStateHash();

  @$internal
  @override
  $StreamProviderElement<CastingState> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<CastingState> create(Ref ref) {
    return castingState(ref);
  }
}

String _$castingStateHash() => r'12fcc8f3a48cce251d38adea0e307767776a04f4';

/// Where a movie or an episode is on the TV.

@ProviderFor(castTimeline)
final castTimelineProvider = CastTimelineProvider._();

/// Where a movie or an episode is on the TV.

final class CastTimelineProvider
    extends
        $FunctionalProvider<
          AsyncValue<VodTimeline>,
          VodTimeline,
          Stream<VodTimeline>
        >
    with $FutureModifier<VodTimeline>, $StreamProvider<VodTimeline> {
  /// Where a movie or an episode is on the TV.
  CastTimelineProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'castTimelineProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$castTimelineHash();

  @$internal
  @override
  $StreamProviderElement<VodTimeline> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<VodTimeline> create(Ref ref) {
    return castTimeline(ref);
  }
}

String _$castTimelineHash() => r'ee172c0e9a2a5ade2d953b030d4e7f38a1717dce';

/// Whether the casting view shows in place of the screen (the canvas
/// draws it inside the shell). It closes by itself when the session ends.

@ProviderFor(CastingViewOpen)
final castingViewOpenProvider = CastingViewOpenProvider._();

/// Whether the casting view shows in place of the screen (the canvas
/// draws it inside the shell). It closes by itself when the session ends.
final class CastingViewOpenProvider
    extends $NotifierProvider<CastingViewOpen, bool> {
  /// Whether the casting view shows in place of the screen (the canvas
  /// draws it inside the shell). It closes by itself when the session ends.
  CastingViewOpenProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'castingViewOpenProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$castingViewOpenHash();

  @$internal
  @override
  CastingViewOpen create() => CastingViewOpen();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$castingViewOpenHash() => r'304285f7f0a6ac13f2470f396d5ddf9984181e31';

/// Whether the casting view shows in place of the screen (the canvas
/// draws it inside the shell). It closes by itself when the session ends.

abstract class _$CastingViewOpen extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The devices the app keeps, with their settings and what they taught.

@ProviderFor(knownCastDevices)
final knownCastDevicesProvider = KnownCastDevicesProvider._();

/// The devices the app keeps, with their settings and what they taught.

final class KnownCastDevicesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<KnownCastDevice>>,
          List<KnownCastDevice>,
          Stream<List<KnownCastDevice>>
        >
    with
        $FutureModifier<List<KnownCastDevice>>,
        $StreamProvider<List<KnownCastDevice>> {
  /// The devices the app keeps, with their settings and what they taught.
  KnownCastDevicesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'knownCastDevicesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$knownCastDevicesHash();

  @$internal
  @override
  $StreamProviderElement<List<KnownCastDevice>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<KnownCastDevice>> create(Ref ref) {
    return knownCastDevices(ref);
  }
}

String _$knownCastDevicesHash() => r'27e7c19987e452d12a07699255b8d6bec222e1fe';

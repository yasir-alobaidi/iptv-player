// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'live_tv_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(channelRepository)
final channelRepositoryProvider = ChannelRepositoryProvider._();

final class ChannelRepositoryProvider
    extends
        $FunctionalProvider<
          ChannelRepository,
          ChannelRepository,
          ChannelRepository
        >
    with $Provider<ChannelRepository> {
  ChannelRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'channelRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$channelRepositoryHash();

  @$internal
  @override
  $ProviderElement<ChannelRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ChannelRepository create(Ref ref) {
    return channelRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ChannelRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ChannelRepository>(value),
    );
  }
}

String _$channelRepositoryHash() => r'e0f63d18e0287d335bde4ba808b80755c2cf4d1e';

/// How many channels [query] matches, live.

@ProviderFor(channelCount)
final channelCountProvider = ChannelCountFamily._();

/// How many channels [query] matches, live.

final class ChannelCountProvider
    extends $FunctionalProvider<AsyncValue<int>, int, Stream<int>>
    with $FutureModifier<int>, $StreamProvider<int> {
  /// How many channels [query] matches, live.
  ChannelCountProvider._({
    required ChannelCountFamily super.from,
    required ChannelQuery super.argument,
  }) : super(
         retry: null,
         name: r'channelCountProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$channelCountHash();

  @override
  String toString() {
    return r'channelCountProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<int> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<int> create(Ref ref) {
    final argument = this.argument as ChannelQuery;
    return channelCount(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ChannelCountProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$channelCountHash() => r'72f18199e0daca7d9b95fca2b61bd210f8909a16';

/// How many channels [query] matches, live.

final class ChannelCountFamily extends $Family
    with $FunctionalFamilyOverride<Stream<int>, ChannelQuery> {
  ChannelCountFamily._()
    : super(
        retry: null,
        name: r'channelCountProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// How many channels [query] matches, live.

  ChannelCountProvider call(ChannelQuery query) =>
      ChannelCountProvider._(argument: query, from: this);

  @override
  String toString() => r'channelCountProvider';
}

/// The provider's short EPG (ADR-010 decision 2), behind the imported
/// guide for the channels it has nothing for.

@ProviderFor(shortEpgGuide)
final shortEpgGuideProvider = ShortEpgGuideProvider._();

/// The provider's short EPG (ADR-010 decision 2), behind the imported
/// guide for the channels it has nothing for.

final class ShortEpgGuideProvider
    extends $FunctionalProvider<GuideService, GuideService, GuideService>
    with $Provider<GuideService> {
  /// The provider's short EPG (ADR-010 decision 2), behind the imported
  /// guide for the channels it has nothing for.
  ShortEpgGuideProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'shortEpgGuideProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$shortEpgGuideHash();

  @$internal
  @override
  $ProviderElement<GuideService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  GuideService create(Ref ref) {
    return shortEpgGuide(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GuideService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GuideService>(value),
    );
  }
}

String _$shortEpgGuideHash() => r'358c8b3d242681f50e793fce31cf14505a579713';

/// Now and next for the channels on screen: the imported guide first, the
/// short EPG behind it (Phase 4 decision 1).

@ProviderFor(guideService)
final guideServiceProvider = GuideServiceProvider._();

/// Now and next for the channels on screen: the imported guide first, the
/// short EPG behind it (Phase 4 decision 1).

final class GuideServiceProvider
    extends $FunctionalProvider<GuideService, GuideService, GuideService>
    with $Provider<GuideService> {
  /// Now and next for the channels on screen: the imported guide first, the
  /// short EPG behind it (Phase 4 decision 1).
  GuideServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'guideServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$guideServiceHash();

  @$internal
  @override
  $ProviderElement<GuideService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  GuideService create(Ref ref) {
    return guideService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GuideService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GuideService>(value),
    );
  }
}

String _$guideServiceHash() => r'ec0470fcf5ae72c88df6fe0edc0d3185b6fbd625';

/// What's on [channel] now and next; [NowNext.none] when unknown. Asks
/// again when the guide changes, and when the answer changes shape (the
/// programme on now ends, or the next one starts), so the preview and the
/// player's OSD move on by themselves.

@ProviderFor(nowNext)
final nowNextProvider = NowNextFamily._();

/// What's on [channel] now and next; [NowNext.none] when unknown. Asks
/// again when the guide changes, and when the answer changes shape (the
/// programme on now ends, or the next one starts), so the preview and the
/// player's OSD move on by themselves.

final class NowNextProvider
    extends $FunctionalProvider<AsyncValue<NowNext>, NowNext, FutureOr<NowNext>>
    with $FutureModifier<NowNext>, $FutureProvider<NowNext> {
  /// What's on [channel] now and next; [NowNext.none] when unknown. Asks
  /// again when the guide changes, and when the answer changes shape (the
  /// programme on now ends, or the next one starts), so the preview and the
  /// player's OSD move on by themselves.
  NowNextProvider._({
    required NowNextFamily super.from,
    required ChannelItem super.argument,
  }) : super(
         retry: null,
         name: r'nowNextProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$nowNextHash();

  @override
  String toString() {
    return r'nowNextProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<NowNext> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<NowNext> create(Ref ref) {
    final argument = this.argument as ChannelItem;
    return nowNext(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is NowNextProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$nowNextHash() => r'a0ebab5d8f1be18c2540610310b152bec5aaebd0';

/// What's on [channel] now and next; [NowNext.none] when unknown. Asks
/// again when the guide changes, and when the answer changes shape (the
/// programme on now ends, or the next one starts), so the preview and the
/// player's OSD move on by themselves.

final class NowNextFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<NowNext>, ChannelItem> {
  NowNextFamily._()
    : super(
        retry: null,
        name: r'nowNextProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// What's on [channel] now and next; [NowNext.none] when unknown. Asks
  /// again when the guide changes, and when the answer changes shape (the
  /// programme on now ends, or the next one starts), so the preview and the
  /// player's OSD move on by themselves.

  NowNextProvider call(ChannelItem channel) =>
      NowNextProvider._(argument: channel, from: this);

  @override
  String toString() => r'nowNextProvider';
}

/// Counts guide lookups, so rows showing only what is already cached
/// redraw when a lookup lands.

@ProviderFor(GuideRevision)
final guideRevisionProvider = GuideRevisionProvider._();

/// Counts guide lookups, so rows showing only what is already cached
/// redraw when a lookup lands.
final class GuideRevisionProvider
    extends $NotifierProvider<GuideRevision, int> {
  /// Counts guide lookups, so rows showing only what is already cached
  /// redraw when a lookup lands.
  GuideRevisionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'guideRevisionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$guideRevisionHash();

  @$internal
  @override
  GuideRevision create() => GuideRevision();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$guideRevisionHash() => r'30773efd336c1fc3f7debaf3ad62aeae1da20d87';

/// Counts guide lookups, so rows showing only what is already cached
/// redraw when a lookup lands.

abstract class _$GuideRevision extends $Notifier<int> {
  int build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<int, int>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<int, int>,
              int,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Counts the times the guide said its answers may be stale (an import,
/// the matcher): [nowNext] asks again, and a list looks its rows up again.
/// Each one also bumps [GuideRevision], so what is on screen redraws.

@ProviderFor(GuideChanges)
final guideChangesProvider = GuideChangesProvider._();

/// Counts the times the guide said its answers may be stale (an import,
/// the matcher): [nowNext] asks again, and a list looks its rows up again.
/// Each one also bumps [GuideRevision], so what is on screen redraws.
final class GuideChangesProvider extends $NotifierProvider<GuideChanges, int> {
  /// Counts the times the guide said its answers may be stale (an import,
  /// the matcher): [nowNext] asks again, and a list looks its rows up again.
  /// Each one also bumps [GuideRevision], so what is on screen redraws.
  GuideChangesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'guideChangesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$guideChangesHash();

  @$internal
  @override
  GuideChanges create() => GuideChanges();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$guideChangesHash() => r'3b3bfd80200c47a90c4af690fca908e96cbf7b93';

/// Counts the times the guide said its answers may be stale (an import,
/// the matcher): [nowNext] asks again, and a list looks its rows up again.
/// Each one also bumps [GuideRevision], so what is on screen redraws.

abstract class _$GuideChanges extends $Notifier<int> {
  int build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<int, int>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<int, int>,
              int,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// [channel] as the database has it now (a favorite toggled, a rename).

@ProviderFor(freshChannel)
final freshChannelProvider = FreshChannelFamily._();

/// [channel] as the database has it now (a favorite toggled, a rename).

final class FreshChannelProvider
    extends
        $FunctionalProvider<
          AsyncValue<ChannelItem?>,
          ChannelItem?,
          Stream<ChannelItem?>
        >
    with $FutureModifier<ChannelItem?>, $StreamProvider<ChannelItem?> {
  /// [channel] as the database has it now (a favorite toggled, a rename).
  FreshChannelProvider._({
    required FreshChannelFamily super.from,
    required ChannelItem super.argument,
  }) : super(
         retry: null,
         name: r'freshChannelProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$freshChannelHash();

  @override
  String toString() {
    return r'freshChannelProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<ChannelItem?> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<ChannelItem?> create(Ref ref) {
    final argument = this.argument as ChannelItem;
    return freshChannel(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is FreshChannelProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$freshChannelHash() => r'818c9e53a97a9f29129f1da6accfefa50b8f5b18';

/// [channel] as the database has it now (a favorite toggled, a rename).

final class FreshChannelFamily extends $Family
    with $FunctionalFamilyOverride<Stream<ChannelItem?>, ChannelItem> {
  FreshChannelFamily._()
    : super(
        retry: null,
        name: r'freshChannelProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// [channel] as the database has it now (a favorite toggled, a rename).

  FreshChannelProvider call(ChannelItem channel) =>
      FreshChannelProvider._(argument: channel, from: this);

  @override
  String toString() => r'freshChannelProvider';
}

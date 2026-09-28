// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'home_state.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Continue watching, across every source (decision 5).

@ProviderFor(continueWatching)
final continueWatchingProvider = ContinueWatchingProvider._();

/// Continue watching, across every source (decision 5).

final class ContinueWatchingProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ContinueItem>>,
          List<ContinueItem>,
          Stream<List<ContinueItem>>
        >
    with
        $FutureModifier<List<ContinueItem>>,
        $StreamProvider<List<ContinueItem>> {
  /// Continue watching, across every source (decision 5).
  ContinueWatchingProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'continueWatchingProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$continueWatchingHash();

  @$internal
  @override
  $StreamProviderElement<List<ContinueItem>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<ContinueItem>> create(Ref ref) {
    return continueWatching(ref);
  }
}

String _$continueWatchingHash() => r'35237ed41a2ab3f5f59b9b9db595d2ab9f3f3b5d';

@ProviderFor(homeFavoriteChannels)
final homeFavoriteChannelsProvider = HomeFavoriteChannelsFamily._();

final class HomeFavoriteChannelsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ChannelItem>>,
          List<ChannelItem>,
          Stream<List<ChannelItem>>
        >
    with
        $FutureModifier<List<ChannelItem>>,
        $StreamProvider<List<ChannelItem>> {
  HomeFavoriteChannelsProvider._({
    required HomeFavoriteChannelsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'homeFavoriteChannelsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$homeFavoriteChannelsHash();

  @override
  String toString() {
    return r'homeFavoriteChannelsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<ChannelItem>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<ChannelItem>> create(Ref ref) {
    final argument = this.argument as String;
    return homeFavoriteChannels(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is HomeFavoriteChannelsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$homeFavoriteChannelsHash() =>
    r'af4288be80c2db2fc32126c2fdda8fbc32482446';

final class HomeFavoriteChannelsFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<ChannelItem>>, String> {
  HomeFavoriteChannelsFamily._()
    : super(
        retry: null,
        name: r'homeFavoriteChannelsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  HomeFavoriteChannelsProvider call(String sourceId) =>
      HomeFavoriteChannelsProvider._(argument: sourceId, from: this);

  @override
  String toString() => r'homeFavoriteChannelsProvider';
}

@ProviderFor(homeRecentChannels)
final homeRecentChannelsProvider = HomeRecentChannelsFamily._();

final class HomeRecentChannelsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ChannelItem>>,
          List<ChannelItem>,
          Stream<List<ChannelItem>>
        >
    with
        $FutureModifier<List<ChannelItem>>,
        $StreamProvider<List<ChannelItem>> {
  HomeRecentChannelsProvider._({
    required HomeRecentChannelsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'homeRecentChannelsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$homeRecentChannelsHash();

  @override
  String toString() {
    return r'homeRecentChannelsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<ChannelItem>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<ChannelItem>> create(Ref ref) {
    final argument = this.argument as String;
    return homeRecentChannels(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is HomeRecentChannelsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$homeRecentChannelsHash() =>
    r'74d396a7da1255a4e94a0e24dd26475ccb2ccb22';

final class HomeRecentChannelsFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<ChannelItem>>, String> {
  HomeRecentChannelsFamily._()
    : super(
        retry: null,
        name: r'homeRecentChannelsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  HomeRecentChannelsProvider call(String sourceId) =>
      HomeRecentChannelsProvider._(argument: sourceId, from: this);

  @override
  String toString() => r'homeRecentChannelsProvider';
}

@ProviderFor(homeRecentMovies)
final homeRecentMoviesProvider = HomeRecentMoviesFamily._();

final class HomeRecentMoviesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<MovieItem>>,
          List<MovieItem>,
          Stream<List<MovieItem>>
        >
    with $FutureModifier<List<MovieItem>>, $StreamProvider<List<MovieItem>> {
  HomeRecentMoviesProvider._({
    required HomeRecentMoviesFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'homeRecentMoviesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$homeRecentMoviesHash();

  @override
  String toString() {
    return r'homeRecentMoviesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<MovieItem>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<MovieItem>> create(Ref ref) {
    final argument = this.argument as String;
    return homeRecentMovies(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is HomeRecentMoviesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$homeRecentMoviesHash() => r'217bf6900e7415468616b9c3ac6b6c23fefb05f7';

final class HomeRecentMoviesFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<MovieItem>>, String> {
  HomeRecentMoviesFamily._()
    : super(
        retry: null,
        name: r'homeRecentMoviesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  HomeRecentMoviesProvider call(String sourceId) =>
      HomeRecentMoviesProvider._(argument: sourceId, from: this);

  @override
  String toString() => r'homeRecentMoviesProvider';
}

@ProviderFor(homeRecentSeries)
final homeRecentSeriesProvider = HomeRecentSeriesFamily._();

final class HomeRecentSeriesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<SeriesItem>>,
          List<SeriesItem>,
          Stream<List<SeriesItem>>
        >
    with $FutureModifier<List<SeriesItem>>, $StreamProvider<List<SeriesItem>> {
  HomeRecentSeriesProvider._({
    required HomeRecentSeriesFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'homeRecentSeriesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$homeRecentSeriesHash();

  @override
  String toString() {
    return r'homeRecentSeriesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<SeriesItem>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<SeriesItem>> create(Ref ref) {
    final argument = this.argument as String;
    return homeRecentSeries(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is HomeRecentSeriesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$homeRecentSeriesHash() => r'e025cdd83f165060969a065d11186d5eea106995';

final class HomeRecentSeriesFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<SeriesItem>>, String> {
  HomeRecentSeriesFamily._()
    : super(
        retry: null,
        name: r'homeRecentSeriesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  HomeRecentSeriesProvider call(String sourceId) =>
      HomeRecentSeriesProvider._(argument: sourceId, from: this);

  @override
  String toString() => r'homeRecentSeriesProvider';
}

/// Anything ever watched: until then Home leads with its hero.

@ProviderFor(watchedAnything)
final watchedAnythingProvider = WatchedAnythingProvider._();

/// Anything ever watched: until then Home leads with its hero.

final class WatchedAnythingProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, Stream<bool>>
    with $FutureModifier<bool>, $StreamProvider<bool> {
  /// Anything ever watched: until then Home leads with its hero.
  WatchedAnythingProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'watchedAnythingProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$watchedAnythingHash();

  @$internal
  @override
  $StreamProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<bool> create(Ref ref) {
    return watchedAnything(ref);
  }
}

String _$watchedAnythingHash() => r'af22bd4473515f9dcea0f6d6dd6eefb283dc0933';

/// The first-run hero's counts: the source's visible channels, its movies
/// or its series.

@ProviderFor(homeCount)
final homeCountProvider = HomeCountFamily._();

/// The first-run hero's counts: the source's visible channels, its movies
/// or its series.

final class HomeCountProvider
    extends $FunctionalProvider<AsyncValue<int>, int, Stream<int>>
    with $FutureModifier<int>, $StreamProvider<int> {
  /// The first-run hero's counts: the source's visible channels, its movies
  /// or its series.
  HomeCountProvider._({
    required HomeCountFamily super.from,
    required (String, CatalogueKind) super.argument,
  }) : super(
         retry: null,
         name: r'homeCountProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$homeCountHash();

  @override
  String toString() {
    return r'homeCountProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $StreamProviderElement<int> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<int> create(Ref ref) {
    final argument = this.argument as (String, CatalogueKind);
    return homeCount(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is HomeCountProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$homeCountHash() => r'1fb135ad113d1a35ac5f1c773973c771a12f2a6a';

/// The first-run hero's counts: the source's visible channels, its movies
/// or its series.

final class HomeCountFamily extends $Family
    with $FunctionalFamilyOverride<Stream<int>, (String, CatalogueKind)> {
  HomeCountFamily._()
    : super(
        retry: null,
        name: r'homeCountProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The first-run hero's counts: the source's visible channels, its movies
  /// or its series.

  HomeCountProvider call(String sourceId, CatalogueKind kind) =>
      HomeCountProvider._(argument: (sourceId, kind), from: this);

  @override
  String toString() => r'homeCountProvider';
}

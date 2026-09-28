// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'details_state.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The movie a details page is about, as the grid row knows it; null when
/// the provider no longer has it.

@ProviderFor(movieItem)
final movieItemProvider = MovieItemFamily._();

/// The movie a details page is about, as the grid row knows it; null when
/// the provider no longer has it.

final class MovieItemProvider
    extends
        $FunctionalProvider<
          AsyncValue<Result<MovieItem?>>,
          Result<MovieItem?>,
          FutureOr<Result<MovieItem?>>
        >
    with
        $FutureModifier<Result<MovieItem?>>,
        $FutureProvider<Result<MovieItem?>> {
  /// The movie a details page is about, as the grid row knows it; null when
  /// the provider no longer has it.
  MovieItemProvider._({
    required MovieItemFamily super.from,
    required (String, String) super.argument,
  }) : super(
         retry: null,
         name: r'movieItemProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$movieItemHash();

  @override
  String toString() {
    return r'movieItemProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<Result<MovieItem?>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Result<MovieItem?>> create(Ref ref) {
    final argument = this.argument as (String, String);
    return movieItem(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is MovieItemProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$movieItemHash() => r'6ce15fb7131ecedbfad18bb11758b63c5ed5a1e3';

/// The movie a details page is about, as the grid row knows it; null when
/// the provider no longer has it.

final class MovieItemFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<Result<MovieItem?>>,
          (String, String)
        > {
  MovieItemFamily._()
    : super(
        retry: null,
        name: r'movieItemProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The movie a details page is about, as the grid row knows it; null when
  /// the provider no longer has it.

  MovieItemProvider call(String sourceId, String remoteKey) =>
      MovieItemProvider._(argument: (sourceId, remoteKey), from: this);

  @override
  String toString() => r'movieItemProvider';
}

@ProviderFor(seriesItem)
final seriesItemProvider = SeriesItemFamily._();

final class SeriesItemProvider
    extends
        $FunctionalProvider<
          AsyncValue<Result<SeriesItem?>>,
          Result<SeriesItem?>,
          FutureOr<Result<SeriesItem?>>
        >
    with
        $FutureModifier<Result<SeriesItem?>>,
        $FutureProvider<Result<SeriesItem?>> {
  SeriesItemProvider._({
    required SeriesItemFamily super.from,
    required (String, String) super.argument,
  }) : super(
         retry: null,
         name: r'seriesItemProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$seriesItemHash();

  @override
  String toString() {
    return r'seriesItemProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<Result<SeriesItem?>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Result<SeriesItem?>> create(Ref ref) {
    final argument = this.argument as (String, String);
    return seriesItem(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is SeriesItemProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$seriesItemHash() => r'146110cecaf44b3621e448c667a7ece1908379e5';

final class SeriesItemFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<Result<SeriesItem?>>,
          (String, String)
        > {
  SeriesItemFamily._()
    : super(
        retry: null,
        name: r'seriesItemProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  SeriesItemProvider call(String sourceId, String remoteKey) =>
      SeriesItemProvider._(argument: (sourceId, remoteKey), from: this);

  @override
  String toString() => r'seriesItemProvider';
}

/// A movie's details as they arrive (decision 2), keyed by the title, not
/// its row, so a favorite toggled on the page doesn't start it over.

@ProviderFor(movieDetails)
final movieDetailsProvider = MovieDetailsFamily._();

/// A movie's details as they arrive (decision 2), keyed by the title, not
/// its row, so a favorite toggled on the page doesn't start it over.

final class MovieDetailsProvider
    extends
        $FunctionalProvider<
          AsyncValue<Details<MovieDetails>>,
          Details<MovieDetails>,
          Stream<Details<MovieDetails>>
        >
    with
        $FutureModifier<Details<MovieDetails>>,
        $StreamProvider<Details<MovieDetails>> {
  /// A movie's details as they arrive (decision 2), keyed by the title, not
  /// its row, so a favorite toggled on the page doesn't start it over.
  MovieDetailsProvider._({
    required MovieDetailsFamily super.from,
    required (String, String) super.argument,
  }) : super(
         retry: null,
         name: r'movieDetailsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$movieDetailsHash();

  @override
  String toString() {
    return r'movieDetailsProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $StreamProviderElement<Details<MovieDetails>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<Details<MovieDetails>> create(Ref ref) {
    final argument = this.argument as (String, String);
    return movieDetails(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is MovieDetailsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$movieDetailsHash() => r'b36253a33e9c72b0e0d4d3a41e8252af84a8fe10';

/// A movie's details as they arrive (decision 2), keyed by the title, not
/// its row, so a favorite toggled on the page doesn't start it over.

final class MovieDetailsFamily extends $Family
    with
        $FunctionalFamilyOverride<
          Stream<Details<MovieDetails>>,
          (String, String)
        > {
  MovieDetailsFamily._()
    : super(
        retry: null,
        name: r'movieDetailsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// A movie's details as they arrive (decision 2), keyed by the title, not
  /// its row, so a favorite toggled on the page doesn't start it over.

  MovieDetailsProvider call(String sourceId, String remoteKey) =>
      MovieDetailsProvider._(argument: (sourceId, remoteKey), from: this);

  @override
  String toString() => r'movieDetailsProvider';
}

@ProviderFor(seriesDetails)
final seriesDetailsProvider = SeriesDetailsFamily._();

final class SeriesDetailsProvider
    extends
        $FunctionalProvider<
          AsyncValue<Details<SeriesDetails>>,
          Details<SeriesDetails>,
          Stream<Details<SeriesDetails>>
        >
    with
        $FutureModifier<Details<SeriesDetails>>,
        $StreamProvider<Details<SeriesDetails>> {
  SeriesDetailsProvider._({
    required SeriesDetailsFamily super.from,
    required (String, String) super.argument,
  }) : super(
         retry: null,
         name: r'seriesDetailsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$seriesDetailsHash();

  @override
  String toString() {
    return r'seriesDetailsProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $StreamProviderElement<Details<SeriesDetails>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<Details<SeriesDetails>> create(Ref ref) {
    final argument = this.argument as (String, String);
    return seriesDetails(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is SeriesDetailsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$seriesDetailsHash() => r'5e7e599929e4cbef4c1ccb83cb11659090b61a92';

final class SeriesDetailsFamily extends $Family
    with
        $FunctionalFamilyOverride<
          Stream<Details<SeriesDetails>>,
          (String, String)
        > {
  SeriesDetailsFamily._()
    : super(
        retry: null,
        name: r'seriesDetailsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  SeriesDetailsProvider call(String sourceId, String remoteKey) =>
      SeriesDetailsProvider._(argument: (sourceId, remoteKey), from: this);

  @override
  String toString() => r'seriesDetailsProvider';
}

/// Where a movie or an episode was left, live.

@ProviderFor(watchMark)
final watchMarkProvider = WatchMarkFamily._();

/// Where a movie or an episode was left, live.

final class WatchMarkProvider
    extends
        $FunctionalProvider<
          AsyncValue<WatchMark?>,
          WatchMark?,
          Stream<WatchMark?>
        >
    with $FutureModifier<WatchMark?>, $StreamProvider<WatchMark?> {
  /// Where a movie or an episode was left, live.
  WatchMarkProvider._({
    required WatchMarkFamily super.from,
    required VodRef super.argument,
  }) : super(
         retry: null,
         name: r'watchMarkProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$watchMarkHash();

  @override
  String toString() {
    return r'watchMarkProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<WatchMark?> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<WatchMark?> create(Ref ref) {
    final argument = this.argument as VodRef;
    return watchMark(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is WatchMarkProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$watchMarkHash() => r'89464dbbbeb02879feb7433d5408cf8ab9a7ddb2';

/// Where a movie or an episode was left, live.

final class WatchMarkFamily extends $Family
    with $FunctionalFamilyOverride<Stream<WatchMark?>, VodRef> {
  WatchMarkFamily._()
    : super(
        retry: null,
        name: r'watchMarkProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Where a movie or an episode was left, live.

  WatchMarkProvider call(VodRef title) =>
      WatchMarkProvider._(argument: title, from: this);

  @override
  String toString() => r'watchMarkProvider';
}

/// A series' episodes' marks, live, by the episode's remote key.

@ProviderFor(seriesMarks)
final seriesMarksProvider = SeriesMarksFamily._();

/// A series' episodes' marks, live, by the episode's remote key.

final class SeriesMarksProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, WatchMark>>,
          Map<String, WatchMark>,
          Stream<Map<String, WatchMark>>
        >
    with
        $FutureModifier<Map<String, WatchMark>>,
        $StreamProvider<Map<String, WatchMark>> {
  /// A series' episodes' marks, live, by the episode's remote key.
  SeriesMarksProvider._({
    required SeriesMarksFamily super.from,
    required (String, String) super.argument,
  }) : super(
         retry: null,
         name: r'seriesMarksProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$seriesMarksHash();

  @override
  String toString() {
    return r'seriesMarksProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $StreamProviderElement<Map<String, WatchMark>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<Map<String, WatchMark>> create(Ref ref) {
    final argument = this.argument as (String, String);
    return seriesMarks(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is SeriesMarksProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$seriesMarksHash() => r'a407e757320d649799520d5170313b6719c03052';

/// A series' episodes' marks, live, by the episode's remote key.

final class SeriesMarksFamily extends $Family
    with
        $FunctionalFamilyOverride<
          Stream<Map<String, WatchMark>>,
          (String, String)
        > {
  SeriesMarksFamily._()
    : super(
        retry: null,
        name: r'seriesMarksProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// A series' episodes' marks, live, by the episode's remote key.

  SeriesMarksProvider call(String sourceId, String seriesKey) =>
      SeriesMarksProvider._(argument: (sourceId, seriesKey), from: this);

  @override
  String toString() => r'seriesMarksProvider';
}

/// Starts a movie or an episode full screen. The player takes it over in
/// step 6; until then nothing plays.

@ProviderFor(vodLauncher)
final vodLauncherProvider = VodLauncherProvider._();

/// Starts a movie or an episode full screen. The player takes it over in
/// step 6; until then nothing plays.

final class VodLauncherProvider
    extends $FunctionalProvider<VodLauncher, VodLauncher, VodLauncher>
    with $Provider<VodLauncher> {
  /// Starts a movie or an episode full screen. The player takes it over in
  /// step 6; until then nothing plays.
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

String _$vodLauncherHash() => r'7300c1fc544692c6bb3a7d9ad9296e899946f7a4';

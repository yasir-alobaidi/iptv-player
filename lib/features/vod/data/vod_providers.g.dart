// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vod_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// `get_vod_info` / `get_series_info`, one client per source.

@ProviderFor(titleDetailsSource)
final titleDetailsSourceProvider = TitleDetailsSourceProvider._();

/// `get_vod_info` / `get_series_info`, one client per source.

final class TitleDetailsSourceProvider
    extends
        $FunctionalProvider<
          TitleDetailsSource,
          TitleDetailsSource,
          TitleDetailsSource
        >
    with $Provider<TitleDetailsSource> {
  /// `get_vod_info` / `get_series_info`, one client per source.
  TitleDetailsSourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'titleDetailsSourceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$titleDetailsSourceHash();

  @$internal
  @override
  $ProviderElement<TitleDetailsSource> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  TitleDetailsSource create(Ref ref) {
    return titleDetailsSource(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TitleDetailsSource value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TitleDetailsSource>(value),
    );
  }
}

String _$titleDetailsSourceHash() =>
    r'2ce7e85069efaf8e92d00748039b99f53167803c';

@ProviderFor(movieRepository)
final movieRepositoryProvider = MovieRepositoryProvider._();

final class MovieRepositoryProvider
    extends
        $FunctionalProvider<MovieRepository, MovieRepository, MovieRepository>
    with $Provider<MovieRepository> {
  MovieRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'movieRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$movieRepositoryHash();

  @$internal
  @override
  $ProviderElement<MovieRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  MovieRepository create(Ref ref) {
    return movieRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MovieRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MovieRepository>(value),
    );
  }
}

String _$movieRepositoryHash() => r'5f7e993f26f062ce5cf1c79426fe39a4addcbb34';

@ProviderFor(seriesRepository)
final seriesRepositoryProvider = SeriesRepositoryProvider._();

final class SeriesRepositoryProvider
    extends
        $FunctionalProvider<
          SeriesRepository,
          SeriesRepository,
          SeriesRepository
        >
    with $Provider<SeriesRepository> {
  SeriesRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'seriesRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$seriesRepositoryHash();

  @$internal
  @override
  $ProviderElement<SeriesRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SeriesRepository create(Ref ref) {
    return seriesRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SeriesRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SeriesRepository>(value),
    );
  }
}

String _$seriesRepositoryHash() => r'424a635841ec53f9df62e06074877f0c0deab8ae';

@ProviderFor(watchProgress)
final watchProgressProvider = WatchProgressProvider._();

final class WatchProgressProvider
    extends $FunctionalProvider<WatchProgress, WatchProgress, WatchProgress>
    with $Provider<WatchProgress> {
  WatchProgressProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'watchProgressProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$watchProgressHash();

  @$internal
  @override
  $ProviderElement<WatchProgress> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  WatchProgress create(Ref ref) {
    return watchProgress(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WatchProgress value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WatchProgress>(value),
    );
  }
}

String _$watchProgressHash() => r'e70d8d0bdf8ce61bda025aba5190ac7428b35d1a';

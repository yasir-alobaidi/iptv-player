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

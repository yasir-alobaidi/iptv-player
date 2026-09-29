// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'favorites_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(favoritesRepository)
final favoritesRepositoryProvider = FavoritesRepositoryProvider._();

final class FavoritesRepositoryProvider
    extends
        $FunctionalProvider<
          FavoritesRepository,
          FavoritesRepository,
          FavoritesRepository
        >
    with $Provider<FavoritesRepository> {
  FavoritesRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'favoritesRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$favoritesRepositoryHash();

  @$internal
  @override
  $ProviderElement<FavoritesRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  FavoritesRepository create(Ref ref) {
    return favoritesRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FavoritesRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FavoritesRepository>(value),
    );
  }
}

String _$favoritesRepositoryHash() =>
    r'6cddc72d6c42b9238b5cecc02914cf88e3e8785c';

/// A source's groups of favorite channels, in their order, kept current.

@ProviderFor(favoriteGroups)
final favoriteGroupsProvider = FavoriteGroupsFamily._();

/// A source's groups of favorite channels, in their order, kept current.

final class FavoriteGroupsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<FavoriteGroup>>,
          List<FavoriteGroup>,
          Stream<List<FavoriteGroup>>
        >
    with
        $FutureModifier<List<FavoriteGroup>>,
        $StreamProvider<List<FavoriteGroup>> {
  /// A source's groups of favorite channels, in their order, kept current.
  FavoriteGroupsProvider._({
    required FavoriteGroupsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'favoriteGroupsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$favoriteGroupsHash();

  @override
  String toString() {
    return r'favoriteGroupsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<FavoriteGroup>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<FavoriteGroup>> create(Ref ref) {
    final argument = this.argument as String;
    return favoriteGroups(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is FavoriteGroupsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$favoriteGroupsHash() => r'81627e9cdc73af9a1a352b7b1c3c8e3b193ae30c';

/// A source's groups of favorite channels, in their order, kept current.

final class FavoriteGroupsFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<FavoriteGroup>>, String> {
  FavoriteGroupsFamily._()
    : super(
        retry: null,
        name: r'favoriteGroupsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// A source's groups of favorite channels, in their order, kept current.

  FavoriteGroupsProvider call(String sourceId) =>
      FavoriteGroupsProvider._(argument: sourceId, from: this);

  @override
  String toString() => r'favoriteGroupsProvider';
}

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'router.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Where the app opens: Home, or Welcome when no source is configured yet.
/// `bootstrap()` decides before the first frame.

@ProviderFor(startLocation)
final startLocationProvider = StartLocationProvider._();

/// Where the app opens: Home, or Welcome when no source is configured yet.
/// `bootstrap()` decides before the first frame.

final class StartLocationProvider
    extends $FunctionalProvider<String, String, String>
    with $Provider<String> {
  /// Where the app opens: Home, or Welcome when no source is configured yet.
  /// `bootstrap()` decides before the first frame.
  StartLocationProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'startLocationProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$startLocationHash();

  @$internal
  @override
  $ProviderElement<String> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  String create(Ref ref) {
    return startLocation(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }
}

String _$startLocationHash() => r'ace2815f37092e249cc7f57cc4b4c7fc760948e5';

@ProviderFor(router)
final routerProvider = RouterProvider._();

final class RouterProvider
    extends $FunctionalProvider<GoRouter, GoRouter, GoRouter>
    with $Provider<GoRouter> {
  RouterProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'routerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$routerHash();

  @$internal
  @override
  $ProviderElement<GoRouter> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  GoRouter create(Ref ref) {
    return router(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GoRouter value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GoRouter>(value),
    );
  }
}

String _$routerHash() => r'92c64a2479c0cc2b833824ae06a3a778f9196e5e';

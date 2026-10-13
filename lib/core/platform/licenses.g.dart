// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'licenses.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Read when the Licences dialog opens; let go when it closes.

@ProviderFor(licenses)
final licensesProvider = LicensesProvider._();

/// Read when the Licences dialog opens; let go when it closes.

final class LicensesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<PackageLicenses>>,
          List<PackageLicenses>,
          FutureOr<List<PackageLicenses>>
        >
    with
        $FutureModifier<List<PackageLicenses>>,
        $FutureProvider<List<PackageLicenses>> {
  /// Read when the Licences dialog opens; let go when it closes.
  LicensesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'licensesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$licensesHash();

  @$internal
  @override
  $FutureProviderElement<List<PackageLicenses>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<PackageLicenses>> create(Ref ref) {
    return licenses(ref);
  }
}

String _$licensesHash() => r'952a07b923cc0a319266ec6a4394af69f03e2ba5';

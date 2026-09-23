// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'guide_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(epgRepository)
final epgRepositoryProvider = EpgRepositoryProvider._();

final class EpgRepositoryProvider
    extends $FunctionalProvider<EpgRepository, EpgRepository, EpgRepository>
    with $Provider<EpgRepository> {
  EpgRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'epgRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$epgRepositoryHash();

  @$internal
  @override
  $ProviderElement<EpgRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  EpgRepository create(Ref ref) {
    return epgRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(EpgRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<EpgRepository>(value),
    );
  }
}

String _$epgRepositoryHash() => r'6eb225bd715c7894de32ae8f530813e966f2f377';

/// The one match service: rematches a source after an import's swap and
/// after a sync (`syncServiceProvider` wires the second). Stops its runs
/// when the app closes.
///
/// It depends on nothing but the database and the log, so both the sync
/// engine and the importer can depend on it without a cycle.

@ProviderFor(epgMatchService)
final epgMatchServiceProvider = EpgMatchServiceProvider._();

/// The one match service: rematches a source after an import's swap and
/// after a sync (`syncServiceProvider` wires the second). Stops its runs
/// when the app closes.
///
/// It depends on nothing but the database and the log, so both the sync
/// engine and the importer can depend on it without a cycle.

final class EpgMatchServiceProvider
    extends
        $FunctionalProvider<EpgMatchService, EpgMatchService, EpgMatchService>
    with $Provider<EpgMatchService> {
  /// The one match service: rematches a source after an import's swap and
  /// after a sync (`syncServiceProvider` wires the second). Stops its runs
  /// when the app closes.
  ///
  /// It depends on nothing but the database and the log, so both the sync
  /// engine and the importer can depend on it without a cycle.
  EpgMatchServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'epgMatchServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$epgMatchServiceHash();

  @$internal
  @override
  $ProviderElement<EpgMatchService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  EpgMatchService create(Ref ref) {
    return epgMatchService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(EpgMatchService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<EpgMatchService>(value),
    );
  }
}

String _$epgMatchServiceHash() => r'4cc99273195e860baff2e2eaaa9aefae7ded4f1a';

/// The one guide importer, which rematches after every swap. Cancels its
/// imports when the app closes.

@ProviderFor(epgImporter)
final epgImporterProvider = EpgImporterProvider._();

/// The one guide importer, which rematches after every swap. Cancels its
/// imports when the app closes.

final class EpgImporterProvider
    extends $FunctionalProvider<EpgImporter, EpgImporter, EpgImporter>
    with $Provider<EpgImporter> {
  /// The one guide importer, which rematches after every swap. Cancels its
  /// imports when the app closes.
  EpgImporterProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'epgImporterProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$epgImporterHash();

  @$internal
  @override
  $ProviderElement<EpgImporter> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  EpgImporter create(Ref ref) {
    return epgImporter(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(EpgImporter value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<EpgImporter>(value),
    );
  }
}

String _$epgImporterHash() => r'e6a57cf72e3d9ebd4b0aca3be00413750cf40d03';

/// What the guide covers for [sourceId], live: Settings → Guide and the
/// Guide screen's empty states read it.

@ProviderFor(guideCoverage)
final guideCoverageProvider = GuideCoverageFamily._();

/// What the guide covers for [sourceId], live: Settings → Guide and the
/// Guide screen's empty states read it.

final class GuideCoverageProvider
    extends
        $FunctionalProvider<
          AsyncValue<GuideCoverage>,
          GuideCoverage,
          Stream<GuideCoverage>
        >
    with $FutureModifier<GuideCoverage>, $StreamProvider<GuideCoverage> {
  /// What the guide covers for [sourceId], live: Settings → Guide and the
  /// Guide screen's empty states read it.
  GuideCoverageProvider._({
    required GuideCoverageFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'guideCoverageProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$guideCoverageHash();

  @override
  String toString() {
    return r'guideCoverageProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<GuideCoverage> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<GuideCoverage> create(Ref ref) {
    final argument = this.argument as String;
    return guideCoverage(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is GuideCoverageProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$guideCoverageHash() => r'e2552b152ad219a9b44dba50a6ea32ce18bfa049';

/// What the guide covers for [sourceId], live: Settings → Guide and the
/// Guide screen's empty states read it.

final class GuideCoverageFamily extends $Family
    with $FunctionalFamilyOverride<Stream<GuideCoverage>, String> {
  GuideCoverageFamily._()
    : super(
        retry: null,
        name: r'guideCoverageProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// What the guide covers for [sourceId], live: Settings → Guide and the
  /// Guide screen's empty states read it.

  GuideCoverageProvider call(String sourceId) =>
      GuideCoverageProvider._(argument: sourceId, from: this);

  @override
  String toString() => r'guideCoverageProvider';
}

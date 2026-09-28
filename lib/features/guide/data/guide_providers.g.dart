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

String _$epgRepositoryHash() => r'6562c8d39399e5905dbb6d014c4cbf2819d4e129';

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

String _$epgImporterHash() => r'f337ee0f1378480bb0e23ed03915d1a4221da365';

/// Imports guides on its own: after the launch's syncs, hourly, and
/// after each sync (ADR-011 decision 5). `bootstrap()` starts it; the sync
/// engine tells it of every sync that succeeds.

@ProviderFor(guideScheduler)
final guideSchedulerProvider = GuideSchedulerProvider._();

/// Imports guides on its own: after the launch's syncs, hourly, and
/// after each sync (ADR-011 decision 5). `bootstrap()` starts it; the sync
/// engine tells it of every sync that succeeds.

final class GuideSchedulerProvider
    extends $FunctionalProvider<GuideScheduler, GuideScheduler, GuideScheduler>
    with $Provider<GuideScheduler> {
  /// Imports guides on its own: after the launch's syncs, hourly, and
  /// after each sync (ADR-011 decision 5). `bootstrap()` starts it; the sync
  /// engine tells it of every sync that succeeds.
  GuideSchedulerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'guideSchedulerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$guideSchedulerHash();

  @$internal
  @override
  $ProviderElement<GuideScheduler> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  GuideScheduler create(Ref ref) {
    return guideScheduler(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GuideScheduler value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GuideScheduler>(value),
    );
  }
}

String _$guideSchedulerHash() => r'8b7c6a981148150a94cde6dac458cc01898633ec';

/// The importer as the screens see it.

@ProviderFor(guideImportService)
final guideImportServiceProvider = GuideImportServiceProvider._();

/// The importer as the screens see it.

final class GuideImportServiceProvider
    extends
        $FunctionalProvider<
          GuideImportService,
          GuideImportService,
          GuideImportService
        >
    with $Provider<GuideImportService> {
  /// The importer as the screens see it.
  GuideImportServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'guideImportServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$guideImportServiceHash();

  @$internal
  @override
  $ProviderElement<GuideImportService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  GuideImportService create(Ref ref) {
    return guideImportService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GuideImportService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GuideImportService>(value),
    );
  }
}

String _$guideImportServiceHash() =>
    r'bcf2a1953a235884ab2ee4ff162f69eae45ee51c';

/// The match service as the screens see it.

@ProviderFor(guideMatching)
final guideMatchingProvider = GuideMatchingProvider._();

/// The match service as the screens see it.

final class GuideMatchingProvider
    extends $FunctionalProvider<GuideMatching, GuideMatching, GuideMatching>
    with $Provider<GuideMatching> {
  /// The match service as the screens see it.
  GuideMatchingProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'guideMatchingProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$guideMatchingHash();

  @$internal
  @override
  $ProviderElement<GuideMatching> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  GuideMatching create(Ref ref) {
    return guideMatching(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GuideMatching value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GuideMatching>(value),
    );
  }
}

String _$guideMatchingHash() => r'2a1f98a21128a8dda647f60637481debe5b69f69';

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

/// One programme whole, description and all, for the Guide's detail
/// sheet: the grid reads programmes without their descriptions.

@ProviderFor(guideProgramme)
final guideProgrammeProvider = GuideProgrammeFamily._();

/// One programme whole, description and all, for the Guide's detail
/// sheet: the grid reads programmes without their descriptions.

final class GuideProgrammeProvider
    extends
        $FunctionalProvider<
          AsyncValue<EpgProgramme?>,
          EpgProgramme?,
          FutureOr<EpgProgramme?>
        >
    with $FutureModifier<EpgProgramme?>, $FutureProvider<EpgProgramme?> {
  /// One programme whole, description and all, for the Guide's detail
  /// sheet: the grid reads programmes without their descriptions.
  GuideProgrammeProvider._({
    required GuideProgrammeFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'guideProgrammeProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$guideProgrammeHash();

  @override
  String toString() {
    return r'guideProgrammeProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<EpgProgramme?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<EpgProgramme?> create(Ref ref) {
    final argument = this.argument as int;
    return guideProgramme(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is GuideProgrammeProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$guideProgrammeHash() => r'cef1ec12c57ed6de51c4ba884af382a912546344';

/// One programme whole, description and all, for the Guide's detail
/// sheet: the grid reads programmes without their descriptions.

final class GuideProgrammeFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<EpgProgramme?>, int> {
  GuideProgrammeFamily._()
    : super(
        retry: null,
        name: r'guideProgrammeProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// One programme whole, description and all, for the Guide's detail
  /// sheet: the grid reads programmes without their descriptions.

  GuideProgrammeProvider call(int id) =>
      GuideProgrammeProvider._(argument: id, from: this);

  @override
  String toString() => r'guideProgrammeProvider';
}

/// How far [sourceId]'s running import has got; nothing while none runs.

@ProviderFor(guideImportProgress)
final guideImportProgressProvider = GuideImportProgressFamily._();

/// How far [sourceId]'s running import has got; nothing while none runs.

final class GuideImportProgressProvider
    extends
        $FunctionalProvider<
          AsyncValue<EpgImportProgress>,
          EpgImportProgress,
          Stream<EpgImportProgress>
        >
    with
        $FutureModifier<EpgImportProgress>,
        $StreamProvider<EpgImportProgress> {
  /// How far [sourceId]'s running import has got; nothing while none runs.
  GuideImportProgressProvider._({
    required GuideImportProgressFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'guideImportProgressProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$guideImportProgressHash();

  @override
  String toString() {
    return r'guideImportProgressProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<EpgImportProgress> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<EpgImportProgress> create(Ref ref) {
    final argument = this.argument as String;
    return guideImportProgress(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is GuideImportProgressProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$guideImportProgressHash() =>
    r'69d0cd42058b5d30f10c7217db03bb044a560f6d';

/// How far [sourceId]'s running import has got; nothing while none runs.

final class GuideImportProgressFamily extends $Family
    with $FunctionalFamilyOverride<Stream<EpgImportProgress>, String> {
  GuideImportProgressFamily._()
    : super(
        retry: null,
        name: r'guideImportProgressProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// How far [sourceId]'s running import has got; nothing while none runs.

  GuideImportProgressProvider call(String sourceId) =>
      GuideImportProgressProvider._(argument: sourceId, from: this);

  @override
  String toString() => r'guideImportProgressProvider';
}

/// How well [sourceId]'s guide covers the channels the user can see.

@ProviderFor(channelMatchCounts)
final channelMatchCountsProvider = ChannelMatchCountsFamily._();

/// How well [sourceId]'s guide covers the channels the user can see.

final class ChannelMatchCountsProvider
    extends
        $FunctionalProvider<
          AsyncValue<ChannelMatchCounts>,
          ChannelMatchCounts,
          Stream<ChannelMatchCounts>
        >
    with
        $FutureModifier<ChannelMatchCounts>,
        $StreamProvider<ChannelMatchCounts> {
  /// How well [sourceId]'s guide covers the channels the user can see.
  ChannelMatchCountsProvider._({
    required ChannelMatchCountsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'channelMatchCountsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$channelMatchCountsHash();

  @override
  String toString() {
    return r'channelMatchCountsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<ChannelMatchCounts> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<ChannelMatchCounts> create(Ref ref) {
    final argument = this.argument as String;
    return channelMatchCounts(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ChannelMatchCountsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$channelMatchCountsHash() =>
    r'eedd5e893a1fcd06bb5b3eec064f8d7513a6a92b';

/// How well [sourceId]'s guide covers the channels the user can see.

final class ChannelMatchCountsFamily extends $Family
    with $FunctionalFamilyOverride<Stream<ChannelMatchCounts>, String> {
  ChannelMatchCountsFamily._()
    : super(
        retry: null,
        name: r'channelMatchCountsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// How well [sourceId]'s guide covers the channels the user can see.

  ChannelMatchCountsProvider call(String sourceId) =>
      ChannelMatchCountsProvider._(argument: sourceId, from: this);

  @override
  String toString() => r'channelMatchCountsProvider';
}

/// Where [sourceId]'s guide comes from, or why it has none. Worked out
/// again whenever a source is edited (its EPG URL may have changed).

@ProviderFor(guideOrigin)
final guideOriginProvider = GuideOriginFamily._();

/// Where [sourceId]'s guide comes from, or why it has none. Worked out
/// again whenever a source is edited (its EPG URL may have changed).

final class GuideOriginProvider
    extends
        $FunctionalProvider<
          AsyncValue<Result<GuideOrigin>>,
          Result<GuideOrigin>,
          FutureOr<Result<GuideOrigin>>
        >
    with
        $FutureModifier<Result<GuideOrigin>>,
        $FutureProvider<Result<GuideOrigin>> {
  /// Where [sourceId]'s guide comes from, or why it has none. Worked out
  /// again whenever a source is edited (its EPG URL may have changed).
  GuideOriginProvider._({
    required GuideOriginFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'guideOriginProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$guideOriginHash();

  @override
  String toString() {
    return r'guideOriginProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<Result<GuideOrigin>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Result<GuideOrigin>> create(Ref ref) {
    final argument = this.argument as String;
    return guideOrigin(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is GuideOriginProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$guideOriginHash() => r'43f4c62b02965e057ec463d46842e9eb8160da2f';

/// Where [sourceId]'s guide comes from, or why it has none. Worked out
/// again whenever a source is edited (its EPG URL may have changed).

final class GuideOriginFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<Result<GuideOrigin>>, String> {
  GuideOriginFamily._()
    : super(
        retry: null,
        name: r'guideOriginProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Where [sourceId]'s guide comes from, or why it has none. Worked out
  /// again whenever a source is edited (its EPG URL may have changed).

  GuideOriginProvider call(String sourceId) =>
      GuideOriginProvider._(argument: sourceId, from: this);

  @override
  String toString() => r'guideOriginProvider';
}

@ProviderFor(guideSettingsStore)
final guideSettingsStoreProvider = GuideSettingsStoreProvider._();

final class GuideSettingsStoreProvider
    extends
        $FunctionalProvider<
          GuideSettingsStore,
          GuideSettingsStore,
          GuideSettingsStore
        >
    with $Provider<GuideSettingsStore> {
  GuideSettingsStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'guideSettingsStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$guideSettingsStoreHash();

  @$internal
  @override
  $ProviderElement<GuideSettingsStore> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  GuideSettingsStore create(Ref ref) {
    return guideSettingsStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GuideSettingsStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GuideSettingsStore>(value),
    );
  }
}

String _$guideSettingsStoreHash() =>
    r'5e5fcdc3c0e351f2139d31d12b378e4f6a08da1a';

/// Settings → Guide's choices: the days kept (global) and a source's time
/// offset. The defaults at once, the stored choices as soon as they are
/// read. A change is saved, then re-imports the guides it affects
/// (ADR-011 decision 4), one source at a time.

@ProviderFor(GuideSettingsController)
final guideSettingsControllerProvider = GuideSettingsControllerProvider._();

/// Settings → Guide's choices: the days kept (global) and a source's time
/// offset. The defaults at once, the stored choices as soon as they are
/// read. A change is saved, then re-imports the guides it affects
/// (ADR-011 decision 4), one source at a time.
final class GuideSettingsControllerProvider
    extends $NotifierProvider<GuideSettingsController, GuideSettings> {
  /// Settings → Guide's choices: the days kept (global) and a source's time
  /// offset. The defaults at once, the stored choices as soon as they are
  /// read. A change is saved, then re-imports the guides it affects
  /// (ADR-011 decision 4), one source at a time.
  GuideSettingsControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'guideSettingsControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$guideSettingsControllerHash();

  @$internal
  @override
  GuideSettingsController create() => GuideSettingsController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GuideSettings value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GuideSettings>(value),
    );
  }
}

String _$guideSettingsControllerHash() =>
    r'186f4932b7f754c6187674d58d11101907285d1f';

/// Settings → Guide's choices: the days kept (global) and a source's time
/// offset. The defaults at once, the stored choices as soon as they are
/// read. A change is saved, then re-imports the guides it affects
/// (ADR-011 decision 4), one source at a time.

abstract class _$GuideSettingsController extends $Notifier<GuideSettings> {
  GuideSettings build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<GuideSettings, GuideSettings>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<GuideSettings, GuideSettings>,
              GuideSettings,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

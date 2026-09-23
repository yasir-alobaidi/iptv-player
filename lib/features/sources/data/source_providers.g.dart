// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'source_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(sourceRepository)
final sourceRepositoryProvider = SourceRepositoryProvider._();

final class SourceRepositoryProvider
    extends
        $FunctionalProvider<
          SourceRepository,
          SourceRepository,
          SourceRepository
        >
    with $Provider<SourceRepository> {
  SourceRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sourceRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sourceRepositoryHash();

  @$internal
  @override
  $ProviderElement<SourceRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SourceRepository create(Ref ref) {
    return sourceRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SourceRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SourceRepository>(value),
    );
  }
}

String _$sourceRepositoryHash() => r'e9e0f2798ebc1bb20fd2164faf86a7476a303996';

/// The configured sources in the user's order, kept current.

@ProviderFor(sources)
final sourcesProvider = SourcesProvider._();

/// The configured sources in the user's order, kept current.

final class SourcesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Source>>,
          List<Source>,
          Stream<List<Source>>
        >
    with $FutureModifier<List<Source>>, $StreamProvider<List<Source>> {
  /// The configured sources in the user's order, kept current.
  SourcesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sourcesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sourcesHash();

  @$internal
  @override
  $StreamProviderElement<List<Source>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Source>> create(Ref ref) {
    return sources(ref);
  }
}

String _$sourcesHash() => r'f09e477b25080c9ab0360280dc9a6bab664301d3';

/// The one sync engine. Cancels every run when the app closes. A sync
/// that succeeds rematches the source's channels to its guide, which
/// the sync doesn't wait for (the match service logs how it went).

@ProviderFor(syncService)
final syncServiceProvider = SyncServiceProvider._();

/// The one sync engine. Cancels every run when the app closes. A sync
/// that succeeds rematches the source's channels to its guide, which
/// the sync doesn't wait for (the match service logs how it went).

final class SyncServiceProvider
    extends $FunctionalProvider<SyncService, SyncService, SyncService>
    with $Provider<SyncService> {
  /// The one sync engine. Cancels every run when the app closes. A sync
  /// that succeeds rematches the source's channels to its guide, which
  /// the sync doesn't wait for (the match service logs how it went).
  SyncServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'syncServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$syncServiceHash();

  @$internal
  @override
  $ProviderElement<SyncService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SyncService create(Ref ref) {
    return syncService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SyncService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SyncService>(value),
    );
  }
}

String _$syncServiceHash() => r'3fd1903b57f57e83709d7efe8392b796908aad43';

/// A source's sync as it happens: idle, running with progress, or how the
/// last run this session ended.

@ProviderFor(syncStatus)
final syncStatusProvider = SyncStatusFamily._();

/// A source's sync as it happens: idle, running with progress, or how the
/// last run this session ended.

final class SyncStatusProvider
    extends
        $FunctionalProvider<
          AsyncValue<SyncStatus>,
          SyncStatus,
          Stream<SyncStatus>
        >
    with $FutureModifier<SyncStatus>, $StreamProvider<SyncStatus> {
  /// A source's sync as it happens: idle, running with progress, or how the
  /// last run this session ended.
  SyncStatusProvider._({
    required SyncStatusFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'syncStatusProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$syncStatusHash();

  @override
  String toString() {
    return r'syncStatusProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<SyncStatus> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<SyncStatus> create(Ref ref) {
    final argument = this.argument as String;
    return syncStatus(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is SyncStatusProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$syncStatusHash() => r'df04b02b2da2ddc6453be686f1ae08da0d43ec02';

/// A source's sync as it happens: idle, running with progress, or how the
/// last run this session ended.

final class SyncStatusFamily extends $Family
    with $FunctionalFamilyOverride<Stream<SyncStatus>, String> {
  SyncStatusFamily._()
    : super(
        retry: null,
        name: r'syncStatusProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// A source's sync as it happens: idle, running with progress, or how the
  /// last run this session ended.

  SyncStatusProvider call(String sourceId) =>
      SyncStatusProvider._(argument: sourceId, from: this);

  @override
  String toString() => r'syncStatusProvider';
}

/// One source, kept current; null once it is removed.

@ProviderFor(sourceById)
final sourceByIdProvider = SourceByIdFamily._();

/// One source, kept current; null once it is removed.

final class SourceByIdProvider
    extends $FunctionalProvider<AsyncValue<Source?>, Source?, Stream<Source?>>
    with $FutureModifier<Source?>, $StreamProvider<Source?> {
  /// One source, kept current; null once it is removed.
  SourceByIdProvider._({
    required SourceByIdFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'sourceByIdProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$sourceByIdHash();

  @override
  String toString() {
    return r'sourceByIdProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<Source?> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<Source?> create(Ref ref) {
    final argument = this.argument as String;
    return sourceById(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is SourceByIdProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$sourceByIdHash() => r'93aa0cefc1a90d16c3357d504496cd4a9c7a8f08';

/// One source, kept current; null once it is removed.

final class SourceByIdFamily extends $Family
    with $FunctionalFamilyOverride<Stream<Source?>, String> {
  SourceByIdFamily._()
    : super(
        retry: null,
        name: r'sourceByIdProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// One source, kept current; null once it is removed.

  SourceByIdProvider call(String sourceId) =>
      SourceByIdProvider._(argument: sourceId, from: this);

  @override
  String toString() => r'sourceByIdProvider';
}

/// "Test connection" in onboarding.

@ProviderFor(sourceChecker)
final sourceCheckerProvider = SourceCheckerProvider._();

/// "Test connection" in onboarding.

final class SourceCheckerProvider
    extends $FunctionalProvider<SourceChecker, SourceChecker, SourceChecker>
    with $Provider<SourceChecker> {
  /// "Test connection" in onboarding.
  SourceCheckerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sourceCheckerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sourceCheckerHash();

  @$internal
  @override
  $ProviderElement<SourceChecker> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SourceChecker create(Ref ref) {
    return sourceChecker(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SourceChecker value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SourceChecker>(value),
    );
  }
}

String _$sourceCheckerHash() => r'8c187c5080f4e28ab2b6e1b6429a1aab1021e8a1';

@ProviderFor(categoryRepository)
final categoryRepositoryProvider = CategoryRepositoryProvider._();

final class CategoryRepositoryProvider
    extends
        $FunctionalProvider<
          CategoryRepository,
          CategoryRepository,
          CategoryRepository
        >
    with $Provider<CategoryRepository> {
  CategoryRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'categoryRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$categoryRepositoryHash();

  @$internal
  @override
  $ProviderElement<CategoryRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CategoryRepository create(Ref ref) {
    return categoryRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CategoryRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CategoryRepository>(value),
    );
  }
}

String _$categoryRepositoryHash() =>
    r'e8fc300e2462a69cee8351abc287a91a76e48c76';

/// A source's categories of one kind with their item counts, for the
/// pickers.

@ProviderFor(categoryList)
final categoryListProvider = CategoryListFamily._();

/// A source's categories of one kind with their item counts, for the
/// pickers.

final class CategoryListProvider
    extends
        $FunctionalProvider<
          AsyncValue<CategoryList>,
          CategoryList,
          Stream<CategoryList>
        >
    with $FutureModifier<CategoryList>, $StreamProvider<CategoryList> {
  /// A source's categories of one kind with their item counts, for the
  /// pickers.
  CategoryListProvider._({
    required CategoryListFamily super.from,
    required (String, CatalogueKind) super.argument,
  }) : super(
         retry: null,
         name: r'categoryListProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$categoryListHash();

  @override
  String toString() {
    return r'categoryListProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $StreamProviderElement<CategoryList> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<CategoryList> create(Ref ref) {
    final argument = this.argument as (String, CatalogueKind);
    return categoryList(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is CategoryListProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$categoryListHash() => r'0362094b90880d31916a340c7a03e69d13103988';

/// A source's categories of one kind with their item counts, for the
/// pickers.

final class CategoryListFamily extends $Family
    with
        $FunctionalFamilyOverride<
          Stream<CategoryList>,
          (String, CatalogueKind)
        > {
  CategoryListFamily._()
    : super(
        retry: null,
        name: r'categoryListProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// A source's categories of one kind with their item counts, for the
  /// pickers.

  CategoryListProvider call(String sourceId, CatalogueKind kind) =>
      CategoryListProvider._(argument: (sourceId, kind), from: this);

  @override
  String toString() => r'categoryListProvider';
}

@ProviderFor(sourceOverviewRepository)
final sourceOverviewRepositoryProvider = SourceOverviewRepositoryProvider._();

final class SourceOverviewRepositoryProvider
    extends
        $FunctionalProvider<
          SourceOverviewRepository,
          SourceOverviewRepository,
          SourceOverviewRepository
        >
    with $Provider<SourceOverviewRepository> {
  SourceOverviewRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sourceOverviewRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sourceOverviewRepositoryHash();

  @$internal
  @override
  $ProviderElement<SourceOverviewRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SourceOverviewRepository create(Ref ref) {
    return sourceOverviewRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SourceOverviewRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SourceOverviewRepository>(value),
    );
  }
}

String _$sourceOverviewRepositoryHash() =>
    r'd5669b89752cde7b4d01089a0ff28ff07653ba73';

/// A source's account, counts and latest sync, for Settings → Sources and
/// the top bar; null once the source is gone.

@ProviderFor(sourceOverview)
final sourceOverviewProvider = SourceOverviewFamily._();

/// A source's account, counts and latest sync, for Settings → Sources and
/// the top bar; null once the source is gone.

final class SourceOverviewProvider
    extends
        $FunctionalProvider<
          AsyncValue<SourceOverview?>,
          SourceOverview?,
          Stream<SourceOverview?>
        >
    with $FutureModifier<SourceOverview?>, $StreamProvider<SourceOverview?> {
  /// A source's account, counts and latest sync, for Settings → Sources and
  /// the top bar; null once the source is gone.
  SourceOverviewProvider._({
    required SourceOverviewFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'sourceOverviewProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$sourceOverviewHash();

  @override
  String toString() {
    return r'sourceOverviewProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<SourceOverview?> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<SourceOverview?> create(Ref ref) {
    final argument = this.argument as String;
    return sourceOverview(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is SourceOverviewProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$sourceOverviewHash() => r'6d3804b35427d61867e07569de877877023899d0';

/// A source's account, counts and latest sync, for Settings → Sources and
/// the top bar; null once the source is gone.

final class SourceOverviewFamily extends $Family
    with $FunctionalFamilyOverride<Stream<SourceOverview?>, String> {
  SourceOverviewFamily._()
    : super(
        retry: null,
        name: r'sourceOverviewProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// A source's account, counts and latest sync, for Settings → Sources and
  /// the top bar; null once the source is gone.

  SourceOverviewProvider call(String sourceId) =>
      SourceOverviewProvider._(argument: sourceId, from: this);

  @override
  String toString() => r'sourceOverviewProvider';
}

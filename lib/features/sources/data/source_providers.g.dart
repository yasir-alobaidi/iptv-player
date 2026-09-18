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

/// The one sync engine. Cancels every run when the app closes.

@ProviderFor(syncService)
final syncServiceProvider = SyncServiceProvider._();

/// The one sync engine. Cancels every run when the app closes.

final class SyncServiceProvider
    extends $FunctionalProvider<SyncService, SyncService, SyncService>
    with $Provider<SyncService> {
  /// The one sync engine. Cancels every run when the app closes.
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

String _$syncServiceHash() => r'8c3286facc3008a7104e48c9ed47dcd3f1e245f4';

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

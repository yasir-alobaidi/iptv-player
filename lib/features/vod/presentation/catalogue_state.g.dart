// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'catalogue_state.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The sort a Movies or Series grid was left on, for the session: coming
/// back to a grid finds it as it was (docs/05).

@ProviderFor(CatalogueSort)
final catalogueSortProvider = CatalogueSortFamily._();

/// The sort a Movies or Series grid was left on, for the session: coming
/// back to a grid finds it as it was (docs/05).
final class CatalogueSortProvider
    extends $NotifierProvider<CatalogueSort, TitleSort> {
  /// The sort a Movies or Series grid was left on, for the session: coming
  /// back to a grid finds it as it was (docs/05).
  CatalogueSortProvider._({
    required CatalogueSortFamily super.from,
    required CatalogueKind super.argument,
  }) : super(
         retry: null,
         name: r'catalogueSortProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$catalogueSortHash();

  @override
  String toString() {
    return r'catalogueSortProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  CatalogueSort create() => CatalogueSort();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TitleSort value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TitleSort>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is CatalogueSortProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$catalogueSortHash() => r'cd5dcbef8ac1dba5e1c3e10e1f6fcd5147135171';

/// The sort a Movies or Series grid was left on, for the session: coming
/// back to a grid finds it as it was (docs/05).

final class CatalogueSortFamily extends $Family
    with
        $ClassFamilyOverride<
          CatalogueSort,
          TitleSort,
          TitleSort,
          TitleSort,
          CatalogueKind
        > {
  CatalogueSortFamily._()
    : super(
        retry: null,
        name: r'catalogueSortProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// The sort a Movies or Series grid was left on, for the session: coming
  /// back to a grid finds it as it was (docs/05).

  CatalogueSortProvider call(CatalogueKind kind) =>
      CatalogueSortProvider._(argument: kind, from: this);

  @override
  String toString() => r'catalogueSortProvider';
}

/// The sort a Movies or Series grid was left on, for the session: coming
/// back to a grid finds it as it was (docs/05).

abstract class _$CatalogueSort extends $Notifier<TitleSort> {
  late final _$args = ref.$arg as CatalogueKind;
  CatalogueKind get kind => _$args;

  TitleSort build(CatalogueKind kind);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<TitleSort, TitleSort>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<TitleSort, TitleSort>,
              TitleSort,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}

/// What a Movies or Series grid shows: the browsed source's titles, one
/// category or all, a filter and the sort. Starts over when the source
/// changes; the sort stays.

@ProviderFor(CatalogueController)
final catalogueControllerProvider = CatalogueControllerFamily._();

/// What a Movies or Series grid shows: the browsed source's titles, one
/// category or all, a filter and the sort. Starts over when the source
/// changes; the sort stays.
final class CatalogueControllerProvider
    extends $NotifierProvider<CatalogueController, TitleQuery?> {
  /// What a Movies or Series grid shows: the browsed source's titles, one
  /// category or all, a filter and the sort. Starts over when the source
  /// changes; the sort stays.
  CatalogueControllerProvider._({
    required CatalogueControllerFamily super.from,
    required CatalogueKind super.argument,
  }) : super(
         retry: null,
         name: r'catalogueControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$catalogueControllerHash();

  @override
  String toString() {
    return r'catalogueControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  CatalogueController create() => CatalogueController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TitleQuery? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TitleQuery?>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is CatalogueControllerProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$catalogueControllerHash() =>
    r'93396ac76f94a8c181c82b40f7a86c7ce69b5cac';

/// What a Movies or Series grid shows: the browsed source's titles, one
/// category or all, a filter and the sort. Starts over when the source
/// changes; the sort stays.

final class CatalogueControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          CatalogueController,
          TitleQuery?,
          TitleQuery?,
          TitleQuery?,
          CatalogueKind
        > {
  CatalogueControllerFamily._()
    : super(
        retry: null,
        name: r'catalogueControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// What a Movies or Series grid shows: the browsed source's titles, one
  /// category or all, a filter and the sort. Starts over when the source
  /// changes; the sort stays.

  CatalogueControllerProvider call(CatalogueKind kind) =>
      CatalogueControllerProvider._(argument: kind, from: this);

  @override
  String toString() => r'catalogueControllerProvider';
}

/// What a Movies or Series grid shows: the browsed source's titles, one
/// category or all, a filter and the sort. Starts over when the source
/// changes; the sort stays.

abstract class _$CatalogueController extends $Notifier<TitleQuery?> {
  late final _$args = ref.$arg as CatalogueKind;
  CatalogueKind get kind => _$args;

  TitleQuery? build(CatalogueKind kind);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<TitleQuery?, TitleQuery?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<TitleQuery?, TitleQuery?>,
              TitleQuery?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}

@ProviderFor(titleCount)
final titleCountProvider = TitleCountFamily._();

final class TitleCountProvider
    extends
        $FunctionalProvider<
          AsyncValue<TitleCount>,
          TitleCount,
          Stream<TitleCount>
        >
    with $FutureModifier<TitleCount>, $StreamProvider<TitleCount> {
  TitleCountProvider._({
    required TitleCountFamily super.from,
    required (CatalogueKind, TitleQuery) super.argument,
  }) : super(
         retry: null,
         name: r'titleCountProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$titleCountHash();

  @override
  String toString() {
    return r'titleCountProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $StreamProviderElement<TitleCount> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<TitleCount> create(Ref ref) {
    final argument = this.argument as (CatalogueKind, TitleQuery);
    return titleCount(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is TitleCountProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$titleCountHash() => r'25366534489013930f285d2ad8586baefa7dc63a';

final class TitleCountFamily extends $Family
    with
        $FunctionalFamilyOverride<
          Stream<TitleCount>,
          (CatalogueKind, TitleQuery)
        > {
  TitleCountFamily._()
    : super(
        retry: null,
        name: r'titleCountProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  TitleCountProvider call(CatalogueKind kind, TitleQuery query) =>
      TitleCountProvider._(argument: (kind, query), from: this);

  @override
  String toString() => r'titleCountProvider';
}

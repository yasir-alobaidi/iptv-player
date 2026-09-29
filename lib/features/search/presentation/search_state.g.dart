// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'search_state.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// One opening of the overlay: the search as it is typed. Gone when the
/// overlay closes.

@ProviderFor(SearchSession)
final searchSessionProvider = SearchSessionProvider._();

/// One opening of the overlay: the search as it is typed. Gone when the
/// overlay closes.
final class SearchSessionProvider
    extends $NotifierProvider<SearchSession, SearchView> {
  /// One opening of the overlay: the search as it is typed. Gone when the
  /// overlay closes.
  SearchSessionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'searchSessionProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$searchSessionHash();

  @$internal
  @override
  SearchSession create() => SearchSession();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SearchView value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SearchView>(value),
    );
  }
}

String _$searchSessionHash() => r'5483bf09bea6b6ed537019fa5727e92752a29a38';

/// One opening of the overlay: the search as it is typed. Gone when the
/// overlay closes.

abstract class _$SearchSession extends $Notifier<SearchView> {
  SearchView build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<SearchView, SearchView>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SearchView, SearchView>,
              SearchView,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

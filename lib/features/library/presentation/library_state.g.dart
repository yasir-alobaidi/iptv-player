// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'library_state.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(LibraryView)
final libraryViewProvider = LibraryViewProvider._();

final class LibraryViewProvider
    extends $NotifierProvider<LibraryView, LibraryViewState> {
  LibraryViewProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'libraryViewProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$libraryViewHash();

  @$internal
  @override
  LibraryView create() => LibraryView();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LibraryViewState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LibraryViewState>(value),
    );
  }
}

String _$libraryViewHash() => r'050a799857f1c9aab5a6dc2e5a5ee1af4aaf4855';

abstract class _$LibraryView extends $Notifier<LibraryViewState> {
  LibraryViewState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<LibraryViewState, LibraryViewState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<LibraryViewState, LibraryViewState>,
              LibraryViewState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(libraryCount)
final libraryCountProvider = LibraryCountFamily._();

final class LibraryCountProvider
    extends
        $FunctionalProvider<
          AsyncValue<LibraryCount>,
          LibraryCount,
          Stream<LibraryCount>
        >
    with $FutureModifier<LibraryCount>, $StreamProvider<LibraryCount> {
  LibraryCountProvider._({
    required LibraryCountFamily super.from,
    required LibraryQuery super.argument,
  }) : super(
         retry: null,
         name: r'libraryCountProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$libraryCountHash();

  @override
  String toString() {
    return r'libraryCountProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<LibraryCount> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<LibraryCount> create(Ref ref) {
    final argument = this.argument as LibraryQuery;
    return libraryCount(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is LibraryCountProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$libraryCountHash() => r'dbd28f0300b1709c7a242c89b068102e3422cb38';

final class LibraryCountFamily extends $Family
    with $FunctionalFamilyOverride<Stream<LibraryCount>, LibraryQuery> {
  LibraryCountFamily._()
    : super(
        retry: null,
        name: r'libraryCountProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  LibraryCountProvider call(LibraryQuery query) =>
      LibraryCountProvider._(argument: query, from: this);

  @override
  String toString() => r'libraryCountProvider';
}

@ProviderFor(libraryShows)
final libraryShowsProvider = LibraryShowsFamily._();

final class LibraryShowsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<LibraryShow>>,
          List<LibraryShow>,
          Stream<List<LibraryShow>>
        >
    with
        $FutureModifier<List<LibraryShow>>,
        $StreamProvider<List<LibraryShow>> {
  LibraryShowsProvider._({
    required LibraryShowsFamily super.from,
    required LibraryOrigin super.argument,
  }) : super(
         retry: null,
         name: r'libraryShowsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$libraryShowsHash();

  @override
  String toString() {
    return r'libraryShowsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<LibraryShow>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<LibraryShow>> create(Ref ref) {
    final argument = this.argument as LibraryOrigin;
    return libraryShows(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is LibraryShowsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$libraryShowsHash() => r'f405db75856069bf3e6a438c559f78a0f551f52c';

final class LibraryShowsFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<LibraryShow>>, LibraryOrigin> {
  LibraryShowsFamily._()
    : super(
        retry: null,
        name: r'libraryShowsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  LibraryShowsProvider call(LibraryOrigin origin) =>
      LibraryShowsProvider._(argument: origin, from: this);

  @override
  String toString() => r'libraryShowsProvider';
}

@ProviderFor(libraryShowEpisodes)
final libraryShowEpisodesProvider = LibraryShowEpisodesFamily._();

final class LibraryShowEpisodesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<LibraryItem>>,
          List<LibraryItem>,
          Stream<List<LibraryItem>>
        >
    with
        $FutureModifier<List<LibraryItem>>,
        $StreamProvider<List<LibraryItem>> {
  LibraryShowEpisodesProvider._({
    required LibraryShowEpisodesFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'libraryShowEpisodesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$libraryShowEpisodesHash();

  @override
  String toString() {
    return r'libraryShowEpisodesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<LibraryItem>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<LibraryItem>> create(Ref ref) {
    final argument = this.argument as String;
    return libraryShowEpisodes(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is LibraryShowEpisodesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$libraryShowEpisodesHash() =>
    r'd2f961c0bc70ff34ed25e604b4c1d805c258297d';

final class LibraryShowEpisodesFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<LibraryItem>>, String> {
  LibraryShowEpisodesFamily._()
    : super(
        retry: null,
        name: r'libraryShowEpisodesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  LibraryShowEpisodesProvider call(String showKey) =>
      LibraryShowEpisodesProvider._(argument: showKey, from: this);

  @override
  String toString() => r'libraryShowEpisodesProvider';
}

@ProviderFor(libraryFolders)
final libraryFoldersProvider = LibraryFoldersProvider._();

final class LibraryFoldersProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<LibraryFolder>>,
          List<LibraryFolder>,
          Stream<List<LibraryFolder>>
        >
    with
        $FutureModifier<List<LibraryFolder>>,
        $StreamProvider<List<LibraryFolder>> {
  LibraryFoldersProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'libraryFoldersProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$libraryFoldersHash();

  @$internal
  @override
  $StreamProviderElement<List<LibraryFolder>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<LibraryFolder>> create(Ref ref) {
    return libraryFolders(ref);
  }
}

String _$libraryFoldersHash() => r'9cd943dffb36ac566a3cb75d06dcb9f65c414b63';

@ProviderFor(libraryFolderTotals)
final libraryFolderTotalsProvider = LibraryFolderTotalsProvider._();

final class LibraryFolderTotalsProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<int, LibraryFolderTotals>>,
          Map<int, LibraryFolderTotals>,
          Stream<Map<int, LibraryFolderTotals>>
        >
    with
        $FutureModifier<Map<int, LibraryFolderTotals>>,
        $StreamProvider<Map<int, LibraryFolderTotals>> {
  LibraryFolderTotalsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'libraryFolderTotalsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$libraryFolderTotalsHash();

  @$internal
  @override
  $StreamProviderElement<Map<int, LibraryFolderTotals>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<Map<int, LibraryFolderTotals>> create(Ref ref) {
    return libraryFolderTotals(ref);
  }
}

String _$libraryFolderTotalsHash() =>
    r'716b1f0fb96dcc9b332ade2257d53a2c9870005a';

/// One item, read again when the library changes (its page).

@ProviderFor(libraryItem)
final libraryItemProvider = LibraryItemFamily._();

/// One item, read again when the library changes (its page).

final class LibraryItemProvider
    extends
        $FunctionalProvider<
          AsyncValue<LibraryItem?>,
          LibraryItem?,
          Stream<LibraryItem?>
        >
    with $FutureModifier<LibraryItem?>, $StreamProvider<LibraryItem?> {
  /// One item, read again when the library changes (its page).
  LibraryItemProvider._({
    required LibraryItemFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'libraryItemProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$libraryItemHash();

  @override
  String toString() {
    return r'libraryItemProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<LibraryItem?> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<LibraryItem?> create(Ref ref) {
    final argument = this.argument as int;
    return libraryItem(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is LibraryItemProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$libraryItemHash() => r'c2dd2a558a6dacfd70a7920eb49c059f568780af';

/// One item, read again when the library changes (its page).

final class LibraryItemFamily extends $Family
    with $FunctionalFamilyOverride<Stream<LibraryItem?>, int> {
  LibraryItemFamily._()
    : super(
        retry: null,
        name: r'libraryItemProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// One item, read again when the library changes (its page).

  LibraryItemProvider call(int itemId) =>
      LibraryItemProvider._(argument: itemId, from: this);

  @override
  String toString() => r'libraryItemProvider';
}

/// Where a library item was left (its card's bar, its page's Resume).

@ProviderFor(libraryMark)
final libraryMarkProvider = LibraryMarkFamily._();

/// Where a library item was left (its card's bar, its page's Resume).

final class LibraryMarkProvider
    extends
        $FunctionalProvider<
          AsyncValue<WatchMark?>,
          WatchMark?,
          Stream<WatchMark?>
        >
    with $FutureModifier<WatchMark?>, $StreamProvider<WatchMark?> {
  /// Where a library item was left (its card's bar, its page's Resume).
  LibraryMarkProvider._({
    required LibraryMarkFamily super.from,
    required LibraryItem super.argument,
  }) : super(
         retry: null,
         name: r'libraryMarkProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$libraryMarkHash();

  @override
  String toString() {
    return r'libraryMarkProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<WatchMark?> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<WatchMark?> create(Ref ref) {
    final argument = this.argument as LibraryItem;
    return libraryMark(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is LibraryMarkProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$libraryMarkHash() => r'6a2424e2480fff491d26668448f919ae4475f856';

/// Where a library item was left (its card's bar, its page's Resume).

final class LibraryMarkFamily extends $Family
    with $FunctionalFamilyOverride<Stream<WatchMark?>, LibraryItem> {
  LibraryMarkFamily._()
    : super(
        retry: null,
        name: r'libraryMarkProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Where a library item was left (its card's bar, its page's Resume).

  LibraryMarkProvider call(LibraryItem item) =>
      LibraryMarkProvider._(argument: item, from: this);

  @override
  String toString() => r'libraryMarkProvider';
}

/// Whether a library item is a favorite (its card's star, F).

@ProviderFor(libraryFavorite)
final libraryFavoriteProvider = LibraryFavoriteFamily._();

/// Whether a library item is a favorite (its card's star, F).

final class LibraryFavoriteProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, Stream<bool>>
    with $FutureModifier<bool>, $StreamProvider<bool> {
  /// Whether a library item is a favorite (its card's star, F).
  LibraryFavoriteProvider._({
    required LibraryFavoriteFamily super.from,
    required LibraryItem super.argument,
  }) : super(
         retry: null,
         name: r'libraryFavoriteProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$libraryFavoriteHash();

  @override
  String toString() {
    return r'libraryFavoriteProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<bool> create(Ref ref) {
    final argument = this.argument as LibraryItem;
    return libraryFavorite(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is LibraryFavoriteProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$libraryFavoriteHash() => r'20557ff1cc8463c3e6ab83a238913eedbbaf4d07';

/// Whether a library item is a favorite (its card's star, F).

final class LibraryFavoriteFamily extends $Family
    with $FunctionalFamilyOverride<Stream<bool>, LibraryItem> {
  LibraryFavoriteFamily._()
    : super(
        retry: null,
        name: r'libraryFavoriteProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Whether a library item is a favorite (its card's star, F).

  LibraryFavoriteProvider call(LibraryItem item) =>
      LibraryFavoriteProvider._(argument: item, from: this);

  @override
  String toString() => r'libraryFavoriteProvider';
}

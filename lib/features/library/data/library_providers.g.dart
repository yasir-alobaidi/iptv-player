// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'library_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The scanner's runs (docs/09): one at a time, each a guarded job on the
/// app's database. `bootstrap()` starts them after launch.

@ProviderFor(libraryScans)
final libraryScansProvider = LibraryScansProvider._();

/// The scanner's runs (docs/09): one at a time, each a guarded job on the
/// app's database. `bootstrap()` starts them after launch.

final class LibraryScansProvider
    extends $FunctionalProvider<LibraryScans, LibraryScans, LibraryScans>
    with $Provider<LibraryScans> {
  /// The scanner's runs (docs/09): one at a time, each a guarded job on the
  /// app's database. `bootstrap()` starts them after launch.
  LibraryScansProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'libraryScansProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$libraryScansHash();

  @$internal
  @override
  $ProviderElement<LibraryScans> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  LibraryScans create(Ref ref) {
    return libraryScans(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LibraryScans value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LibraryScans>(value),
    );
  }
}

String _$libraryScansHash() => r'99cf78e77ba168e0835b473be4e59579ccc2c2db';

/// The library as the screens use it (docs/09).

@ProviderFor(libraryRepository)
final libraryRepositoryProvider = LibraryRepositoryProvider._();

/// The library as the screens use it (docs/09).

final class LibraryRepositoryProvider
    extends
        $FunctionalProvider<
          LibraryRepository,
          LibraryRepository,
          LibraryRepository
        >
    with $Provider<LibraryRepository> {
  /// The library as the screens use it (docs/09).
  LibraryRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'libraryRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$libraryRepositoryHash();

  @$internal
  @override
  $ProviderElement<LibraryRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  LibraryRepository create(Ref ref) {
    return libraryRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LibraryRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LibraryRepository>(value),
    );
  }
}

String _$libraryRepositoryHash() => r'9b1bfb93057fcf87f169004fb99addad641293c8';

/// Where library videos' frames are kept. `bootstrap()` points it into
/// the app's cache; this is the fallback when it has none.

@ProviderFor(libraryThumbnailFolder)
final libraryThumbnailFolderProvider = LibraryThumbnailFolderProvider._();

/// Where library videos' frames are kept. `bootstrap()` points it into
/// the app's cache; this is the fallback when it has none.

final class LibraryThumbnailFolderProvider
    extends $FunctionalProvider<Directory, Directory, Directory>
    with $Provider<Directory> {
  /// Where library videos' frames are kept. `bootstrap()` points it into
  /// the app's cache; this is the fallback when it has none.
  LibraryThumbnailFolderProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'libraryThumbnailFolderProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$libraryThumbnailFolderHash();

  @$internal
  @override
  $ProviderElement<Directory> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Directory create(Ref ref) {
    return libraryThumbnailFolder(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Directory value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Directory>(value),
    );
  }
}

String _$libraryThumbnailFolderHash() =>
    r'8f520838a3cc32adc7e6d88b6281d2f84c1b0c31';

/// Frames for library videos, made when first shown (docs/09).

@ProviderFor(libraryThumbnails)
final libraryThumbnailsProvider = LibraryThumbnailsProvider._();

/// Frames for library videos, made when first shown (docs/09).

final class LibraryThumbnailsProvider
    extends
        $FunctionalProvider<
          LibraryThumbnails,
          LibraryThumbnails,
          LibraryThumbnails
        >
    with $Provider<LibraryThumbnails> {
  /// Frames for library videos, made when first shown (docs/09).
  LibraryThumbnailsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'libraryThumbnailsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$libraryThumbnailsHash();

  @$internal
  @override
  $ProviderElement<LibraryThumbnails> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  LibraryThumbnails create(Ref ref) {
    return libraryThumbnails(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LibraryThumbnails value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LibraryThumbnails>(value),
    );
  }
}

String _$libraryThumbnailsHash() => r'a26a7fbd701dfa4b3e3224051231985574e32d28';

/// A library video's frame, made on first ask.

@ProviderFor(libraryThumbnail)
final libraryThumbnailProvider = LibraryThumbnailFamily._();

/// A library video's frame, made on first ask.

final class LibraryThumbnailProvider
    extends $FunctionalProvider<AsyncValue<String?>, String?, FutureOr<String?>>
    with $FutureModifier<String?>, $FutureProvider<String?> {
  /// A library video's frame, made on first ask.
  LibraryThumbnailProvider._({
    required LibraryThumbnailFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'libraryThumbnailProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$libraryThumbnailHash();

  @override
  String toString() {
    return r'libraryThumbnailProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<String?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<String?> create(Ref ref) {
    final argument = this.argument as int;
    return libraryThumbnail(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is LibraryThumbnailProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$libraryThumbnailHash() => r'b9c0879e59068e861e8528059fba2396c8aeb8c7';

/// A library video's frame, made on first ask.

final class LibraryThumbnailFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<String?>, int> {
  LibraryThumbnailFamily._()
    : super(
        retry: null,
        name: r'libraryThumbnailProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// A library video's frame, made on first ask.

  LibraryThumbnailProvider call(int itemId) =>
      LibraryThumbnailProvider._(argument: itemId, from: this);

  @override
  String toString() => r'libraryThumbnailProvider';
}

/// The scan's progress, for the Library's header.

@ProviderFor(libraryScanState)
final libraryScanStateProvider = LibraryScanStateProvider._();

/// The scan's progress, for the Library's header.

final class LibraryScanStateProvider
    extends
        $FunctionalProvider<
          AsyncValue<LibraryScanState>,
          LibraryScanState,
          Stream<LibraryScanState>
        >
    with $FutureModifier<LibraryScanState>, $StreamProvider<LibraryScanState> {
  /// The scan's progress, for the Library's header.
  LibraryScanStateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'libraryScanStateProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$libraryScanStateHash();

  @$internal
  @override
  $StreamProviderElement<LibraryScanState> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<LibraryScanState> create(Ref ref) {
    return libraryScanState(ref);
  }
}

String _$libraryScanStateHash() => r'9d51a84867c986423752fd3dfa823a3782818a70';

/// F on a library item.

@ProviderFor(libraryFavorites)
final libraryFavoritesProvider = LibraryFavoritesProvider._();

/// F on a library item.

final class LibraryFavoritesProvider
    extends
        $FunctionalProvider<
          LibraryFavorites,
          LibraryFavorites,
          LibraryFavorites
        >
    with $Provider<LibraryFavorites> {
  /// F on a library item.
  LibraryFavoritesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'libraryFavoritesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$libraryFavoritesHash();

  @$internal
  @override
  $ProviderElement<LibraryFavorites> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  LibraryFavorites create(Ref ref) {
    return libraryFavorites(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LibraryFavorites value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LibraryFavorites>(value),
    );
  }
}

String _$libraryFavoritesHash() => r'14570b8f73ae6f7021aabbaaeab28f2e2d2a63ed';

/// Whether a folder is watched ("Updates automatically") or only scanned
/// when asked ("Updates when rescanned"); null until its watch started.

@ProviderFor(libraryFolderWatched)
final libraryFolderWatchedProvider = LibraryFolderWatchedFamily._();

/// Whether a folder is watched ("Updates automatically") or only scanned
/// when asked ("Updates when rescanned"); null until its watch started.

final class LibraryFolderWatchedProvider
    extends $FunctionalProvider<AsyncValue<bool?>, bool?, Stream<bool?>>
    with $FutureModifier<bool?>, $StreamProvider<bool?> {
  /// Whether a folder is watched ("Updates automatically") or only scanned
  /// when asked ("Updates when rescanned"); null until its watch started.
  LibraryFolderWatchedProvider._({
    required LibraryFolderWatchedFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'libraryFolderWatchedProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$libraryFolderWatchedHash();

  @override
  String toString() {
    return r'libraryFolderWatchedProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<bool?> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<bool?> create(Ref ref) {
    final argument = this.argument as int;
    return libraryFolderWatched(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is LibraryFolderWatchedProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$libraryFolderWatchedHash() =>
    r'c53a6538fbd6552f1a11d5b72b32dd949c5c5763';

/// Whether a folder is watched ("Updates automatically") or only scanned
/// when asked ("Updates when rescanned"); null until its watch started.

final class LibraryFolderWatchedFamily extends $Family
    with $FunctionalFamilyOverride<Stream<bool?>, int> {
  LibraryFolderWatchedFamily._()
    : super(
        retry: null,
        name: r'libraryFolderWatchedProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Whether a folder is watched ("Updates automatically") or only scanned
  /// when asked ("Updates when rescanned"); null until its watch started.

  LibraryFolderWatchedProvider call(int folderId) =>
      LibraryFolderWatchedProvider._(argument: folderId, from: this);

  @override
  String toString() => r'libraryFolderWatchedProvider';
}

/// The user's home folder, which folder paths show as `~`.

@ProviderFor(homeFolder)
final homeFolderProvider = HomeFolderProvider._();

/// The user's home folder, which folder paths show as `~`.

final class HomeFolderProvider
    extends $FunctionalProvider<String?, String?, String?>
    with $Provider<String?> {
  /// The user's home folder, which folder paths show as `~`.
  HomeFolderProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'homeFolderProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$homeFolderHash();

  @$internal
  @override
  $ProviderElement<String?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  String? create(Ref ref) {
    return homeFolder(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$homeFolderHash() => r'52196f1693be974071c0658a18d2c39712ce5436';

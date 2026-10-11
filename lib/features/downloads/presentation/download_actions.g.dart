// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'download_actions.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The downloaded file of a provider's title, read again when the
/// library changes.

@ProviderFor(downloadedFile)
final downloadedFileProvider = DownloadedFileFamily._();

/// The downloaded file of a provider's title, read again when the
/// library changes.

final class DownloadedFileProvider
    extends
        $FunctionalProvider<
          AsyncValue<LibraryItem?>,
          LibraryItem?,
          Stream<LibraryItem?>
        >
    with $FutureModifier<LibraryItem?>, $StreamProvider<LibraryItem?> {
  /// The downloaded file of a provider's title, read again when the
  /// library changes.
  DownloadedFileProvider._({
    required DownloadedFileFamily super.from,
    required (VodType, String, String) super.argument,
  }) : super(
         retry: null,
         name: r'downloadedFileProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$downloadedFileHash();

  @override
  String toString() {
    return r'downloadedFileProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $StreamProviderElement<LibraryItem?> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<LibraryItem?> create(Ref ref) {
    final argument = this.argument as (VodType, String, String);
    return downloadedFile(ref, argument.$1, argument.$2, argument.$3);
  }

  @override
  bool operator ==(Object other) {
    return other is DownloadedFileProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$downloadedFileHash() => r'91bcbc8cf9c4d4c0e19730cc379f8e54cd43c19a';

/// The downloaded file of a provider's title, read again when the
/// library changes.

final class DownloadedFileFamily extends $Family
    with
        $FunctionalFamilyOverride<
          Stream<LibraryItem?>,
          (VodType, String, String)
        > {
  DownloadedFileFamily._()
    : super(
        retry: null,
        name: r'downloadedFileProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The downloaded file of a provider's title, read again when the
  /// library changes.

  DownloadedFileProvider call(
    VodType type,
    String sourceId,
    String remoteKey,
  ) => DownloadedFileProvider._(
    argument: (type, sourceId, remoteKey),
    from: this,
  );

  @override
  String toString() => r'downloadedFileProvider';
}

/// A title's download, live (the Download button, sketch E).

@ProviderFor(titleDownload)
final titleDownloadProvider = TitleDownloadFamily._();

/// A title's download, live (the Download button, sketch E).

final class TitleDownloadProvider
    extends $FunctionalProvider<TitleDownload, TitleDownload, TitleDownload>
    with $Provider<TitleDownload> {
  /// A title's download, live (the Download button, sketch E).
  TitleDownloadProvider._({
    required TitleDownloadFamily super.from,
    required (VodType, String, String) super.argument,
  }) : super(
         retry: null,
         name: r'titleDownloadProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$titleDownloadHash();

  @override
  String toString() {
    return r'titleDownloadProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $ProviderElement<TitleDownload> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  TitleDownload create(Ref ref) {
    final argument = this.argument as (VodType, String, String);
    return titleDownload(ref, argument.$1, argument.$2, argument.$3);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TitleDownload value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TitleDownload>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is TitleDownloadProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$titleDownloadHash() => r'a71a23b41bf57f755711604d15485a0284b6cb73';

/// A title's download, live (the Download button, sketch E).

final class TitleDownloadFamily extends $Family
    with $FunctionalFamilyOverride<TitleDownload, (VodType, String, String)> {
  TitleDownloadFamily._()
    : super(
        retry: null,
        name: r'titleDownloadProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// A title's download, live (the Download button, sketch E).

  TitleDownloadProvider call(VodType type, String sourceId, String remoteKey) =>
      TitleDownloadProvider._(
        argument: (type, sourceId, remoteKey),
        from: this,
      );

  @override
  String toString() => r'titleDownloadProvider';
}

/// What the queue last said it lacks on the drive, for the Downloads
/// tab's banner (sketch G: "Free up 3.2 GB or choose another download
/// folder."); null when it never said.

@ProviderFor(DownloadSpaceNeeded)
final downloadSpaceNeededProvider = DownloadSpaceNeededProvider._();

/// What the queue last said it lacks on the drive, for the Downloads
/// tab's banner (sketch G: "Free up 3.2 GB or choose another download
/// folder."); null when it never said.
final class DownloadSpaceNeededProvider
    extends $NotifierProvider<DownloadSpaceNeeded, int?> {
  /// What the queue last said it lacks on the drive, for the Downloads
  /// tab's banner (sketch G: "Free up 3.2 GB or choose another download
  /// folder."); null when it never said.
  DownloadSpaceNeededProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'downloadSpaceNeededProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$downloadSpaceNeededHash();

  @$internal
  @override
  DownloadSpaceNeeded create() => DownloadSpaceNeeded();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int?>(value),
    );
  }
}

String _$downloadSpaceNeededHash() =>
    r'ad7c26183c0dbe11e02187db92ba2b6515dbd3d9';

/// What the queue last said it lacks on the drive, for the Downloads
/// tab's banner (sketch G: "Free up 3.2 GB or choose another download
/// folder."); null when it never said.

abstract class _$DownloadSpaceNeeded extends $Notifier<int?> {
  int? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<int?, int?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<int?, int?>,
              int?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The queue's news as toasts (docs/05): "Download finished · <title>"
/// with Play, "Downloads paused while you watch — your provider allows 1
/// connection.", a refused account with Edit source, and no disk space
/// with Show (the Downloads tab has the banner and Change folder). Alive
/// from launch (`bootstrap()` reads it once).

@ProviderFor(downloadToasts)
final downloadToastsProvider = DownloadToastsProvider._();

/// The queue's news as toasts (docs/05): "Download finished · <title>"
/// with Play, "Downloads paused while you watch — your provider allows 1
/// connection.", a refused account with Edit source, and no disk space
/// with Show (the Downloads tab has the banner and Change folder). Alive
/// from launch (`bootstrap()` reads it once).

final class DownloadToastsProvider extends $FunctionalProvider<void, void, void>
    with $Provider<void> {
  /// The queue's news as toasts (docs/05): "Download finished · <title>"
  /// with Play, "Downloads paused while you watch — your provider allows 1
  /// connection.", a refused account with Edit source, and no disk space
  /// with Show (the Downloads tab has the banner and Change folder). Alive
  /// from launch (`bootstrap()` reads it once).
  DownloadToastsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'downloadToastsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$downloadToastsHash();

  @$internal
  @override
  $ProviderElement<void> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  void create(Ref ref) {
    return downloadToasts(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$downloadToastsHash() => r'83ad6b5882afb839fb1372e86fb1f8b82cfb454e';

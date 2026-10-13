// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'download_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Settings → Downloads & library's download half. The defaults at once,
/// the stored choices as soon as they are read; a change is saved, and
/// applies to downloads that start after it.

@ProviderFor(DownloadSettingsController)
final downloadSettingsControllerProvider =
    DownloadSettingsControllerProvider._();

/// Settings → Downloads & library's download half. The defaults at once,
/// the stored choices as soon as they are read; a change is saved, and
/// applies to downloads that start after it.
final class DownloadSettingsControllerProvider
    extends $NotifierProvider<DownloadSettingsController, DownloadSettings> {
  /// Settings → Downloads & library's download half. The defaults at once,
  /// the stored choices as soon as they are read; a change is saved, and
  /// applies to downloads that start after it.
  DownloadSettingsControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'downloadSettingsControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$downloadSettingsControllerHash();

  @$internal
  @override
  DownloadSettingsController create() => DownloadSettingsController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DownloadSettings value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DownloadSettings>(value),
    );
  }
}

String _$downloadSettingsControllerHash() =>
    r'3e6ea4a042464ff7b0bd33905927434b60ef40dd';

/// Settings → Downloads & library's download half. The defaults at once,
/// the stored choices as soon as they are read; a change is saved, and
/// applies to downloads that start after it.

abstract class _$DownloadSettingsController
    extends $Notifier<DownloadSettings> {
  DownloadSettings build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<DownloadSettings, DownloadSettings>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<DownloadSettings, DownloadSettings>,
              DownloadSettings,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The system's Videos folder. Tests point it elsewhere.

@ProviderFor(systemVideos)
final systemVideosProvider = SystemVideosProvider._();

/// The system's Videos folder. Tests point it elsewhere.

final class SystemVideosProvider
    extends $FunctionalProvider<AsyncValue<String>, String, FutureOr<String>>
    with $FutureModifier<String>, $FutureProvider<String> {
  /// The system's Videos folder. Tests point it elsewhere.
  SystemVideosProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'systemVideosProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$systemVideosHash();

  @$internal
  @override
  $FutureProviderElement<String> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<String> create(Ref ref) {
    return systemVideos(ref);
  }
}

String _$systemVideosHash() => r'490029835b9a8a31c48c952e7a93f73738008568';

/// Where new downloads go now (docs/09): the folder chosen in Settings,
/// else the system's Videos folder + `IPTV Player`.

@ProviderFor(downloadFolder)
final downloadFolderProvider = DownloadFolderProvider._();

/// Where new downloads go now (docs/09): the folder chosen in Settings,
/// else the system's Videos folder + `IPTV Player`.

final class DownloadFolderProvider
    extends $FunctionalProvider<AsyncValue<String>, String, FutureOr<String>>
    with $FutureModifier<String>, $FutureProvider<String> {
  /// Where new downloads go now (docs/09): the folder chosen in Settings,
  /// else the system's Videos folder + `IPTV Player`.
  DownloadFolderProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'downloadFolderProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$downloadFolderHash();

  @$internal
  @override
  $FutureProviderElement<String> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<String> create(Ref ref) {
    return downloadFolder(ref);
  }
}

String _$downloadFolderHash() => r'122abe6af367c5e1a56b15f34a58e52a8c9b2e0e';

/// Moves downloads' bytes, in its own isolate (Phase 8 decision 2).

@ProviderFor(downloadRunner)
final downloadRunnerProvider = DownloadRunnerProvider._();

/// Moves downloads' bytes, in its own isolate (Phase 8 decision 2).

final class DownloadRunnerProvider
    extends $FunctionalProvider<DownloadRunner, DownloadRunner, DownloadRunner>
    with $Provider<DownloadRunner> {
  /// Moves downloads' bytes, in its own isolate (Phase 8 decision 2).
  DownloadRunnerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'downloadRunnerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$downloadRunnerHash();

  @$internal
  @override
  $ProviderElement<DownloadRunner> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  DownloadRunner create(Ref ref) {
    return downloadRunner(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DownloadRunner value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DownloadRunner>(value),
    );
  }
}

String _$downloadRunnerHash() => r'4560696680cdc632c06cd61885e0215f52e805c4';

/// The download queue (docs/09). `bootstrap()` starts it after launch and
/// shuts it down on quit; it gives way to the player and the cast on the
/// connections they share.

@ProviderFor(downloadQueue)
final downloadQueueProvider = DownloadQueueProvider._();

/// The download queue (docs/09). `bootstrap()` starts it after launch and
/// shuts it down on quit; it gives way to the player and the cast on the
/// connections they share.

final class DownloadQueueProvider
    extends $FunctionalProvider<DownloadQueue, DownloadQueue, DownloadQueue>
    with $Provider<DownloadQueue> {
  /// The download queue (docs/09). `bootstrap()` starts it after launch and
  /// shuts it down on quit; it gives way to the player and the cast on the
  /// connections they share.
  DownloadQueueProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'downloadQueueProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$downloadQueueHash();

  @$internal
  @override
  $ProviderElement<DownloadQueue> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  DownloadQueue create(Ref ref) {
    return downloadQueue(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DownloadQueue value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DownloadQueue>(value),
    );
  }
}

String _$downloadQueueHash() => r'0b33aee4a4ea177065dcf1d66189ce8677afb06a';

/// The queue as the screens use it.

@ProviderFor(downloadService)
final downloadServiceProvider = DownloadServiceProvider._();

/// The queue as the screens use it.

final class DownloadServiceProvider
    extends
        $FunctionalProvider<DownloadService, DownloadService, DownloadService>
    with $Provider<DownloadService> {
  /// The queue as the screens use it.
  DownloadServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'downloadServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$downloadServiceHash();

  @$internal
  @override
  $ProviderElement<DownloadService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  DownloadService create(Ref ref) {
    return downloadService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DownloadService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DownloadService>(value),
    );
  }
}

String _$downloadServiceHash() => r'074524f078dff4f5053d1dc23113e93919023eb6';

/// Every download in the queue's order, with their speed while they run.

@ProviderFor(downloadTasks)
final downloadTasksProvider = DownloadTasksProvider._();

/// Every download in the queue's order, with their speed while they run.

final class DownloadTasksProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<DownloadTask>>,
          List<DownloadTask>,
          Stream<List<DownloadTask>>
        >
    with
        $FutureModifier<List<DownloadTask>>,
        $StreamProvider<List<DownloadTask>> {
  /// Every download in the queue's order, with their speed while they run.
  DownloadTasksProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'downloadTasksProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$downloadTasksHash();

  @$internal
  @override
  $StreamProviderElement<List<DownloadTask>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<DownloadTask>> create(Ref ref) {
    return downloadTasks(ref);
  }
}

String _$downloadTasksHash() => r'ca7611d7b4453a710fd0bd758161da9a72f9c19b';

/// The queue's toasts and banners.
/// The queue's news, as the stream itself: what turns it into toasts
/// subscribes to it directly, since a provider nothing watches is paused
/// and would miss it.

@ProviderFor(downloadNoticeStream)
final downloadNoticeStreamProvider = DownloadNoticeStreamProvider._();

/// The queue's toasts and banners.
/// The queue's news, as the stream itself: what turns it into toasts
/// subscribes to it directly, since a provider nothing watches is paused
/// and would miss it.

final class DownloadNoticeStreamProvider
    extends
        $FunctionalProvider<
          Raw<Stream<DownloadNotice>>,
          Raw<Stream<DownloadNotice>>,
          Raw<Stream<DownloadNotice>>
        >
    with $Provider<Raw<Stream<DownloadNotice>>> {
  /// The queue's toasts and banners.
  /// The queue's news, as the stream itself: what turns it into toasts
  /// subscribes to it directly, since a provider nothing watches is paused
  /// and would miss it.
  DownloadNoticeStreamProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'downloadNoticeStreamProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$downloadNoticeStreamHash();

  @$internal
  @override
  $ProviderElement<Raw<Stream<DownloadNotice>>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  Raw<Stream<DownloadNotice>> create(Ref ref) {
    return downloadNoticeStream(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Raw<Stream<DownloadNotice>> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Raw<Stream<DownloadNotice>>>(value),
    );
  }
}

String _$downloadNoticeStreamHash() =>
    r'c41dd7cace4bc2eea0389f9dc5de9096985b43d7';

/// The drive the download folder is on: what is free on it and its size,
/// read again whenever the downloads move (the Downloads tab's meter).

@ProviderFor(downloadDiskSpace)
final downloadDiskSpaceProvider = DownloadDiskSpaceProvider._();

/// The drive the download folder is on: what is free on it and its size,
/// read again whenever the downloads move (the Downloads tab's meter).

final class DownloadDiskSpaceProvider
    extends
        $FunctionalProvider<
          AsyncValue<({int free, int total})?>,
          ({int free, int total})?,
          FutureOr<({int free, int total})?>
        >
    with
        $FutureModifier<({int free, int total})?>,
        $FutureProvider<({int free, int total})?> {
  /// The drive the download folder is on: what is free on it and its size,
  /// read again whenever the downloads move (the Downloads tab's meter).
  DownloadDiskSpaceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'downloadDiskSpaceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$downloadDiskSpaceHash();

  @$internal
  @override
  $FutureProviderElement<({int free, int total})?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<({int free, int total})?> create(Ref ref) {
    return downloadDiskSpace(ref);
  }
}

String _$downloadDiskSpaceHash() => r'cd03b8466541cfa6850f1bdbf1fbe7f06189954c';

@ProviderFor(changeDownloadFolder)
final changeDownloadFolderProvider = ChangeDownloadFolderProvider._();

final class ChangeDownloadFolderProvider
    extends
        $FunctionalProvider<
          DownloadFolderChange,
          DownloadFolderChange,
          DownloadFolderChange
        >
    with $Provider<DownloadFolderChange> {
  ChangeDownloadFolderProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'changeDownloadFolderProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$changeDownloadFolderHash();

  @$internal
  @override
  $ProviderElement<DownloadFolderChange> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DownloadFolderChange create(Ref ref) {
    return changeDownloadFolder(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DownloadFolderChange value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DownloadFolderChange>(value),
    );
  }
}

String _$changeDownloadFolderHash() =>
    r'8dc07ba69b75ab395e9271e38df95554d18528e3';

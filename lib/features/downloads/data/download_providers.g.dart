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
    r'73e6e7ae37b831aed7406ca1b70a5a06d24c9ae6';

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

String _$downloadQueueHash() => r'96b4b28f6fe8a8971d2b79f376fc70d21238c871';

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

@ProviderFor(downloadNotices)
final downloadNoticesProvider = DownloadNoticesProvider._();

/// The queue's toasts and banners.

final class DownloadNoticesProvider
    extends
        $FunctionalProvider<
          AsyncValue<DownloadNotice>,
          DownloadNotice,
          Stream<DownloadNotice>
        >
    with $FutureModifier<DownloadNotice>, $StreamProvider<DownloadNotice> {
  /// The queue's toasts and banners.
  DownloadNoticesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'downloadNoticesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$downloadNoticesHash();

  @$internal
  @override
  $StreamProviderElement<DownloadNotice> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<DownloadNotice> create(Ref ref) {
    return downloadNotices(ref);
  }
}

String _$downloadNoticesHash() => r'fc0a0358dfa1b2bb927774dda5598cc1323778e0';

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

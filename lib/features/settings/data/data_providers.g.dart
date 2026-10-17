// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'data_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Settings → Data's Export… and Import….

@ProviderFor(settingsTransfer)
final settingsTransferProvider = SettingsTransferProvider._();

/// Settings → Data's Export… and Import….

final class SettingsTransferProvider
    extends
        $FunctionalProvider<
          SettingsTransfer,
          SettingsTransfer,
          SettingsTransfer
        >
    with $Provider<SettingsTransfer> {
  /// Settings → Data's Export… and Import….
  SettingsTransferProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'settingsTransferProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$settingsTransferHash();

  @$internal
  @override
  $ProviderElement<SettingsTransfer> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SettingsTransfer create(Ref ref) {
    return settingsTransfer(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SettingsTransfer value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SettingsTransfer>(value),
    );
  }
}

String _$settingsTransferHash() => r'a9a4a95ef724240417dea83b2d9453393ae695f8';

/// How much room the kept pictures take; measured again after Clear.

@ProviderFor(artworkUsage)
final artworkUsageProvider = ArtworkUsageProvider._();

/// How much room the kept pictures take; measured again after Clear.

final class ArtworkUsageProvider
    extends
        $FunctionalProvider<
          AsyncValue<Result<ArtworkUsage>>,
          Result<ArtworkUsage>,
          FutureOr<Result<ArtworkUsage>>
        >
    with
        $FutureModifier<Result<ArtworkUsage>>,
        $FutureProvider<Result<ArtworkUsage>> {
  /// How much room the kept pictures take; measured again after Clear.
  ArtworkUsageProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'artworkUsageProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$artworkUsageHash();

  @$internal
  @override
  $FutureProviderElement<Result<ArtworkUsage>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Result<ArtworkUsage>> create(Ref ref) {
    return artworkUsage(ref);
  }
}

String _$artworkUsageHash() => r'2b4caa793f1140a6ef265a64aaa9f07f6d3d9af6';

/// What Settings → Data says about the guide: null while it is read.
/// A source whose guide can't be read counts as having none.

@ProviderFor(guideTotals)
final guideTotalsProvider = GuideTotalsProvider._();

/// What Settings → Data says about the guide: null while it is read.
/// A source whose guide can't be read counts as having none.

final class GuideTotalsProvider
    extends $FunctionalProvider<GuideTotals?, GuideTotals?, GuideTotals?>
    with $Provider<GuideTotals?> {
  /// What Settings → Data says about the guide: null while it is read.
  /// A source whose guide can't be read counts as having none.
  GuideTotalsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'guideTotalsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$guideTotalsHash();

  @$internal
  @override
  $ProviderElement<GuideTotals?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  GuideTotals? create(Ref ref) {
    return guideTotals(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GuideTotals? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GuideTotals?>(value),
    );
  }
}

String _$guideTotalsHash() => r'760bfbe6549ba8e6f36940b94ab4f9731527f26e';

/// The tidy-up of the database: Settings → Data's Watch history and
/// Database rows, and the launch's own (ADR-031).

@ProviderFor(dataUpkeep)
final dataUpkeepProvider = DataUpkeepProvider._();

/// The tidy-up of the database: Settings → Data's Watch history and
/// Database rows, and the launch's own (ADR-031).

final class DataUpkeepProvider
    extends $FunctionalProvider<DataUpkeep, DataUpkeep, DataUpkeep>
    with $Provider<DataUpkeep> {
  /// The tidy-up of the database: Settings → Data's Watch history and
  /// Database rows, and the launch's own (ADR-031).
  DataUpkeepProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dataUpkeepProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dataUpkeepHash();

  @$internal
  @override
  $ProviderElement<DataUpkeep> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  DataUpkeep create(Ref ref) {
    return dataUpkeep(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DataUpkeep value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DataUpkeep>(value),
    );
  }
}

String _$dataUpkeepHash() => r'9aeaafa1e67ca757a9a8f6aac1418ff0cd1b23ff';

/// What was watched, as Settings → Data counts it.

@ProviderFor(historyCounts)
final historyCountsProvider = HistoryCountsProvider._();

/// What was watched, as Settings → Data counts it.

final class HistoryCountsProvider
    extends
        $FunctionalProvider<
          AsyncValue<HistoryCounts>,
          HistoryCounts,
          Stream<HistoryCounts>
        >
    with $FutureModifier<HistoryCounts>, $StreamProvider<HistoryCounts> {
  /// What was watched, as Settings → Data counts it.
  HistoryCountsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'historyCountsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$historyCountsHash();

  @$internal
  @override
  $StreamProviderElement<HistoryCounts> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<HistoryCounts> create(Ref ref) {
    return historyCounts(ref);
  }
}

String _$historyCountsHash() => r'5ec44f2bdc01607b777155d99ca9f0c94757601b';

/// The database file's size and free room; measured again after Compact.

@ProviderFor(databaseRoom)
final databaseRoomProvider = DatabaseRoomProvider._();

/// The database file's size and free room; measured again after Compact.

final class DatabaseRoomProvider
    extends
        $FunctionalProvider<
          AsyncValue<Result<DatabaseRoom>>,
          Result<DatabaseRoom>,
          FutureOr<Result<DatabaseRoom>>
        >
    with
        $FutureModifier<Result<DatabaseRoom>>,
        $FutureProvider<Result<DatabaseRoom>> {
  /// The database file's size and free room; measured again after Compact.
  DatabaseRoomProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'databaseRoomProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$databaseRoomHash();

  @$internal
  @override
  $FutureProviderElement<Result<DatabaseRoom>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Result<DatabaseRoom>> create(Ref ref) {
    return databaseRoom(ref);
  }
}

String _$databaseRoomHash() => r'411b1df35b56a649a9dd91fee8e0643cf4446c8a';

/// What keeps Compact from running now, as it changes; null when nothing
/// does. The player, never made, has played nothing; a TV has no
/// downloads.

@ProviderFor(compactBlocker)
final compactBlockerProvider = CompactBlockerProvider._();

/// What keeps Compact from running now, as it changes; null when nothing
/// does. The player, never made, has played nothing; a TV has no
/// downloads.

final class CompactBlockerProvider
    extends $FunctionalProvider<UpkeepBlocker?, UpkeepBlocker?, UpkeepBlocker?>
    with $Provider<UpkeepBlocker?> {
  /// What keeps Compact from running now, as it changes; null when nothing
  /// does. The player, never made, has played nothing; a TV has no
  /// downloads.
  CompactBlockerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'compactBlockerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$compactBlockerHash();

  @$internal
  @override
  $ProviderElement<UpkeepBlocker?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  UpkeepBlocker? create(Ref ref) {
    return compactBlocker(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(UpkeepBlocker? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<UpkeepBlocker?>(value),
    );
  }
}

String _$compactBlockerHash() => r'e6711f3388a6d4a13e2fb5b0065c8cdde165027e';

@ProviderFor(upkeepBlockerCheck)
final upkeepBlockerCheckProvider = UpkeepBlockerCheckProvider._();

final class UpkeepBlockerCheckProvider
    extends
        $FunctionalProvider<
          UpkeepBlockerCheck,
          UpkeepBlockerCheck,
          UpkeepBlockerCheck
        >
    with $Provider<UpkeepBlockerCheck> {
  UpkeepBlockerCheckProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'upkeepBlockerCheckProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$upkeepBlockerCheckHash();

  @$internal
  @override
  $ProviderElement<UpkeepBlockerCheck> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  UpkeepBlockerCheck create(Ref ref) {
    return upkeepBlockerCheck(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(UpkeepBlockerCheck value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<UpkeepBlockerCheck>(value),
    );
  }
}

String _$upkeepBlockerCheckHash() =>
    r'939c700b3b90020bb4c407e2746cb2b9cada402a';

/// The launch's tidy-up; `bootstrap()` runs it once the launch's syncs
/// and guide imports are done.

@ProviderFor(launchTidyUp)
final launchTidyUpProvider = LaunchTidyUpProvider._();

/// The launch's tidy-up; `bootstrap()` runs it once the launch's syncs
/// and guide imports are done.

final class LaunchTidyUpProvider
    extends $FunctionalProvider<LaunchTidyUp, LaunchTidyUp, LaunchTidyUp>
    with $Provider<LaunchTidyUp> {
  /// The launch's tidy-up; `bootstrap()` runs it once the launch's syncs
  /// and guide imports are done.
  LaunchTidyUpProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'launchTidyUpProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$launchTidyUpHash();

  @$internal
  @override
  $ProviderElement<LaunchTidyUp> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  LaunchTidyUp create(Ref ref) {
    return launchTidyUp(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LaunchTidyUp value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LaunchTidyUp>(value),
    );
  }
}

String _$launchTidyUpHash() => r'ad89b49aae7704d56c5ee7ded204992bf814b9bb';

/// The system's Save dialog for a settings file. Tests override it.

@ProviderFor(settingsSavePicker)
final settingsSavePickerProvider = SettingsSavePickerProvider._();

/// The system's Save dialog for a settings file. Tests override it.

final class SettingsSavePickerProvider
    extends $FunctionalProvider<SaveFilePicker, SaveFilePicker, SaveFilePicker>
    with $Provider<SaveFilePicker> {
  /// The system's Save dialog for a settings file. Tests override it.
  SettingsSavePickerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'settingsSavePickerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$settingsSavePickerHash();

  @$internal
  @override
  $ProviderElement<SaveFilePicker> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SaveFilePicker create(Ref ref) {
    return settingsSavePicker(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SaveFilePicker value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SaveFilePicker>(value),
    );
  }
}

String _$settingsSavePickerHash() =>
    r'427cd60b5b0c419e1421d65b412964ad9443f94f';

/// The system's Open dialog for a settings file. Tests override it.

@ProviderFor(settingsOpenPicker)
final settingsOpenPickerProvider = SettingsOpenPickerProvider._();

/// The system's Open dialog for a settings file. Tests override it.

final class SettingsOpenPickerProvider
    extends $FunctionalProvider<OpenFilePicker, OpenFilePicker, OpenFilePicker>
    with $Provider<OpenFilePicker> {
  /// The system's Open dialog for a settings file. Tests override it.
  SettingsOpenPickerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'settingsOpenPickerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$settingsOpenPickerHash();

  @$internal
  @override
  $ProviderElement<OpenFilePicker> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  OpenFilePicker create(Ref ref) {
    return settingsOpenPicker(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(OpenFilePicker value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<OpenFilePicker>(value),
    );
  }
}

String _$settingsOpenPickerHash() =>
    r'f36c451107f28b5df63d8b4c4a22e058eed32a98';

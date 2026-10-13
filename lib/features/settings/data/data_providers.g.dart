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

String _$settingsTransferHash() => r'dc7e33a084bdf9d4641fd10bdf262664a9516bfd';

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

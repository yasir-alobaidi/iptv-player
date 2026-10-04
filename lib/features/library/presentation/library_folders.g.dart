// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'library_folders.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The system's folder dialog. Tests override it.

@ProviderFor(folderPicker)
final folderPickerProvider = FolderPickerProvider._();

/// The system's folder dialog. Tests override it.

final class FolderPickerProvider
    extends $FunctionalProvider<FolderPicker, FolderPicker, FolderPicker>
    with $Provider<FolderPicker> {
  /// The system's folder dialog. Tests override it.
  FolderPickerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'folderPickerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$folderPickerHash();

  @$internal
  @override
  $ProviderElement<FolderPicker> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  FolderPicker create(Ref ref) {
    return folderPicker(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FolderPicker value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FolderPicker>(value),
    );
  }
}

String _$folderPickerHash() => r'0ba7cabd7131b6ad8cc33a65625a23929962ecc1';

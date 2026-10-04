// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'file_reveal.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Show in folder. Nothing here; `bootstrap()` gives it the system's
/// (`platformFileReveal`).

@ProviderFor(fileReveal)
final fileRevealProvider = FileRevealProvider._();

/// Show in folder. Nothing here; `bootstrap()` gives it the system's
/// (`platformFileReveal`).

final class FileRevealProvider
    extends $FunctionalProvider<FileReveal, FileReveal, FileReveal>
    with $Provider<FileReveal> {
  /// Show in folder. Nothing here; `bootstrap()` gives it the system's
  /// (`platformFileReveal`).
  FileRevealProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'fileRevealProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$fileRevealHash();

  @$internal
  @override
  $ProviderElement<FileReveal> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  FileReveal create(Ref ref) {
    return fileReveal(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FileReveal value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FileReveal>(value),
    );
  }
}

String _$fileRevealHash() => r'1553ea86d181b8518d014e0dcd813507e5a621ff';

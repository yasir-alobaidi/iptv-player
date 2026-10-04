// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'failed_file.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The file on this computer a play that failed was reading (Phase 8
/// decision 8): a library file, or a title's download. The failure card
/// offers Show in folder and Remove from library for it.

@ProviderFor(failedFile)
final failedFileProvider = FailedFileFamily._();

/// The file on this computer a play that failed was reading (Phase 8
/// decision 8): a library file, or a title's download. The failure card
/// offers Show in folder and Remove from library for it.

final class FailedFileProvider
    extends
        $FunctionalProvider<
          AsyncValue<LibraryItem?>,
          LibraryItem?,
          FutureOr<LibraryItem?>
        >
    with $FutureModifier<LibraryItem?>, $FutureProvider<LibraryItem?> {
  /// The file on this computer a play that failed was reading (Phase 8
  /// decision 8): a library file, or a title's download. The failure card
  /// offers Show in folder and Remove from library for it.
  FailedFileProvider._({
    required FailedFileFamily super.from,
    required Playable super.argument,
  }) : super(
         retry: null,
         name: r'failedFileProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$failedFileHash();

  @override
  String toString() {
    return r'failedFileProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<LibraryItem?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<LibraryItem?> create(Ref ref) {
    final argument = this.argument as Playable;
    return failedFile(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is FailedFileProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$failedFileHash() => r'8c4d48ff1ad515226d5d4fefb6db1003630c72b7';

/// The file on this computer a play that failed was reading (Phase 8
/// decision 8): a library file, or a title's download. The failure card
/// offers Show in folder and Remove from library for it.

final class FailedFileFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<LibraryItem?>, Playable> {
  FailedFileFamily._()
    : super(
        retry: null,
        name: r'failedFileProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The file on this computer a play that failed was reading (Phase 8
  /// decision 8): a library file, or a title's download. The failure card
  /// offers Show in folder and Remove from library for it.

  FailedFileProvider call(Playable item) =>
      FailedFileProvider._(argument: item, from: this);

  @override
  String toString() => r'failedFileProvider';
}

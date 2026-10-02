// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'process_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Where supervised processes keep their PID files. `bootstrap()` points
/// it into the app's own folder; this is the fallback when it has none.

@ProviderFor(processFolder)
final processFolderProvider = ProcessFolderProvider._();

/// Where supervised processes keep their PID files. `bootstrap()` points
/// it into the app's own folder; this is the fallback when it has none.

final class ProcessFolderProvider
    extends $FunctionalProvider<Directory, Directory, Directory>
    with $Provider<Directory> {
  /// Where supervised processes keep their PID files. `bootstrap()` points
  /// it into the app's own folder; this is the fallback when it has none.
  ProcessFolderProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'processFolderProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$processFolderHash();

  @$internal
  @override
  $ProviderElement<Directory> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Directory create(Ref ref) {
    return processFolder(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Directory value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Directory>(value),
    );
  }
}

String _$processFolderHash() => r'f048ff97a62ce7479c4740fef154c6e2928e54fd';

/// Every FFmpeg and ffprobe the app runs goes through this (hard rule 8);
/// they stop with it.

@ProviderFor(processSupervisor)
final processSupervisorProvider = ProcessSupervisorProvider._();

/// Every FFmpeg and ffprobe the app runs goes through this (hard rule 8);
/// they stop with it.

final class ProcessSupervisorProvider
    extends
        $FunctionalProvider<
          ProcessSupervisor,
          ProcessSupervisor,
          ProcessSupervisor
        >
    with $Provider<ProcessSupervisor> {
  /// Every FFmpeg and ffprobe the app runs goes through this (hard rule 8);
  /// they stop with it.
  ProcessSupervisorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'processSupervisorProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$processSupervisorHash();

  @$internal
  @override
  $ProviderElement<ProcessSupervisor> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ProcessSupervisor create(Ref ref) {
    return processSupervisor(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ProcessSupervisor value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ProcessSupervisor>(value),
    );
  }
}

String _$processSupervisorHash() => r'b821308566c45cb470178d8be1b2c4cab209b2de';

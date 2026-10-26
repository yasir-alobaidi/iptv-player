// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'run_logs.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// `bootstrap()` gives a TV's (`AndroidRunLogs`).

@ProviderFor(runLogs)
final runLogsProvider = RunLogsProvider._();

/// `bootstrap()` gives a TV's (`AndroidRunLogs`).

final class RunLogsProvider
    extends $FunctionalProvider<RunLogsSource, RunLogsSource, RunLogsSource>
    with $Provider<RunLogsSource> {
  /// `bootstrap()` gives a TV's (`AndroidRunLogs`).
  RunLogsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'runLogsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$runLogsHash();

  @$internal
  @override
  $ProviderElement<RunLogsSource> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  RunLogsSource create(Ref ref) {
    return runLogs(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RunLogsSource value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RunLogsSource>(value),
    );
  }
}

String _$runLogsHash() => r'6e37f07a24de87dacd71faf9233da50c0c112b0a';

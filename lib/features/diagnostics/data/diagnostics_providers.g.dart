// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'diagnostics_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The app's log files, read off the UI isolate. `bootstrap()` gives the
/// real one; a run with no log file has none.

@ProviderFor(logReader)
final logReaderProvider = LogReaderProvider._();

/// The app's log files, read off the UI isolate. `bootstrap()` gives the
/// real one; a run with no log file has none.

final class LogReaderProvider
    extends $FunctionalProvider<LogReader, LogReader, LogReader>
    with $Provider<LogReader> {
  /// The app's log files, read off the UI isolate. `bootstrap()` gives the
  /// real one; a run with no log file has none.
  LogReaderProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'logReaderProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$logReaderHash();

  @$internal
  @override
  $ProviderElement<LogReader> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  LogReader create(Ref ref) {
    return logReader(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LogReader value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LogReader>(value),
    );
  }
}

String _$logReaderHash() => r'c7f025e225149ddb0a4c81148f179dfaa298ff77';

/// Settings → About & diagnostics' report.

@ProviderFor(diagnostics)
final diagnosticsProvider = DiagnosticsProvider._();

/// Settings → About & diagnostics' report.

final class DiagnosticsProvider
    extends
        $FunctionalProvider<
          DiagnosticsService,
          DiagnosticsService,
          DiagnosticsService
        >
    with $Provider<DiagnosticsService> {
  /// Settings → About & diagnostics' report.
  DiagnosticsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'diagnosticsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$diagnosticsHash();

  @$internal
  @override
  $ProviderElement<DiagnosticsService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DiagnosticsService create(Ref ref) {
    return diagnostics(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DiagnosticsService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DiagnosticsService>(value),
    );
  }
}

String _$diagnosticsHash() => r'fea6d6d37c6ce5cd9210566da7a3086c6e152754';

/// The report as the page shows it: made when the page opens, and again
/// when asked.

@ProviderFor(diagnosticsReport)
final diagnosticsReportProvider = DiagnosticsReportProvider._();

/// The report as the page shows it: made when the page opens, and again
/// when asked.

final class DiagnosticsReportProvider
    extends
        $FunctionalProvider<
          AsyncValue<Result<String>>,
          Result<String>,
          FutureOr<Result<String>>
        >
    with $FutureModifier<Result<String>>, $FutureProvider<Result<String>> {
  /// The report as the page shows it: made when the page opens, and again
  /// when asked.
  DiagnosticsReportProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'diagnosticsReportProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$diagnosticsReportHash();

  @$internal
  @override
  $FutureProviderElement<Result<String>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Result<String>> create(Ref ref) {
    return diagnosticsReport(ref);
  }
}

String _$diagnosticsReportHash() => r'463c88ae06fed20d8ed8e836ff2d9c1136bbd891';

/// The system's Save dialog for the report. Tests override it.

@ProviderFor(reportSavePicker)
final reportSavePickerProvider = ReportSavePickerProvider._();

/// The system's Save dialog for the report. Tests override it.

final class ReportSavePickerProvider
    extends
        $FunctionalProvider<
          ReportSavePicker,
          ReportSavePicker,
          ReportSavePicker
        >
    with $Provider<ReportSavePicker> {
  /// The system's Save dialog for the report. Tests override it.
  ReportSavePickerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'reportSavePickerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$reportSavePickerHash();

  @$internal
  @override
  $ProviderElement<ReportSavePicker> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ReportSavePicker create(Ref ref) {
    return reportSavePicker(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ReportSavePicker value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ReportSavePicker>(value),
    );
  }
}

String _$reportSavePickerHash() => r'c37fa43a66d471570d47987a0ad8dee4242a37d6';

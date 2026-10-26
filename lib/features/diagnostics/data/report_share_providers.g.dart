// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'report_share_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Hands the report to a phone on the same network (ADR-059). Tests
/// override it.

@ProviderFor(reportSharer)
final reportSharerProvider = ReportSharerProvider._();

/// Hands the report to a phone on the same network (ADR-059). Tests
/// override it.

final class ReportSharerProvider
    extends $FunctionalProvider<ReportSharer, ReportSharer, ReportSharer>
    with $Provider<ReportSharer> {
  /// Hands the report to a phone on the same network (ADR-059). Tests
  /// override it.
  ReportSharerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'reportSharerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$reportSharerHash();

  @$internal
  @override
  $ProviderElement<ReportSharer> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ReportSharer create(Ref ref) {
    return reportSharer(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ReportSharer value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ReportSharer>(value),
    );
  }
}

String _$reportSharerHash() => r'9582169ccdf75de807ef6405311b9af97d295913';

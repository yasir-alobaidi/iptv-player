// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'system_facts.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// `bootstrap()` gives the system's.

@ProviderFor(systemFactsReader)
final systemFactsReaderProvider = SystemFactsReaderProvider._();

/// `bootstrap()` gives the system's.

final class SystemFactsReaderProvider
    extends
        $FunctionalProvider<
          SystemFactsReader,
          SystemFactsReader,
          SystemFactsReader
        >
    with $Provider<SystemFactsReader> {
  /// `bootstrap()` gives the system's.
  SystemFactsReaderProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'systemFactsReaderProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$systemFactsReaderHash();

  @$internal
  @override
  $ProviderElement<SystemFactsReader> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SystemFactsReader create(Ref ref) {
    return systemFactsReader(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SystemFactsReader value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SystemFactsReader>(value),
    );
  }
}

String _$systemFactsReaderHash() => r'b1d84ddfd24f937ac048488c19f35c8a5dc24b49';

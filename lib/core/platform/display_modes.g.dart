// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'display_modes.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// `bootstrap()` gives a TV's (`AndroidDisplayModes`).

@ProviderFor(displayModes)
final displayModesProvider = DisplayModesProvider._();

/// `bootstrap()` gives a TV's (`AndroidDisplayModes`).

final class DisplayModesProvider
    extends $FunctionalProvider<DisplayModes, DisplayModes, DisplayModes>
    with $Provider<DisplayModes> {
  /// `bootstrap()` gives a TV's (`AndroidDisplayModes`).
  DisplayModesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'displayModesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$displayModesHash();

  @$internal
  @override
  $ProviderElement<DisplayModes> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  DisplayModes create(Ref ref) {
    return displayModes(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DisplayModes value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DisplayModes>(value),
    );
  }
}

String _$displayModesHash() => r'c4efcbfcc2c413ae966063593a33a71d3aac083f';

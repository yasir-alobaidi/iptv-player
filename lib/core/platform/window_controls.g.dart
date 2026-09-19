// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'window_controls.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(windowControls)
final windowControlsProvider = WindowControlsProvider._();

final class WindowControlsProvider
    extends $FunctionalProvider<WindowControls, WindowControls, WindowControls>
    with $Provider<WindowControls> {
  WindowControlsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'windowControlsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$windowControlsHash();

  @$internal
  @override
  $ProviderElement<WindowControls> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  WindowControls create(Ref ref) {
    return windowControls(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WindowControls value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WindowControls>(value),
    );
  }
}

String _$windowControlsHash() => r'1a4f2c6662910a5cd79f1c2f380c29a8d595b6b6';

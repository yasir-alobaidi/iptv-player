// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cast_shell_slots.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The cast's notices as toasts (docs/05: "Automatic fallbacks are quiet:
/// badge change + small toast"). `bootstrap()` reads it once.

@ProviderFor(castNoticeToasts)
final castNoticeToastsProvider = CastNoticeToastsProvider._();

/// The cast's notices as toasts (docs/05: "Automatic fallbacks are quiet:
/// badge change + small toast"). `bootstrap()` reads it once.

final class CastNoticeToastsProvider
    extends $FunctionalProvider<void, void, void>
    with $Provider<void> {
  /// The cast's notices as toasts (docs/05: "Automatic fallbacks are quiet:
  /// badge change + small toast"). `bootstrap()` reads it once.
  CastNoticeToastsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'castNoticeToastsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$castNoticeToastsHash();

  @$internal
  @override
  $ProviderElement<void> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  void create(Ref ref) {
    return castNoticeToasts(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$castNoticeToastsHash() => r'4de3113ba92ca33fedbf94808c95c758992ff643';

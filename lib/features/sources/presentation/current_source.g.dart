// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'current_source.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The source the user last picked in the top bar's switcher, remembered
/// across restarts. Null means "the first one".

@ProviderFor(ChosenSourceId)
final chosenSourceIdProvider = ChosenSourceIdProvider._();

/// The source the user last picked in the top bar's switcher, remembered
/// across restarts. Null means "the first one".
final class ChosenSourceIdProvider
    extends $NotifierProvider<ChosenSourceId, String?> {
  /// The source the user last picked in the top bar's switcher, remembered
  /// across restarts. Null means "the first one".
  ChosenSourceIdProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'chosenSourceIdProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$chosenSourceIdHash();

  @$internal
  @override
  ChosenSourceId create() => ChosenSourceId();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$chosenSourceIdHash() => r'c8fb61f145ba4e54d861985eef239fe614cf94f7';

/// The source the user last picked in the top bar's switcher, remembered
/// across restarts. Null means "the first one".

abstract class _$ChosenSourceId extends $Notifier<String?> {
  String? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<String?, String?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String?, String?>,
              String?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The source the app browses: the one the user picked, or the first in
/// their order when they haven't picked one or it was removed. Null while
/// there is no source.

@ProviderFor(currentSource)
final currentSourceProvider = CurrentSourceProvider._();

/// The source the app browses: the one the user picked, or the first in
/// their order when they haven't picked one or it was removed. Null while
/// there is no source.

final class CurrentSourceProvider
    extends $FunctionalProvider<Source?, Source?, Source?>
    with $Provider<Source?> {
  /// The source the app browses: the one the user picked, or the first in
  /// their order when they haven't picked one or it was removed. Null while
  /// there is no source.
  CurrentSourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentSourceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentSourceHash();

  @$internal
  @override
  $ProviderElement<Source?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Source? create(Ref ref) {
    return currentSource(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Source? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Source?>(value),
    );
  }
}

String _$currentSourceHash() => r'13e115f22645ec7847ef0f5c5d26f5c30807a85a';

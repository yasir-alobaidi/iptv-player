// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'appearance_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Where Settings → Appearance is kept: in memory until `bootstrap()`
/// gives the database's, already read.

@ProviderFor(appearanceStore)
final appearanceStoreProvider = AppearanceStoreProvider._();

/// Where Settings → Appearance is kept: in memory until `bootstrap()`
/// gives the database's, already read.

final class AppearanceStoreProvider
    extends
        $FunctionalProvider<AppearanceStore, AppearanceStore, AppearanceStore>
    with $Provider<AppearanceStore> {
  /// Where Settings → Appearance is kept: in memory until `bootstrap()`
  /// gives the database's, already read.
  AppearanceStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appearanceStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appearanceStoreHash();

  @$internal
  @override
  $ProviderElement<AppearanceStore> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AppearanceStore create(Ref ref) {
    return appearanceStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppearanceStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppearanceStore>(value),
    );
  }
}

String _$appearanceStoreHash() => r'a9e3d6c17f58e77638f13466fa0d83e10833f5e3';

/// What the desktop says about text size, motion and the clock, read
/// again whenever the system reports a change and whenever the window
/// comes back to the front (a change of the clock format alone isn't
/// announced). Tests give it a value.

@ProviderFor(DesktopAppearance)
final desktopAppearanceProvider = DesktopAppearanceProvider._();

/// What the desktop says about text size, motion and the clock, read
/// again whenever the system reports a change and whenever the window
/// comes back to the front (a change of the clock format alone isn't
/// announced). Tests give it a value.
final class DesktopAppearanceProvider
    extends $NotifierProvider<DesktopAppearance, SystemAppearance> {
  /// What the desktop says about text size, motion and the clock, read
  /// again whenever the system reports a change and whenever the window
  /// comes back to the front (a change of the clock format alone isn't
  /// announced). Tests give it a value.
  DesktopAppearanceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'desktopAppearanceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$desktopAppearanceHash();

  @$internal
  @override
  DesktopAppearance create() => DesktopAppearance();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SystemAppearance value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SystemAppearance>(value),
    );
  }
}

String _$desktopAppearanceHash() => r'd1c06ebe8241f2814dc2ad22549462fbc9712882';

/// What the desktop says about text size, motion and the clock, read
/// again whenever the system reports a change and whenever the window
/// comes back to the front (a change of the clock format alone isn't
/// announced). Tests give it a value.

abstract class _$DesktopAppearance extends $Notifier<SystemAppearance> {
  SystemAppearance build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<SystemAppearance, SystemAppearance>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SystemAppearance, SystemAppearance>,
              SystemAppearance,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Settings → Appearance. A change shows at once and is saved behind it;
/// one that can't be saved still holds for this run.

@ProviderFor(AppearanceController)
final appearanceControllerProvider = AppearanceControllerProvider._();

/// Settings → Appearance. A change shows at once and is saved behind it;
/// one that can't be saved still holds for this run.
final class AppearanceControllerProvider
    extends $NotifierProvider<AppearanceController, AppearanceState> {
  /// Settings → Appearance. A change shows at once and is saved behind it;
  /// one that can't be saved still holds for this run.
  AppearanceControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appearanceControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appearanceControllerHash();

  @$internal
  @override
  AppearanceController create() => AppearanceController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppearanceState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppearanceState>(value),
    );
  }
}

String _$appearanceControllerHash() =>
    r'baabe1c334ccf987de5300f1491190ca3d7cdf94';

/// Settings → Appearance. A change shows at once and is saved behind it;
/// one that can't be saved still holds for this run.

abstract class _$AppearanceController extends $Notifier<AppearanceState> {
  AppearanceState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AppearanceState, AppearanceState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AppearanceState, AppearanceState>,
              AppearanceState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The look the app is drawn with: the user's choices, with every
/// "System" answered by the desktop.

@ProviderFor(appearance)
final appearanceProvider = AppearanceProvider._();

/// The look the app is drawn with: the user's choices, with every
/// "System" answered by the desktop.

final class AppearanceProvider
    extends $FunctionalProvider<Appearance, Appearance, Appearance>
    with $Provider<Appearance> {
  /// The look the app is drawn with: the user's choices, with every
  /// "System" answered by the desktop.
  AppearanceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appearanceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appearanceHash();

  @$internal
  @override
  $ProviderElement<Appearance> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Appearance create(Ref ref) {
    return appearance(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Appearance value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Appearance>(value),
    );
  }
}

String _$appearanceHash() => r'365246f57bb2648b2b9a9f4331979553c80b61d0';

/// How a time of day is written, for text made away from a screen (a
/// toast, a notification). Screens read `context.tokens.timeStyle`.

@ProviderFor(timeStyle)
final timeStyleProvider = TimeStyleProvider._();

/// How a time of day is written, for text made away from a screen (a
/// toast, a notification). Screens read `context.tokens.timeStyle`.

final class TimeStyleProvider
    extends $FunctionalProvider<TimeStyle, TimeStyle, TimeStyle>
    with $Provider<TimeStyle> {
  /// How a time of day is written, for text made away from a screen (a
  /// toast, a notification). Screens read `context.tokens.timeStyle`.
  TimeStyleProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'timeStyleProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$timeStyleHash();

  @$internal
  @override
  $ProviderElement<TimeStyle> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  TimeStyle create(Ref ref) {
    return timeStyle(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TimeStyle value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TimeStyle>(value),
    );
  }
}

String _$timeStyleHash() => r'05eae35bcee501c68dcd7d39c82f7654308569d7';

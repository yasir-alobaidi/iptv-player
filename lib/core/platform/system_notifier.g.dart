// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'system_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// `bootstrap()` gives the system's. (Not named `systemNotifier`: the
/// generator drops a trailing "Notifier" from a provider's name.)

@ProviderFor(systemNotifications)
final systemNotificationsProvider = SystemNotificationsProvider._();

/// `bootstrap()` gives the system's. (Not named `systemNotifier`: the
/// generator drops a trailing "Notifier" from a provider's name.)

final class SystemNotificationsProvider
    extends $FunctionalProvider<SystemNotifier, SystemNotifier, SystemNotifier>
    with $Provider<SystemNotifier> {
  /// `bootstrap()` gives the system's. (Not named `systemNotifier`: the
  /// generator drops a trailing "Notifier" from a provider's name.)
  SystemNotificationsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'systemNotificationsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$systemNotificationsHash();

  @$internal
  @override
  $ProviderElement<SystemNotifier> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SystemNotifier create(Ref ref) {
    return systemNotifications(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SystemNotifier value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SystemNotifier>(value),
    );
  }
}

String _$systemNotificationsHash() =>
    r'749ea566f8409805ee92a46849b397947ceafef0';

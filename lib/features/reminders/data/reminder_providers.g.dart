// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reminder_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(reminderRepository)
final reminderRepositoryProvider = ReminderRepositoryProvider._();

final class ReminderRepositoryProvider
    extends
        $FunctionalProvider<
          ReminderRepository,
          ReminderRepository,
          ReminderRepository
        >
    with $Provider<ReminderRepository> {
  ReminderRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'reminderRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$reminderRepositoryHash();

  @$internal
  @override
  $ProviderElement<ReminderRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ReminderRepository create(Ref ref) {
    return reminderRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ReminderRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ReminderRepository>(value),
    );
  }
}

String _$reminderRepositoryHash() =>
    r'a115ac3978131759d0fabd01350aaf234fac60fe';

@ProviderFor(reminderGuide)
final reminderGuideProvider = ReminderGuideProvider._();

final class ReminderGuideProvider
    extends $FunctionalProvider<ReminderGuide, ReminderGuide, ReminderGuide>
    with $Provider<ReminderGuide> {
  ReminderGuideProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'reminderGuideProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$reminderGuideHash();

  @$internal
  @override
  $ProviderElement<ReminderGuide> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ReminderGuide create(Ref ref) {
    return reminderGuide(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ReminderGuide value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ReminderGuide>(value),
    );
  }
}

String _$reminderGuideHash() => r'4e44a459c83a9251f52df66a18d59a85aaa05812';

/// Every reminder, soonest first.

@ProviderFor(reminders)
final remindersProvider = RemindersProvider._();

/// Every reminder, soonest first.

final class RemindersProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Reminder>>,
          List<Reminder>,
          Stream<List<Reminder>>
        >
    with $FutureModifier<List<Reminder>>, $StreamProvider<List<Reminder>> {
  /// Every reminder, soonest first.
  RemindersProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'remindersProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$remindersHash();

  @$internal
  @override
  $StreamProviderElement<List<Reminder>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Reminder>> create(Ref ref) {
    return reminders(ref);
  }
}

String _$remindersHash() => r'8355908c043003304ae9fdb8f8b1206464ca75e0';

/// How a due reminder is said, and where its Watch is heard.

@ProviderFor(reminderAlerts)
final reminderAlertsProvider = ReminderAlertsProvider._();

/// How a due reminder is said, and where its Watch is heard.

final class ReminderAlertsProvider
    extends $FunctionalProvider<ReminderAlerts, ReminderAlerts, ReminderAlerts>
    with $Provider<ReminderAlerts> {
  /// How a due reminder is said, and where its Watch is heard.
  ReminderAlertsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'reminderAlertsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$reminderAlertsHash();

  @$internal
  @override
  $ProviderElement<ReminderAlerts> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ReminderAlerts create(Ref ref) {
    return reminderAlerts(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ReminderAlerts value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ReminderAlerts>(value),
    );
  }
}

String _$reminderAlertsHash() => r'6802d02d9088cb0cb35bb0654b3b5773008885ab';

/// The reminders at work: shown when due, and following their programmes
/// through every guide refresh. `bootstrap()` starts it after the first
/// frame; nothing else needs to.

@ProviderFor(reminderService)
final reminderServiceProvider = ReminderServiceProvider._();

/// The reminders at work: shown when due, and following their programmes
/// through every guide refresh. `bootstrap()` starts it after the first
/// frame; nothing else needs to.

final class ReminderServiceProvider
    extends
        $FunctionalProvider<ReminderService, ReminderService, ReminderService>
    with $Provider<ReminderService> {
  /// The reminders at work: shown when due, and following their programmes
  /// through every guide refresh. `bootstrap()` starts it after the first
  /// frame; nothing else needs to.
  ReminderServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'reminderServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$reminderServiceHash();

  @$internal
  @override
  $ProviderElement<ReminderService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ReminderService create(Ref ref) {
    return reminderService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ReminderService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ReminderService>(value),
    );
  }
}

String _$reminderServiceHash() => r'147358de1a9f223be7e7689cca4e7cef43bd16fd';

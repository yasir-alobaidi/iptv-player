// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reminder_watch.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Watch on a reminder, from the desktop's notification or the app's
/// toast, plays its channel (Phase 9 decision 10). Alive from launch:
/// `bootstrap()` reads it once.
///
/// It listens to the alerts' stream itself: a provider nobody watches is
/// paused, and a Watch must not wait for a screen.

@ProviderFor(reminderWatches)
final reminderWatchesProvider = ReminderWatchesProvider._();

/// Watch on a reminder, from the desktop's notification or the app's
/// toast, plays its channel (Phase 9 decision 10). Alive from launch:
/// `bootstrap()` reads it once.
///
/// It listens to the alerts' stream itself: a provider nobody watches is
/// paused, and a Watch must not wait for a screen.

final class ReminderWatchesProvider
    extends $FunctionalProvider<void, void, void>
    with $Provider<void> {
  /// Watch on a reminder, from the desktop's notification or the app's
  /// toast, plays its channel (Phase 9 decision 10). Alive from launch:
  /// `bootstrap()` reads it once.
  ///
  /// It listens to the alerts' stream itself: a provider nobody watches is
  /// paused, and a Watch must not wait for a screen.
  ReminderWatchesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'reminderWatchesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$reminderWatchesHash();

  @$internal
  @override
  $ProviderElement<void> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  void create(Ref ref) {
    return reminderWatches(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$reminderWatchesHash() => r'ed4cb0d7bcc949513423b2f3100fdd1e9b8e4f70';

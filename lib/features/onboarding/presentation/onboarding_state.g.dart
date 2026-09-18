// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'onboarding_state.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The details the user typed, kept while their first sync runs, so
/// Cancel or a failed sync can take them back to a filled-in form. Held in
/// memory only, and dropped when onboarding finishes.

@ProviderFor(PendingSourceDraft)
final pendingSourceDraftProvider = PendingSourceDraftProvider._();

/// The details the user typed, kept while their first sync runs, so
/// Cancel or a failed sync can take them back to a filled-in form. Held in
/// memory only, and dropped when onboarding finishes.
final class PendingSourceDraftProvider
    extends $NotifierProvider<PendingSourceDraft, SourceDraft?> {
  /// The details the user typed, kept while their first sync runs, so
  /// Cancel or a failed sync can take them back to a filled-in form. Held in
  /// memory only, and dropped when onboarding finishes.
  PendingSourceDraftProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pendingSourceDraftProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pendingSourceDraftHash();

  @$internal
  @override
  PendingSourceDraft create() => PendingSourceDraft();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SourceDraft? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SourceDraft?>(value),
    );
  }
}

String _$pendingSourceDraftHash() =>
    r'18e4d234e32d098c1a37ed89a63b3aa3393d2d31';

/// The details the user typed, kept while their first sync runs, so
/// Cancel or a failed sync can take them back to a filled-in form. Held in
/// memory only, and dropped when onboarding finishes.

abstract class _$PendingSourceDraft extends $Notifier<SourceDraft?> {
  SourceDraft? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<SourceDraft?, SourceDraft?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SourceDraft?, SourceDraft?>,
              SourceDraft?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The system's file dialog, filtered to playlists. Tests override it.

@ProviderFor(playlistFilePicker)
final playlistFilePickerProvider = PlaylistFilePickerProvider._();

/// The system's file dialog, filtered to playlists. Tests override it.

final class PlaylistFilePickerProvider
    extends
        $FunctionalProvider<
          PlaylistFilePicker,
          PlaylistFilePicker,
          PlaylistFilePicker
        >
    with $Provider<PlaylistFilePicker> {
  /// The system's file dialog, filtered to playlists. Tests override it.
  PlaylistFilePickerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'playlistFilePickerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$playlistFilePickerHash();

  @$internal
  @override
  $ProviderElement<PlaylistFilePicker> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PlaylistFilePicker create(Ref ref) {
    return playlistFilePicker(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PlaylistFilePicker value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PlaylistFilePicker>(value),
    );
  }
}

String _$playlistFilePickerHash() =>
    r'4ac4e601ffc440b025c7ab01910200bd7ff5c872';

/// The clock onboarding counts days to expiry with. Tests pin it.

@ProviderFor(onboardingClock)
final onboardingClockProvider = OnboardingClockProvider._();

/// The clock onboarding counts days to expiry with. Tests pin it.

final class OnboardingClockProvider
    extends
        $FunctionalProvider<
          DateTime Function(),
          DateTime Function(),
          DateTime Function()
        >
    with $Provider<DateTime Function()> {
  /// The clock onboarding counts days to expiry with. Tests pin it.
  OnboardingClockProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'onboardingClockProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$onboardingClockHash();

  @$internal
  @override
  $ProviderElement<DateTime Function()> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DateTime Function() create(Ref ref) {
    return onboardingClock(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DateTime Function() value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DateTime Function()>(value),
    );
  }
}

String _$onboardingClockHash() => r'fb636bf37c2cfe9b49d944af0f5aa9edaebc2bc9';

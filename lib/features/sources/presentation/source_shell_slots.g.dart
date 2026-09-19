// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'source_shell_slots.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The chip: the current source, green while its last sync worked and
/// its account is usable, amber otherwise.

@ProviderFor(sourceChip)
final sourceChipProvider = SourceChipProvider._();

/// The chip: the current source, green while its last sync worked and
/// its account is usable, amber otherwise.

final class SourceChipProvider
    extends $FunctionalProvider<ShellSource?, ShellSource?, ShellSource?>
    with $Provider<ShellSource?> {
  /// The chip: the current source, green while its last sync worked and
  /// its account is usable, amber otherwise.
  SourceChipProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sourceChipProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sourceChipHash();

  @$internal
  @override
  $ProviderElement<ShellSource?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ShellSource? create(Ref ref) {
    return sourceChip(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ShellSource? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ShellSource?>(value),
    );
  }
}

String _$sourceChipHash() => r'e44176e8959716a9a14581749fea2d3514830043';

/// Every source, for the switcher; null below two.

@ProviderFor(sourceSwitcher)
final sourceSwitcherProvider = SourceSwitcherProvider._();

/// Every source, for the switcher; null below two.

final class SourceSwitcherProvider
    extends
        $FunctionalProvider<
          ShellSourceChoices?,
          ShellSourceChoices?,
          ShellSourceChoices?
        >
    with $Provider<ShellSourceChoices?> {
  /// Every source, for the switcher; null below two.
  SourceSwitcherProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sourceSwitcherProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sourceSwitcherHash();

  @$internal
  @override
  $ProviderElement<ShellSourceChoices?> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ShellSourceChoices? create(Ref ref) {
    return sourceSwitcher(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ShellSourceChoices? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ShellSourceChoices?>(value),
    );
  }
}

String _$sourceSwitcherHash() => r'380938fdc294dd71f7b6475d60357cff725798c0';

/// "Syncing channels · 12,340" while any source syncs; with more than
/// one source, the line names which.

@ProviderFor(sourceSyncLine)
final sourceSyncLineProvider = SourceSyncLineProvider._();

/// "Syncing channels · 12,340" while any source syncs; with more than
/// one source, the line names which.

final class SourceSyncLineProvider
    extends
        $FunctionalProvider<
          ShellSyncStatus?,
          ShellSyncStatus?,
          ShellSyncStatus?
        >
    with $Provider<ShellSyncStatus?> {
  /// "Syncing channels · 12,340" while any source syncs; with more than
  /// one source, the line names which.
  SourceSyncLineProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sourceSyncLineProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sourceSyncLineHash();

  @$internal
  @override
  $ProviderElement<ShellSyncStatus?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ShellSyncStatus? create(Ref ref) {
    return sourceSyncLine(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ShellSyncStatus? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ShellSyncStatus?>(value),
    );
  }
}

String _$sourceSyncLineHash() => r'3704fd2958135bc1f81eeb6a169ee1e35dc166a5';

/// The notices the user closed this session, by source and kind. A new
/// launch shows them again: an expiring subscription is worth one
/// reminder a session.

@ProviderFor(DismissedSourceNotices)
final dismissedSourceNoticesProvider = DismissedSourceNoticesProvider._();

/// The notices the user closed this session, by source and kind. A new
/// launch shows them again: an expiring subscription is worth one
/// reminder a session.
final class DismissedSourceNoticesProvider
    extends
        $NotifierProvider<
          DismissedSourceNotices,
          Set<(String, SourceNoticeKind)>
        > {
  /// The notices the user closed this session, by source and kind. A new
  /// launch shows them again: an expiring subscription is worth one
  /// reminder a session.
  DismissedSourceNoticesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dismissedSourceNoticesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dismissedSourceNoticesHash();

  @$internal
  @override
  DismissedSourceNotices create() => DismissedSourceNotices();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Set<(String, SourceNoticeKind)> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Set<(String, SourceNoticeKind)>>(
        value,
      ),
    );
  }
}

String _$dismissedSourceNoticesHash() =>
    r'868841cb52c3aae4eaced26bdcc50a3a6fb2459b';

/// The notices the user closed this session, by source and kind. A new
/// launch shows them again: an expiring subscription is worth one
/// reminder a session.

abstract class _$DismissedSourceNotices
    extends $Notifier<Set<(String, SourceNoticeKind)>> {
  Set<(String, SourceNoticeKind)> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              Set<(String, SourceNoticeKind)>,
              Set<(String, SourceNoticeKind)>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                Set<(String, SourceNoticeKind)>,
                Set<(String, SourceNoticeKind)>
              >,
              Set<(String, SourceNoticeKind)>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The banner for the current source: sign-in refused, account not
/// active, expired, or expiring within a week.

@ProviderFor(sourceBanner)
final sourceBannerProvider = SourceBannerProvider._();

/// The banner for the current source: sign-in refused, account not
/// active, expired, or expiring within a week.

final class SourceBannerProvider
    extends $FunctionalProvider<ShellNotice?, ShellNotice?, ShellNotice?>
    with $Provider<ShellNotice?> {
  /// The banner for the current source: sign-in refused, account not
  /// active, expired, or expiring within a week.
  SourceBannerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sourceBannerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sourceBannerHash();

  @$internal
  @override
  $ProviderElement<ShellNotice?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ShellNotice? create(Ref ref) {
    return sourceBanner(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ShellNotice? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ShellNotice?>(value),
    );
  }
}

String _$sourceBannerHash() => r'25f98d6148633a2913296f41a940b47588245d5f';

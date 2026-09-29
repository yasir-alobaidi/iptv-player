// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'guide_programme_request.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// A programme the Guide shows as soon as it can, cursor on it and its
/// sheet open: set by search for an upcoming programme (Phase 6 decision
/// 4), read once by the Guide.

@ProviderFor(GuideProgrammeRequest)
final guideProgrammeRequestProvider = GuideProgrammeRequestProvider._();

/// A programme the Guide shows as soon as it can, cursor on it and its
/// sheet open: set by search for an upcoming programme (Phase 6 decision
/// 4), read once by the Guide.
final class GuideProgrammeRequestProvider
    extends
        $NotifierProvider<
          GuideProgrammeRequest,
          ({ChannelItem channel, EpgProgramme programme})?
        > {
  /// A programme the Guide shows as soon as it can, cursor on it and its
  /// sheet open: set by search for an upcoming programme (Phase 6 decision
  /// 4), read once by the Guide.
  GuideProgrammeRequestProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'guideProgrammeRequestProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$guideProgrammeRequestHash();

  @$internal
  @override
  GuideProgrammeRequest create() => GuideProgrammeRequest();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(
    ({ChannelItem channel, EpgProgramme programme})? value,
  ) {
    return $ProviderOverride(
      origin: this,
      providerOverride:
          $SyncValueProvider<({ChannelItem channel, EpgProgramme programme})?>(
            value,
          ),
    );
  }
}

String _$guideProgrammeRequestHash() =>
    r'797f1b8420070c2a48d01bb5249eeb76fabf9775';

/// A programme the Guide shows as soon as it can, cursor on it and its
/// sheet open: set by search for an upcoming programme (Phase 6 decision
/// 4), read once by the Guide.

abstract class _$GuideProgrammeRequest
    extends $Notifier<({ChannelItem channel, EpgProgramme programme})?> {
  ({ChannelItem channel, EpgProgramme programme})? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              ({ChannelItem channel, EpgProgramme programme})?,
              ({ChannelItem channel, EpgProgramme programme})?
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                ({ChannelItem channel, EpgProgramme programme})?,
                ({ChannelItem channel, EpgProgramme programme})?
              >,
              ({ChannelItem channel, EpgProgramme programme})?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

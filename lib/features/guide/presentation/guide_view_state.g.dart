// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'guide_view_state.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Which channels the Guide lists: the current source's, all of them or
/// one category's, in number order as Live TV sorts them. Its own, not
/// Live TV's: choosing a category in one screen leaves the other alone.
/// Starts over when the source changes.

@ProviderFor(GuideChannels)
final guideChannelsProvider = GuideChannelsProvider._();

/// Which channels the Guide lists: the current source's, all of them or
/// one category's, in number order as Live TV sorts them. Its own, not
/// Live TV's: choosing a category in one screen leaves the other alone.
/// Starts over when the source changes.
final class GuideChannelsProvider
    extends $NotifierProvider<GuideChannels, ChannelQuery?> {
  /// Which channels the Guide lists: the current source's, all of them or
  /// one category's, in number order as Live TV sorts them. Its own, not
  /// Live TV's: choosing a category in one screen leaves the other alone.
  /// Starts over when the source changes.
  GuideChannelsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'guideChannelsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$guideChannelsHash();

  @$internal
  @override
  GuideChannels create() => GuideChannels();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ChannelQuery? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ChannelQuery?>(value),
    );
  }
}

String _$guideChannelsHash() => r'5f770acbaea982aa437f25fd00c83b1a5ece895f';

/// Which channels the Guide lists: the current source's, all of them or
/// one category's, in number order as Live TV sorts them. Its own, not
/// Live TV's: choosing a category in one screen leaves the other alone.
/// Starts over when the source changes.

abstract class _$GuideChannels extends $Notifier<ChannelQuery?> {
  ChannelQuery? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<ChannelQuery?, ChannelQuery?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ChannelQuery?, ChannelQuery?>,
              ChannelQuery?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

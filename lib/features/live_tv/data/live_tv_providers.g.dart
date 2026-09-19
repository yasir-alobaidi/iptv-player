// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'live_tv_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(channelRepository)
final channelRepositoryProvider = ChannelRepositoryProvider._();

final class ChannelRepositoryProvider
    extends
        $FunctionalProvider<
          ChannelRepository,
          ChannelRepository,
          ChannelRepository
        >
    with $Provider<ChannelRepository> {
  ChannelRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'channelRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$channelRepositoryHash();

  @$internal
  @override
  $ProviderElement<ChannelRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ChannelRepository create(Ref ref) {
    return channelRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ChannelRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ChannelRepository>(value),
    );
  }
}

String _$channelRepositoryHash() => r'e0f63d18e0287d335bde4ba808b80755c2cf4d1e';

/// How many channels [query] matches, live.

@ProviderFor(channelCount)
final channelCountProvider = ChannelCountFamily._();

/// How many channels [query] matches, live.

final class ChannelCountProvider
    extends $FunctionalProvider<AsyncValue<int>, int, Stream<int>>
    with $FutureModifier<int>, $StreamProvider<int> {
  /// How many channels [query] matches, live.
  ChannelCountProvider._({
    required ChannelCountFamily super.from,
    required ChannelQuery super.argument,
  }) : super(
         retry: null,
         name: r'channelCountProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$channelCountHash();

  @override
  String toString() {
    return r'channelCountProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<int> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<int> create(Ref ref) {
    final argument = this.argument as ChannelQuery;
    return channelCount(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ChannelCountProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$channelCountHash() => r'72f18199e0daca7d9b95fca2b61bd210f8909a16';

/// How many channels [query] matches, live.

final class ChannelCountFamily extends $Family
    with $FunctionalFamilyOverride<Stream<int>, ChannelQuery> {
  ChannelCountFamily._()
    : super(
        retry: null,
        name: r'channelCountProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// How many channels [query] matches, live.

  ChannelCountProvider call(ChannelQuery query) =>
      ChannelCountProvider._(argument: query, from: this);

  @override
  String toString() => r'channelCountProvider';
}

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reminders_dialog.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The channel a reminder is for, as its source lists it now: the list
/// draws its logo from it. Null once the source no longer has it.

@ProviderFor(reminderChannelItem)
final reminderChannelItemProvider = ReminderChannelItemFamily._();

/// The channel a reminder is for, as its source lists it now: the list
/// draws its logo from it. Null once the source no longer has it.

final class ReminderChannelItemProvider
    extends
        $FunctionalProvider<
          AsyncValue<ChannelItem?>,
          ChannelItem?,
          FutureOr<ChannelItem?>
        >
    with $FutureModifier<ChannelItem?>, $FutureProvider<ChannelItem?> {
  /// The channel a reminder is for, as its source lists it now: the list
  /// draws its logo from it. Null once the source no longer has it.
  ReminderChannelItemProvider._({
    required ReminderChannelItemFamily super.from,
    required (String, String) super.argument,
  }) : super(
         retry: null,
         name: r'reminderChannelItemProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$reminderChannelItemHash();

  @override
  String toString() {
    return r'reminderChannelItemProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<ChannelItem?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ChannelItem?> create(Ref ref) {
    final argument = this.argument as (String, String);
    return reminderChannelItem(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is ReminderChannelItemProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$reminderChannelItemHash() =>
    r'019733d254ca6056e4b8c2107de8a777f23f5f22';

/// The channel a reminder is for, as its source lists it now: the list
/// draws its logo from it. Null once the source no longer has it.

final class ReminderChannelItemFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<ChannelItem?>, (String, String)> {
  ReminderChannelItemFamily._()
    : super(
        retry: null,
        name: r'reminderChannelItemProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The channel a reminder is for, as its source lists it now: the list
  /// draws its logo from it. Null once the source no longer has it.

  ReminderChannelItemProvider call(String sourceId, String channelKey) =>
      ReminderChannelItemProvider._(
        argument: (sourceId, channelKey),
        from: this,
      );

  @override
  String toString() => r'reminderChannelItemProvider';
}

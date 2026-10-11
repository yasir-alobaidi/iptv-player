// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'download_settings_section.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The videos hidden from the Library, Search and Home (sketch H).

@ProviderFor(hiddenLibraryItems)
final hiddenLibraryItemsProvider = HiddenLibraryItemsProvider._();

/// The videos hidden from the Library, Search and Home (sketch H).

final class HiddenLibraryItemsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<LibraryItem>>,
          List<LibraryItem>,
          Stream<List<LibraryItem>>
        >
    with
        $FutureModifier<List<LibraryItem>>,
        $StreamProvider<List<LibraryItem>> {
  /// The videos hidden from the Library, Search and Home (sketch H).
  HiddenLibraryItemsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'hiddenLibraryItemsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$hiddenLibraryItemsHash();

  @$internal
  @override
  $StreamProviderElement<List<LibraryItem>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<LibraryItem>> create(Ref ref) {
    return hiddenLibraryItems(ref);
  }
}

String _$hiddenLibraryItemsHash() =>
    r'5e82a7fe25c060578a8155e8f1c5c37e5145c6bb';

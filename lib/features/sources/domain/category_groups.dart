import 'package:iptv_player/features/sources/domain/categories.dart';

/// Categories that share a country or language tag ("UK | Sports", "UK:
/// News"), as the Pick-categories screen clusters them (docs/05).
final class CategoryGroup {
  const new({required this.code, required this.label, required this.entries});

  /// The tag as the provider writes it (`UK`, `AR`); null for the
  /// categories that have none.
  final String? code;

  /// `United Kingdom`, `Arabic`, the bare code for one we don't know, or
  /// `No country tag`.
  final String label;
  final List<CategoryEntry> entries;

  int get visibleCount => entries.where((e) => !e.category.isHidden).length;

  int get itemCount => entries.fold(0, (sum, e) => sum + e.category.itemCount);

  int get visibleItemCount => entries
      .where((e) => !e.category.isHidden)
      .fold(0, (sum, e) => sum + e.category.itemCount);
}

/// A category inside its group, with the tag taken off its name: "UK |
/// Sports" shows as "Sports" under United Kingdom.
final class CategoryEntry {
  const new({required this.category, required this.shortName});

  final CategoryChoice category;
  final String shortName;
}

/// The label of the group for categories without a tag.
const untaggedGroupLabel = 'No country tag';

/// Clusters [categories] by their leading tag, groups in the order the
/// provider first uses them, the untagged ones last. A tag used by one
/// category only isn't a cluster: that category counts as untagged.
List<CategoryGroup> groupCategories(List<CategoryChoice> categories) {
  final tagged = <String, List<CategoryEntry>>{};
  final untagged = <CategoryEntry>[];
  final parsed = [
    for (final category in categories) (category, categoryTag(category.name)),
  ];
  final uses = <String, int>{};
  for (final (_, tag) in parsed) {
    if (tag != null) uses[tag.code] = (uses[tag.code] ?? 0) + 1;
  }
  for (final (category, tag) in parsed) {
    if (tag != null && uses[tag.code]! > 1) {
      (tagged[tag.code] ??= []).add(
        CategoryEntry(category: category, shortName: tag.rest),
      );
    } else {
      untagged.add(CategoryEntry(category: category, shortName: category.name));
    }
  }
  return [
    for (final MapEntry(key: code, value: entries) in tagged.entries)
      CategoryGroup(code: code, label: tagLabel(code), entries: entries),
    if (untagged.isNotEmpty)
      CategoryGroup(code: null, label: untaggedGroupLabel, entries: untagged),
  ];
}

/// The country or language tag at the start of a category name, and the
/// name without it. Recognized: two or three capital letters (or a
/// hyphenated pair, `EX-YU`), optionally bracketed (`|UK|`, `[UK]`,
/// `(UK)`), then a separator (`|`, `:`, `-`, `–`, `—`, `▎`, `•`, `◉`, `»`,
/// `/`) or the closing bracket. "TV Shows" and "Sports" have none.
({String code, String rest})? categoryTag(String name) {
  final match = _tag.firstMatch(name.trim());
  if (match == null) return null;
  final rest = match.group(2)!.trim();
  if (rest.isEmpty) return null;
  return (code: match.group(1)!, rest: rest);
}

final _tag = RegExp(
  r'^[\|\[\(]?\s*([A-Z]{2,3}(?:-[A-Z]{2,3})?)\s*'
  r'(?:[\]\)]\s*[\|:\-–—▎•◉»/]?|[\|:\-–—▎•◉»/])\s*(.+)$',
);

/// A name for a tag: the country or language it stands for, or the tag
/// itself.
String tagLabel(String code) => _tagNames[code] ?? code;

const _tagNames = {
  'UK': 'United Kingdom',
  'GB': 'United Kingdom',
  'US': 'United States',
  'USA': 'United States',
  'CA': 'Canada',
  'AU': 'Australia',
  'IE': 'Ireland',
  'EN': 'English',
  'AR': 'Arabic',
  'ARB': 'Arabic',
  'FR': 'France',
  'DE': 'Germany',
  'GER': 'Germany',
  'ES': 'Spain',
  'IT': 'Italy',
  'PT': 'Portugal',
  'BR': 'Brazil',
  'NL': 'Netherlands',
  'BE': 'Belgium',
  'CH': 'Switzerland',
  'AT': 'Austria',
  'PL': 'Poland',
  'RO': 'Romania',
  'GR': 'Greece',
  'TR': 'Turkey',
  'RU': 'Russia',
  'UA': 'Ukraine',
  'SE': 'Sweden',
  'NO': 'Norway',
  'DK': 'Denmark',
  'FI': 'Finland',
  'IN': 'India',
  'PK': 'Pakistan',
  'BD': 'Bangladesh',
  'IR': 'Iran',
  'KU': 'Kurdish',
  'AF': 'Africa',
  'LAT': 'Latin America',
  'MX': 'Mexico',
  'JP': 'Japan',
  'KR': 'Korea',
  'CN': 'China',
  'PH': 'Philippines',
  'ALB': 'Albania',
  'AL': 'Albania',
  'EX-YU': 'Ex-Yugoslavia',
};

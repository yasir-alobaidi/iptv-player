// The mixer below needs splitmix64's 64-bit constants, and this tool only
// ever runs on the Dart VM, where an int is 64 bits.
// ignore_for_file: avoid_js_rounded_ints

/// Deterministic, lazily generated catalogue.
///
/// Everything derives from [FakeProfile.seed], so the same profile always
/// produces the same data — a test can assert on channel 4211 without
/// generating the other 49,999. Items are built on demand and never all held
/// at once, which is what keeps the `large` profile (50k channels, 30k
/// movies, 3k series) cheap.
library;

import 'package:fake_provider/models.dart';
import 'package:fake_provider/profile.dart';

/// Xtream ids are opaque strings in the API but panels use integers, and the
/// three kinds share no range so a wrong id is a 404, not a wrong item.
const liveIdBase = 1;
const movieIdBase = 100000;
const seriesIdBase = 200000;
const episodeIdBase = 300000;

/// Live samples the generator assigns to channels, in order
/// (tools/media_samples/out).
const liveSamples = <String>[
  'h264_1080p50_aac.ts',
  'h264_1080p25_ac3.ts',
  'hevc_1080p50_aac.ts',
  'h264_1080i50_mp2.ts',
  'mpeg2_576i25_mp2.ts',
  'hevc_2160p25_eac3.ts',
  'h264_2160p25_aac.ts',
  'codec_switch_h264_720p_to_1080p.ts',
];

/// VOD samples for movies and episodes.
const vodSamples = <String>[
  'vod_h264_aac_10min.mp4',
  'vod_h264_ac3_10min.mkv',
  'vod_hevc_eac3_subs.mkv',
];

/// The generated provider catalogue for one profile.
class FakeCatalog {
  new(this.profile);

  final FakeProfile profile;

  /// Built on first use: the getters are hit once per request, the lists are
  /// at most a few hundred rows, and the ids must not move between calls.
  late final List<FakeCategory> _liveCategories = _buildCategories(
    count: profile.liveCategoryCount,
    idBase: _liveCategoryIdBase,
    salt: _saltLiveCategory,
    left: _countries,
    right: _liveTopics,
    name: (country, topic) => '$country | $topic',
  );

  late final List<FakeCategory> _movieCategories = _buildCategories(
    count: profile.movieCategoryCount,
    idBase: _movieCategoryIdBase,
    salt: _saltMovieCategory,
    left: _genres,
    right: _shelves,
    name: (genre, shelf) =>
        shelf.isEmpty ? 'Movies | $genre' : 'Movies | $genre $shelf',
  );

  late final List<FakeCategory> _seriesCategories = _buildCategories(
    count: profile.seriesCategoryCount,
    idBase: _seriesCategoryIdBase,
    salt: _saltSeriesCategory,
    left: _genres,
    right: _shelves,
    name: (genre, shelf) =>
        shelf.isEmpty ? 'Series | $genre' : 'Series | $genre $shelf',
  );

  /// Categories are small and always fully materialized.
  List<FakeCategory> get liveCategories => _liveCategories;
  List<FakeCategory> get movieCategories => _movieCategories;
  List<FakeCategory> get seriesCategories => _seriesCategories;

  int get liveCount => profile.liveCount;
  int get movieCount => profile.movieCount;
  int get seriesCount => profile.seriesCount;

  /// Channels in `num` order. With [categoryId] only that category's
  /// channels, which still means walking the range lazily — no list is built.
  Iterable<FakeChannel> channels({String? categoryId}) {
    final all = Iterable<FakeChannel>.generate(liveCount, _channelAt);
    return categoryId == null
        ? all
        : all.where((c) => c.categoryId == categoryId);
  }

  /// `null` when the id is outside the live range.
  FakeChannel? channelById(int streamId) {
    final index = streamId - liveIdBase;
    if (index < 0 || index >= liveCount) return null;
    return _channelAt(index);
  }

  Iterable<FakeMovie> movies({String? categoryId}) {
    final all = Iterable<FakeMovie>.generate(movieCount, _movieAt);
    return categoryId == null
        ? all
        : all.where((m) => m.categoryId == categoryId);
  }

  FakeMovie? movieById(int streamId) {
    final index = streamId - movieIdBase;
    if (index < 0 || index >= movieCount) return null;
    return _movieAt(index);
  }

  Iterable<FakeSeries> series({String? categoryId}) {
    final all = Iterable<FakeSeries>.generate(seriesCount, _seriesAt);
    return categoryId == null
        ? all
        : all.where((s) => s.categoryId == categoryId);
  }

  FakeSeries? seriesById(int seriesId) {
    final index = seriesId - seriesIdBase;
    if (index < 0 || index >= seriesCount) return null;
    return _seriesAt(index);
  }

  /// Season number -> episodes, in season and episode order.
  Map<int, List<FakeEpisode>> episodesOf(FakeSeries series) {
    final seriesIndex = series.seriesId - seriesIdBase;
    if (seriesIndex < 0 || seriesIndex >= seriesCount) return {};
    final out = <int, List<FakeEpisode>>{};
    for (var season = 1; season <= _seasonCountOf(seriesIndex); season++) {
      final count = _episodeCountOf(seriesIndex, season);
      out[season] = List<FakeEpisode>.generate(
        count,
        (i) => _episodeAt(seriesIndex, season, i + 1),
        growable: false,
      );
    }
    return out;
  }

  /// `null` when the id is outside the episode range or names a season or
  /// episode the series does not have.
  FakeEpisode? episodeById(int episodeId) {
    final relative = episodeId - episodeIdBase;
    if (relative < 0) return null;
    final seriesIndex = relative ~/ _episodeIdSeriesStride;
    if (seriesIndex >= seriesCount) return null;
    final within = relative % _episodeIdSeriesStride;
    final season = within ~/ _episodeIdSeasonStride;
    final episode = within % _episodeIdSeasonStride;
    if (season < 1 || season > _seasonCountOf(seriesIndex)) return null;
    if (episode < 1 || episode > _episodeCountOf(seriesIndex, season)) {
      return null;
    }
    return _episodeAt(seriesIndex, season, episode);
  }

  /// `action=get_short_epg`: the programme covering [now] and the ones after
  /// it. Empty for a channel with no `epg_channel_id`. The schedule is a
  /// deterministic function of the channel and the hour, so it is stable
  /// within a run and never needs storing.
  List<FakeProgramme> shortEpg(int streamId, {int limit = 4, DateTime? now}) {
    final channel = channelById(streamId);
    final epgChannelId = channel?.epgChannelId;
    if (channel == null || epgChannelId == null || limit <= 0) {
      return const [];
    }
    final at = (now ?? DateTime.now()).toUtc();
    // A fixed grid makes "the programme covering now" a division instead of
    // a walk, which is what keeps the schedule storage-free.
    final slot = at.millisecondsSinceEpoch ~/ _epgSlotMs;
    return List<FakeProgramme>.generate(
      limit,
      (i) => _programmeAt(channel, epgChannelId, slot + i),
      growable: false,
    );
  }

  // ---------------------------------------------------------------- items

  FakeChannel _channelAt(int index) {
    final mix = _Mix(profile.seed, _saltLive, index);
    final streamId = liveIdBase + index;
    final brand = mix.pick(_brands);
    final topic = mix.pick(_liveTopics);
    final feed = mix.below(10);
    final quality = mix.pick(_qualityTags);
    final country = mix.pick(_countryPrefixes);
    // Only some channels are numbered, so the EPG name normalization in
    // docs/02 sees both "Aurora Movies FHD" and "Aurora Movies 2".
    final suffix = feed < 4 ? ' ${feed + 1}' : '';
    final clean =
        '${country.$1}$brand $topic$suffix'
        '${quality.isEmpty ? '' : ' $quality'}';
    return FakeChannel(
      streamId: streamId,
      number: index + 1,
      name: _quirkyName(clean, index),
      icon: _iconOr('$_iconRoot/live/$streamId.png', index),
      epgChannelId: _everyNth(index, 9)
          ? null
          : '${brand.toLowerCase()}${topic.toLowerCase()}'
                '${suffix.trim()}.${country.$2}',
      categoryId: _categoryIdFor(liveCategories, index),
      added: _dateFrom(mix),
      archiveDays: switch (mix.below(5)) {
        0 => 7,
        1 => 3,
        2 => 14,
        _ => 0,
      },
      sample: liveSamples[index % liveSamples.length],
    );
  }

  FakeMovie _movieAt(int index) {
    final mix = _Mix(profile.seed, _saltMovie, index);
    final streamId = movieIdBase + index;
    final year = 1971 + mix.below(55);
    final title = _titleOf(mix);
    final sample = vodSamples[index % vodSamples.length];
    return FakeMovie(
      streamId: streamId,
      number: index + 1,
      name: _quirkyName(
        mix.below(5) == 0 ? _releaseName(title, year, mix) : '$title ($year)',
        index,
      ),
      icon: _iconOr('$_iconRoot/movie/$streamId.jpg', index),
      rating: _ratingFrom(mix),
      categoryId: _categoryIdFor(movieCategories, index),
      added: _dateFrom(mix),
      containerExtension: _extensionOf(sample),
      year: year,
      plot: _plotFrom(mix),
      cast: _castFrom(mix),
      director: _personFrom(mix),
      genre: '${mix.pick(_genres)}, ${mix.pick(_genres)}',
      durationSecs: (75 + mix.below(65)) * 60 + mix.below(60),
      sample: sample,
    );
  }

  FakeSeries _seriesAt(int index) {
    final mix = _Mix(profile.seed, _saltSeries, index);
    final seriesId = seriesIdBase + index;
    final year = 1994 + mix.below(32);
    final title = _titleOf(mix);
    return FakeSeries(
      seriesId: seriesId,
      number: index + 1,
      name: _quirkyName(mix.below(4) == 0 ? '$title ($year)' : title, index),
      cover: _iconOr('$_iconRoot/series/$seriesId.jpg', index),
      rating: _ratingFrom(mix),
      categoryId: _categoryIdFor(seriesCategories, index),
      year: year,
      plot: _plotFrom(mix),
      genre: '${mix.pick(_genres)}, ${mix.pick(_genres)}',
      cast: _castFrom(mix),
      director: _personFrom(mix),
      lastModified: _dateFrom(mix),
      // Read from its own salt, not from this draw stream: episodesOf and
      // episodeById must agree with the list row without rebuilding it.
      seasonCount: _seasonCountOf(index),
    );
  }

  FakeEpisode _episodeAt(int seriesIndex, int season, int episode) {
    final relative = _episodeRelativeId(seriesIndex, season, episode);
    final mix = _Mix(profile.seed, _saltEpisode, relative);
    final sample =
        vodSamples[(seriesIndex + season + episode) % vodSamples.length];
    final title = _titleOf(mix);
    return FakeEpisode(
      id: episodeIdBase + relative,
      season: season,
      episode: episode,
      title: _quirkyName(
        mix.below(6) == 0
            ? _episodeReleaseName(title, season, episode, mix)
            : title,
        relative,
      ),
      containerExtension: _extensionOf(sample),
      durationSecs: (38 + mix.below(20)) * 60 + mix.below(60),
      plot: _plotFrom(mix),
      still: _iconOr(
        '$_iconRoot/episode/${episodeIdBase + relative}.jpg',
        relative,
      ),
      added: _dateFrom(mix),
      sample: sample,
    );
  }

  FakeProgramme _programmeAt(
    FakeChannel channel,
    String epgChannelId,
    int slot,
  ) {
    final mix = _Mix(profile.seed, _saltEpg, channel.streamId * 100003 + slot);
    final start = DateTime.fromMillisecondsSinceEpoch(
      slot * _epgSlotMs,
      isUtc: true,
    );
    final title = switch (mix.below(3)) {
      0 => '${mix.pick(_titleNouns)} ${mix.pick(_programmeKinds)}',
      1 =>
        '${mix.pick(_titleNouns)} ${mix.pick(_programmeKinds)}, '
            'Ep. ${1 + mix.below(24)}',
      _ => 'The ${mix.pick(_titleAdjectives)} ${mix.pick(_titleNouns)}',
    };
    return FakeProgramme(
      id: channel.streamId * 1000000 + slot % 1000000,
      epgChannelId: epgChannelId,
      streamId: channel.streamId,
      title: title,
      description: '$title. ${_plotFrom(mix)}',
      start: start,
      end: start.add(const Duration(milliseconds: _epgSlotMs)),
    );
  }

  // ------------------------------------------------------------ structure

  List<FakeCategory> _buildCategories({
    required int count,
    required int idBase,
    required int salt,
    required List<String> left,
    required List<String> right,
    required String Function(String, String) name,
  }) {
    // The seed only rotates the pairs: category names stay plausible and
    // unique while two profiles with different seeds still differ.
    final rotation = _hash64(profile.seed, salt, 0);
    final leftStart = rotation % left.length;
    final rightStart = (rotation ~/ left.length) % right.length;
    return List<FakeCategory>.generate(count, (i) {
      final l = left[(leftStart + i) % left.length];
      final r = right[(rightStart + i ~/ left.length) % right.length];
      final combos = left.length * right.length;
      // Past every pair the suffix keeps names unique rather than repeating.
      final overflow = i ~/ combos;
      final label = overflow == 0
          ? name(l, r)
          : '${name(l, r)} ${overflow + 1}';
      return FakeCategory(id: '${idBase + i}', name: label);
    }, growable: false);
  }

  int _seasonCountOf(int seriesIndex) =>
      1 + _Mix(profile.seed, _saltSeasons, seriesIndex).below(5);

  int _episodeCountOf(int seriesIndex, int season) =>
      4 +
      _Mix(
        profile.seed,
        _saltEpisodeCount,
        seriesIndex * _maxSeasons + season,
      ).below(21);

  int _episodeRelativeId(int seriesIndex, int season, int episode) =>
      seriesIndex * _episodeIdSeriesStride +
      season * _episodeIdSeasonStride +
      episode;

  // --------------------------------------------------------------- quirks

  /// Value quirks that depend on the item's position. Representation quirks
  /// (numbers as strings, `""` for null) belong to [JsonShape].
  String _quirkyName(String clean, int index) {
    var name = clean;
    if (profile.quirks.htmlEntities) name = _entities(name, index);
    if (profile.quirks.invalidUtf8Names && _everyNth(index, 17)) {
      name = '$name $invalidUtf8Marker';
    }
    return name;
  }

  String? _categoryIdFor(List<FakeCategory> categories, int index) {
    if (profile.quirks.danglingCategoryIds) {
      // The "no category at all" rule wins where the two coincide.
      if (_everyNth(index, 29)) return null;
      if (_everyNth(index, 13)) return '$_danglingCategoryId${index % 89}';
    }
    if (categories.isEmpty) return null;
    // Round-robin: even enough that every category has rows, and cheap to
    // evaluate for one index.
    return categories[index % categories.length].id;
  }

  String? _iconOr(String url, int index) {
    if (profile.quirks.junkIcons && _everyNth(index, 11)) {
      return _junkIcons[index % _junkIcons.length];
    }
    // Some items have no logo whatever the quirks, because real panels do.
    if (_everyNth(index, 23)) return null;
    return url;
  }
}

// ------------------------------------------------------------------ mixing

/// Index-addressable draws.
///
/// A sequential `Random(seed)` would make an item depend on how many items
/// were built before it, which breaks `channelById(4211)` on a lazy range.
/// Hashing (seed, salt, index) into a splitmix64 state instead gives every
/// item its own stream, computable on its own.
class _Mix {
  new(int seed, int salt, int index) : _state = _hash64(seed, salt, index);

  int _state;

  int next() {
    _state += 0x9E3779B97F4A7C15;
    var z = _state;
    z = (z ^ (z >>> 30)) * 0xBF58476D1CE4E5B9;
    z = (z ^ (z >>> 27)) * 0x94D049BB133111EB;
    return (z ^ (z >>> 31)) & _positive;
  }

  int below(int bound) => next() % bound;

  T pick<T>(List<T> items) => items[below(items.length)];
}

int _hash64(int seed, int salt, int index) {
  var z =
      seed * 0x9E3779B97F4A7C15 ^
      salt * 0xC2B2AE3D27D4EB4F ^
      index * 0x165667B19E3779F9;
  z = (z ^ (z >>> 30)) * 0xBF58476D1CE4E5B9;
  z = (z ^ (z >>> 27)) * 0x94D049BB133111EB;
  return (z ^ (z >>> 31)) & _positive;
}

/// Clears the sign bit: every draw is a valid modulus operand.
const int _positive = 0x3FFFFFFFFFFFFFFF;

/// One salt per kind, so adding a draw to movies never shifts the channels.
const _saltLive = 0x4c495645;
const _saltMovie = 0x564f4421;
const _saltSeries = 0x53455249;
const _saltEpisode = 0x45504953;
const _saltEpg = 0x45504721;
const _saltSeasons = 0x5345414e;
const _saltEpisodeCount = 0x45504354;
const _saltLiveCategory = 0x4c434154;
const _saltMovieCategory = 0x4d434154;
const _saltSeriesCategory = 0x53434154;

// ----------------------------------------------------------------- pieces

const _liveCategoryIdBase = 1;
const _movieCategoryIdBase = 2001;
const _seriesCategoryIdBase = 3001;

/// Outside every category id base, so a parser must fall back to
/// "Uncategorized" (docs/02).
const _danglingCategoryId = '999';

const int _epgSlotMs = 30 * 60 * 1000;

/// Episode ids pack (series, season, episode) so [FakeCatalog.episodeById]
/// is the exact inverse of the ids [FakeCatalog.episodesOf] hands out.
const _episodeIdSeriesStride = 1000;
const _episodeIdSeasonStride = 100;
const _maxSeasons = 10;

const _iconRoot = 'https://images.northwind.invalid/art';

/// Invented names only (docs/06): nothing here may match a real broadcaster.
const _brands = <String>[
  'Northwind',
  'Aurora',
  'Meridian',
  'Kestrel',
  'Halcyon',
  'Vantage',
  'Zephyr',
  'Lumen',
  'Basalt',
  'Cobalt',
  'Driftwood',
  'Solstice',
  'Ironwood',
  'Marlow',
  'Pelagic',
  'Sable',
];

const _liveTopics = <String>[
  'Sports',
  'Movies',
  'News',
  'Kids',
  'Drama',
  'Music',
  'Docs',
  'Comedy',
  'Life',
  'Cinema',
  'Action',
  'Classics',
  'Nature',
  'Travel',
  'Kitchen',
  'Arena',
];

/// The tags docs/02 step 3 strips before matching a channel to the guide.
const _qualityTags = <String>['HD', 'FHD', 'UHD', '4K', 'SD', 'H265', '', ''];

/// Name prefix and the matching EPG id suffix, so ids stay plausible.
const _countryPrefixes = <(String, String)>[
  ('UK: ', 'uk'),
  ('|EN| ', 'en'),
  ('[US] ', 'us'),
  ('DE: ', 'de'),
  ('FR | ', 'fr'),
  ('', 'tv'),
  ('', 'tv'),
  ('', 'tv'),
];

const _countries = <String>[
  'UK',
  'US',
  'DE',
  'FR',
  'ES',
  'IT',
  'NL',
  'PL',
  'SE',
  'NO',
  'DK',
  'PT',
  'TR',
  'GR',
  'IE',
  'CA',
];

const _genres = <String>[
  'Action',
  'Comedy',
  'Drama',
  'Thriller',
  'Sci-Fi',
  'Horror',
  'Family',
  'Animation',
  'Romance',
  'Crime',
  'Documentary',
  'Western',
  'Fantasy',
  'Mystery',
  'War',
  'Musical',
  'Sport',
  'Adventure',
  'Noir',
  'Biopic',
];

const _shelves = <String>['', '4K', 'Classics', 'New', 'Kids', 'Box Sets'];

const _titleAdjectives = <String>[
  'Silent',
  'Crimson',
  'Hollow',
  'Iron',
  'Glass',
  'Last',
  'Pale',
  'Second',
  'Gilded',
  'Quiet',
  'Broken',
  'Salt',
  'Winter',
  'Amber',
  'Hidden',
  'Restless',
];

const _titleNouns = <String>[
  'Harbour',
  'Signal',
  'Orchard',
  'Lantern',
  'Vector',
  'Meridian',
  'Quarry',
  'Ledger',
  'Fathom',
  'Cascade',
  'Archive',
  'Tide',
  'Compass',
  'Requiem',
  'Foundry',
  'Beacon',
];

const _titleSuffixes = <String>[
  'Rising',
  'Reckoning',
  'Protocol',
  'Returns',
  'Part Two',
  'Aftermath',
];

const _programmeKinds = <String>[
  'Live',
  'Tonight',
  'Report',
  'Weekly',
  'Special',
  'Roundup',
  'Late',
  'Encore',
];

/// Release-name noise, the shape docs/06 wants the library scanner and the
/// title cleaner to cope with.
const _releaseQualities = <String>[
  '1080p.WEB-DL.x264',
  '2160p.HDR.x265',
  '720p.BluRay.x264',
  '1080p.AMZN.WEBRip.DDP5.1.H264',
];

const _releaseGroups = <String>[
  'GLIMMER',
  'NORTHW',
  'KESTRL',
  'LUMEN',
  'SABLE',
];

/// Junk icons never contain the item's id, so a test can tell them from a
/// real URL without knowing this list.
const _junkIcons = <String>[
  'n/a',
  'null',
  'htp:/broken.logo',
  '/images/404/missing.png',
  'about:blank',
  'https://images.northwind.invalid/404.png',
];

const _firstNames = <String>[
  'Ada',
  'Iris',
  'Marek',
  'Tomas',
  'Neve',
  'Elias',
  'Rania',
  'Jonas',
  'Sofia',
  'Dario',
  'Lena',
  'Osric',
  'Mira',
  'Ilya',
  'Bea',
  'Kofi',
];

const _lastNames = <String>[
  'Vance',
  'Orlov',
  'Keller',
  'Brandt',
  'Okoye',
  'Sandoval',
  'Lindqvist',
  'Maroni',
  'Tate',
  'Yilmaz',
  'Dubois',
  'Aster',
  'Halloran',
  'Frost',
  'Voss',
  'Nkemdi',
];

const _plotOpeners = <String>[
  'A harbour pilot',
  'A retired archivist',
  'Two rival cartographers',
  'A night-shift dispatcher',
  'A disgraced auditor',
  'A travelling luthier',
];

const _plotTurns = <String>[
  'inherits a ledger nobody will explain',
  'agrees to one last crossing',
  'follows a signal into the marshes',
  'is mistaken for a witness',
  'opens a season of the wrong kind of luck',
];

const _plotEnds = <String>[
  'and the tide keeps its own accounts.',
  'before the last ferry of the year.',
  'while the town rehearses its alibi.',
  'and nothing in the valley stays buried.',
];

// ---------------------------------------------------------------- helpers

/// 1-based counting: the quirk docs say "every 13th item", meaning the 13th.
bool _everyNth(int index, int n) => (index + 1) % n == 0;

String _entities(String name, int index) => switch (index % 4) {
  0 => name.replaceFirst(' ', ' &amp; '),
  1 => name.replaceFirst(' ', '&#39;s '),
  2 => '  $name  ',
  _ => name,
};

String _titleOf(_Mix mix) {
  final adjective = mix.pick(_titleAdjectives);
  final noun = mix.pick(_titleNouns);
  return switch (mix.below(4)) {
    0 => 'The $adjective $noun',
    1 => '$adjective $noun',
    2 => '$noun of the $adjective ${mix.pick(_titleNouns)}',
    _ => '$noun: ${mix.pick(_titleSuffixes)}',
  };
}

String _releaseName(String title, int year, _Mix mix) =>
    '${title.replaceAll(' ', '.').replaceAll(':', '')}.$year.'
    '${mix.pick(_releaseQualities)}-${mix.pick(_releaseGroups)}';

String _episodeReleaseName(String title, int season, int episode, _Mix mix) {
  String pad(int v) => '$v'.padLeft(2, '0');
  return 'S${pad(season)}E${pad(episode)}.'
      '${title.replaceAll(' ', '.').replaceAll(':', '')}.'
      '${mix.pick(_releaseQualities)}-${mix.pick(_releaseGroups)}';
}

String _personFrom(_Mix mix) =>
    '${mix.pick(_firstNames)} ${mix.pick(_lastNames)}';

String _castFrom(_Mix mix) =>
    '${_personFrom(mix)}, ${_personFrom(mix)}, ${_personFrom(mix)}';

String _plotFrom(_Mix mix) =>
    '${mix.pick(_plotOpeners)} ${mix.pick(_plotTurns)}, '
    '${mix.pick(_plotEnds)}';

/// 3.0–9.9, or unrated: docs/02 lets `rating` be missing.
double? _ratingFrom(_Mix mix) =>
    mix.below(11) == 0 ? null : (30 + mix.below(70)) / 10;

/// A fixed base date, never `DateTime.now()`: `added` has to be stable
/// across runs like everything else.
DateTime _dateFrom(_Mix mix) =>
    DateTime.utc(2024)
        .add(Duration(days: mix.below(720), minutes: mix.below(1440)));

String _extensionOf(String sample) => sample.split('.').last;

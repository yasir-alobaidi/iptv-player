/// Profiles: how much data the fake provider generates, and how badly it
/// behaves while doing it. docs/06-quality.md "Fake provider".
library;

/// Name marker for the invalid-UTF-8 quirk.
///
/// The generator puts this in a name; the response encoder replaces it with a
/// byte that is not valid UTF-8 (docs/02: decode with `allowMalformed: true`).
/// Keeping it a marker rather than a real code unit means the generated data
/// stays a normal Dart `String` and only the wire bytes are broken.
const invalidUtf8Marker = '~BAD~';

/// The provider's misbehaviours, all off by default.
///
/// Every one of these is a quirk docs/02 says the parser MUST tolerate, so a
/// profile with all of them on is the parser's fixture suite at full size.
class FakeQuirks {
  const new({
    this.numbersAsStrings = false,
    this.emptyStringForNull = false,
    this.infoAsEmptyList = false,
    this.episodesAsMap = false,
    this.invalidUtf8Names = false,
    this.danglingCategoryIds = false,
    this.junkIcons = false,
    this.htmlEntities = false,
    this.messyM3u = false,
    this.refusedSignInAs404 = false,
  });

  /// All quirks on, for the `quirky` profile.
  static const all = FakeQuirks(
    numbersAsStrings: true,
    emptyStringForNull: true,
    infoAsEmptyList: true,
    episodesAsMap: true,
    invalidUtf8Names: true,
    danglingCategoryIds: true,
    junkIcons: true,
    htmlEntities: true,
    messyM3u: true,
    refusedSignInAs404: true,
  );

  /// `"num": "12"`, `"rating": "7.4"`, timestamps as strings.
  final bool numbersAsStrings;

  /// `""` instead of `null` for a missing value.
  final bool emptyStringForNull;

  /// `get_vod_info.info` as `[]` instead of `{}`.
  final bool infoAsEmptyList;

  /// `get_series_info.episodes` as a map keyed by season, not a list.
  final bool episodesAsMap;

  /// Every 17th name carries [invalidUtf8Marker].
  final bool invalidUtf8Names;

  /// Every 13th item points at a `category_id` that no category has, and
  /// every 29th has none at all → "Uncategorized".
  final bool danglingCategoryIds;

  /// Every 11th icon URL is junk (not a URL, or a 404 path).
  final bool junkIcons;

  /// HTML entities and stray whitespace in names.
  final bool htmlEntities;

  /// `get.php` as real exports come: CRLF line ends, an `#EXTVLCOPT`
  /// user agent on every 7th entry, a `#KODIPROP` line on every 9th.
  final bool messyM3u;

  /// A wrong username or password gets an empty `404` from
  /// `player_api.php` instead of `200` with `auth: 0`, as a real panel
  /// answered (2026-09-19). A page that doesn't exist still gets the web
  /// server's error page, with a body.
  final bool refusedSignInAs404;

  Map<String, Object?> toJson() => {
    'numbers_as_strings': numbersAsStrings,
    'empty_string_for_null': emptyStringForNull,
    'info_as_empty_list': infoAsEmptyList,
    'episodes_as_map': episodesAsMap,
    'invalid_utf8_names': invalidUtf8Names,
    'dangling_category_ids': danglingCategoryIds,
    'junk_icons': junkIcons,
    'html_entities': htmlEntities,
    'messy_m3u': messyM3u,
    'refused_sign_in_as_404': refusedSignInAs404,
  };
}

/// The fault set. This step only stores and reports it (`/admin/faults`);
/// injection arrives with the phases that test it (docs/06).
class FakeFaults {
  const new({
    this.dropAfterS,
    this.stallAfterS,
    this.slowStartMs,
    this.httpStatus,
    this.maxConnections,
    this.codecSwitchAfterS,
    this.redirectWithExpiringToken = false,
    this.ignoreRange = false,
    this.dropAfterBytes,
    this.throttleKbps,
    this.changeEtag = false,
    this.wrongContentLength = false,
  });

  /// Reads the fault set a POST /admin/faults body carries. Unknown keys are
  /// ignored and a value of the wrong type falls back to "not set", so a typo
  /// in a test never takes the server down.
  factory fromJson(Map<String, Object?> json) {
    int? asInt(String key) {
      final v = json[key];
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v);
      return null;
    }

    bool asBool(String key) {
      final v = json[key];
      if (v is bool) return v;
      if (v is num) return v != 0;
      if (v is String) return v == '1' || v.toLowerCase() == 'true';
      return false;
    }

    return FakeFaults(
      dropAfterS: asInt('drop_after_s'),
      stallAfterS: asInt('stall_after_s'),
      slowStartMs: asInt('slow_start_ms'),
      httpStatus: asInt('http_status'),
      maxConnections: asInt('max_connections'),
      codecSwitchAfterS: asInt('codec_switch_after_s'),
      redirectWithExpiringToken: asBool('redirect_with_expiring_token'),
      ignoreRange: asBool('ignore_range'),
      dropAfterBytes: asInt('drop_after_bytes'),
      throttleKbps: asInt('throttle_kbps'),
      changeEtag: asBool('change_etag'),
      wrongContentLength: asBool('wrong_content_length'),
    );
  }

  final int? dropAfterS;
  final int? stallAfterS;
  final int? slowStartMs;
  final int? httpStatus;

  /// Overrides the profile's limit while set (docs/06 fault list).
  final int? maxConnections;
  final int? codecSwitchAfterS;
  final bool redirectWithExpiringToken;
  final bool ignoreRange;
  final int? dropAfterBytes;
  final int? throttleKbps;
  final bool changeEtag;
  final bool wrongContentLength;

  Map<String, Object?> toJson() => {
    'drop_after_s': dropAfterS,
    'stall_after_s': stallAfterS,
    'slow_start_ms': slowStartMs,
    'http_status': httpStatus,
    'max_connections': maxConnections,
    'codec_switch_after_s': codecSwitchAfterS,
    'redirect_with_expiring_token': redirectWithExpiringToken,
    'ignore_range': ignoreRange,
    'drop_after_bytes': dropAfterBytes,
    'throttle_kbps': throttleKbps,
    'change_etag': changeEtag,
    'wrong_content_length': wrongContentLength,
  };
}

/// One named set of counts, a seed, and the quirks.
class FakeProfile {
  const new({
    required this.name,
    required this.seed,
    required this.liveCount,
    required this.movieCount,
    required this.seriesCount,
    required this.liveCategoryCount,
    required this.movieCategoryCount,
    required this.seriesCategoryCount,
    this.maxConnections = 2,
    this.username = 'test',
    this.password = 'test',
    this.quirks = const FakeQuirks(),
    this.faults = const FakeFaults(),
    this.expiresInDays = 365,
  });

  final String name;

  /// Every generated value derives from this, so two runs of the same
  /// profile produce byte-identical data.
  final int seed;

  final int liveCount;
  final int movieCount;
  final int seriesCount;
  final int liveCategoryCount;
  final int movieCategoryCount;
  final int seriesCategoryCount;

  /// `user_info.max_connections`, and the limit the stream handler enforces.
  final int maxConnections;

  final String username;
  final String password;
  final FakeQuirks quirks;
  final FakeFaults faults;

  /// `null` means no expiry (docs/02: `exp_date` null).
  final int? expiresInDays;

  FakeProfile copyWith({
    int? liveCount,
    int? movieCount,
    int? seriesCount,
    int? maxConnections,
    String? username,
    String? password,
    FakeQuirks? quirks,
    FakeFaults? faults,
  }) => FakeProfile(
    name: name,
    seed: seed,
    liveCount: liveCount ?? this.liveCount,
    movieCount: movieCount ?? this.movieCount,
    seriesCount: seriesCount ?? this.seriesCount,
    liveCategoryCount: liveCategoryCount,
    movieCategoryCount: movieCategoryCount,
    seriesCategoryCount: seriesCategoryCount,
    maxConnections: maxConnections ?? this.maxConnections,
    username: username ?? this.username,
    password: password ?? this.password,
    quirks: quirks ?? this.quirks,
    faults: faults ?? this.faults,
    expiresInDays: expiresInDays,
  );
}

/// The built-in profiles, by `--profile` name.
const fakeProfiles = <String, FakeProfile>{
  'default': FakeProfile(
    name: 'default',
    seed: 20260916,
    liveCount: 240,
    movieCount: 120,
    seriesCount: 24,
    liveCategoryCount: 12,
    movieCategoryCount: 8,
    seriesCategoryCount: 5,
  ),
  // The docs/06 perf profile: 50k channels, 30k movies, 3k series.
  'large': FakeProfile(
    name: 'large',
    seed: 20260916,
    liveCount: 50000,
    movieCount: 30000,
    seriesCount: 3000,
    liveCategoryCount: 180,
    movieCategoryCount: 90,
    seriesCategoryCount: 40,
    maxConnections: 4,
  ),
  // Every quirk docs/02 lists, at a size that is still quick to eyeball.
  'quirky': FakeProfile(
    name: 'quirky',
    seed: 7,
    liveCount: 320,
    movieCount: 200,
    seriesCount: 40,
    liveCategoryCount: 10,
    movieCategoryCount: 6,
    seriesCategoryCount: 4,
    quirks: FakeQuirks.all,
    expiresInDays: null,
  ),
};

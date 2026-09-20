/// What the handlers share: the profile, the live fault set, the catalogue,
/// and where the samples and ffmpeg are.
library;

import 'package:fake_provider/generator.dart';
import 'package:fake_provider/profile.dart';

class FakeServerState {
  new({
    required this.profile,
    required this.samplesDir,
    required this.ffmpegPath,
    required this.runDir,
    this.epgDays = 3,
    this.epgGzip = false,
  }) : faults = profile.faults,
       catalog = FakeCatalog(profile);

  final FakeProfile profile;
  final FakeCatalog catalog;

  /// tools/media_samples/out by default.
  final String samplesDir;

  /// The bundled ffmpeg (`third_party/ffmpeg/<platform>/ffmpeg`).
  final String ffmpegPath;

  /// Where PID files and the MKV loop cache live.
  final String runDir;

  /// Days of guide `xmltv.php` serves after now, unless the request asks
  /// for another number (`--epg-days`).
  final int epgDays;

  /// Whether `xmltv.php` gzips by default (`--epg-gzip`).
  final bool epgGzip;

  final DateTime startedAt = DateTime.now();

  /// Live streams being served right now. The stream handler owns this;
  /// `player_api.php` reports it as `user_info.active_cons`.
  int activeStreams = 0;

  /// Replaced wholesale by `POST /admin/faults`.
  FakeFaults faults;

  /// The fault set wins over the profile while it is set.
  int get maxConnections => faults.maxConnections ?? profile.maxConnections;

  bool authenticates(String? username, String? password) =>
      username == profile.username && password == profile.password;
}

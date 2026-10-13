import 'package:iptv_player/core/result.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'artwork_store.g.dart';

/// How much room the kept pictures take, and how much they may.
typedef ArtworkUsage = ({int bytes, int maxBytes});

/// The picture cache as Settings → Data sees it: posters, logos and
/// stills kept on this computer.
abstract interface class ArtworkStore {
  /// What is on disk now, measured off the UI isolate.
  Future<Result<ArtworkUsage>> usage();

  /// Deletes every kept picture, and drops the decoded ones from memory.
  /// What is on screen stays until it is drawn again.
  Future<Result<void>> clear();
}

/// A build with no picture cache (no app folder): nothing kept, nothing
/// to clear.
final class NoArtworkStore implements ArtworkStore {
  const new();

  @override
  Future<Result<ArtworkUsage>> usage() async =>
      const Ok((bytes: 0, maxBytes: 0));

  @override
  Future<Result<void>> clear() async => const Ok(null);
}

/// `bootstrap()` gives the real one.
@Riverpod(keepAlive: true)
ArtworkStore artworkStore(Ref ref) => const NoArtworkStore();

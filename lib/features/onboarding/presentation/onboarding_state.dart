import 'package:file_selector/file_selector.dart';
import 'package:iptv_player/features/sources/domain/source.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'onboarding_state.g.dart';

/// The labels of the onboarding header's steps (canvas).
const onboardingSteps = ['Source', 'Connect', 'Sync', 'Pick categories'];

/// What Connect opens with when it isn't blank: Welcome's "Open a file
/// instead" hands over the file it picked.
final class ConnectPreset {
  const new({required this.type, this.path});

  final SourceType type;
  final String? path;
}

/// The details the user typed, kept while their first sync runs, so
/// Cancel or a failed sync can take them back to a filled-in form. Held in
/// memory only, and dropped when onboarding finishes.
@Riverpod(keepAlive: true)
class PendingSourceDraft extends _$PendingSourceDraft {
  @override
  SourceDraft? build() => null;

  // ignore: avoid_setters_without_getters, the state is the getter.
  set draft(SourceDraft? draft) => state = draft;
}

/// Where adding a source ends: Home for the first source, or the screen
/// the user started from (Settings → Sources) for another. Finish, and
/// Connect's Back when there is nothing to pop, go here.
@Riverpod(keepAlive: true)
class OnboardingReturnPath extends _$OnboardingReturnPath {
  @override
  String? build() => null;

  // ignore: avoid_setters_without_getters, the state is the getter.
  set path(String? path) => state = path;
}

/// Asks the user for a playlist file; null when they close the dialog.
typedef PlaylistFilePicker = Future<String?> Function();

/// The system's file dialog, filtered to playlists. Tests override it.
@Riverpod(keepAlive: true)
PlaylistFilePicker playlistFilePicker(Ref ref) => () async {
  final file = await openFile(
    acceptedTypeGroups: const [
      XTypeGroup(
        label: 'Playlists',
        extensions: ['m3u', 'm3u8', 'txt', 'gz'],
        mimeTypes: ['audio/x-mpegurl', 'application/vnd.apple.mpegurl'],
      ),
      XTypeGroup(label: 'All files'),
    ],
  );
  return file?.path;
};

/// The clock onboarding counts days to expiry with. Tests pin it.
@Riverpod(keepAlive: true)
DateTime Function() onboardingClock(Ref ref) => DateTime.now;

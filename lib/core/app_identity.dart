// Plain Dart: the relay's isolate and the data layer name the app too.

/// The app's name, wherever a person reads it: windows, notifications,
/// the About line, files it suggests (docs/05 "Brand", ADR-018).
///
/// What the system knows the app by stays as it was, so that nothing
/// already saved is lost: the Dart package (`iptv_player`), the
/// application id (`io.github.yasiralobaidi.iptvplayer`: the data folder
/// on Linux, the desktop entry, notifications), the database's file, and
/// on Windows the version information's product name (the data folder
/// and the passwords' file). Phase 10 decides how an installer moves them.
const appName = 'Bijou';

/// What the app's own files are called: `bijou-settings-2026-10-14.json`.
const appFileSlug = 'bijou';

/// What the app is, in a sentence: a player for what the user brings,
/// with nothing of its own to watch.
const appDescription =
    'A player for your videos, playlists and services. It comes with '
    'nothing to watch of its own.';

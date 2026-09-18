/// HTTP settings shared by the Xtream client and the M3U reader.
library;

/// What the app sends as its User-Agent unless the source overrides it.
/// Panels commonly block agents they don't recognize, and a media player's
/// is the one they expect (docs/02).
const defaultUserAgent = 'VLC/3.0.20 LibVLC/3.0.20';

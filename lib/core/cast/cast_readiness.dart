/// Whether this build can cast at all, before any device is involved.
enum CastReadiness {
  ready,

  /// The bundled FFmpeg or ffprobe is missing ("This build can't cast:
  /// FFmpeg is missing"), never a crash.
  ffmpegMissing,
}

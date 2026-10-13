/// A player that can say what it is, for the diagnostics report: "mpv
/// 0.34.1". Not part of `PlayerEngine`: only the report asks.
abstract interface class PlayerVersion {
  /// Null when the player doesn't say.
  Future<String?> playerVersion();
}

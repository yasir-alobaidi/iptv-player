// Plain Dart: the relay's isolate imports it (no Flutter, or
// relay_kill_test's `dart run` victim stops compiling).

/// The ports the relay serves the TV on (docs/04): what a firewall must
/// let in.
const castRelayFirstPort = 38400;
const castRelayLastPort = 38499;

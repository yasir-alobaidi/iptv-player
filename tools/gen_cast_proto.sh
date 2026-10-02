#!/usr/bin/env bash
# Regenerates lib/data/cast/proto/ from lib/data/cast/proto/cast_channel.proto
# (docs/04: generated once and committed). Needs protoc (apt
# protobuf-compiler); the Dart plugin comes from the Phase 0 spike, whose
# protoc_plugin (25.1.0) matches the app's protobuf (6.1.0).
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
DART="${DART:-$(command -v dart || echo "$HOME/develop/flutter/bin/dart")}"
spike="$root/spike/cast_spike"
plugin="$spike/.dart_tool/protoc-gen-dart"
if [[ ! -x $plugin ]]; then
  (cd "$spike" && "$DART" pub get >/dev/null)
  source=$(python3 -c 'import json,sys; print(next(p["rootUri"] for p in json.load(open(sys.argv[1]))["packages"] if p["name"] == "protoc_plugin"))' "$spike/.dart_tool/package_config.json")
  "$DART" compile exe --packages="$spike/.dart_tool/package_config.json" \
    "${source#file://}/bin/protoc_plugin.dart" -o "$plugin"
fi
out="$root/lib/data/cast/proto"
protoc --plugin=protoc-gen-dart="$plugin" --dart_out="$out" -I"$out" \
  "$out/cast_channel.proto"
# Only the message and its enums are used; the JSON descriptors are not.
rm -f "$out/cast_channel.pbjson.dart"
"$DART" format "$out"

#!/usr/bin/env bash
# Regenerates lib/src/proto/ from proto/cast_channel.proto (needs protoc: apt protobuf-compiler).
set -euo pipefail
cd "$(dirname "$0")/.."
DART="${DART:-$(command -v dart || echo "$HOME/develop/flutter/bin/dart")}"
PLUGIN=.dart_tool/protoc-gen-dart
if [[ ! -x $PLUGIN ]]; then
  root=$(python3 -c 'import json; print(next(p["rootUri"] for p in json.load(open(".dart_tool/package_config.json"))["packages"] if p["name"] == "protoc_plugin"))')
  "$DART" compile exe --packages=.dart_tool/package_config.json "${root#file://}/bin/protoc_plugin.dart" -o "$PLUGIN"
fi
mkdir -p lib/src/proto
protoc --plugin=protoc-gen-dart="$PLUGIN" --dart_out=lib/src/proto -Iproto proto/cast_channel.proto

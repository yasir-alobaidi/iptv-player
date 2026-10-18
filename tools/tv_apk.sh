#!/usr/bin/env bash
# Builds the Google TV app (32-bit, the Chromecast with Google TV's) as
# build/tv/bijou-<channel>-<build>.apk (ADR-034):
#   stable  "Bijou", io.github.yasiralobaidi.bijou      (from main)
#   beta    "Bijou Beta", io.github.yasiralobaidi.bijou.beta (from dev)
# The two install side by side, each with its own data and sign-in.
# A second argument builds a trial of the picture's own layer (T1,
# docs/plans/tv-video-layer-and-frame-rate.md) as …-layer[-clear]-<build>.apk:
#   layer        --dart-define=BIJOU_VIDEO_LAYER=true
#   layer-clear  the same, the window with no background of its own
# Install: adb -s <tv> install -r build/tv/bijou-<channel>-<build>.apk
# Run nothing else with flutter in this checkout while it builds, and stop
# Gradle afterwards (docs/setup.md; the laptop's memory).
set -euo pipefail
repo=$(cd "$(dirname "$0")/.." && pwd)
channel=${1:-}
trial=${2:-}
flutter=${FLUTTER:-$HOME/develop/flutter/bin/flutter}

case $channel in
  stable) defines=() ;;
  beta) defines=(--dart-define=BIJOU_CHANNEL=beta) ;;
  *)
    echo "usage: $0 stable|beta [layer|layer-clear]" >&2
    exit 2
    ;;
esac
case $trial in
  '') ;;
  layer) defines+=(--dart-define=BIJOU_VIDEO_LAYER=true) ;;
  layer-clear) defines+=(--dart-define=BIJOU_VIDEO_LAYER=clear) ;;
  *)
    echo "usage: $0 stable|beta [layer|layer-clear]" >&2
    exit 2
    ;;
esac

branch=$(git -C "$repo" rev-parse --abbrev-ref HEAD)
if [[ $channel == stable && $branch != main ]]; then
  echo "warning: a stable build from '$branch', not main" >&2
fi

cd "$repo"
"$flutter" build apk --release --target-platform android-arm "${defines[@]}"
build=$(git rev-list --count HEAD)
mkdir -p build/tv
out="build/tv/bijou-$channel${trial:+-$trial}-$build.apk"
cp build/app/outputs/flutter-apk/app-release.apk "$out"
(cd android && ./gradlew --stop >/dev/null 2>&1) || true
pkill -f '[K]otlinCompileDaemon' || true
echo "$out"

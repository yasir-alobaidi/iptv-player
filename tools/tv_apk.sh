#!/usr/bin/env bash
# Builds the Google TV app (32-bit, the Chromecast with Google TV's) as
# build/tv/bijou-<channel>-<build>.apk (ADR-034):
#   stable  "Bijou", io.github.yasiralobaidi.bijou      (from main)
#   beta    "Bijou Beta", io.github.yasiralobaidi.bijou.beta (from dev)
# The two install side by side, each with its own data and sign-in.
# Films play on the picture's own layer (T1, ADR-035 §1) in every build. A
# second argument builds a variant as …-<variant>-<build>.apk:
#   texture      --dart-define=BIJOU_VIDEO_LAYER=off: the picture on
#                Flutter's texture, as before T1 (to compare, or fall back)
#   layer-clear  the layer, the window with no background of its own
#   cover        the cover photo as the icon, not the jewel (the Living
#                Room's "FAISAL TV", ADR-057; change its label by hand)
# To hand out (32- and 64-bit, dist/Bijou-TV.apk): tools/dist_apk.sh.
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
    echo "usage: $0 stable|beta [texture|layer-clear|cover]" >&2
    exit 2
    ;;
esac
case $trial in
  '') ;;
  layer) trial= ;; # the default since ADR-035's go; kept for old notes
  texture) defines+=(--dart-define=BIJOU_VIDEO_LAYER=off) ;;
  layer-clear) defines+=(--dart-define=BIJOU_VIDEO_LAYER=clear) ;;
  cover) defines+=(--dart-define=BIJOU_ICON=cover) ;;
  *)
    echo "usage: $0 stable|beta [texture|layer-clear|cover]" >&2
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
# Gradle's --stop needs the JDK the build used (Flutter's jdk-dir); without
# JAVA_HOME it fails, and the 3 GB daemon stayed after every build.
jdk=$("$flutter" config --list 2>/dev/null | sed -n 's/^ *jdk-dir: //p')
(cd android && JAVA_HOME=${JAVA_HOME:-$jdk} ./gradlew --stop >/dev/null 2>&1) ||
  pkill -f '[G]radleDaemon' || true
pkill -f '[K]otlinCompileDaemon' || true
echo "$out"

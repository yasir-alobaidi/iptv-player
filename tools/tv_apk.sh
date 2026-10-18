#!/usr/bin/env bash
# Builds the Google TV app (32-bit, the Chromecast with Google TV's) as
# build/tv/bijou-<channel>-<build>.apk (ADR-034):
#   stable  "Bijou", io.github.yasiralobaidi.bijou      (from main)
#   beta    "Bijou Beta", io.github.yasiralobaidi.bijou.beta (from dev)
# The two install side by side, each with its own data and sign-in.
# Install: adb -s <tv> install -r build/tv/bijou-<channel>-<build>.apk
# Run nothing else with flutter in this checkout while it builds, and stop
# Gradle afterwards (docs/setup.md; the laptop's memory).
set -euo pipefail
repo=$(cd "$(dirname "$0")/.." && pwd)
channel=${1:-}
flutter=${FLUTTER:-$HOME/develop/flutter/bin/flutter}

case $channel in
  stable) defines=() ;;
  beta) defines=(--dart-define=BIJOU_CHANNEL=beta) ;;
  *)
    echo "usage: $0 stable|beta" >&2
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
out="build/tv/bijou-$channel-$build.apk"
cp build/app/outputs/flutter-apk/app-release.apk "$out"
# Gradle's --stop needs the JDK the build used (Flutter's jdk-dir); without
# JAVA_HOME it fails, and the 3 GB daemon stayed after every build.
jdk=$("$flutter" config --list 2>/dev/null | sed -n 's/^ *jdk-dir: //p')
(cd android && JAVA_HOME=${JAVA_HOME:-$jdk} ./gradlew --stop >/dev/null 2>&1) ||
  pkill -f '[G]radleDaemon' || true
pkill -f '[K]otlinCompileDaemon' || true
echo "$out"

#!/usr/bin/env bash
# Builds the TV app to hand out (docs/install/android-tv.md, "The APK
# file"): "Bijou" with the jewel, for 32- and 64-bit ARM (every Google TV,
# Android TV and Fire TV), signed with the key the TVs' Bijou has (this
# laptop's debug key, or BIJOU_KEYSTORE's: ADR-056), as
# dist/Bijou-TV.apk. The release workflow makes the same file.
#
#   tools/dist_apk.sh           from the checkout as it is (main for stable)
#   tools/dist_apk.sh cover     the cover photo as its icon (FAISAL TV's)
#
# Then install it by hand: tools/serve_apk.py and the Downloader app, a USB
# stick, or `adb install -r dist/Bijou-TV.apk`. Run nothing else with
# flutter in this checkout while it builds; Gradle is stopped afterwards
# (the laptop's memory).
set -euo pipefail
repo=$(cd "$(dirname "$0")/.." && pwd)
flutter=${FLUTTER:-$HOME/develop/flutter/bin/flutter}

defines=()
name=Bijou-TV.apk
case ${1:-} in
  '') ;;
  cover)
    defines+=(--dart-define=BIJOU_ICON=cover)
    name=Bijou-TV-cover.apk
    ;;
  *)
    echo "usage: $0 [cover]" >&2
    exit 2
    ;;
esac

branch=$(git -C "$repo" rev-parse --abbrev-ref HEAD)
if [[ $(git -C "$repo" rev-parse HEAD) != $(git -C "$repo" rev-parse main) ]]; then
  echo "note: building '$branch', which isn't main (the stable build)" >&2
fi

cd "$repo"
"$flutter" build apk --release --target-platform android-arm,android-arm64 \
  "${defines[@]}"
mkdir -p dist
cp build/app/outputs/flutter-apk/app-release.apk "dist/$name"
build=$(git rev-list --count HEAD)
# Gradle's --stop needs the JDK the build used (Flutter's jdk-dir).
jdk=$("$flutter" config --list 2>/dev/null | sed -n 's/^ *jdk-dir: //p')
(cd android && JAVA_HOME=${JAVA_HOME:-$jdk} ./gradlew --stop >/dev/null 2>&1) ||
  pkill -f '[G]radleDaemon' || true
pkill -f '[K]otlinCompileDaemon' || true
echo "dist/$name (build $build, $(du -h "dist/$name" | cut -f1))"

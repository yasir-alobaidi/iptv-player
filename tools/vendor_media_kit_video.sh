#!/usr/bin/env bash
# Rebuilds third_party/media_kit_video: media_kit_video 2.0.1 from pub.dev plus
# every third_party/patches/media_kit_video-2.0.1-*.patch, in name order:
#   android-video-layer  the picture's own layer on Google TV (the T1 trial,
#                        docs/plans/tv-video-layer-and-frame-rate.md)
#   egl-display          media_kit #1404 (ADR-003)
# The app points dependency_overrides at that folder until upstream ships a fix.
set -euo pipefail
repo=$(cd "$(dirname "$0")/.." && pwd)
version=2.0.1
dest="$repo/third_party/media_kit_video"
src="${PUB_CACHE:-$HOME/.pub-cache}/hosted/pub.dev/media_kit_video-$version"

if [[ ! -d $src ]]; then
  dart=$(command -v dart || echo "$HOME/develop/flutter/bin/dart")
  "$dart" pub cache add media_kit_video --version "$version"
fi

tmp=$(mktemp -d "$repo/third_party/.media_kit_video.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
cp -r "$src" "$tmp/media_kit_video"
chmod -R u+w "$tmp/media_kit_video"
rm -rf "$tmp/media_kit_video/example"
applied=()
for patch_file in "$repo"/third_party/patches/media_kit_video-"$version"-*.patch; do
  (cd "$tmp" && patch -p1 -s --no-backup-if-mismatch < "$patch_file")
  applied+=("$(basename "$patch_file")")
done
rm -rf "$dest"
mv "$tmp/media_kit_video" "$dest"
echo "third_party/media_kit_video = media_kit_video $version + ${applied[*]}"

#!/usr/bin/env bash
# Rebuilds third_party/media_kit_video: media_kit_video 2.0.1 from pub.dev plus
# third_party/patches/media_kit_video-2.0.1-egl-display.patch (media_kit #1404, ADR-003).
# The app points dependency_overrides at that folder until upstream ships a fix.
set -euo pipefail
repo=$(cd "$(dirname "$0")/.." && pwd)
version=2.0.1
patch_file="$repo/third_party/patches/media_kit_video-$version-egl-display.patch"
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
(cd "$tmp" && patch -p1 -s --no-backup-if-mismatch < "$patch_file")
rm -rf "$dest"
mv "$tmp/media_kit_video" "$dest"
echo "third_party/media_kit_video = media_kit_video $version + $(basename "$patch_file")"

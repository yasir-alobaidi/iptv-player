#!/usr/bin/env bash
# Downloads static FFmpeg + ffprobe builds (BtbN/FFmpeg-Builds, GPL variant) into
# third_party/ffmpeg/<platform>/. The app only ever runs these binaries, never the system FFmpeg.
#
# Usage: tools/fetch_ffmpeg.sh [linux-x64|windows-x64|all]   (default: linux-x64)
# Env:   FFMPEG_BRANCH   release branch, default 8.1 (must be 7.x or newer)
#        FFMPEG_TAG      GitHub release tag, default "latest" (BtbN rebuilds it daily;
#                        use a dated autobuild-YYYY-MM-DD-HH-MM tag to pin a build)
set -euo pipefail

BRANCH="${FFMPEG_BRANCH:-8.1}"
TAG="${FFMPEG_TAG:-latest}"
TARGET="${1:-linux-x64}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BASE_URL="https://github.com/BtbN/FFmpeg-Builds/releases/download/${TAG}"

case "${BRANCH%%.*}" in
  7|8|9|[1-9][0-9]) ;;
  *) echo "FFMPEG_BRANCH must be 7.x or newer (got ${BRANCH})" >&2; exit 2 ;;
esac

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "Fetching checksums for release ${TAG}…"
curl -fsSL --retry 3 -o "$WORK/checksums.sha256" "${BASE_URL}/checksums.sha256"

fetch() {
  local platform="$1" asset="$2" ext="$3"
  local dest="${REPO_ROOT}/third_party/ffmpeg/${platform}"
  local expected
  expected="$(awk -v a="$asset" '$2 == a || $2 == "*"a {print $1}' "$WORK/checksums.sha256")"
  if [[ -z "$expected" ]]; then
    echo "No checksum for ${asset} in release ${TAG}" >&2
    exit 1
  fi

  echo "Downloading ${asset}…"
  curl -fL --retry 3 --progress-bar -o "$WORK/$asset" "${BASE_URL}/${asset}"
  echo "${expected}  $WORK/$asset" | sha256sum -c --quiet -
  echo "Checksum OK"

  mkdir -p "$WORK/x-$platform"
  if [[ "$ext" == "zip" ]]; then
    unzip -q "$WORK/$asset" -d "$WORK/x-$platform"
  else
    tar -xf "$WORK/$asset" -C "$WORK/x-$platform"
  fi
  local bin_dir
  bin_dir="$(find "$WORK/x-$platform" -type d -name bin | head -n1)"

  rm -rf "$dest"
  mkdir -p "$dest"
  if [[ "$platform" == windows-* ]]; then
    cp "$bin_dir/ffmpeg.exe" "$bin_dir/ffprobe.exe" "$dest/"
  else
    cp "$bin_dir/ffmpeg" "$bin_dir/ffprobe" "$dest/"
    chmod +x "$dest/ffmpeg" "$dest/ffprobe"
  fi
  local lic
  lic="$(find "$WORK/x-$platform" -maxdepth 2 -name 'LICENSE*' | head -n1 || true)"
  [[ -n "$lic" ]] && cp "$lic" "$dest/LICENSE.txt"

  {
    echo "source=https://github.com/BtbN/FFmpeg-Builds"
    echo "release_tag=${TAG}"
    echo "asset=${asset}"
    echo "sha256=${expected}"
    echo "fetched=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  } > "$dest/VERSION"

  if [[ "$platform" == linux-* && "$(uname -s)" == "Linux" ]]; then
    "$dest/ffmpeg" -hide_banner -version | head -n1
    "$dest/ffprobe" -hide_banner -version | head -n1
    echo "ffmpeg -version: $("$dest/ffmpeg" -hide_banner -version | head -n1)" >> "$dest/VERSION"
  fi
  echo "Installed into ${dest}"
}

case "$TARGET" in
  linux-x64)   fetch linux-x64   "ffmpeg-n${BRANCH}-latest-linux64-gpl-${BRANCH}.tar.xz" tar ;;
  windows-x64) fetch windows-x64 "ffmpeg-n${BRANCH}-latest-win64-gpl-${BRANCH}.zip" zip ;;
  all)
    fetch linux-x64   "ffmpeg-n${BRANCH}-latest-linux64-gpl-${BRANCH}.tar.xz" tar
    fetch windows-x64 "ffmpeg-n${BRANCH}-latest-win64-gpl-${BRANCH}.zip" zip
    ;;
  *) echo "Unknown target: ${TARGET} (linux-x64 | windows-x64 | all)" >&2; exit 2 ;;
esac

#!/usr/bin/env bash
# Bijou's desktop entry and icons in ~/.local/share (linux/packaging), so
# that the dock, the app grid and notifications show its name and icon for
# the build in build/linux/x64/<mode>/bundle (release by default). Phase
# 10's AppImage carries the same files. The icons are made by
# tools/brand/make_icons.py.
#
#   tools/install_desktop_entry.sh [release|profile|debug]
#   tools/install_desktop_entry.sh --remove
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
id=io.github.yasiralobaidi.iptvplayer
data="${XDG_DATA_HOME:-$HOME/.local/share}"
entry="$data/applications/$id.desktop"

if [[ "${1:-}" == "--remove" ]]; then
  rm -f "$entry"
  find "$data/icons/hicolor" -name "$id.*" -delete 2>/dev/null || true
  echo "Removed $entry and its icons."
  exit 0
fi

mode="${1:-release}"
binary="$root/build/linux/x64/$mode/bundle/iptv_player"
if [[ ! -x "$binary" ]]; then
  echo "No $mode build at $binary: run 'flutter build linux --$mode' first." >&2
  exit 1
fi

mkdir -p "$data/applications"
sed "s|^Exec=.*|Exec=\"$binary\"|" \
  "$root/linux/packaging/$id.desktop" > "$entry"
(cd "$root/linux/packaging/icons" && find hicolor -type f) | while read -r icon; do
  mkdir -p "$data/icons/$(dirname "$icon")"
  cp "$root/linux/packaging/icons/$icon" "$data/icons/$icon"
done
gtk-update-icon-cache -q -t "$data/icons/hicolor" 2>/dev/null || true
update-desktop-database -q "$data/applications" 2>/dev/null || true
echo "Installed $entry for $binary."

#!/usr/bin/env bash
# Installs Bijou on this Linux PC from `main` (the stable branch, ADR-034)
# or any other commit or tag: built as a release in its own worktree, so
# the checkout you work in (dev) is left as it is, then copied to
# ~/.local/share/bijou/app with the app grid's entry and icons (the cover,
# ADR-041). Run it again to update; the last build's worktree is kept in
# ~/.cache/bijou/stable-src, so later builds are quicker.
#
#   tools/install_stable_linux.sh              # main
#   tools/install_stable_linux.sh stable-287   # a tag, a branch or a commit
#   tools/install_stable_linux.sh --remove     # the app, its entry and icons
#
# Your data (sources, favorites, history) is not touched either way: it is
# in ~/.local/share/io.github.yasiralobaidi.iptvplayer, shared with any
# build run from the checkout.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
data="${XDG_DATA_HOME:-$HOME/.local/share}"
app="$data/bijou/app"
src="${XDG_CACHE_HOME:-$HOME/.cache}/bijou/stable-src"

if [[ "${1:-}" == "--remove" ]]; then
  "$root/tools/install_desktop_entry.sh" --remove
  rm -rf "$data/bijou"
  if git -C "$root" worktree list --porcelain | grep -qx "worktree $src"; then
    git -C "$root" worktree remove --force "$src"
  fi
  echo "Removed Bijou from $data/bijou."
  exit 0
fi

ref="${1:-main}"
commit="$(git -C "$root" rev-parse --verify --quiet "$ref^{commit}")" || {
  echo "No commit named '$ref' in $root." >&2
  exit 1
}
flutter="$(command -v flutter || echo "$HOME/develop/flutter/bin/flutter")"
if [[ ! -x "$flutter" ]]; then
  echo "Flutter not found: put it on PATH (docs/setup.md)." >&2
  exit 1
fi

# The worktree, at the commit asked for.
if git -C "$root" worktree list --porcelain | grep -qx "worktree $src"; then
  git -C "$src" checkout --quiet --detach --force "$commit"
  git -C "$src" clean -fdq -e build -e .dart_tool
else
  rm -rf "$src"
  mkdir -p "$(dirname "$src")"
  git -C "$root" worktree add --quiet --detach "$src" "$commit"
fi
# What git doesn't keep: the bundled FFmpeg (casting) and its libva.
for kept in ffmpeg libva; do
  if [[ -d "$root/third_party/$kept" && ! -e "$src/third_party/$kept" ]]; then
    ln -s "$root/third_party/$kept" "$src/third_party/$kept"
  fi
done
if [[ ! -x "$root/third_party/ffmpeg/linux-x64/ffmpeg" ]]; then
  echo "No FFmpeg in third_party/: this build can't cast (tools/fetch_ffmpeg.sh)." >&2
fi

echo "Building $(git -C "$src" log -1 --format='%h %s') …"
(
  cd "$src"
  "$flutter" pub get >/dev/null
  "$flutter" build linux --release
)

# The new bundle in place of the old one, in one move.
mkdir -p "$data/bijou"
rm -rf "$app.new" "$app.old"
cp -a "$src/build/linux/x64/release/bundle" "$app.new"
[[ -d "$app" ]] && mv "$app" "$app.old"
mv "$app.new" "$app"
rm -rf "$app.old"
git -C "$src" log -1 --format='%H %s' > "$app/COMMIT"

BIJOU_BINARY="$app/iptv_player" "$root/tools/install_desktop_entry.sh"
echo "Bijou ($(cut -c1-7 "$app/COMMIT")) is in your app grid. Open it from there."

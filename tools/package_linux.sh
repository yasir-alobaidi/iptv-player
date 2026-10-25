#!/usr/bin/env bash
# Packs the Linux release bundle as the tarball tools/install_linux.sh
# installs (the release workflow's Linux job; docs/install.md):
#
#   bijou/app/        the bundle (build/linux/x64/release/bundle) and COMMIT
#   bijou/packaging/  the desktop entry and the icons (linux/packaging)
#   bijou/TARGET      the system it was built on: ubuntu22.04 or ubuntu24.04
#
#   tools/package_linux.sh <out.tar.gz> [bundle]
#
# One build can't serve both Ubuntus: media_kit links the system's libmpv,
# libmpv.so.1 on 22.04 and libmpv.so.2 on 24.04 (and 24.04's build needs
# its glibc). It refuses a bundle without the bundled FFmpeg (a release
# casts) and prints what the bundle needs from the system, so the packages
# install_linux.sh installs can be checked against it.
# Env: BIJOU_TARGET overrides TARGET (default: ubuntu<VERSION_ID>).
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
out="${1:?usage: tools/package_linux.sh <out.tar.gz> [bundle]}"
bundle="${2:-$root/build/linux/x64/release/bundle}"
id=io.github.yasiralobaidi.iptvplayer

if [[ ! -x "$bundle/iptv_player" ]]; then
  echo "No release bundle at $bundle: run 'flutter build linux --release' first." >&2
  exit 1
fi
if [[ ! -x "$bundle/ffmpeg/ffmpeg" || ! -x "$bundle/ffmpeg/ffprobe" ]]; then
  echo "The bundle has no FFmpeg, so it couldn't cast: run tools/fetch_ffmpeg.sh and build again." >&2
  exit 1
fi
if [[ ! -f "$bundle/ffmpeg/libva/libva.so.2" ]]; then
  echo "warning: no bundled libva (tools/fetch_libva.sh): VA-API casting needs the system's to be 2.21 or newer." >&2
fi

target="${BIJOU_TARGET:-}"
if [[ -z "$target" ]]; then
  # shellcheck disable=SC1091
  target="$(. /etc/os-release && echo "${ID:-linux}${VERSION_ID:-}")"
fi

# Staged beside the output, hard-linked where the file system allows (the
# bundle is 360 MB, most of it FFmpeg).
mkdir -p "$(dirname "$out")"
out_dir="$(cd "$(dirname "$out")" && pwd)"
out="$out_dir/$(basename "$out")"
stage="$(mktemp -d "$out_dir/.bijou-package.XXXXXX")"
trap 'rm -rf "$stage"' EXIT
mkdir -p "$stage/bijou/packaging"
cp -al "$bundle" "$stage/bijou/app" 2>/dev/null || {
  rm -rf "$stage/bijou/app"
  cp -a "$bundle" "$stage/bijou/app"
}
rm -f "$stage/bijou/app/COMMIT"
git -C "$root" log -1 --format='%H %s' > "$stage/bijou/app/COMMIT"
cp "$root/linux/packaging/$id.desktop" "$stage/bijou/packaging/"
cp -r "$root/linux/packaging/icons" "$stage/bijou/packaging/"
echo "$target" > "$stage/bijou/TARGET"

tar -C "$stage" --owner=0 --group=0 --numeric-owner -czf "$out.tmp" bijou
mv "$out.tmp" "$out"

# What the bundle needs from the system: the release log shows it, and the
# packages install_linux.sh installs (docs/install.md) are checked by it.
report="$stage/ldd.txt"
{
  echo "== ldd iptv_player"
  ldd "$bundle/iptv_player"
  for lib in "$bundle"/lib/*.so; do
    echo "== ldd lib/$(basename "$lib")"
    LD_LIBRARY_PATH="$bundle/lib" ldd "$lib" || true
  done
} > "$report"
cat "$report"
# What the bundle itself names (readelf), the system's part of it: the
# packages these come from must be installed; apt brings the rest.
echo "== What the bundle links from the system, and the packages it comes from"
for file in "$bundle/iptv_player" "$bundle"/lib/*.so; do
  readelf -d "$file" | sed -n 's/.*(NEEDED).*\[\(.*\)\]/\1/p'
done | sort -u | while read -r soname; do
  [[ -e "$bundle/lib/$soname" ]] && continue
  # `name => /path (…)`, or the loader's own `/path (…)`.
  path="$(awk -v n="$soname" '
    $1 == n && $2 == "=>" {print $3; exit}
    substr($1, length($1) - length(n)) == "/" n {print $1; exit}' "$report")"
  owner=""
  if [[ "$path" == /* ]]; then
    # By name: dpkg knows /lib/… where a merged /usr resolves to /usr/lib/….
    owner="$(dpkg -S "*/x86_64-linux-gnu/$(basename "$(readlink -f "$path")")" 2>/dev/null |
      awk -F: 'NR == 1 {print $1}' || true)"
  fi
  printf '%-28s %s\n' "$soname" "${owner:-${path:-not found}}"
done
missing="$(awk '/not found/ {print $1}' "$report" | sort -u | tr '\n' ' ')"
if [[ -n "$missing" ]]; then
  echo "::warning::Not found on the build machine: $missing"
fi

echo "Packed $out ($(du -h "$out" | cut -f1), target $target, $(cut -c1-7 "$stage/bijou/app/COMMIT"))."

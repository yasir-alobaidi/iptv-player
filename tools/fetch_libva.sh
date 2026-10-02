#!/usr/bin/env bash
# Builds libva (the VA-API loader) for the bundled FFmpeg into third_party/libva/linux-x64/.
#
# Why: the bundled FFmpeg (BtbN) calls vaMapBuffer2, which only libva 2.21 and newer have.
# Ubuntu 22.04 ships 2.14 and 24.04 ships 2.20, so with the system's libva every VA-API
# encode aborts (ADR-014, Phase 7 step 4). The app runs FFmpeg with this libva first and falls
# back to the system's, so a system newer than this one still works. The Intel and AMD drivers
# themselves stay the system's.
#
# Built in a throwaway Ubuntu 22.04 container (glibc 2.35, the oldest system the app supports),
# so it needs docker or podman. Nothing is installed on this computer.
#
# Usage: tools/fetch_libva.sh
# Env:   LIBVA_VERSION   default 2.22.0
#        LIBVA_SHA256    the source tarball's checksum (known for the default version)
set -euo pipefail

VERSION="${LIBVA_VERSION:-2.22.0}"
if [[ "$VERSION" == "2.22.0" ]]; then
  SHA256="${LIBVA_SHA256:-467c418c2640a178c6baad5be2e00d569842123763b80507721ab87eb7af8735}"
else
  SHA256="${LIBVA_SHA256:?set LIBVA_SHA256 for libva ${VERSION}}"
fi
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="${REPO_ROOT}/third_party/libva/linux-x64"
URL="https://github.com/intel/libva/archive/refs/tags/${VERSION}.tar.gz"
# Where Debian/Ubuntu, Fedora/openSUSE and Arch keep the drivers; LIBVA_DRIVERS_PATH still wins.
DRIVER_DIRS="/usr/lib/x86_64-linux-gnu/dri:/usr/lib64/dri:/usr/lib/dri:/usr/local/lib/dri"

ENGINE="$(command -v docker || command -v podman || true)"
if [[ -z "$ENGINE" ]]; then
  echo "Needs docker or podman to build libva in a container." >&2
  exit 2
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "Building libva ${VERSION} in ubuntu:22.04…"
"$ENGINE" run --rm -v "$WORK:/out" ubuntu:22.04 bash -euo pipefail -c "
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq >/dev/null
  apt-get install -y -qq --no-install-recommends \
    meson ninja-build pkg-config libdrm-dev gcc libc6-dev curl ca-certificates >/dev/null
  cd /tmp
  curl -fsSL --retry 3 -o libva.tar.gz '${URL}'
  echo '${SHA256}  libva.tar.gz' | sha256sum -c --quiet -
  tar -xzf libva.tar.gz
  cd libva-${VERSION}
  meson setup build --buildtype=release \
    -Ddriverdir='${DRIVER_DIRS}' \
    -Dwith_x11=no -Dwith_glx=no -Dwith_wayland=no >/dev/null
  ninja -C build >/dev/null
  strip --strip-unneeded build/va/libva.so.2.*.0 build/va/libva-drm.so.2.*.0
  cp build/va/libva.so.2.*.0 /out/libva.so.2
  cp build/va/libva-drm.so.2.*.0 /out/libva-drm.so.2
  cp COPYING /out/COPYING
  chown -R $(id -u):$(id -g) /out
"

rm -rf "$DEST"
mkdir -p "$DEST"
cp "$WORK/libva.so.2" "$WORK/libva-drm.so.2" "$WORK/COPYING" "$DEST/"
{
  echo "source=${URL}"
  echo "source_sha256=${SHA256}"
  echo "built_on=ubuntu:22.04"
  echo "driverdir=${DRIVER_DIRS}"
  echo "built=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
} > "$DEST/VERSION"
echo "Installed into ${DEST}"

FFMPEG="${REPO_ROOT}/third_party/ffmpeg/linux-x64/ffmpeg"
if [[ -x "$FFMPEG" ]]; then
  # A VA-API encode on each render node (none shows anywhere); a node without VA-API just fails.
  for node in /dev/dri/renderD*; do
    [[ -e "$node" ]] || continue
    if LD_LIBRARY_PATH="$DEST" "$FFMPEG" -hide_banner -loglevel error -nostdin \
        -init_hw_device "vaapi=va:${node}" -filter_hw_device va \
        -f lavfi -t 1 -i testsrc2=size=1280x720:rate=25 \
        -vf format=nv12,hwupload -c:v h264_vaapi -f null - 2>/dev/null; then
      echo "VA-API encodes on ${node} with this libva"
    else
      echo "No VA-API encode on ${node}"
    fi
  done
fi

#!/usr/bin/env bash
# Build and run Spike A for one combination; results go to results/<label>.{jsonl,log}.
# Usage: run_matrix.sh <pub|git|patched> <intel|nvidia> [wayland|x11] [spike args, default: --auto all]
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../.." && pwd)
variant=${1:?pub|git|patched}
gpu=${2:?intel|nvidia}
backend=${3:-wayland}
shift $(( $# >= 3 ? 3 : 2 ))
[[ $# -eq 0 ]] && set -- --auto all
export PATH="$HOME/develop/flutter/bin:$PATH"
cd "$here"

case $variant in
  pub) rm -f pubspec_overrides.yaml ;;
  git) cp git_overrides.yaml pubspec_overrides.yaml ;;
  patched)
    vendor="$here/../vendor"
    rm -rf "$vendor/media_kit_video"
    cp -r "${PUB_CACHE:-$HOME/.pub-cache}/hosted/pub.dev/media_kit_video-2.0.1" "$vendor/media_kit_video"
    chmod -R u+w "$vendor/media_kit_video"
    (cd "$vendor" && patch -p1 -s < media_kit_video_egl_display.patch)
    cp patched_overrides.yaml pubspec_overrides.yaml ;;
  *) echo "variant must be pub, git, or patched" >&2; exit 2 ;;
esac
# Switching media_kit sources changes the native plugin code: rebuild from clean.
if [[ "$(cat build/.variant 2>/dev/null)" != "$variant" ]]; then flutter clean >/dev/null; fi
flutter pub get >/dev/null
flutter build linux --release
echo "$variant" > build/.variant

env_args=()
case $gpu in
  intel) env_args+=(DRI_PRIME=0) ;;
  nvidia) env_args+=(__NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia
                     __EGL_VENDOR_LIBRARY_FILENAMES=/usr/share/glvnd/egl_vendor.d/10_nvidia.json) ;;
  *) echo "gpu must be intel or nvidia" >&2; exit 2 ;;
esac
case $backend in
  wayland|x11) env_args+=(GDK_BACKEND=$backend) ;;
  *) echo "backend must be wayland or x11" >&2; exit 2 ;;
esac

label="${variant}_${gpu}_${backend}"
mkdir -p results
rm -f "results/$label.jsonl"
if [[ $gpu == nvidia ]] && command -v nvidia-smi >/dev/null; then
  (sleep 25; nvidia-smi > "results/$label.nvidia-smi.txt" 2>&1) &
fi
env "${env_args[@]}" build/linux/x64/release/bundle/playback_spike \
  --repo "$repo" --label "$label" --out "$here/results/$label.jsonl" "$@" 2>&1 | tee "results/$label.log"

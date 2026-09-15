#!/usr/bin/env bash
# Grab one frame of the playback_spike window to check the video is visible, not black.
# Works only for GDK_BACKEND=x11 runs (the window must exist in XWayland's tree).
# Usage: grab_frame.sh <out.png> [delay_s after the window appears, default 30]
set -euo pipefail
out=${1:?out.png}
delay=${2:-30}
here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../.." && pwd)

id=""
for _ in $(seq 120); do
  id=$(xwininfo -root -tree 2>/dev/null | awk '/"playback_spike"/ {print $1; exit}')
  [[ -n $id ]] && break
  sleep 1
done
[[ -n $id ]] || { echo "playback_spike window not found" >&2; exit 1; }
sleep "$delay"
"$repo/third_party/ffmpeg/linux-x64/ffmpeg" -hide_banner -loglevel error -y \
  -f x11grab -window_id "$id" -i "${DISPLAY:-:0}" -frames:v 1 "$out"
echo "grabbed window $id -> $out"

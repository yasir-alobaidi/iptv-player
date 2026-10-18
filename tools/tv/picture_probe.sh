#!/usr/bin/env bash
# What the TV is doing with the picture, read over adb while something plays
# (docs/plans/tv-video-layer-and-frame-rate.md, step 8):
#   - the display's mode (resolution, refresh rate) and HDR state;
#   - the hardware composer's layers: each one's composition (DEVICE is the
#     composer's own plane, CLIENT the GPU) and its dataspace (BT2020_PQ /
#     BT2020_HLG for HDR) and buffer size;
#   - how many frames a second each of the app's surfaces drew: Flutter's
#     about the film's rate on the texture, about 0 on the picture's own layer
#     while the OSD hides (where the picture's surface draws the film's rate);
#   - CPU: the app's busiest threads, SurfaceFlinger, the codec service.
#
# Usage: tools/tv/picture_probe.sh <adb serial> [package] [seconds]
#   package  io.github.yasiralobaidi.bijou.beta (default) or …bijou
#   seconds  the CPU sample (default 5)
# Read-only: it sends no keys and changes nothing on the TV.
set -euo pipefail
serial=${1:?usage: $0 <adb serial> [package] [seconds]}
package=${2:-io.github.yasiralobaidi.bijou.beta}
seconds=${3:-5}
adb=${ADB:-$HOME/Android/Sdk/platform-tools/adb}
# adb shell reads stdin: the while loop below would lose its lines to it.
sh() { "$adb" -s "$serial" shell "$@" </dev/null; }

pid=$(sh pidof "$package" | tr -d '\r' || true)
echo "== $package (pid ${pid:-none}) at $(date +%T)"

echo "== Display"
sh dumpsys display | grep -E "mActiveSfDisplayMode|mActiveColorMode|mUserPreferredMode|isHdr|mHdrConversionMode|mMatchContentFrameRate" | sed 's/^ */  /' | head -8
sh dumpsys SurfaceFlinger | grep -E "^\s*(activeMode|Active mode|refresh-rate|hdrSdrRatio)" | sed 's/^ */  /' | head -4

echo "== Composer layers (name · composition · frame · crop)"
sh dumpsys SurfaceFlinger | awk '
  /HWC layers:/ { on = 1; next }
  on && /^-+$/ { next }
  on && /^ *$/ { on = 0 }
  on { print "  " $0 }
' | head -20

echo "== Layer dataspaces and buffers"
sh dumpsys SurfaceFlinger | grep -E "^\+ |^\* Layer|dataspace=|activeBuffer=" | grep -iE -A2 "SurfaceView|Flutter|bijou" | grep -E "Layer|dataspace|activeBuffer" | sed -E 's/^ */  /' | cut -c1-160 | head -16

echo "== Frames each of the app's surfaces drew in the last second of its history"
# Both the picture's layer and Flutter's are "SurfaceView[<package>/…]…(BLAST)";
# on the texture only Flutter's exists. Its rate is the film's on the texture
# and about 0 on the picture's own layer with the OSD hidden.
found=0
while IFS= read -r layer; do
  [[ -z $layer ]] && continue
  found=1
  sh dumpsys SurfaceFlinger --latency "'$layer'" | tr -d '\r' | awk -v name="$layer" '
    NR == 1 { next }
    $2 > 0 && $2 < 9e18 { t[n++] = $2 }
    END {
      c = 0
      if (n > 0) { last = t[n - 1]; for (i = 0; i < n; i++) if (last - t[i] <= 1e9) c++ }
      printf "  %3d  %s\n", c, name
    }'
done < <(sh dumpsys SurfaceFlinger --list | tr -d '\r' | grep -F "SurfaceView[$package/" || true)
[[ $found == 1 ]] || echo "  (no SurfaceView of $package)"

echo "== CPU over ${seconds} s (% of one core; the TV has four)"
sh top -b -d "$seconds" -n 2 -m 12 -o PID,%CPU,RES,NAME | awk 'f; /PID/ && ++n == 2 { f = 1 }' | head -12 | sed 's/^/  /'
if [[ -n $pid ]]; then
  echo "== $package's threads"
  sh top -H -b -d "$seconds" -n 2 -p "$pid" -o TID,%CPU,NAME | awk 'f; /TID/ && ++n == 2 { f = 1 }' | sort -k2 -rn | head -8 | sed 's/^/  /'
  echo "== Memory"
  sh dumpsys meminfo "$package" | grep -E "TOTAL PSS|TOTAL:" | head -2 | sed 's/^ */  /'
fi

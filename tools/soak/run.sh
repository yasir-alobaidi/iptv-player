#!/usr/bin/env bash
# The soak (docs/06): the whole app on the fake panel for N minutes — a
# live channel with a zap or a fault every 90 s, and every 20 minutes a
# cast to the fake TV, a download, and the Guide, Movies and Search —
# memory and CPU logged every minute.
#
# Usage: tools/soak/run.sh [minutes]      default 60 (a phase's exit);
#                                         480 before a release
# Env:   IPTV_PLAYER_VIDEO=0          no picture (a machine without a GPU)
#        IPTV_SOAK_ROUND_MINUTES=3    rounds closer together, for a trial
#                                     (under 26 minutes memory isn't judged)
#
# Run it on the real display for real CPU numbers: xvfb decodes in
# software. The window must stay open and the desktop unlocked. Only the
# fake panel and the fake TV are used: no provider, no real TV. It needs
# the media samples (tools/media_samples/generate.sh) and FFmpeg (bundled,
# else the system's).
# Writes build/soak/soak.csv (a row a minute) and build/soak/summary.txt.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."
MINUTES="${1:-60}"
IPTV_SOAK_MINUTES="$MINUTES" flutter test integration_test/soak_test.dart -d linux
echo
cat build/soak/summary.txt
echo "Per-minute log: build/soak/soak.csv"

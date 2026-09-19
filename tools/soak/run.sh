#!/usr/bin/env bash
# The soak (docs/06): live playback on the real player with random faults
# for N minutes, memory and CPU logged every minute.
#
# Usage: tools/soak/run.sh [minutes]      default 60 (the Phase 3 exit);
#                                         480 before a release
# Env:   IPTV_PLAYER_VIDEO=0   no picture (a machine without a GPU)
#
# Run it on the real display for real CPU numbers: xvfb decodes in
# software. It needs the media samples (tools/media_samples/generate.sh).
# Writes build/soak/soak.csv (a row a minute) and build/soak/summary.txt.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."
MINUTES="${1:-60}"
IPTV_SOAK_MINUTES="$MINUTES" flutter test integration_test/soak_test.dart -d linux
echo
cat build/soak/summary.txt
echo "Per-minute log: build/soak/soak.csv"

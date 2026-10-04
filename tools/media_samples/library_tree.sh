#!/usr/bin/env bash
# Builds a fake video library for the scanner's tests and its budget
# (docs/06-quality.md → Media samples; docs/09 → Local library).
# Fictional names only; the clips are lavfi test patterns and tones.
#
# Usage: tools/media_samples/library_tree.sh <dir> <count>
#   dir    where the tree goes (made; must be empty or missing)
#   count  how many videos the scanner should list; the junk it must skip
#          comes on top
# Env:   FFMPEG  ffmpeg binary (default: the bundled one, else ffmpeg on PATH)
#
# What it writes, in about the shares a real collection has:
#   - movies (40 %): "Movies/Title (Year)/Title (Year).mkv" with a poster
#     and subtitles now and then; release names ("Title.Year.1080p.BluRay.
#     x264-GRP.mkv"); bracketed tags; loose files in the root;
#   - episodes (50 %): "TV/Show/Season 01/Show.S01E03.Title.720p.WEB-DL.mkv",
#     "Show - 1x03 - Title.mp4", "Show/Season 2/03 - Title.mkv", and a
#     two-episode file per show ("S01E01E02"); forced subtitles;
#   - unsorted videos (10 %): home videos and camera files, a few with an
#     embedded title tag;
#   - junk the scanner skips: samples, trailers, featurettes, a hidden
#     folder, a .part file, a file under the size minimum, non-video files.
# Every video is a copy of one of two 2-second clips with its own number
# appended, so sizes and quick hashes (size + first and last 64 KB) differ.
# Video files are about 40 KB; tests lower the scanner's 20 MB minimum.
#
# `<dir>/.manifest.tsv` (hidden, so the scanner skips it) lists every file
# with what the scanner should make of it: path, kind (movie, episode,
# unsorted, skip), title, year, show, season, episode, last episode.
set -euo pipefail

if [[ $# -ne 2 || "$1" == -h || "$1" == --help ]]; then
  sed -n '2,29p' "$0"
  exit 2
fi
ROOT="$1"
COUNT="$2"
[[ "$COUNT" =~ ^[0-9]+$ && "$COUNT" -gt 0 ]] || { echo "count must be a positive number" >&2; exit 2; }
if [[ -e "$ROOT" && -n "$(ls -A "$ROOT" 2>/dev/null)" ]]; then
  echo "$ROOT is not empty" >&2
  exit 1
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
if [[ -z "${FFMPEG:-}" ]]; then
  FFMPEG="${REPO_ROOT}/third_party/ffmpeg/linux-x64/ffmpeg"
  [[ -x "$FFMPEG" ]] || FFMPEG="$(command -v ffmpeg || true)"
fi
[[ -n "$FFMPEG" && -x "$FFMPEG" ]] || { echo "no ffmpeg (set FFMPEG)" >&2; exit 1; }
ff() { "$FFMPEG" -hide_banner -loglevel error -nostdin -y "$@"; }

mkdir -p "$ROOT"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# The two clips and a poster, made once.
clip_args=(-f lavfi -i "testsrc2=size=160x90:rate=10:duration=2"
  -f lavfi -i "sine=frequency=330:sample_rate=48000:duration=2"
  -c:v libx264 -preset ultrafast -pix_fmt yuv420p -g 10
  -c:a aac -b:a 32k -shortest)
ff "${clip_args[@]}" -movflags +faststart "$WORK/clip.mp4"
ff "${clip_args[@]}" "$WORK/clip.mkv"
ff -f lavfi -i "smptebars=size=60x90" -frames:v 1 "$WORK/poster.jpg"
printf '1\n00:00:00,500 --> 00:00:01,500\nA line of dialogue.\n' > "$WORK/subs.srt"

ADJ=(Copper Glass Ember Quiet Winter Northern Paper Salt Night Silver Iron
  Pale Amber Cedar Velvet Granite Scarlet Willow Saffron Cinder Juniper
  Marble Coral Falcon Meadow Bitter Driftwood Basalt Tundra Distant)
NOUN=(Harbor Tide Road Kites Ferry Flats Bus Ash Lake Quarry Hotel Pines
  Coast Ledger Orchard Bridge Lantern Garden River Signal Valley Station
  Canyon Archive Mill Crossing Beacon Hollow Summit Current)
EPISODE=("Low Water" "The Long Tide" "Undertow" "Dead Reckoning" "Slack Water"
  "Breakwater" "The Ledger" "High Ground" "Spring Tide" "Fog Bank"
  "Landfall" "The Crossing")
PLACES=(lake garden beach station market harbor park mountains)

MANIFEST="$ROOT/.manifest.tsv"
printf 'path\tkind\ttitle\tyear\tshow\tseason\tepisode\tepisode_end\n' > "$MANIFEST"
n=0

# copy <relative path> <clip ext>: a clip with its own number appended.
put() {
  local path="$ROOT/$1"
  mkdir -p "$(dirname "$path")"
  cp "$WORK/clip.$2" "$path"
  printf 'IPTVPLAYER-FAKE-%08d\n' "$n" >> "$path"
  n=$((n + 1))
}
row() { printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$@" >> "$MANIFEST"; }

# name <i>: a fictional two-word title, unique for the first 900.
name() {
  local i=$1 a=${#ADJ[@]} b=${#NOUN[@]}
  local t="${ADJ[$((i % a))]} ${NOUN[$(((i / a + i) % b))]}"
  local round=$((i / (a * b)))
  [[ $round -gt 0 ]] && t="$t $((round + 1))"
  echo "$t"
}
dots() { echo "${1// /.}"; }

movies=$((COUNT * 40 / 100))
unsorted=$((COUNT * 10 / 100))
episodes=$((COUNT - movies - unsorted))

for ((i = 0; i < movies; i++)); do
  title="$(name "$i")"
  year=$((1975 + (i * 7) % 50))
  case $((i % 4)) in
    0)
      dir="Movies/$title ($year)"
      put "$dir/$title ($year).mkv" mkv
      row "$dir/$title ($year).mkv" movie "$title" "$year" "" "" "" ""
      if ((i % 8 == 0)); then
        cp "$WORK/poster.jpg" "$ROOT/$dir/poster.jpg"
        cp "$WORK/subs.srt" "$ROOT/$dir/$title ($year).en.srt"
      fi
      ;;
    1)
      file="Movies/$(dots "$title").$year.1080p.BluRay.x264-GRP.mkv"
      put "$file" mkv
      row "$file" movie "$title" "$year" "" "" "" ""
      ;;
    2)
      file="Movies/$title ($year) [2160p] [UHD] x265.mkv"
      put "$file" mkv
      row "$file" movie "$title" "$year" "" "" "" ""
      ;;
    3)
      file="$(dots "$title").$year.WEBRip.mp4"
      put "$file" mp4
      row "$file" movie "$title" "$year" "" "" "" ""
      ;;
  esac
done

# Shows of up to 3 seasons × 8 episodes, filled in order.
made=0
show_index=0
while ((made < episodes)); do
  show="The $(name $((show_index + 500)))"
  style=$((show_index % 3))
  for ((season = 1; season <= 3 && made < episodes; season++)); do
    for ((episode = 1; episode <= 8 && made < episodes; episode++)); do
      ep_title="${EPISODE[$(((show_index + season * 8 + episode) % ${#EPISODE[@]}))]}"
      s2=$(printf '%02d' "$season")
      e2=$(printf '%02d' "$episode")
      case $style in
        0)
          if ((season == 1 && episode == 1 && made + 1 < episodes)); then
            # Two episodes in one file; episode 2 is in it.
            file="TV/$show/Season $s2/$(dots "$show").S${s2}E01E02.720p.WEB-DL.x264-GRP.mkv"
            put "$file" mkv
            row "$file" episode "" "" "$show" "$season" 1 2
            made=$((made + 1))
            episode=2
            continue
          fi
          file="TV/$show/Season $s2/$(dots "$show").S${s2}E${e2}.$(dots "$ep_title").720p.WEB-DL.x264-GRP.mkv"
          put "$file" mkv
          row "$file" episode "$ep_title" "" "$show" "$season" "$episode" ""
          if ((episode == 3)); then
            cp "$WORK/subs.srt" "$ROOT/${file%.mkv}.eng.forced.srt"
          fi
          ;;
        1)
          file="TV/$show/$show - ${season}x$e2 - $ep_title.mp4"
          put "$file" mp4
          row "$file" episode "$ep_title" "" "$show" "$season" "$episode" ""
          ;;
        2)
          file="TV/$show/Season $season/$e2 - $ep_title.mkv"
          put "$file" mkv
          row "$file" episode "$ep_title" "" "$show" "$season" "$episode" ""
          ;;
      esac
      made=$((made + 1))
    done
  done
  show_index=$((show_index + 1))
done

for ((i = 0; i < unsorted; i++)); do
  if ((i % 2 == 0)); then
    place="${PLACES[$((i % ${#PLACES[@]}))]}"
    word="$(name $((i + 700)))"
    file="Home videos/${word%% *} at the $place $((2010 + i % 15)) $i.mp4"
  else
    file="Camera/VID_$((20200101 + i % 28))_$(printf '%06d' "$i").mp4"
  fi
  if ((i % 25 == 0)); then
    # An embedded title tag (docs/09: titles come from names and tags).
    mkdir -p "$(dirname "$ROOT/$file")"
    ff -i "$WORK/clip.mp4" -c copy -metadata title="Tagged video $i" \
      -metadata comment="IPTVPLAYER-FAKE-$n" "$ROOT/$file"
    n=$((n + 1))
  else
    put "$file" mp4
  fi
  row "$file" unsorted "" "" "" "" "" ""
done

# The junk: one of each per 50 videos, at least one.
junk=$(((COUNT + 49) / 50))
for ((i = 0; i < junk; i++)); do
  title="$(name $((i + 800)))"
  for file in \
    "Movies/$title (2020)/Sample/$(dots "$title").2020.1080p-sample.mkv" \
    "Movies/$title (2020)/$title - Featurette.mkv" \
    ".hidden/$title.mkv" \
    "Movies/$title (2021).mkv.part"; do
    put "$file" mkv
    row "$file" skip "" "" "" "" "" ""
  done
  put "Movies/$title (2020)/$title trailer.mp4" mp4
  row "Movies/$title (2020)/$title trailer.mp4" skip "" "" "" "" "" ""
  tiny="Movies/$title tiny.mkv"
  head -c 1024 "$WORK/clip.mkv" > "$ROOT/$tiny"
  row "$tiny" skip "" "" "" "" "" ""
  printf 'notes\n' > "$ROOT/Movies/$title (2020)/movie.nfo"
done

echo "wrote $COUNT videos and $((junk * 6)) to skip under $ROOT ($(du -sh "$ROOT" | cut -f1))"

#!/usr/bin/env bash
# Generates synthetic test media (docs/06-quality.md → Media samples).
# Sources are lavfi test patterns and tones only (testsrc2, smptehdbars, sine) — no copyrighted content.
#
# Usage: tools/media_samples/generate.sh [--force] [--picture] [name ...]
#   name   one or more sample names without extension (default: all but the picture tests)
#   --force  regenerate files that already exist
#   --picture  also make the picture tests (23.976/24 fps films, HDR10, HLG; slow, for the TV)
# Env:   FFMPEG   ffmpeg binary (default: third_party/ffmpeg/linux-x64/ffmpeg, from tools/fetch_ffmpeg.sh)
#        OUT_DIR  output directory (default: tools/media_samples/out, gitignored)
#        LIVE_SECONDS  length of live samples, 30–120 (default 60; 4K HEVC uses 30)
#        VOD_SECONDS   length of VOD samples (default 600)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FFMPEG="${FFMPEG:-${REPO_ROOT}/third_party/ffmpeg/linux-x64/ffmpeg}"
OUT_DIR="${OUT_DIR:-${REPO_ROOT}/tools/media_samples/out}"
LIVE_SECONDS="${LIVE_SECONDS:-60}"
VOD_SECONDS="${VOD_SECONDS:-600}"
FORCE=0
PICTURE=0

ARGS=()
for a in "$@"; do
  case "$a" in
    --force) FORCE=1 ;;
    --picture) PICTURE=1 ;;
    -h|--help) sed -n '2,14p' "$0"; exit 0 ;;
    *) ARGS+=("$a") ;;
  esac
done

if [[ ! -x "$FFMPEG" ]]; then
  echo "ffmpeg not found at $FFMPEG — run tools/fetch_ffmpeg.sh first (or set FFMPEG)" >&2
  exit 1
fi
mkdir -p "$OUT_DIR"

ff() { "$FFMPEG" -hide_banner -loglevel error -nostdin -y "$@"; }

# Video test pattern at size/rate. $3 picks the pattern so zapping between samples is visible.
video_src() { echo "-f lavfi -i ${3:-testsrc2}=size=$1:rate=$2"; }
# Tone; frequency differs per sample so audio switches are audible.
audio_src() { echo "-f lavfi -i sine=frequency=$1:sample_rate=48000"; }

# Common H.264 settings that look like IPTV: 2 s GOP, capped bitrate, yuv420p.
h264() { echo "-c:v libx264 -preset veryfast -profile:v high -pix_fmt yuv420p -g $1 -keyint_min $1 -sc_threshold 0 -b:v $2 -maxrate $2 -bufsize $3"; }
hevc() { echo "-c:v libx265 -preset ultrafast -pix_fmt yuv420p -tag:v hvc1 -x265-params log-level=error:keyint=$1:min-keyint=$1:scenecut=0 -b:v $2 -maxrate $2 -bufsize $3"; }

ts_out() { echo "-f mpegts -mpegts_flags +resend_headers -metadata service_name=$1 -metadata service_provider=FakeIPTV"; }

# $3 = picture: only when named, or with --picture.
want() {
  local name="$1" file="$2"
  if [[ ${#ARGS[@]} -eq 0 && "${3:-}" == picture && $PICTURE -eq 0 ]]; then
    return 1
  fi
  if [[ ${#ARGS[@]} -gt 0 ]]; then
    local hit=0
    for a in "${ARGS[@]}"; do [[ "$a" == "$name" ]] && hit=1; done
    [[ $hit -eq 1 ]] || return 1
  fi
  if [[ -f "$OUT_DIR/$file" && $FORCE -eq 0 ]]; then
    echo "skip  $file (exists)"
    return 1
  fi
  echo "make  $file"
  return 0
}

write_srt() {
  local path="$1" seconds="$2" lang_label="$3" i=0 t=0
  : > "$path"
  while (( t + 4 <= seconds )); do
    i=$((i + 1))
    printf '%d\n%02d:%02d:%02d,000 --> %02d:%02d:%02d,000\n%s subtitle %d at %d s\n\n' \
      "$i" $((t/3600)) $((t%3600/60)) $((t%60)) $(((t+4)/3600)) $(((t+4)%3600/60)) $(((t+4)%60)) \
      "$lang_label" "$i" "$t" >> "$path"
    t=$((t + 10))
  done
}

L="$LIVE_SECONDS"
V="$VOD_SECONDS"

# ---------- Live samples (MPEG-TS, looped by the fake provider) ----------

if want h264_1080p50_aac h264_1080p50_aac.ts; then
  # shellcheck disable=SC2046
  ff $(video_src 1920x1080 50) $(audio_src 440) -t "$L" \
    $(h264 100 6M 12M) -c:a aac -b:a 128k -ac 2 \
    $(ts_out h264_1080p50_aac) "$OUT_DIR/h264_1080p50_aac.ts"
fi

if want h264_1080p25_ac3 h264_1080p25_ac3.ts; then
  # shellcheck disable=SC2046
  ff $(video_src 1920x1080 25 smptehdbars) $(audio_src 523) -t "$L" \
    $(h264 50 5M 10M) -c:a ac3 -b:a 384k -ac 6 \
    $(ts_out h264_1080p25_ac3) "$OUT_DIR/h264_1080p25_ac3.ts"
fi

if want h264_1080i50_mp2 h264_1080i50_mp2.ts; then
  # 50 progressive frames/s woven into 25 interlaced frames/s (50 fields), top field first.
  # shellcheck disable=SC2046
  ff $(video_src 1920x1080 50) $(audio_src 587) -t "$L" \
    -vf "tinterlace=mode=interleave_top,setfield=tff" \
    $(h264 50 8M 16M) -flags +ildct+ilme -x264-params tff=1 -field_order tt \
    -c:a mp2 -b:a 192k -ac 2 \
    $(ts_out h264_1080i50_mp2) "$OUT_DIR/h264_1080i50_mp2.ts"
fi

if want hevc_2160p25_eac3 hevc_2160p25_eac3.ts; then
  # 4K HEVC is slow to encode on CPU, so this one is capped at 30 s.
  # shellcheck disable=SC2046
  ff $(video_src 3840x2160 25) $(audio_src 659) -t "$(( L < 30 ? L : 30 ))" \
    $(hevc 50 15M 30M) -c:a eac3 -b:a 448k -ac 6 \
    $(ts_out hevc_2160p25_eac3) "$OUT_DIR/hevc_2160p25_eac3.ts"
fi

if want hevc_1080p50_aac hevc_1080p50_aac.ts; then
  # shellcheck disable=SC2046
  ff $(video_src 1920x1080 50 smptehdbars) $(audio_src 698) -t "$L" \
    $(hevc 100 4M 8M) -c:a aac -b:a 128k -ac 2 \
    $(ts_out hevc_1080p50_aac) "$OUT_DIR/hevc_1080p50_aac.ts"
fi

if want mpeg2_576i25_mp2 mpeg2_576i25_mp2.ts; then
  # shellcheck disable=SC2046
  ff $(video_src 720x576 50) $(audio_src 784) -t "$L" \
    -vf "tinterlace=mode=interleave_top,setfield=tff,setdar=16/11" \
    -c:v mpeg2video -pix_fmt yuv420p -flags +ildct+ilme -top 1 -g 12 -b:v 4M -maxrate 4M -bufsize 1835k \
    -c:a mp2 -b:a 192k -ac 2 \
    $(ts_out mpeg2_576i25_mp2) "$OUT_DIR/mpeg2_576i25_mp2.ts"
fi

if want codec_switch_h264_720p_to_1080p codec_switch_h264_720p_to_1080p.ts; then
  # Half the stream at 720p50, then 1080p50 in the same TS (same PIDs) — like a provider changing encoders mid-stream.
  tmp="$(mktemp -d)"
  half=$(( L / 2 ))
  # shellcheck disable=SC2046
  ff $(video_src 1280x720 50 smptehdbars) $(audio_src 880) -t "$half" \
    $(h264 100 3M 6M) -c:a aac -b:a 128k -ac 2 $(ts_out codec_switch) "$tmp/a.ts"
  # shellcheck disable=SC2046
  ff $(video_src 1920x1080 50) $(audio_src 880) -t "$half" \
    $(h264 100 6M 12M) -c:a aac -b:a 128k -ac 2 -output_ts_offset "$half" $(ts_out codec_switch) "$tmp/b.ts"
  cat "$tmp/a.ts" "$tmp/b.ts" > "$OUT_DIR/codec_switch_h264_720p_to_1080p.ts"
  rm -rf "$tmp"
fi

# ---------- VOD samples ----------

if want vod_h264_aac_10min vod_h264_aac_10min.mp4; then
  # Plain MP4 with moov at the front: the direct-file casting path (docs/04, docs/09).
  # shellcheck disable=SC2046
  ff $(video_src 1920x1080 25) $(audio_src 440) -t "$V" \
    $(h264 50 2500k 5M) -c:a aac -b:a 128k -ac 2 \
    -metadata title="VOD H.264 AAC sample" -movflags +faststart \
    "$OUT_DIR/vod_h264_aac_10min.mp4"
fi

if want vod_hevc_eac3_subs vod_hevc_eac3_subs.mkv; then
  tmp="$(mktemp -d)"
  write_srt "$tmp/en.srt" "$V" "English"
  write_srt "$tmp/de.srt" "$V" "Deutsch"
  # shellcheck disable=SC2046
  ff $(video_src 1920x1080 25 smptehdbars) $(audio_src 523) -i "$tmp/en.srt" -i "$tmp/de.srt" -t "$V" \
    -map 0:v -map 1:a -map 2:s -map 3:s \
    $(hevc 50 2500k 5M) -c:a eac3 -b:a 384k -ac 6 -c:s srt \
    -metadata:s:a:0 language=eng -metadata:s:s:0 language=eng -metadata:s:s:1 language=ger \
    -metadata title="VOD HEVC E-AC-3 with subtitles" \
    "$OUT_DIR/vod_hevc_eac3_subs.mkv"
  rm -rf "$tmp"
fi

if want vod_h264_ac3_10min vod_h264_ac3_10min.mkv; then
  # shellcheck disable=SC2046
  ff $(video_src 1920x1080 25) $(audio_src 587) -t "$V" \
    $(h264 50 2500k 5M) -c:a ac3 -b:a 384k -ac 6 \
    -metadata:s:a:0 language=eng -metadata title="VOD H.264 AC-3 sample" \
    "$OUT_DIR/vod_h264_ac3_10min.mkv"
  # External subtitle beside the video (docs/09 external subtitles).
  write_srt "$OUT_DIR/vod_h264_ac3_10min.en.srt" "$V" "External English"
fi

# ---------- Picture tests (only when named, or with --picture) ----------
# Films for the TV's picture work (docs/plans/tv-video-layer-and-frame-rate.md):
# 23.976 and 24 fps to match the display's rate (16 min: Match frame rate
# leaves films under 15 min alone), HDR10 and HLG. A white bar crosses the
# picture at a steady speed: at 59.94 Hz its steps are uneven (3:2 judder),
# at a matched rate even.

# One HDR conversion of the SDR pattern: BT.709 → linear (SDR white at 100 nits) → BT.2020 → $1.
to_hdr() {
  echo "format=yuv444p,setparams=color_primaries=bt709:color_trc=bt709:colorspace=bt709:range=tv,zscale=t=linear:npl=100,format=gbrpf32le,zscale=p=bt2020,zscale=t=$1:m=bt2020nc:r=tv,format=yuv420p10le"
}
moving_bar() { echo "drawbox=x='mod(t*$1\,iw)':y=0:w=$2:h=ih:color=white@1:t=fill"; }

# A minute of 4K/HEVC is slow to encode (about 13 fps here), so the HDR films
# are one minute (1440 frames, 30 whole GOPs) looped to 16 by stream copy.
loop_to_16min() {
  local one="$1" out="$2"
  ff -stream_loop 15 -i "$one" -map 0 -c copy -t 960 "$out"
}

for rate in 2398 24; do
  name="vod_h264_1080p${rate}_16min"
  fps=$([[ $rate == 2398 ]] && echo 24000/1001 || echo 24)
  if want "$name" "$name.mp4" picture; then
    # shellcheck disable=SC2046
    ff $(video_src 1920x1080 "$fps") $(audio_src 440) -t 960 \
      -vf "$(moving_bar 480 16)" \
      $(h264 48 4M 8M) -c:a aac -b:a 128k -ac 2 \
      -metadata title="Picture test: 1080p at $fps fps" -movflags +faststart \
      "$OUT_DIR/$name.mp4"
  fi
done

if want vod_hevc_2160p2398_hdr10_16min vod_hevc_2160p2398_hdr10_16min.mkv picture; then
  tmp="$(mktemp -d)"
  # shellcheck disable=SC2046
  ff $(video_src 3840x2160 24000/1001) $(audio_src 523) -frames:v 1440 -t 60.06 \
    -vf "$(moving_bar 960 32),$(to_hdr smpte2084)" \
    -c:v libx265 -preset ultrafast -pix_fmt yuv420p10le -tag:v hvc1 \
    -x265-params "log-level=error:keyint=48:min-keyint=48:scenecut=0:colorprim=bt2020:transfer=smpte2084:colormatrix=bt2020nc:master-display=G(13250,34500)B(7500,3000)R(34000,16000)WP(15635,16450)L(10000000,1):max-cll=1000,400:hdr10=1:hdr10-opt=1:repeat-headers=1" \
    -b:v 12M -maxrate 12M -bufsize 24M \
    -color_primaries bt2020 -color_trc smpte2084 -colorspace bt2020nc \
    -c:a aac -b:a 128k -ac 2 -metadata title="Picture test: 4K HDR10 at 23.976 fps" \
    "$tmp/one.mkv"
  loop_to_16min "$tmp/one.mkv" "$OUT_DIR/vod_hevc_2160p2398_hdr10_16min.mkv"
  rm -rf "$tmp"
fi

if want vod_hevc_1080p2398_hlg_16min vod_hevc_1080p2398_hlg_16min.mkv picture; then
  tmp="$(mktemp -d)"
  # shellcheck disable=SC2046
  ff $(video_src 1920x1080 24000/1001 smptehdbars) $(audio_src 587) -frames:v 1440 -t 60.06 \
    -vf "$(moving_bar 480 16),$(to_hdr arib-std-b67)" \
    -c:v libx265 -preset ultrafast -pix_fmt yuv420p10le -tag:v hvc1 \
    -x265-params "log-level=error:keyint=48:min-keyint=48:scenecut=0:colorprim=bt2020:transfer=arib-std-b67:colormatrix=bt2020nc:repeat-headers=1" \
    -b:v 6M -maxrate 6M -bufsize 12M \
    -color_primaries bt2020 -color_trc arib-std-b67 -colorspace bt2020nc \
    -c:a aac -b:a 128k -ac 2 -metadata title="Picture test: 1080p HLG at 23.976 fps" \
    "$tmp/one.mkv"
  loop_to_16min "$tmp/one.mkv" "$OUT_DIR/vod_hevc_1080p2398_hlg_16min.mkv"
  rm -rf "$tmp"
fi

echo "Samples in $OUT_DIR:"
ls -lh "$OUT_DIR" | tail -n +2

#!/usr/bin/env bash
# Capture only: no install, save reset, launch, or input automation.
set -euo pipefail
MODE=${1:?Usage: capture-motion.sh android|desktop}
: "${OUT:?Set private capture output directory}"
SECONDS_TO_RECORD=${DURATION:-30}
[[ "$SECONDS_TO_RECORD" =~ ^[0-9]+$ ]] && (( SECONDS_TO_RECORD >= 1 && SECONDS_TO_RECORD <= 180 ))
mkdir -p "$OUT"
STAMP=$(date +%Y%m%d-%H%M%S)-$$
VIDEO="$OUT/$MODE-$STAMP.mp4"
case "$MODE" in
 android)
  : "${ADB:=adb}"
  : "${SERIAL:?Set explicitly authorized isolated emulator serial}"
  [[ "$SERIAL" =~ ^emulator-[0-9]+$ ]] || { echo 'Physical devices not authorized by this harness' >&2; exit 2; }
  "$ADB" -s "$SERIAL" get-state
  REMOTE="/sdcard/vc-motion-$STAMP.mp4"
  "$ADB" -s "$SERIAL" shell screenrecord --bit-rate 8000000 --time-limit "$SECONDS_TO_RECORD" "$REMOTE"
  "$ADB" -s "$SERIAL" pull "$REMOTE" "$VIDEO"
  "$ADB" -s "$SERIAL" shell rm "$REMOTE"
  "$ADB" -s "$SERIAL" logcat -d -t 2000 > "$OUT/android-$STAMP-logcat.txt"
  ;;
 desktop)
  : "${DISPLAY:?Desktop X11 display required}"
  : "${CAPTURE_SIZE:?Set game window size, e.g. 360x640}"
  : "${CAPTURE_OFFSET:?Set verified game-only X,Y offset, e.g. 100,100}"
  ffmpeg -nostdin -n -f x11grab -framerate 30 -video_size "$CAPTURE_SIZE" -i "$DISPLAY+$CAPTURE_OFFSET" -t "$SECONDS_TO_RECORD" -c:v libx264 -pix_fmt yuv420p "$VIDEO"
  ;;
 *) echo 'Expected android or desktop' >&2; exit 2;;
esac
ffprobe -v error -show_entries stream=codec_name,width,height,r_frame_rate,duration -show_entries format=duration -of json "$VIDEO" > "$VIDEO.json"
# Chronological sheets, sampled at 2 fps; video remains primary motion proof.
ffmpeg -nostdin -n -i "$VIDEO" -vf "fps=2,scale=180:-2,drawtext=text='%{pts\:hms}':x=4:y=4:fontsize=12:fontcolor=white:box=1:boxcolor=black@0.7,tile=6x5" -frames:v 12 "$OUT/$MODE-$STAMP-sheet-%02d.png"
sha256sum "$VIDEO" > "$VIDEO.sha256"
printf 'Captured %s; NOT visually reviewed. Record action timestamps and acceptance separately.\n' "$VIDEO"

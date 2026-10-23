#!/bin/bash
# Records the move flows with the real player, films the athlete replaying them, and
# makes one MP4 per flow.   tools/motion/film.sh <godot> <out_dir> [flows...]
GODOT=${1:-godot}
OUT=${2:-/tmp/motion}
shift 2
cd "$(dirname "$0")/../.."
mkdir -p "$OUT/rec"
"$GODOT" --headless --path . --script res://tools/motion/record.gd -- "$OUT/rec" "$@" 2>&1 | grep -E "^recorded"
xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --path . --rendering-driver opengl3 --resolution 1280x720 \
	--script res://tools/motion/film.gd -- "$OUT/rec" "$OUT" "$@" 2>&1 | grep -E "^filmed"
for d in "$OUT"/*/; do
	f=$(basename "$d")
	[ "$f" = "rec" ] && continue
	ffmpeg -y -loglevel error -framerate 30 -i "$d/%04d.png" -c:v libx264 -pix_fmt yuv420p -crf 20 "$OUT/$f.mp4" && echo "video $OUT/$f.mp4"
done

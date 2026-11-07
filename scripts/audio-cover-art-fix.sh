#!/bin/bash
set -euo pipefail

SCRIPT_PATH="${BASH_SOURCE[0]}"
while [ -L "$SCRIPT_PATH" ]; do
  SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
  SCRIPT_PATH="$(readlink "$SCRIPT_PATH")"
  [[ "$SCRIPT_PATH" != /* ]] && SCRIPT_PATH="$SCRIPT_DIR/$SCRIPT_PATH"
done
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"

echo "🎧 Navidrome - Add Cover Art"
echo ""

usage() {
  echo "Usage:"
  echo "audio-cover-art-fix <cover-image.jpg|cover-image.png> [file1.m4a file2.opus ...]"
  echo ""
  echo "If no audio files are provided, every .m4a or .opus file in the current folder is updated."
  echo "Existing embedded artwork is replaced. Audio is copied without re-encoding."
  echo "Requires ffmpeg; Opus artwork also requires ffprobe and python3."
}

fix_one_file() {
  local input="$1"
  local temp_output

  if [ ! -f "$input" ]; then
    echo "❌ File not found: $input"
    return 1
  fi

  if [[ ! "$input" =~ \.([mM]4[aA]|[oO][pP][uU][sS])$ ]]; then
    echo "⚠️ Skipping unsupported file: $input"
    return 0
  fi

  echo "Updating: ${input#./}"
  if [[ "$input" =~ \.[oO][pP][uU][sS]$ ]]; then
    python3 "$SCRIPT_DIR/lib/opus-metadata.py" "$input" --cover "$cover_image"
    return
  fi

  temp_output="$(dirname "$input")/.${input##*/}.cover.tmp.$$.m4a"

  ffmpeg \
    -hide_banner \
    -loglevel error \
    -y \
    -i "$input" \
    -i "$cover_image" \
    -map 0 \
    -map -0:v \
    -map 1:v:0 \
    -map_metadata 0 \
    -c copy \
    -c:v mjpeg \
    -disposition:v:0 attached_pic \
    "$temp_output"

  mv "$temp_output" "$input"
}

cleanup_temp_files() {
  rm -f .*.cover.tmp.$$.m4a 2>/dev/null || true
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
  exit 0
fi

if [ "$#" -lt 1 ]; then
  usage
  exit 1
fi

cover_image="$1"
shift

if [ ! -f "$cover_image" ]; then
  echo "❌ Cover image not found: $cover_image"
  exit 1
fi

if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "❌ ffmpeg is not installed or not available in PATH."
  exit 1
fi

trap cleanup_temp_files EXIT

case "$cover_image" in
  *.[jJ][pP][gG]|*.[jJ][pP][eE][gG]|*.[pP][nN][gG]) ;;
  *)
    echo "❌ Cover image must be .jpg, .jpeg, or .png"
    exit 1
    ;;
esac

if [ "$#" -eq 0 ]; then
  shopt -s nullglob nocaseglob
  audio_files=(./*.m4a ./*.opus)
  shopt -u nocaseglob
else
  audio_files=("$@")
fi

if [ "${#audio_files[@]}" -eq 0 ]; then
  echo "⚠️ No .m4a or .opus files found."
  exit 0
fi

for audio_file in "${audio_files[@]}"; do
  if [[ "$audio_file" =~ \.[oO][pP][uU][sS]$ ]] && ! command -v python3 >/dev/null 2>&1; then
    echo 'Missing required command for Opus artwork: python3' >&2
    exit 1
  fi
done

echo "▶️ Cover art plan:"
echo "- Cover:  $cover_image"
echo "- Files:  ${#audio_files[@]}"
echo "- Mode:   replace existing artwork"
echo ""

for audio_file in "${audio_files[@]}"; do
  fix_one_file "$audio_file"
done

echo ""
echo "✅ Done"

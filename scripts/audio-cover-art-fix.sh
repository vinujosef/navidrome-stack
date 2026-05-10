#!/bin/bash
set -euo pipefail

echo "🎧 Navidrome - Add Cover Art"
echo ""

usage() {
  echo "Usage:"
  echo "audio-cover-art-fix <cover-image.jpg|cover-image.png> [file1.m4a file2.m4a ...]"
  echo ""
  echo "If no .m4a files are provided, every .m4a file in the current folder is updated."
  echo "Existing embedded artwork is replaced. Audio is copied without re-encoding."
}

fix_one_file() {
  local input="$1"
  local temp_output

  if [ ! -f "$input" ]; then
    echo "❌ File not found: $input"
    return 1
  fi

  if [[ ! "$input" =~ \.[mM]4[aA]$ ]]; then
    echo "⚠️ Skipping non-M4A file: $input"
    return 0
  fi

  echo "Updating: ${input#./}"

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
  audio_files=(*.m4a)
  shopt -u nocaseglob
else
  audio_files=("$@")
fi

if [ "${#audio_files[@]}" -eq 0 ]; then
  echo "⚠️ No .m4a files found."
  exit 0
fi

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

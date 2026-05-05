#!/bin/bash
set -euo pipefail

echo "🎧 Navidrome - FLAC to M4A"
echo ""

usage() {
  echo "Usage:"
  echo "audio-flac-to-m4a"
  echo ""
  echo "Converts every .flac file in the current folder to .m4a at 160k."
}

require_command() {
  local command_name="$1"

  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "❌ $command_name is not installed or not available in PATH."
    exit 1
  fi
}

is_flac_file() {
  local input="$1"
  case "$input" in
    *.[fF][lL][aA][cC])
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

convert_one_file() {
  local input="$1"
  local output="${input%.*}.m4a"
  local output_dir
  local output_name
  local temp_output

  if [ ! -f "$input" ]; then
    echo "❌ File not found: $input"
    return 1
  fi

  if ! is_flac_file "$input"; then
    echo "⚠️ Skipping non-FLAC file: $input"
    return 0
  fi

  if [ -f "$output" ]; then
    echo "⚠️ Skipping existing file: $output"
    return 0
  fi

  output_dir="$(dirname "$output")"
  output_name="$(basename "$output")"
  temp_output="$output_dir/.${output_name%.m4a}.tmp.$$.m4a"

  echo "▶️ Converting:"
  echo "- Input:   $input"
  echo "- Output:  $output"
  echo "- Bitrate: 160k"
  echo ""

  if ! ffmpeg \
    -y \
    -i "$input" \
    -map 0:a:0 \
    -map "0:v?" \
    -map_metadata 0 \
    -c:a aac \
    -b:a 160k \
    -c:v copy \
    -disposition:v attached_pic \
    "$temp_output"; then
    echo ""
    echo "⚠️ Could not copy cover art. Retrying audio only..."
    rm -f "$temp_output"

    ffmpeg \
      -y \
      -i "$input" \
      -map 0:a:0 \
      -map_metadata 0 \
      -vn \
      -c:a aac \
      -b:a 160k \
      "$temp_output"
  fi

  mv "$temp_output" "$output"

  echo "✅ Done: $output"
  echo ""
}

cleanup_temp_files() {
  rm -f .*.tmp.$$.m4a 2>/dev/null || true
}

require_command ffmpeg
trap cleanup_temp_files EXIT

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
  exit 0
fi

if [ "$#" -ne 0 ]; then
  echo "❌ This command does not take arguments."
  echo ""
  usage
  exit 1
fi

echo "▶️ Conversion plan:"
echo "- Format:  m4a AAC"
echo "- Bitrate: 160k"
echo "- Folder:  $(pwd)"
echo "- Existing files: skip"
echo ""

shopt -s nullglob nocaseglob
flac_files=(*.flac)
shopt -u nocaseglob

if [ "${#flac_files[@]}" -eq 0 ]; then
  echo "⚠️ No FLAC files found in current folder."
  exit 0
fi

for flac_file in "${flac_files[@]}"; do
  convert_one_file "$flac_file"
done

echo "✅ All conversions complete"

#!/bin/bash
set -euo pipefail

echo "🎧 Navidrome - Audio Trim"
echo ""

if ! command -v ffmpeg >/dev/null 2>&1 || ! command -v ffprobe >/dev/null 2>&1; then
  echo "❌ ffmpeg and ffprobe must be installed and available in PATH."
  exit 1
fi

is_valid_time() {
  [[ "$1" =~ ^([0-9]{2}:)?[0-9]{2}:[0-9]{2}([.][0-9]+)?$ ]]
}

normalize_time() {
  local time="$1"

  if [[ "$time" =~ ^[0-9]{2}:[0-9]{2}$ ]]; then
    echo "00:$time"
  else
    echo "$time"
  fi
}

normalize_output() {
  local output="$1"
  local output_dir
  local output_name
  local output_base
  local normalized_name

  output_dir="$(dirname "$output")"
  output_name="$(basename "$output")"

  if [[ "$output_name" == *.m4a ]]; then
    echo "$output"
    return
  elif [[ "$output_name" == *.* ]]; then
    output_base="${output_name%.*}"
    normalized_name="$output_base.m4a"
  else
    normalized_name="$output_name.m4a"
  fi

  if [[ "$output_dir" == "." ]]; then
    echo "$normalized_name"
  else
    echo "$output_dir/$normalized_name"
  fi
}

trim_one_file() (
  local input="$1"
  local start="$2"
  local end="$3"
  local output="$4"
  local source_bitrate
  local bitrate=256000
  local temp_output

  if [ ! -f "$input" ]; then
    echo "❌ File not found: $input"
    return 1
  fi

  if ! is_valid_time "$start"; then
    echo "❌ Invalid start time: $start"
    return 1
  fi

  if ! is_valid_time "$end"; then
    echo "❌ Invalid end time: $end"
    return 1
  fi

  start="$(normalize_time "$start")"
  end="$(normalize_time "$end")"
  output="$(normalize_output "$output")"

  source_bitrate="$(ffprobe -v error -select_streams a:0 \
    -show_entries stream=bit_rate -of default=noprint_wrappers=1:nokey=1 "$input")"
  if [[ "$source_bitrate" =~ ^[0-9]+$ ]] && [ "$source_bitrate" -gt 0 ]; then
    if [ "$source_bitrate" -lt "$bitrate" ]; then
      bitrate="$source_bitrate"
    fi
  else
    source_bitrate="unavailable"
    echo "⚠️ Source audio bitrate unavailable; using 256 kbps."
  fi

  if [ -f "$output" ]; then
    echo "⚠️ Overwriting existing file: $output"
  fi

  echo "▶️  Trimming:"
  echo "- Input:  $input"
  echo "- Output: $output"
  echo "- Start:  $start"
  echo "- End:    $end"
  if [ "$source_bitrate" = "unavailable" ]; then
    echo "- Source audio bitrate: unavailable"
  else
    printf -- '- Source audio bitrate: %d.%03d kbps (%s bps)\n' \
      "$((source_bitrate / 1000))" "$((source_bitrate % 1000))" "$source_bitrate"
  fi
  printf -- '- Trimmed file AAC target bitrate: %d.%03d kbps (%s bps)\n' \
    "$((bitrate / 1000))" "$((bitrate % 1000))" "$bitrate"
  echo ""

  # -map 0:a:0 selects the first audio stream, and -vn ignores embedded artwork/video.
  # Cap the AAC target at the source audio bitrate when it is available.
  temp_output="$(mktemp "$(dirname "$output")/.audio-trim.XXXXXX")"
  trap 'rm -f "$temp_output"' EXIT
  ffmpeg -y -ss "$start" -to "$end" -i "$input" -map 0:a:0 -vn \
    -c:a aac -b:a "$bitrate" -f ipod "$temp_output"
  mv -f "$temp_output" "$output"

  echo "✅ Done: $output"
  echo ""
)

usage() {
  echo "Usage:"
  echo "audio-trim <input-filename> <start-time> <end-time> <output-filename>"
  echo ""
  echo "Batch usage:"
  echo "audio-trim input1.m4a 00:11 03:00 output1.m4a input2.m4a 00:05 02:30 output2.m4a"
}

if [ "$#" -eq 0 ]; then
  usage
  exit 1
fi

if [ $(( $# % 4 )) -ne 0 ]; then
  echo "❌ Invalid arguments. Must be in groups of 4:"
  echo "input start end output"
  echo ""
  usage
  exit 1
fi

while [ "$#" -gt 0 ]; do
  trim_one_file "$1" "$2" "$3" "$4"
  shift 4
done

echo "⚠️ Cut not clean? Fine-tune START and retry:"
echo "- 🎯 Progression:"
echo "- +0.3 → first tweak"
echo "- +0.5 → reliable default"
echo "- +0.7 / +0.9 → edge cases only"

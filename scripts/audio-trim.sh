#!/bin/bash
set -euo pipefail

echo "🎧 Navidrome - Audio Trim"
echo ""

if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "❌ ffmpeg is not installed or not available in PATH."
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

trim_one_file() {
  local input="$1"
  local start="$2"
  local end="$3"
  local output="$4"

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

  if [ -f "$output" ]; then
    echo "⚠️ Overwriting existing file: $output"
  fi

  echo "▶️ Trimming:"
  echo "- Input:  $input"
  echo "- Output: $output"
  echo "- Start:  $start"
  echo "- End:    $end"
  echo ""

  ffmpeg -y -ss "$start" -to "$end" -i "$input" -c:a aac -b:a 160k "$output"

  echo "✅ Done: $output"
  echo ""
}

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

#!/bin/bash
set -euo pipefail

usage() {
  echo 'Usage: audio-alac-to-aac [file.m4a ...]'
  echo 'With no arguments, checks every .m4a file in the current folder.'
  echo 'Converts only ALAC audio to AAC at 192 kbps.'
  echo 'Keeps filenames, tags, and artwork in an aac-192 subfolder beside each input.'
  echo 'Originals are preserved; existing outputs are skipped.'
}

if [ "${1:-}" = '-h' ] || [ "${1:-}" = '--help' ]; then
  usage
  exit 0
fi

for command_name in ffmpeg ffprobe; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Missing required command: $command_name" >&2
    exit 1
  fi
done

temp_output=''
file_result=''
failure_reason=''
cleanup() {
  if [ -n "$temp_output" ]; then
    rm -f -- "$temp_output"
  fi
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

convert_one_file() {
  local input="$1"
  local codec output_dir output
  file_result='skipped'
  failure_reason=''

  # Prefix relative paths so filenames beginning with '-' are safe.
  case "$input" in
    /*) ;;
    *) input="./$input" ;;
  esac
  if [ ! -f "$input" ]; then
    echo "File not found: $input" >&2
    failure_reason='File not found'
    return 1
  fi
  case "$input" in
    *.[mM]4[aA]) ;;
    *) echo "Skipping non-M4A file: $input"; return 0 ;;
  esac
  if ! codec="$(ffprobe -v error -select_streams a:0 \
    -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 "$input")"; then
    failure_reason='Could not read audio format'
    return 1
  fi
  if [ -z "$codec" ]; then
    failure_reason='No audio stream found'
    return 1
  fi
  if [ "$codec" != 'alac' ]; then
    echo "Skipping: $input (audio: ${codec:-none})"
    return 0
  fi

  output_dir="$(dirname "$input")/aac-192"
  output="$output_dir/$(basename "$input")"
  if [ -e "$output" ] || [ -L "$output" ]; then
    echo "Skipping existing output: $output"
    return 0
  fi
  if ! mkdir -p "$output_dir"; then
    failure_reason='Could not create output folder'
    return 1
  fi
  if ! temp_output="$(mktemp "$output_dir/.audio-alac-to-aac.XXXXXX")"; then
    failure_reason='Could not create temporary file'
    return 1
  fi
  echo "Converting to AAC 192 kbps: $input"
  if ! ffmpeg -hide_banner -loglevel error -nostdin -y -i "$input" \
    -map 0:a:0 -map '0:v?' -map_metadata 0 \
    -c:a aac -b:a 192k -c:v copy -disposition:v attached_pic \
    -f ipod "$temp_output"; then
    failure_reason='AAC conversion failed'
    return 1
  fi
  # A hard link publishes the finished file without overwriting an existing output.
  if ! ln "$temp_output" "$output"; then
    failure_reason='Could not save output file'
    return 1
  fi
  if ! rm -f -- "$temp_output"; then
    failure_reason='Output saved, but temporary file cleanup failed'
    return 1
  fi
  temp_output=''
  file_result='converted'
  echo "Saved: $output"
}

if [ "$#" -eq 0 ]; then
  shopt -s nullglob nocaseglob
  inputs=(./*.m4a)
  shopt -u nocaseglob
else
  inputs=("$@")
fi

if [ "${#inputs[@]}" -eq 0 ]; then
  echo 'No M4A files found in the current folder.'
  echo ''
  echo 'Processing summary:'
  echo '- Files checked: 0'
  echo '- Converted: 0'
  echo '- Skipped: 0'
  echo '- Failed: 0'
  echo 'Everything finished without errors.'
  exit 0
fi

converted=0
skipped=0
failed=0
failed_files=()
for input in "${inputs[@]}"; do
  if convert_one_file "$input"; then
    if [ "$file_result" = 'converted' ]; then
      converted=$((converted + 1))
    else
      skipped=$((skipped + 1))
    fi
  else
    failed=$((failed + 1))
    failed_files+=("$input: $failure_reason")
    echo "Failed: $input ($failure_reason)" >&2
    # Clean up this file before continuing to the next one.
    if cleanup; then
      temp_output=''
    else
      echo "Could not remove temporary file: $temp_output" >&2
      exit 1
    fi
  fi
done

echo ''
echo 'Processing summary:'
echo "- Files checked: ${#inputs[@]}"
echo "- Converted: $converted"
echo "- Skipped (non-ALAC/non-M4A or existing output): $skipped"
echo "- Failed: $failed"
if [ "$failed" -gt 0 ]; then
  if [ "$failed" -eq "${#inputs[@]}" ]; then
    echo 'Errors occurred in all files.'
  else
    echo 'Processing finished with errors in some files.'
  fi
  echo 'Failed files:'
  printf '  - %s\n' "${failed_files[@]}"
  exit 1
fi
echo 'Everything finished without errors.'

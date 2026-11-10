#!/bin/bash
set -euo pipefail

usage() {
  echo 'Usage: audio-loudness [file1 file2 ...]'
  echo 'Print FFmpeg loudnorm measurements without changing any files.'
  echo 'With no arguments, analyze audio files in the current folder.'
}

if [ "${1:-}" = '-h' ] || [ "${1:-}" = '--help' ]; then
  usage
  exit 0
fi

if ! command -v ffmpeg >/dev/null 2>&1; then
  echo 'Error: ffmpeg is not installed or not available in PATH.' >&2
  exit 1
fi

if [ "$#" -eq 0 ]; then
  shopt -s nullglob nocaseglob
  files=(*.m4a *.flac *.mp3 *.wav *.ogg *.opus *.aac *.aiff *.aif *.alac *.wma)
else
  files=("$@")
fi

if [ "${#files[@]}" -eq 0 ]; then
  echo 'No audio files found in the current folder.'
  exit 0
fi

status=0
for input in "${files[@]}"; do
  printf '\n%s\n' "$input"
  if [ ! -f "$input" ]; then
    printf 'Error: file not found: %s\n' "$input" >&2
    status=1
    continue
  fi
  # Prefix relative paths so filenames beginning with '-' are safe.
  case "$input" in
    /*) ;;
    *) input="./$input" ;;
  esac
  if report=$(ffmpeg -hide_banner -nostdin -nostats -i "$input" \
    -map 0:a:0 -af loudnorm=print_format=json -f null - 2>&1); then
    printf '%s\n' "$report" | awk -F '"' '
      /"input_i"/ { printf "  Integrated loudness: %s LUFS\n", $4 }
      /"input_tp"/ { printf "  True peak:           %s dBTP\n", $4 }
      /"input_lra"/ { printf "  Loudness range:      %s LU\n", $4 }
    '
  else
    printf '%s\n' "$report" >&2
    status=1
  fi
done
exit "$status"

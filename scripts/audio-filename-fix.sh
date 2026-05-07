#!/bin/bash
set -euo pipefail

echo "🎧 Navidrome - Audio Filename Fixing"
echo ""

choice_dot_dash_spacing="1. Dot-dash spacing: rename '01.-Song.m4a' to '01. Song.m4a'"
choice_disc_track_prefix="2. Disc-track prefix: rename '1.2. Song.flac' to '02. Song.flac'"

usage() {
  echo "Usage:"
  echo "audio-filename-fix"
  echo ""
  echo "Choices:"
  echo "  $choice_dot_dash_spacing"
  echo "  $choice_disc_track_prefix"
  echo ""
  echo "Options:"
  echo "  -h, --help   Show this help"
}

rename_file() {
  local file="$1"
  local new_name="$2"

  if [ "$file" = "$new_name" ]; then
    return 1
  fi

  if [ -e "$new_name" ]; then
    echo "⚠️ Skipping, target already exists: ${new_name#./}"
    return 1
  fi

  echo "Renaming: ${file#./} -> ${new_name#./}"
  mv "$file" "$new_name"
}

fix_dot_dash_spacing() {
  local changed=0
  local file
  local new_name

  for file in ./*.-*; do
    if [ ! -f "$file" ]; then
      continue
    fi

    new_name="${file/.-/. }"

    if rename_file "$file" "$new_name"; then
      changed=1
    fi
  done

  if [ "$changed" -eq 0 ]; then
    echo "No matching filenames found."
  fi
}

fix_disc_track_prefix() {
  local changed=0
  local file
  local filename
  local track_number
  local title
  local new_name

  for file in ./*; do
    if [ ! -f "$file" ]; then
      continue
    fi

    filename="${file#./}"

    if [[ ! "$filename" =~ ^1\.([0-9]+)\.\ (.+)$ ]]; then
      continue
    fi

    track_number="${BASH_REMATCH[1]}"
    title="${BASH_REMATCH[2]}"
    printf -v track_number "%02d" "$track_number"
    new_name="./$track_number. $title"

    if rename_file "$file" "$new_name"; then
      changed=1
    fi
  done

  if [ "$changed" -eq 0 ]; then
    echo "No matching filenames found."
  fi
}

run_choice() {
  local choice="$1"

  case "$choice" in
    1)
      fix_dot_dash_spacing
      ;;
    2)
      fix_disc_track_prefix
      ;;
    *)
      echo "❌ Unknown option: $choice"
      exit 1
      ;;
  esac
}

choose_option() {
  local choice

  echo "Choose filename fix:"
  echo "$choice_dot_dash_spacing"
  echo "$choice_disc_track_prefix"
  echo ""
  read -r -p "Enter option: " choice

  run_choice "$choice"
}

if [ "$#" -eq 0 ]; then
  choose_option
  exit 0
fi

if [ "$#" -ne 1 ]; then
  usage
  exit 1
fi

case "$1" in
  -h|--help)
    usage
    ;;
  *)
    echo "❌ Unknown option: $1"
    echo ""
    usage
    exit 1
    ;;
esac

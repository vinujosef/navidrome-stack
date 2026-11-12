#!/bin/bash
set -euo pipefail

# Resolve the installed symlink without changing the user's working folder.
SOURCE="${BASH_SOURCE[0]}"
while [ -L "$SOURCE" ]; do
  SOURCE_DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
  SOURCE="$(readlink "$SOURCE")"
  case "$SOURCE" in
    /*) ;;
    *) SOURCE="$SOURCE_DIR/$SOURCE" ;;
  esac
done
SCRIPT_DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"

if [ "$#" -gt 0 ]; then
  case "$1" in
    -h|--help)
      echo 'Usage: navidrome-tools'
      echo 'Open the audio tools menu in the current folder.'
      exit 0
      ;;
    *) echo 'Usage: navidrome-tools' >&2; exit 1 ;;
  esac
fi

prompt_required() {
  IFS= read -r -p "$1 (blank to cancel): " REPLY || return 1
  [ -n "$REPLY" ]
}

run_tool() {
  local tool="$1"
  local status=0
  shift
  bash "$SCRIPT_DIR/$tool.sh" "$@" || status=$?
  if [ "$status" -ne 0 ]; then
    echo "Command ended with exit code $status. Review the messages above."
  fi
  exit "$status"
}

while true; do
  printf '\nNavidrome tools — folder: %s\n' "$PWD"
  cat <<'MENU'
1. Download audio from YouTube
2. Fix filenames
3. Convert FLAC to AAC (all FLAC files in this folder)
4. Convert ALAC to AAC (all M4A files in this folder)
5. Fix album and track tags
6. Replace cover art (all M4A/Opus files in this folder)
7. Trim audio (existing output will be overwritten on success)
8. Normalize artist and composer names
9. Publish to Navidrome
0. Exit
MENU
  IFS= read -r -p 'Choose an option: ' choice || exit 0
  case "$choice" in
    1)
      prompt_required 'YouTube URL' || exit 0
      run_tool audio-youtube-download "$REPLY"
      ;;
    2) run_tool audio-filename-fix ;;
    3) run_tool audio-flac-to-m4a ;;
    4) run_tool audio-alac-to-aac ;;
    5)
      args=()
      IFS= read -r -p 'Album override (blank for folder default): ' value || exit 0
      [ -z "$value" ] || args+=(--album "$value")
      IFS= read -r -p 'Artist override (blank to keep track artists): ' value || exit 0
      [ -z "$value" ] || args+=(--artist "$value")
      IFS= read -r -p 'Genre override (blank to keep existing): ' value || exit 0
      [ -z "$value" ] || args+=(--genre "$value")
      run_tool audio-album-fix ${args[@]+"${args[@]}"}
      ;;
    6)
      prompt_required 'Artwork path (enter paths without surrounding quotes)' || exit 0
      run_tool audio-cover-art-fix "$REPLY"
      ;;
    7)
      prompt_required 'Input audio path (without surrounding quotes)' || exit 0
      input="$REPLY"
      prompt_required 'Start time (MM:SS or HH:MM:SS)' || exit 0
      start="$REPLY"
      prompt_required 'End time (MM:SS or HH:MM:SS)' || exit 0
      end="$REPLY"
      prompt_required 'Output M4A path (without surrounding quotes)' || exit 0
      run_tool audio-trim "$input" "$start" "$end" "$REPLY"
      ;;
    8)
      IFS= read -r -p '1. Preview changes  2. Review and apply  0. Cancel: ' mode || exit 0
      case "$mode" in
        1) run_tool audio-metadata-normalize --dry-run ;;
        2) run_tool audio-metadata-normalize ;;
        0|'') exit 0 ;;
        *) echo 'Invalid option; choose 1, 2, or 0.' ;;
      esac
      ;;
    9) run_tool audio-publish ;;
    0) exit 0 ;;
    *) echo 'Invalid option; choose a number from 0 to 9.' ;;
  esac
done

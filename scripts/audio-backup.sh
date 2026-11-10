#!/bin/bash
set -euo pipefail

usage() {
  echo "Usage: audio-backup [--dry-run]"
  echo "Run inside a direct child of one of the six music category folders."
  echo "Remote: ${AUDIO_BACKUP_REMOTE:-gdrive} (override with AUDIO_BACKUP_REMOTE)."
}

options=(--progress --create-empty-src-dirs)
case "${1:-}" in
  -h|--help) usage; exit 0 ;;
  --dry-run) options+=(--dry-run) ;;
  "") ;;
  *) usage >&2; exit 1 ;;
esac
if [ "$#" -gt 1 ]; then
  usage >&2
  exit 1
fi

source_dir="$(pwd -P)"
folder_name="$(basename "$source_dir")"
category="$(basename "$(dirname "$source_dir")")"
case "$category" in
  01_Malayalam|02_Tamil|"03_Hindi and Others"|04_Devotional|05_Meditation|"06_English and Others") ;;
  *)
    echo "Error: run inside a direct child of a music category folder." >&2
    echo "Example: .../06_English and Others/Post Malone" >&2
    exit 1
    ;;
esac

if ! command -v rclone >/dev/null 2>&1; then
  echo "Error: install rclone with: brew install rclone" >&2
  echo "Then run rclone config and create a Google Drive remote named gdrive." >&2
  exit 1
fi
remote="${AUDIO_BACKUP_REMOTE:-gdrive}"
if [[ "$remote" == *:* || "$remote" == */* ]]; then
  echo "Error: AUDIO_BACKUP_REMOTE must be a remote name without a colon or path." >&2
  exit 1
fi
remotes="$(rclone listremotes)"
found=false
while IFS= read -r configured_remote; do
  if [ "$configured_remote" = "$remote:" ]; then found=true; break; fi
done <<< "$remotes"
if [ "$found" != true ]; then
  echo "Error: remote '$remote' is missing. Run rclone config to create it." >&2
  exit 1
fi

destination="$remote:97_Navidrome_Song_Backup/$category/$folder_name"
echo "Source:      $source_dir"
echo "Destination: $destination"
echo ""
# rclone copies directory contents, so include the folder name in the destination.
# Preserve destination-only files and include empty subfolders.
rclone copy "$source_dir" "$destination" "${options[@]}"
if [ "${1:-}" = "--dry-run" ]; then
  echo "Preview complete. No files uploaded."
else
  echo "Backup complete: $destination"
fi

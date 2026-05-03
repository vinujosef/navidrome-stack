#!/bin/bash
set -euo pipefail

echo "🎧 Navidrome - Audio Publish"
echo ""

SCRIPT_PATH="${BASH_SOURCE[0]}"
while [ -L "$SCRIPT_PATH" ]; do
  SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
  SCRIPT_PATH="$(readlink "$SCRIPT_PATH")"
  [[ "$SCRIPT_PATH" != /* ]] && SCRIPT_PATH="$SCRIPT_DIR/$SCRIPT_PATH"
done

SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$REPO_DIR/.env"

CATEGORIES=()

usage() {
  echo "Usage:"
  echo "audio-publish"
  echo ""
  echo "Run this command from the local folder you want to upload."
}

shell_quote() {
  printf "%q" "$1"
}

require_command() {
  local command_name="$1"

  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "❌ $command_name is not installed or not available in PATH."
    exit 1
  fi
}

load_env() {
  if [ ! -f "$ENV_FILE" ]; then
    echo "❌ Missing .env file: $ENV_FILE"
    echo ""
    echo "Create it with:"
    echo 'SERVER="<ssh-user>@<server-host>"'
    echo "DEST='<remote-music-folder>'"
    echo "CATEGORIES='<category-one>|<category-two>|<category-three>'"
    exit 1
  fi

  set -a
  # shellcheck source=/dev/null
  source "$ENV_FILE"
  set +a

  if [ -z "${SERVER:-}" ] || [ -z "${DEST:-}" ] || [ -z "${CATEGORIES:-}" ]; then
    echo "❌ .env must define SERVER, DEST, and CATEGORIES."
    exit 1
  fi

  IFS="|" read -r -a CATEGORIES <<< "$CATEGORIES"

  if [ "${#CATEGORIES[@]}" -eq 0 ]; then
    echo "❌ .env CATEGORIES must include at least one destination folder."
    exit 1
  fi
}

choose_category() {
  echo "Choose destination folder:"
  echo ""

  local i
  for i in "${!CATEGORIES[@]}"; do
    printf "%d. %s\n" "$((i + 1))" "${CATEGORIES[$i]}"
  done

  echo ""
  read -r -p "Enter number: " choice

  if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "${#CATEGORIES[@]}" ]; then
    echo "❌ Invalid choice: $choice"
    exit 1
  fi

  selected_category="${CATEGORIES[$((choice - 1))]}"
}

confirm_publish() {
  echo "▶️ Publish plan:"
  echo "- Source:      $source_dir"
  echo "- Server:      $SERVER"
  echo "- Destination: $remote_dir"
  echo ""

  read -r -p "Upload this folder? [y/N]: " confirm

  case "$confirm" in
    y|Y|yes|YES)
      ;;
    *)
      echo "Cancelled."
      exit 0
      ;;
  esac
}

publish_folder() {
  local quoted_remote_dir
  local remote_target

  quoted_remote_dir="$(shell_quote "$remote_dir")"
  remote_target="$SERVER:$(shell_quote "$remote_dir/")"

  echo ""
  echo "📁 Creating remote folder..."
  ssh "$SERVER" "mkdir -p -- $quoted_remote_dir && chmod 755 -- $quoted_remote_dir"

  echo ""
  echo "⬆️ Uploading files..."
  rsync -av --progress --exclude=".*" -- "$source_dir"/ "$remote_target"

  echo ""
  echo "🔐 Updating remote permissions..."
  ssh "$SERVER" "find $quoted_remote_dir -type d -exec chmod 755 {} + && find $quoted_remote_dir -type f -exec chmod 644 {} +"

  echo ""
  echo "✅ Published:"
  echo "$SERVER:$remote_dir"
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
  exit 0
fi

if [ "$#" -ne 0 ]; then
  usage
  exit 1
fi

require_command ssh
require_command rsync
load_env

source_dir="$(pwd)"
folder_name="$(basename "$source_dir")"

if [ "$folder_name" = "/" ] || [ -z "$folder_name" ]; then
  echo "❌ Could not determine current folder name."
  exit 1
fi

choose_category
remote_dir="$DEST/$selected_category/$folder_name"
confirm_publish
publish_folder

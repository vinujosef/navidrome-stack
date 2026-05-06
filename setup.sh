#!/bin/bash
set -euo pipefail

BIN_DIR="$HOME/bin"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="$REPO_DIR/scripts"

echo "🔧 Setting up navidrome-stack scripts..."

mkdir -p "$BIN_DIR"

if [ ! -d "$SCRIPT_DIR" ]; then
  echo "❌ Scripts folder not found: $SCRIPT_DIR"
  exit 1
fi

link_script() {
  local source_file="$1"
  local command_name="$2"
  local target_file="$BIN_DIR/$command_name"

  if [ ! -f "$source_file" ]; then
    echo "⚠️ Skipping missing script: $source_file"
    return
  fi

  chmod +x "$source_file"

  if [ -L "$target_file" ] && [ "$(readlink "$target_file")" = "$source_file" ]; then
    echo "✔️ Already linked: $command_name"
  else
    ln -sf "$source_file" "$target_file"
    echo "🔗 Linked: $command_name -> $source_file"
  fi
}

remove_legacy_link() {
  local command_name="$1"
  local target_file="$BIN_DIR/$command_name"

  if [ -L "$target_file" ]; then
    rm "$target_file"
    echo "🧹 Removed old command: $command_name"
  fi
}

remove_legacy_link "audio-filename-fixing"

link_script "$SCRIPT_DIR/audio-trim.sh" "audio-trim"
link_script "$SCRIPT_DIR/audio-flac-to-m4a.sh" "audio-flac-to-m4a"
link_script "$SCRIPT_DIR/audio-filename-fix.sh" "audio-filename-fix"
link_script "$SCRIPT_DIR/audio-youtube-download.sh" "audio-youtube-download"
link_script "$SCRIPT_DIR/audio-publish.sh" "audio-publish"

echo ""
echo "✅ Setup complete."
echo ""
echo "You can now run:"
echo "- audio-trim"
echo "- audio-flac-to-m4a"
echo "- audio-filename-fix"
echo "- audio-youtube-download"
echo "- audio-publish"

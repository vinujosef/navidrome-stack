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

link_script "$SCRIPT_DIR/audio-trim.sh" "audio-trim"
link_script "$SCRIPT_DIR/audio-youtube-download.sh" "audio-youtube-download"
# link_script "$SCRIPT_DIR/audio-publish.sh" "audio-publish"

echo ""
echo "✅ Setup complete."
echo ""
echo "You can now run:"
echo "- audio-trim"
echo "- audio-youtube-download"

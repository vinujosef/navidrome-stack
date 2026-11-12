#!/bin/bash
set -euo pipefail

BIN_DIR="$HOME/bin"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="$REPO_DIR/scripts"

echo "🔧 Setting up navidrome-tools scripts..."

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
  local destination

  if [ -L "$target_file" ]; then
    destination="$(readlink "$target_file")"
    case "$destination" in
      "$SCRIPT_DIR/$command_name.sh"|"$REPO_DIR/../navidrome-stack/scripts/$command_name.sh"|"$(dirname "$REPO_DIR")/navidrome-stack/scripts/$command_name.sh")
        rm "$target_file"
        echo "🧹 Removed old command: $command_name"
        ;;
      *) echo "⚠️ Kept unrelated link: $target_file" ;;
    esac
  elif [ -e "$target_file" ]; then
    echo "⚠️ Kept existing file: $target_file"
  fi
}

for command_name in audio-trim audio-flac-to-m4a audio-alac-to-aac \
  audio-filename-fix audio-album-fix audio-cover-art-fix \
  audio-metadata-normalize audio-youtube-download audio-publish \
  audio-backup audio-loudness; do
  remove_legacy_link "$command_name"
done

link_script "$SCRIPT_DIR/navidrome-tools.sh" "navidrome-tools"

echo ""
echo "✅ Setup complete. Run navidrome-tools to open the menu."

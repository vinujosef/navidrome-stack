#!/bin/bash
set -euo pipefail

echo "🎧 Navidrome - Audio Metadata Normalize"
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

auto_yes=0
dry_run=0
normalization_rules=()
metadata_tags=(
  artist
  artists
  album_artist
  albumartist
  artist_sort
  artists_sort
  album_artist_sort
  albumartist_sort
  sort_artist
  sort_album_artist
  composer
  composer_sort
)

usage() {
  echo "Usage:"
  echo "audio-metadata-normalize [--yes] [--dry-run]"
  echo ""
  echo "Normalizes configured artist/composer metadata aliases for every .m4a file in the current folder."
  echo ""
  echo "Config:"
  echo "Add rules to repo .env:"
  echo "METADATA_NAME_NORMALIZATIONS='old name=>canonical name|another old name=>another canonical name'"
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
    return
  fi

  set -a
  # shellcheck source=/dev/null
  source "$ENV_FILE"
  set +a
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --yes|-y)
        auto_yes=1
        shift
        ;;
      --dry-run)
        dry_run=1
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        echo "❌ Unknown option: $1"
        echo ""
        usage
        exit 1
        ;;
    esac
  done
}

parse_normalization_rules() {
  local raw_rules="${METADATA_NAME_NORMALIZATIONS:-}"
  local rule
  local from
  local to

  if [ -z "$raw_rules" ]; then
    return
  fi

  IFS="|" read -r -a normalization_rules <<< "$raw_rules"

  for rule in "${normalization_rules[@]}"; do
    if [[ "$rule" != *"=>"* ]]; then
      echo "❌ Invalid normalization rule: $rule"
      echo "Expected format: old name=>canonical name"
      exit 1
    fi

    from="${rule%%=>*}"
    to="${rule#*=>}"

    if [ -z "$from" ] || [ -z "$to" ]; then
      echo "❌ Invalid normalization rule: $rule"
      echo "Both sides of '=>' are required."
      exit 1
    fi
  done
}

load_m4a_files() {
  shopt -s nullglob nocaseglob
  m4a_files=(*.m4a)
  shopt -u nocaseglob

  if [ "${#m4a_files[@]}" -eq 0 ]; then
    echo "⚠️ No .m4a files found in current folder."
    exit 0
  fi
}

metadata_value() {
  local input="$1"
  local tag_name="$2"
  local value

  value="$(ffprobe \
    -v error \
    -show_entries "format_tags=$tag_name" \
    -of default=noprint_wrappers=1:nokey=1 \
    "$input" || true)"

  printf "%s" "$value"
}

normalize_value() {
  local value="$1"
  local rule
  local from
  local to

  for rule in "${normalization_rules[@]}"; do
    from="${rule%%=>*}"
    to="${rule#*=>}"
    value="${value//$from/$to}"
  done

  printf "%s" "$value"
}

scan_file() {
  local input="$1"
  local tag
  local current_value
  local normalized_value

  file_metadata_args=()
  file_change_lines=()

  for tag in "${metadata_tags[@]}"; do
    current_value="$(metadata_value "$input" "$tag")"

    if [ -z "$current_value" ]; then
      continue
    fi

    normalized_value="$(normalize_value "$current_value")"

    if [ "$current_value" = "$normalized_value" ]; then
      continue
    fi

    file_metadata_args+=(-metadata "$tag=$normalized_value")
    file_change_lines+=("  - $tag: $current_value -> $normalized_value")
  done
}

scan_all_files() {
  files_to_update=()
  all_change_lines=()

  local m4a_file
  local line

  for m4a_file in "${m4a_files[@]}"; do
    scan_file "$m4a_file"

    if [ "${#file_metadata_args[@]}" -eq 0 ]; then
      continue
    fi

    files_to_update+=("$m4a_file")
    all_change_lines+=("${m4a_file#./}")

    for line in "${file_change_lines[@]}"; do
      all_change_lines+=("$line")
    done
  done
}

print_plan() {
  local line

  echo "▶️ Metadata normalization plan:"
  echo "- Folder:       $(pwd)"
  echo "- Files scanned: ${#m4a_files[@]}"
  echo "- Files to fix:  ${#files_to_update[@]}"
  echo ""

  if [ "${#files_to_update[@]}" -eq 0 ]; then
    return
  fi

  for line in "${all_change_lines[@]}"; do
    echo "$line"
  done

  echo ""
}

confirm_rewrite() {
  local confirm

  if [ "$dry_run" -eq 1 ] || [ "${#files_to_update[@]}" -eq 0 ] || [ "$auto_yes" -eq 1 ]; then
    return
  fi

  read -r -p "Rewrite metadata for these files? [y/N]: " confirm

  case "$confirm" in
    y|Y|yes|YES)
      ;;
    *)
      echo "Cancelled."
      exit 0
      ;;
  esac

  echo ""
}

fix_one_file() {
  local input="$1"
  local temp_output

  scan_file "$input"

  if [ "${#file_metadata_args[@]}" -eq 0 ]; then
    return
  fi

  temp_output="$(dirname "$input")/.${input##*/}.normalize.tmp.$$.m4a"

  echo "Updating: ${input#./}"

  ffmpeg \
    -hide_banner \
    -loglevel error \
    -y \
    -i "$input" \
    -map 0 \
    -map_metadata 0 \
    -c copy \
    "${file_metadata_args[@]}" \
    "$temp_output"

  mv "$temp_output" "$input"
}

cleanup_temp_files() {
  rm -f .*.normalize.tmp.$$.m4a 2>/dev/null || true
}

require_command ffmpeg
require_command ffprobe
trap cleanup_temp_files EXIT

parse_args "$@"
load_env
parse_normalization_rules

if [ "${#normalization_rules[@]}" -eq 0 ]; then
  echo "No metadata normalization rules configured."
  exit 0
fi

load_m4a_files
scan_all_files
print_plan
confirm_rewrite

if [ "$dry_run" -eq 1 ]; then
  echo "Dry run complete."
  exit 0
fi

for m4a_file in "${files_to_update[@]}"; do
  fix_one_file "$m4a_file"
done

echo ""
echo "✅ Metadata normalization complete"

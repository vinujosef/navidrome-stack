#!/bin/bash
set -euo pipefail

# Navidrome groups albums from embedded metadata, not from folder names.
# This command makes every .m4a in the current folder share one album identity.

echo "🎧 Navidrome - Audio Album Fix"
echo ""

album=""
album_artist=""
artist=""
genre=""

usage() {
  echo "Usage:"
  echo "audio-album-fix"
  echo "audio-album-fix [--album <name>] [--artist <name>] [--genre <name>]"
  echo ""
  echo "Fixes album grouping metadata for every .m4a file in the current folder."
  echo "If --album is omitted, the current folder name is used as the album name."
  echo "If the folder is named '<artist> - <album>', the album artist is inferred from the text before '-'."
  echo "Track artist tags are kept as-is unless --artist is used."
  echo "Date/year, MusicBrainz album ID, and album version tags are cleared."
  echo "Track number is set from the numeric prefix before '.' in each filename."
  echo "Title starts with a capital letter when it starts with an alphabetic character."
  echo "Disc number tags are cleared."
  echo "Comment tags are cleared."
  echo ""
  echo "Typical Navidrome fix:"
  echo 'cd "Taylor Swift - Greatest Hits"'
  echo 'audio-album-fix'
}

require_command() {
  local command_name="$1"

  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "❌ $command_name is not installed or not available in PATH."
    exit 1
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

trim_whitespace() {
  local value="$1"

  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"

  printf "%s" "$value"
}

arg_value() {
  local option="$1"
  local value="${2:-}"

  if [ -z "$value" ] || [[ "$value" == --* ]]; then
    echo "❌ $option requires a value." >&2
    exit 1
  fi

  printf "%s" "$value"
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --album)
        album="$(arg_value "$1" "${2:-}")"
        shift 2
        ;;
      --artist)
        artist="$(arg_value "$1" "${2:-}")"
        shift 2
        ;;
      --genre)
        genre="$(arg_value "$1" "${2:-}")"
        shift 2
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

prompt_for_missing_values() {
  local folder_name

  folder_name="$(basename "$(pwd)")"

  if [ -z "$album" ]; then
    album="$folder_name"
  fi

  if [[ "$folder_name" == *-* ]]; then
    album_artist="$(trim_whitespace "${folder_name%%-*}")"
  fi
}

validate_required_values() {
  if [ -z "$album" ] || [ -z "$album_artist" ]; then
    echo "❌ Album and album artist are required."
    echo "   Use a folder name like '<artist> - <album>' so album artist can be inferred."
    exit 1
  fi
}

build_metadata_args() {
  metadata_args=(
    -metadata "album=$album"
    -metadata "album_artist=$album_artist"
    -metadata "date="
    -metadata "year="
    -metadata "musicbrainz_albumid="
    -metadata "MusicBrainz Album Id="
    -metadata "MUSICBRAINZ_ALBUMID="
    -metadata "albumversion="
    -metadata "ALBUMVERSION="
    -metadata "comment="
    -metadata "COMMENT="
    -metadata "description="
    -metadata "DESCRIPTION="
  )

  if [ -n "$artist" ]; then
    metadata_args+=(-metadata "artist=$artist")
  fi

  if [ -n "$genre" ]; then
    metadata_args+=(-metadata "genre=$genre")
  fi

}

# Track numbers come from names like "01. Song.m4a".
track_number_from_filename() {
  local input="$1"
  local filename

  filename="$(basename "$input")"

  if [[ "$filename" =~ ^([0-9]+)\. ]]; then
    printf "%s" "${BASH_REMATCH[1]}"
  fi
}

# Fail before the confirmation prompt if any file cannot be numbered.
validate_track_number_prefixes() {
  local m4a_file
  local missing_count

  missing_count=0

  for m4a_file in "${m4a_files[@]}"; do
    if [ -z "$(track_number_from_filename "$m4a_file")" ]; then
      if [ "$missing_count" -eq 0 ]; then
        echo "❌ Could not infer track numbers from these filenames:"
      fi

      echo "  - ${m4a_file#./}"
      missing_count=$((missing_count + 1))
    fi
  done

  if [ "$missing_count" -gt 0 ]; then
    echo ""
    echo "Expected filenames to start with a numeric prefix before '.', like:"
    echo "  01. Song.m4a"
    exit 1
  fi
}

# Preserve title text, but fix a lowercase ASCII first letter.
capitalized_title() {
  local title="$1"
  local first_char
  local rest

  if [[ "$title" =~ ^([a-z])(.*)$ ]]; then
    first_char="$(printf "%s" "${BASH_REMATCH[1]}" | tr '[:lower:]' '[:upper:]')"
    rest="${BASH_REMATCH[2]}"
    printf "%s%s" "$first_char" "$rest"
    return
  fi

  printf "%s" "$title"
}

build_file_metadata_args() {
  local input="$1"
  local filename_number="$2"
  local current_title
  local new_title

  current_title="$(metadata_value "$input" "title")"
  new_title="$(capitalized_title "$current_title")"

  file_metadata_args=(
    "${metadata_args[@]}"
    -metadata "disc="
    -metadata "discnumber="
    -metadata "track=$filename_number"
    -metadata "tracknumber=$filename_number"
  )

  if [ -n "$current_title" ] && [ "$current_title" != "$new_title" ]; then
    file_metadata_args+=(-metadata "title=$new_title")
  fi
}

fix_one_file() {
  local input="$1"
  local output_dir
  local output_name
  local temp_output
  local filename_number
  local file_metadata_args

  output_dir="$(dirname "$input")"
  output_name="$(basename "$input")"
  temp_output="$output_dir/.${output_name%.m4a}.metadata.tmp.$$.m4a"
  filename_number="$(track_number_from_filename "$input")"

  build_file_metadata_args "$input" "$filename_number"

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
  rm -f .*.metadata.tmp.$$.m4a 2>/dev/null || true
}

plan_value() {
  local label="$1"
  local value="$2"

  if [ -n "$value" ]; then
    printf -- "- %-13s %s\n" "$label:" "$value"
  else
    printf -- "- %-13s keep existing\n" "$label:"
  fi
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

print_plan() {
  echo ""
  echo "▶️ Album fix plan:"
  echo "- Folder:       $(pwd)"
  echo "- Files:        ${#m4a_files[@]}"
  echo "- Album:        $album"
  echo "- Album artist: $album_artist"
  echo "- Date/year:    clear"
  echo "- MB album ID:  clear"
  echo "- Albumversion: clear"
  echo "- Comments:     clear"
  echo "- Track number: filename prefix before '.'"
  echo "- Disc number:  clear"
  echo "- Compilation:  keep existing"

  plan_value "Track artist" "$artist"
  plan_value "Genre" "$genre"

  echo ""
}

confirm_rewrite() {
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

require_command ffmpeg
require_command ffprobe
trap cleanup_temp_files EXIT

parse_args "$@"
prompt_for_missing_values
validate_required_values
build_metadata_args
load_m4a_files
validate_track_number_prefixes
print_plan
confirm_rewrite

for m4a_file in "${m4a_files[@]}"; do
  fix_one_file "$m4a_file"
done

echo ""
echo "✅ Album fix complete"

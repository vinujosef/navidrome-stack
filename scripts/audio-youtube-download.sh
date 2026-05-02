#!/bin/bash
set -euo pipefail

echo "🎧 Navidrome - YouTube Audio Download"
echo ""

usage() {
  echo "Usage:"
  echo "audio-youtube-download <url>"
}

if ! command -v yt-dlp >/dev/null 2>&1; then
  echo "❌ yt-dlp is not installed or not available in PATH."
  exit 1
fi

if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "❌ ffmpeg is not installed or not available in PATH."
  exit 1
fi

if [ "$#" -ne 1 ]; then
  usage
  exit 1
fi

url="$1"
m4a_format_id=""

echo "▶️ Downloading audio:"
echo "- URL:    $url"
echo "- Folder: $(pwd)"
echo "- Format: m4a"
echo "- Strategy: native m4a as-is, otherwise convert best audio to 160K m4a"
echo ""

m4a_format_id="$(yt-dlp \
  --no-playlist \
  -f "bestaudio[ext=m4a]" \
  --simulate \
  --print "%(format_id)s" \
  "$url" 2>/dev/null || true)"

if [ -n "$m4a_format_id" ]; then
  echo "✅ Native m4a found: format $m4a_format_id"
  echo ""

  yt-dlp \
    --no-playlist \
    -f "$m4a_format_id" \
    --embed-thumbnail \
    -o "%(title).200B [%(id)s].%(ext)s" \
    "$url"

  echo ""
  echo "✅ Downloaded native m4a without audio re-encoding"
else
  echo ""
  echo "ℹ️ Native m4a not available. Converting best audio to m4a at 160K..."
  echo ""

  yt-dlp \
    --no-playlist \
    -f "bestaudio" \
    --extract-audio \
    --audio-format m4a \
    --audio-quality 160K \
    --embed-thumbnail \
    -o "%(title).200B [%(id)s].%(ext)s" \
    "$url"
fi

echo ""
echo "✅ Done"

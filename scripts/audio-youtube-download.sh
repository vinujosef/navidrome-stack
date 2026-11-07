#!/bin/bash
set -euo pipefail

usage() {
  echo 'Usage: audio-youtube-download <url>'
  echo 'Download the best available audio without re-encoding (usually Opus or M4A).'
  echo 'Displays the codec, source container, and reported kbps (unknown when unavailable).'
  echo 'Requires yt-dlp, ffmpeg, and ffprobe.'
}
if [ "${1:-}" = '-h' ] || [ "${1:-}" = '--help' ]; then
  usage
  exit 0
fi
if [ "$#" -ne 1 ]; then
  usage
  exit 1
fi
for command_name in yt-dlp ffmpeg ffprobe; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Missing required command: $command_name" >&2
    exit 1
  fi
done

echo 'Downloading the best available audio without re-encoding.'
echo 'Bitrate is source-reported and may be approximate or unknown.'
yt-dlp --no-playlist -f bestaudio \
  --extract-audio --audio-format best \
  --embed-metadata --embed-thumbnail --convert-thumbnails jpg \
  --print 'before_dl:Selected audio: %(acodec)s | source container: %(ext)s | bitrate: %(abr|unknown)s kbps | format ID: %(format_id)s' \
  --print 'after_move:Saved: %(filepath)s' \
  -o '%(title).200B [%(id)s].%(ext)s' -- "$1"

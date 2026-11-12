# navidrome-tools

Command-line tools to prepare audio files and publish them to Navidrome.

## Setup

Install the [required tools and private configuration](docs/setup.md), then run
from this repository:

```bash
bash setup.sh
```

Ensure `~/bin` is in your `PATH`. Commands then work from any album folder.

## Interactive menu

From an album folder, run:

```bash
navidrome-tools
```

Choose a numbered action and answer its prompts. The menu exits when that action
finishes, returning the command’s exit status. Run `navidrome-tools` again for another
action. It operates in your current folder and uses the existing audio
commands, including their confirmations. Enter paths without surrounding quotes;
spaces are supported. Blank required inputs cancel and exit; `0` exits the menu.
Metadata normalization offers preview or review-and-apply modes.

Setup installs only `navidrome-tools` and removes old repository-owned `audio-*`
shortcuts, including links to the former `navidrome-stack` location. Scripts remain
in `scripts/` for direct use with Bash and batch arguments.

## Menu actions

Run `navidrome-tools` and choose a number:

| Option | Action | Purpose |
|---|---|---|
| 1 | [Download audio from YouTube](docs/commands.md#audio-youtube-download) | Download source audio without re-encoding |
| 2 | [Fix filenames](docs/commands.md#audio-filename-fix) | Fix common filename patterns |
| 3 | [Convert FLAC to AAC](docs/commands.md#audio-flac-to-m4a) | Convert at 256 kbps; keep originals |
| 4 | [Convert ALAC to AAC](docs/commands.md#audio-alac-to-aac) | Convert at 256 kbps; keep originals |
| 5 | [Fix album and track tags](docs/commands.md#audio-album-fix) | Fix album grouping and track tags |
| 6 | [Replace cover art](docs/commands.md#audio-cover-art-fix) | Replace embedded artwork |
| 7 | [Trim audio](docs/commands.md#audio-trim) | Trim to AAC at source bitrate, capped at 256 kbps; overwrites existing output |
| 8 | [Normalize artist and composer names](docs/commands.md#audio-metadata-normalize) | Preview changes or review and apply them |
| 9 | [Publish to Navidrome](docs/commands.md#audio-publish) | Upload M4A/Opus files to your server |
| 0 | Exit | Quit without running an action |

## Example workflow

For an album folder containing tracks named `01. Song.m4a` or `01. Song.opus`:

```bash
cd "Artist - Album"
navidrome-tools
# Run again for each step: album tags, cover art, metadata preview, then publish.
```

Publishing applies metadata normalization before uploading. Metadata and artwork
commands preserve encoded audio. Date fields refer to the movie release date.
See [full usage and audio policies](docs/commands.md) before processing files.

## Verification

Run the offline integration checks from the repository root:

```bash
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests -v
```

Requires `python3`, `ffmpeg`, and `ffprobe`; the publishing check also uses `rsync`.
The real downloader check requires `yt-dlp` and its thumbnail-embedding dependencies
and is skipped when `yt-dlp` is unavailable. Tests use temporary local media and
simulate SSH; they do not contact YouTube or upload to a server. They verify Opus
and M4A metadata/artwork, encoded-audio preservation, bitrate display, and publish
filters.

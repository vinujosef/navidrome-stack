# Command reference

[Back to README](../README.md) · [Setup and configuration](setup.md)

Date and Original Release Date refer to the movie release date in this library.

## Audio format policy

| Operation | Output |
|---|---|
| FLAC conversion | AAC in `.m4a`, target 256 kbps; original retained |
| ALAC conversion | AAC in `.m4a`, target 256 kbps, in `aac-256`; original retained |
| YouTube download | Source audio without re-encoding; usually `.opus` or `.m4a` |
| Trimming | AAC in `.m4a`, target 192 kbps |

AAC bitrates are encoder targets; measured values can vary slightly.

## audio-youtube-download

Download the best available audio from a single YouTube video.

```bash
audio-youtube-download "https://www.youtube.com/watch?v=example"
```

- Saves in the current folder using the video title and ID as the filename.
- Preserves the source codec and embeds available metadata and artwork.
- Displays codec, container, and source-reported bitrate, which may be approximate
  or unknown. Playlists are not downloaded.
- Requires `yt-dlp`, `ffmpeg`, and `ffprobe`.

Downloaded M4A and Opus files work with the metadata, artwork, and publish commands.
Before using `audio-album-fix`, rename tracks to `01. Song.opus` (or `.m4a`)
inside an `Artist - Album` folder.

## audio-filename-fix

Choose a filename correction for files in the current folder.

```bash
audio-filename-fix
```

| Menu option | Before | After |
|---|---|---|
| Dot-dash spacing | `01.-Song.m4a` | `01. Song.m4a` |
| Disc-track prefix | `1.2. Song.flac` | `02. Song.flac` |
| SMR release name | `01-01-Artist-Song_Title-SMR.flac` | `01. Song Title.flac` |
| Dash track separator | `01 - Song.m4a` | `01. Song.m4a` |

## audio-flac-to-m4a

Convert FLAC files in the current folder to AAC at 256 kbps.

```bash
audio-flac-to-m4a
```

- Writes `.m4a` files beside the originals and skips existing outputs.
- Retains original FLAC files; copies metadata and artwork when FFmpeg can preserve them.
- Requires `ffmpeg`.

## audio-alac-to-aac

Convert only ALAC audio in M4A files to AAC at 256 kbps.

```bash
audio-alac-to-aac                  # All M4A files in the current folder
audio-alac-to-aac "01. Song.m4a"    # Selected file; multiple files accepted
```

- Keeps filenames in an `aac-256` subfolder beside each input; retains originals.
- Skips existing outputs and non-ALAC audio. Does not scan subfolders.
- Preserves metadata and artwork, including artwork dimensions.
- Continues after individual failures, prints a summary, and returns a nonzero
  exit code if any file failed.
- Requires `ffmpeg` and `ffprobe`.

## audio-album-fix

Fix tags when Navidrome splits one folder into multiple albums.

```bash
cd "Artist - Album"
audio-album-fix
# Optional overrides:
audio-album-fix --album "Album" --artist "Artist" --genre "Soundtrack"
```

- Requires an `Artist - Album` folder and numbered filenames such as `01. Song.m4a`.
- Processes M4A and Opus files in the current folder only, ignoring extension case.
- Uses the full folder name as the album tag and the folder's artist as album artist.
  Use `--album` to override the album name.
- Sets track numbers from filenames and capitalizes the first letter of titles.
- Clears date/year, MusicBrainz album ID, album version, comment/description, and disc number.
- Changes track artists or genre only when the corresponding override is supplied.
- Asks for confirmation; preserves encoded audio, artwork, and compilation tags.
- Requires `ffmpeg` and `ffprobe`, plus `python3` for Opus.

## audio-cover-art-fix

Replace embedded artwork in M4A and Opus files.

```bash
audio-cover-art-fix cover.jpg                       # All files in the current folder
audio-cover-art-fix cover.jpg "01. Song.m4a" "02. Song.opus"
```

- Accepts JPEG or PNG images; a square JPEG is recommended.
- Replaces existing artwork and preserves encoded audio and metadata.
- Does not scan subfolders; file extensions are case-insensitive.
- Requires `ffmpeg`; Opus also requires `ffprobe` and `python3`.

## audio-trim

Trim audio to AAC in an M4A file at 192 kbps.

```bash
# Input, start, end, output:
audio-trim song.m4a 00:11 03:00 intro.m4a
# Repeat groups of four arguments for multiple trims:
audio-trim song1.m4a 00:11 03:00 intro1.m4a song2.opus 00:05 02:30 intro2.m4a
```

- Accepts `MM:SS` or `HH:MM:SS` timestamps.
- Re-encodes audio, including Opus input; omits artwork.
- Overwrites existing output files. Paths are relative to the current folder.
- Requires `ffmpeg`.

## audio-publish

Upload the current folder's M4A and Opus files to your server.
Configure server details and categories in [setup](setup.md#private-configuration).

```bash
cd "Artist - Album"
audio-publish
```

- Asks you to select a category and confirm the upload.
- Uploads to `<DEST>/<selected-category>/<current-folder-name>`.
- Includes subfolders and ignores extension case; excludes other file types.
- Applies metadata normalization to local files in the current folder before uploading.
  Nested folders are uploaded without normalizing their tags.
- Creates the destination if needed and uses rsync to upload changed files.
- Sets remote directory permissions to `755` and file permissions to `644`.
- Requires `ssh`, `rsync`, `ffmpeg`, `ffprobe`, and `python3`.

## audio-metadata-normalize

Normalize artist and composer names using built-in aliases and optional
[custom rules](setup.md#private-configuration).

```bash
audio-metadata-normalize --dry-run  # Preview changes without writing
audio-metadata-normalize            # Review and confirm changes
audio-metadata-normalize --yes      # Apply without confirmation
```

- Updates artist, album artist, composer, and their related multi-value/sort fields.
- Shows each changed file and field with before/after values.
- Custom rules are case-sensitive text replacements, including within a tag value.
- Processes M4A and Opus files in the current folder only, ignoring extension case.
- Preserves encoded audio, artwork, and unrelated metadata.
- Runs automatically before `audio-publish`, even without custom rules.
- Requires `ffmpeg`, `ffprobe`, and `python3`.

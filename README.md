# 📁 navidrome-stack

Minimal tooling to prepare and deploy audio files for Navidrome.

Focus:
- fast workflow
- repeatable commands
- zero manual mistakes

## Library conventions

- **Date** and **Original Release Date** always refer to the movie release date in this library.

## ⚙️ Setup

### 1. Why setup is needed:
- Scripts live inside: `<your-folder>/navidrome-stack/scripts/`
- You want to run them globally like `audio-trim <input-filename> <start-time> <end-time> <output-filename>`

### 2. What setup.sh does:
- creates ~/bin (if not exists)
- links /scripts into ~/bin
- makes them available globally (using symlinks)
- future changes to scripts are picked up automatically because ~/bin points to the repo files

### 3. Run setup:
- Run `chmod +x setup.sh && ./setup.sh`
- Example result: `~/bin/audio-trim → ~/Code/navidrome-stack/scripts/audio-trim.sh`
- Now you can run `audio-trim` from any folder

### 4. Requirement:
- Make sure ~/bin is in your PATH:
- Add this only once to avoid duplicate PATH lines in `.zshrc`:

```bash
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

### 5. When to rerun setup:
- after moving this repo to a different folder
- after adding a new command script
- if a symlink in ~/bin was deleted or broken

## 🔧 Tools

### Audio format policy

| Operation | Output |
|---|---|
| FLAC conversion | AAC in `.m4a`, target 256 kbps; original FLAC retained |
| ALAC conversion | AAC in `.m4a`, target 256 kbps, in `aac-256`; original retained |
| YouTube download | Best available source audio, without re-encoding; usually `.opus` or `.m4a` |
| Trimming | AAC in `.m4a`, target 192 kbps |

AAC targets are encoder settings; measured bitrates can vary slightly. Existing
files are not automatically upgraded or re-encoded by these setting changes.


### audio-loudness

Print FFmpeg `loudnorm` measurements without changing or creating audio files.

```bash
audio-loudness                       # All audio files in the current folder
audio-loudness "01. Song.m4a"         # One song
audio-loudness "song.m4a" "song.flac"  # Selected songs
```

- Reports input integrated loudness (LUFS), true peak (dBTP), and loudness range (LU).
- More negative LUFS values indicate quieter average loudness.
- Reads each complete song, so large folders can take time.
- Does not scan subfolders. Requires `ffmpeg`.
- Run `bash setup.sh` after adding this command to install its link in `~/bin`.

### 1. audio-youtube-download
Download the best available YouTube audio without re-encoding using yt-dlp.

#### Usage:

`audio-youtube-download <url>`

#### Example:

`audio-youtube-download "https://www.youtube.com/watch?v=example"`

#### Notes:

- Downloads to the current terminal folder
- Uses the YouTube title and video ID as the filename
- Uses yt-dlp's `bestaudio` selection across formats, without preferring M4A
- Shows the selected codec, source container, reported bitrate in kbps, and saved filename
- Bitrate is source-reported and may be approximate; missing values are shown as unknown
- Preserves the audio codec without re-encoding: usually `.opus` for Opus or `.m4a` for AAC
- Embeds available title/artist metadata and converts the thumbnail to JPEG for embedded artwork
- Requires `yt-dlp`, `ffmpeg`, and `ffprobe`; no bitrate menu
- Does not download playlists

YouTube downloads work with `audio-album-fix`, `audio-metadata-normalize`,
`audio-cover-art-fix`, and `audio-publish` in either format. Opus tag/artwork updates
also require `python3` (standard library only), and preserve the encoded audio.
Album fixing still requires filenames such as `01. Song.opus` and a folder such as
`Artist - Album`; rename downloaded filenames before running that command.

### 2. audio-filename-fix
Fix common audio filename patterns in the current folder.

#### Usage:

`audio-filename-fix`

The command asks which filename fix to run:

```text
1. Dot-dash spacing: rename '01.-Song.m4a' to '01. Song.m4a'
2. Disc-track prefix: rename '1.2. Song.flac' to '02. Song.flac'
3. SMR release name: rename '01-01-Artist-Song_Title-SMR.flac' to '01. Song Title.flac'
4. Dash track separator: rename '01 - Song.m4a' to '01. Song.m4a'
```

### 3. audio-flac-to-m4a
Convert FLAC files to `.m4a` using ffmpeg.

#### Usage:

`audio-flac-to-m4a`

#### Examples:

```bash
cd album-folder
audio-flac-to-m4a
```

#### Notes:

- Converts FLAC files to AAC `.m4a`
- AAC target bitrate is 256 kbps
- Converts every `.flac` file in the current folder
- Output files are written to the same folder
- Existing `.m4a` files are skipped
- Metadata and cover art are copied when ffmpeg can preserve them
- A temporary `.m4a` is written first, then renamed after conversion succeeds

### audio-alac-to-aac

Check M4A files and convert only ALAC lossless audio to AAC at 256 kbps.

```bash
audio-alac-to-aac                  # All M4A files in the current folder
audio-alac-to-aac "01. Song.m4a"    # One song (or provide multiple files)
```

- Keeps the same filename in an `aac-256` subfolder beside each input.
- Preserves the original files and skips existing outputs.
- Skips AAC and other non-ALAC audio without re-encoding.
- Copies metadata and cover art; artwork retains its original size.
- Does not scan subfolders. Requires `ffmpeg` and `ffprobe`.
- Writes a temporary file first and publishes it only after conversion succeeds.
- Continues after individual file errors and prints a final summary of converted,
  skipped, and failed files, including failure reasons. Returns a nonzero exit code
  if any file failed.
- Run `bash setup.sh` to install the command link after adding this script.

### 4. audio-album-fix
Fix album grouping metadata for every `.m4a` or `.opus` file in the current folder.

Use this when Navidrome splits one folder into multiple albums because the embedded tags still say the songs belong to different albums or years.

#### Usage:

```bash
cd "Artist - Album"
audio-album-fix
# Optional overrides:
audio-album-fix --album "Album" --artist "Artist" --genre "Soundtrack"
```

The folder must have the form `Artist - Album` so the album artist can be
inferred. By default the full folder name becomes the album tag; use `--album`
to override it. Files must start with a number followed by a dot, such as
`01. Song.m4a` or `01. Song.opus`; this becomes the track number. The script
validates filenames and asks for confirmation before rewriting tags.

Requires `ffmpeg` and `ffprobe`, plus `python3` for Opus. Only the current folder
is processed, with case-insensitive `.m4a` and `.opus` extensions.

#### What it changes:

- `album`
- `album_artist`
- clears `date/year`
- clears `musicbrainz_albumid`
- clears `albumversion`
- clears `comment` / `description`
- clears `discnumber`
- `tracknumber`
- capitalizes the first letter of `title` when needed
- optional `artist`
- optional `genre`

#### What it keeps:

- audio quality, without re-encoding
- existing track titles, except first-letter capitalization
- existing track artists, unless `--artist` is used
- existing `compilation` / `TCMP` tags
- existing cover art

### 5. audio-cover-art-fix
Add or replace embedded cover art for `.m4a` and `.opus` files.

#### Usage:

```bash
audio-cover-art-fix <cover-image.jpg|cover-image.png> [file1.m4a file2.opus ...]
```

#### Examples:

```bash
cd album-folder
audio-cover-art-fix cover.jpg
audio-cover-art-fix cover.jpg "01. Song.m4a" "02. Song.opus"
```

#### Notes:

- Best input format is `.jpg` / `.jpeg`, ideally square
- `.png` is also accepted
- If no audio files are provided, every `.m4a` and `.opus` file in the current folder is updated
- Existing embedded artwork is replaced with the provided image
- Audio is copied without re-encoding
- Existing tags are preserved; M4A uses FFmpeg metadata copying, while Opus tags and artwork are rewritten with the Python helper
- The container is rewritten while the artwork is replaced; Opus uses a standard picture comment
- Requires `ffmpeg`; Opus additionally requires `ffprobe` and `python3` (standard library only)
- Does not scan subfolders; extensions are case-insensitive

### 6. audio-trim
Trim audio files using ffmpeg.

#### Usage:

`audio-trim <input-filename> <start-time> <end-time> <output-filename>`


#### Example:

`audio-trim song.m4a 00:00 03:00 intro.m4a`

#### Batch processing -  Run multiple trims in one command:

```bash
audio-trim \
  song1.m4a 00:11 03:00 intro1.m4a \
  song2.m4a 00:05 02:30 intro2.m4a
```

#### Time format:

- `MM:SS or HH:MM:SS` -> `eg. 00:11, 03:00, 00:00:11`
- Output files are always written as `.m4a`
- Audio is encoded as AAC with a target bitrate of 192 kbps
- Opus input is accepted, but trimming converts it to AAC; artwork is omitted
- Requires `ffmpeg`
- Output files are overwritten if they exist
- Runs relative to the current folder

#### Troubleshooting cuts - If the cut isn’t clean:
- +0.3 → first tweak
- +0.5 → reliable default
- +0.7 / +0.9 → edge cases only

### 7. audio-publish
Upload the current local folder to the Navidrome music folder on the server.

#### Config:

Create `.env` in the repo root:

```bash
SERVER="<ssh-user>@<server-host>"
DEST='<remote-music-folder>'
CATEGORIES='<category-one>|<category-two>|<category-three>'
METADATA_NAME_NORMALIZATIONS='old name=>canonical name|another old name=>another canonical name'
```

#### Usage:

Go into the folder you want to upload, then run:

```bash
audio-publish
```

The script asks which configured Navidrome folder to publish into:

```text
1. <category-one>
2. <category-two>
3. <category-three>
...
```

#### Example:

If you run `audio-publish` from a local folder:

```text
<local-music-work-folder>/<album-folder>
```

and choose a destination category, files are uploaded to:

```text
<DEST>/<selected-category>/<album-folder>
```

#### Notes:

- Uploads only `.m4a` and `.opus` files from the current folder and its subfolders (case-insensitive extensions)
- Runs configured metadata name normalizations on the current folder before upload; nested folders are uploaded but their tags are not normalized
- Uses `rsync`, so repeated publishes only upload changed files
- Creates the destination folder if missing
- Uses the current folder name as the remote album/folder name
- Sets remote folder permissions after upload
- Requires `ssh` and `rsync`; configured metadata normalization also requires `ffmpeg`, `ffprobe`, and `python3` for Opus

### 8. audio-metadata-normalize
Normalize configured artist/composer metadata aliases for every `.m4a` or `.opus` file in the current folder.

Use this when the same person appears under slightly different spellings in Navidrome artist or composer lists.

#### Config:

Add one or more private rules to `.env`:

```bash
METADATA_NAME_NORMALIZATIONS='old name=>canonical name|another old name=>another canonical name'
```

#### Usage:

```bash
audio-metadata-normalize
audio-metadata-normalize --dry-run
audio-metadata-normalize --yes
```

#### What it changes:

- `artist`
- `artists`
- `album_artist`
- `albumartist`
- artist sort fields
- album artist sort fields
- `composer`
- `composer_sort`

#### Notes:

- Rules are case-sensitive text replacements, including matching text within a tag value.
- Processes only the current folder, with case-insensitive `.m4a` and `.opus` extensions.
- Requires `ffmpeg` and `ffprobe`, plus `python3` for Opus.
- Audio is copied without re-encoding.
- Existing metadata and cover art are preserved.
- `audio-publish` automatically runs this first when `METADATA_NAME_NORMALIZATIONS` is configured.


### 9. audio-backup
Copy the current folder, all files, and subfolders to Google Drive under
`97_Navidrome_Song_Backup/<parent-category>/<current-folder>`.

#### First-time setup (macOS):

1. Install rclone: `brew install rclone`.
2. Run `rclone config`:
   - Choose `n` for a new remote and name it `gdrive`.
   - Choose `drive` (Google Drive) as the storage type.
   - Leave client ID and client secret blank to use the built-in client.
   - Choose full Drive access (`drive`) for the scope so it can access your existing backup folders.
   - Leave service account credentials blank and accept other defaults.
   - Skip advanced configuration and choose browser authentication.
   - Sign in to the Google account containing your backup folder and grant access.
   - Answer no to Shared Drive configuration for a folder in My Drive.
   - Save the remote and quit configuration.
3. Verify access: `rclone lsd gdrive:97_Navidrome_Song_Backup`.
4. From this repository, run `bash setup.sh` to make `audio-backup` available.
   Ensure `~/bin` is in PATH as described above.

Official references: [installation](https://rclone.org/install/),
[Google Drive setup](https://rclone.org/drive/), and
[copy behavior](https://rclone.org/commands/rclone_copy/).

#### Usage:

```bash
cd "/path/to/06_English and Others/Post Malone"
audio-backup --dry-run  # Preview without uploading
audio-backup            # Upload
```

Destination: `gdrive:97_Navidrome_Song_Backup/06_English and Others/Post Malone`.

The parent folder must match one of these names exactly:
`01_Malayalam`, `02_Tamil`, `03_Hindi and Others`, `04_Devotional`,
`05_Meditation`, or `06_English and Others`.

- Copies every regular file, including hidden files, and nested/empty folders.
- Skips unchanged files and replaces changed files on repeat runs.
- Keeps Drive-only files when local files are deleted.
- Creates missing destination folders automatically.
- Reports upload failures; rerun the command to retry.
- Symbolic links are skipped by rclone's default behavior.
- Uses `gdrive` by default. For a different configured remote, run
  `AUDIO_BACKUP_REMOTE=myremote audio-backup`.

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

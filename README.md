# 📁 navidrome-stack

Minimal tooling to prepare and deploy audio files for Navidrome.

Focus:
- fast workflow
- repeatable commands
- zero manual mistakes

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

### 1. audio-youtube-download
Download YouTube audio as `.m4a` using yt-dlp.

#### Usage:

`audio-youtube-download <url>`

#### Example:

`audio-youtube-download "https://www.youtube.com/watch?v=example"`

#### Notes:

- Downloads to the current terminal folder
- Uses the YouTube title and video ID as the filename
- Prefers native `.m4a` audio and keeps it as-is to avoid audio re-encoding
- Falls back to best audio and converts to `.m4a` when native `.m4a` is not available
- Converted fallback audio uses AAC at 160k
- Embeds the YouTube thumbnail as cover art
- Does not download playlists

### 2. audio-filename-fix
Fix common audio filename patterns in the current folder.

#### Usage:

`audio-filename-fix`

The command asks which filename fix to run:

```text
1. Dot-dash spacing: rename '01.-Song.m4a' to '01. Song.m4a'
2. Disc-track prefix: rename '1.2. Song.flac' to '02. Song.flac'
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
- Bitrate is always 160k
- Converts every `.flac` file in the current folder
- Output files are written to the same folder
- Existing `.m4a` files are skipped
- Metadata and cover art are copied when ffmpeg can preserve them
- A temporary `.m4a` is written first, then renamed after conversion succeeds

### 4. audio-album-fix
Fix album grouping metadata for every `.m4a` file in the current folder.

Use this when Navidrome splits one folder into multiple albums because the embedded tags still say the songs belong to different albums or years.

#### Usage:

```bash
cd FolderName
audio-album-fix
```

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

### 5. audio-trim
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
- Audio is encoded as AAC at 160k
- Output files are overwritten if they exist
- Runs relative to the current folder

#### Troubleshooting cuts - If the cut isn’t clean:
- +0.3 → first tweak
- +0.5 → reliable default
- +0.7 / +0.9 → edge cases only

### 6. audio-publish
Upload the current local folder to the Navidrome music folder on the server.

#### Config:

Create `.env` in the repo root:

```bash
SERVER="<ssh-user>@<server-host>"
DEST='<remote-music-folder>'
CATEGORIES='<category-one>|<category-two>|<category-three>'
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

- Uploads only `.m4a` files from the current folder
- Uses `rsync`, so repeated publishes only upload changed files
- Creates the destination folder if missing
- Uses the current folder name as the remote album/folder name
- Sets remote folder permissions after upload

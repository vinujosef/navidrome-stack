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

### 3. Run setup:
- Run `chmod +x setup.sh && ./setup.sh`
- Example result: `~/bin/audio-trim → ~/Code/navidrome-stack/scripts/audio-trim.sh`
- Now you can run `audio-trim` from any folder

### 4. Requirement:
- Make sure ~/bin is in your PATH:

```bash
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

## 🔧 Tools

### 1. audio-trim
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

### Notes:


#### Time format:

- `MM:SS or HH:MM:SS` -> `eg. 00:11, 03:00, 00:00:11`
- Output files are always written as `.m4a`
- Audio is encoded as AAC at 192k
- Output files are overwritten if they exist
- Runs relative to the current folder

#### Troubleshooting cuts - If the cut isn’t clean:
- +0.3 → first tweak
- +0.5 → reliable default
- +0.7 / +0.9 → edge cases only



### 2. audio-publish
Send processed files to Navidrome server.
(update later)

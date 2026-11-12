# Setup and configuration

[Back to README](../README.md) · [Command reference](commands.md)

## Requirements

Use Bash on macOS with the following tools available in `PATH`:

| Tool | Needed for |
|---|---|
| `ffmpeg` | Audio conversion, trimming, metadata, and artwork |
| `ffprobe` | Inspecting audio and metadata |
| `python3` | Metadata normalization and Opus metadata/artwork |
| `yt-dlp` | YouTube downloads |
| `ssh`, `rsync` | Publishing to your server |

## Install commands

From the repository root:

```bash
bash setup.sh
```

This creates `~/bin` if needed and links commands to the scripts in this repo.
Edits to existing scripts are available immediately through those links.
The installer can replace existing files or links with the same command names.

Ensure `~/bin` is in your `PATH`. If it is missing, add this line once to
`~/.zshrc`, then open a new terminal:

```bash
export PATH="$HOME/bin:$PATH"
```

Setup installs `navidrome-tools` and removes old repository-owned `audio-*`
shortcuts, including those pointing to the former `navidrome-stack` location.
Unrelated links and regular files are kept.

Rerun `bash setup.sh` after moving the repo or losing the menu link.

## Private configuration

For publishing, create `.env` in the repository root:

```bash
SERVER="<ssh-user>@<server-host>"
DEST='<remote-music-folder>'
CATEGORIES='<category-one>|<category-two>|<category-three>'
```

Optional extra metadata replacement rules:

```bash
METADATA_NAME_NORMALIZATIONS='old name=>canonical name|another old name=>another canonical name'
```

Keep real server details and private rules in `.env`, which Git ignores.
This file is sourced by Bash; use trusted shell assignments and quote values.
See the [command reference](commands.md#audio-publish) for publishing behavior
and [metadata normalization](commands.md#audio-metadata-normalize) for rule details.

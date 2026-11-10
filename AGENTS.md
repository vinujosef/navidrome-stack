# Working in navidrome-stack

This repository contains command-line tools for preparing audio for Navidrome.

## Keep changes easy to review

- Work on one agreed change at a time. Keep unrelated improvements separate.
- Before editing, explain briefly what will change and why in plain language.
- Follow existing script patterns and avoid unnecessary dependencies.
- Finish by explaining what changed, what was checked, and any limitations.
- Do not commit or push unless asked.

## Repository map

- `scripts/audio-*.sh`: user-facing Bash commands.
- `scripts/lib/opus-metadata.py`: shared Opus metadata and artwork helper.
- `setup.sh`: installs command symlinks in `~/bin`.
- `tests/test_youtube_workflow.py`: offline integration tests using temporary media.
- `README.md`: command usage, configuration, and audio policies.

## Audio and file conventions

- Metadata and artwork changes must preserve encoded audio without re-encoding.
- FLAC and ALAC conversions target AAC at 256 kbps and retain originals.
- Trimming targets AAC at 192 kbps. YouTube downloads preserve the source codec.
- Date and Original Release Date refer to the movie release date in this library.
- Quote file paths and handle spaces in filenames.
- Preserve original files on failure; use temporary outputs and publish them only
  after the operation succeeds. Clean up temporary files on exit.
- Keep shell scripts compatible with macOS `/bin/bash`; do not assume Homebrew
  Bash or GNU-only utilities are installed.

## Verification

- For changed Bash scripts, run `bash -n` on each changed file.
- For behavior changes, run the relevant tests. The existing suite is:

  ```bash
  PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests -v
  ```

- Tests require Python 3, FFmpeg, ffprobe, and rsync. The real downloader test also
  needs yt-dlp and its thumbnail dependencies; it skips when yt-dlp is absent.
- Add regression coverage for meaningful behavior changes, especially operations
  that rename, overwrite, or publish files. Documentation-only changes do not
  require running the audio tests.
- Use temporary generated media and simulated remote services for tests. Do not
  use the real music library or upload to a real server as routine verification.
- Report missing tools, skipped tests, and failures clearly.

## Configuration and documentation

- `.env` contains private local configuration. Do not expose its contents in
  responses, logs, tests, or committed files. Use placeholders in examples.
- Do not run `setup.sh` as a routine check: it changes links in `~/bin`.
- When adding a command, update its registration in `setup.sh` and its README
  usage together.
- Document behavior available in this checkout; do not promise pending features.

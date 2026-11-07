"""Offline integration checks: real FFmpeg audio, artwork, tags, and rsync filters."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

REPO = Path(__file__).resolve().parents[1]


def run(args, **kwargs):
    return subprocess.run(args, check=True, text=True, stdout=subprocess.PIPE,
                          stderr=subprocess.PIPE, **kwargs)


def probe(path):
    return json.loads(run(['ffprobe', '-v', 'error', '-show_streams', '-show_format',
                           '-of', 'json', str(path)]).stdout)


def audio_hash(path):
    data = subprocess.check_output(['ffmpeg', '-v', 'error', '-i', str(path),
                                    '-map', '0:a:0', '-c', 'copy', '-f', 'data', '-'])
    return hashlib.sha256(data).hexdigest()


def tags(path):
    info = probe(path)
    result = {k.lower(): v for k, v in info['format'].get('tags', {}).items()}
    for stream in info['streams']:
        if stream['codec_type'] == 'audio':
            result.update({k.lower(): v for k, v in stream.get('tags', {}).items()})
    return result


class WorkflowTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.repo = self.root / 'repo'
        shutil.copytree(REPO / 'scripts', self.repo / 'scripts')
        (self.repo / '.env').write_text(
            "SERVER='test@example.invalid'\nDEST='/music'\nCATEGORIES='Music'\n"
            "METADATA_NAME_NORMALIZATIONS='Old Artist=>New Artist'\n")
        self.album = self.root / 'New Artist - Test Album'
        self.album.mkdir()
        self.cover = self.root / 'cover.png'
        run(['ffmpeg', '-v', 'error', '-f', 'lavfi', '-i', 'color=c=red:s=32x32',
             '-frames:v', '1', str(self.cover)])
        self.paths = []
        for ext, codec in [('opus', 'libopus'), ('m4a', 'aac')]:
            path = self.album / f'01. test.{ext}'
            run(['ffmpeg', '-v', 'error', '-f', 'lavfi', '-i', 'sine=duration=1',
                 '-c:a', codec, '-metadata', 'title=test song',
                 '-metadata', 'artist=Old Artist', '-metadata', 'disc=2',
                 '-metadata', 'comment=remove me', str(path)])
            self.paths.append(path)
        self.original_audio = {p: audio_hash(p) for p in self.paths}

    def tearDown(self):
        self.temp.cleanup()

    def script(self, name, *args, **kwargs):
        return run(['bash', str(self.repo / 'scripts' / name), *args],
                   cwd=self.album, **kwargs)

    def assert_art(self, path):
        images = [s for s in probe(path)['streams'] if s.get('disposition', {}).get('attached_pic')]
        self.assertEqual(len(images), 1)
        return subprocess.check_output(['ffmpeg', '-v', 'error', '-i', str(path),
                                        '-map', f"0:{images[0]['index']}", '-c', 'copy',
                                        '-f', 'image2pipe', '-'])

    def test_tags_artwork_and_audio_preservation(self):
        self.script('audio-cover-art-fix.sh', str(self.cover))
        artwork = {p: self.assert_art(p) for p in self.paths}
        self.script('audio-album-fix.sh', input='y\n')
        self.script('audio-metadata-normalize.sh', '--yes')
        for path in self.paths:
            metadata = tags(path)
            self.assertEqual(metadata['title'], 'Test song')
            self.assertEqual(metadata['artist'], 'New Artist')
            self.assertEqual(metadata['album'], self.album.name)
            self.assertEqual(metadata.get('album_artist', metadata.get('albumartist')), 'New Artist')
            self.assertEqual(int(metadata.get('track', metadata.get('tracknumber'))), 1)
            self.assertFalse(metadata.get('comment'))
            self.assertFalse(metadata.get('disc'))
            self.assertFalse(metadata.get('discnumber'))
            self.assertEqual(self.assert_art(path), artwork[path])
            self.assertEqual(audio_hash(path), self.original_audio[path])
        # Replacing art a second time must leave exactly one embedded picture.
        self.script('audio-cover-art-fix.sh', str(self.cover))
        for path in self.paths:
            self.assert_art(path)
            self.assertEqual(tags(path)['artist'], 'New Artist')
            self.assertEqual(audio_hash(path), self.original_audio[path])

    def test_publish_filters_include_opus(self):
        bindir = self.root / 'bin'
        bindir.mkdir()
        # Exercise the real rsync filters locally; no external upload or SSH.
        (bindir / 'ssh').write_text('#!/bin/sh\nexit 0\n')
        target = self.root / 'published'
        target.mkdir()
        rsync = shutil.which('rsync')
        (bindir / 'rsync').write_text(
            '#!/usr/bin/env python3\nimport os,sys\n'
            f'args=[{rsync!r}]+sys.argv[1:-1]+[{str(target)!r}+"/"]\n'
            'os.execv(args[0], args)\n')
        for path in bindir.iterdir():
            path.chmod(0o755)
        nested = self.album / 'Disc 2'
        nested.mkdir()
        shutil.copy(self.paths[0], nested / '02. Upper.OPUS')
        (self.album / 'private.txt').write_text('excluded')
        env = dict(os.environ, PATH=str(bindir) + ':' + os.environ['PATH'])
        self.script('audio-publish.sh', input='1\ny\n', env=env)
        self.assertTrue((target / self.paths[0].name).exists())
        self.assertTrue((target / self.paths[1].name).exists())
        self.assertTrue((target / 'Disc 2/02. Upper.OPUS').exists())
        self.assertFalse((target / 'private.txt').exists())
        for path in self.paths:
            self.assertEqual(tags(target / path.name)['artist'], 'New Artist')

    def test_large_opus_artwork_and_special_tags(self):
        cover = self.root / 'large.png'
        run(['ffmpeg', '-v', 'error', '-f', 'lavfi', '-i',
             'color=s=512x512,noise=alls=100:allf=t', '-frames:v', '1', str(cover)])
        self.assertGreater(cover.stat().st_size, 128000)
        value = 'A title; with # marks = symbols \\ and\na second line: café'
        run(['python3', str(self.repo / 'scripts/lib/opus-metadata.py'),
             str(self.paths[0]), '--cover', str(cover), '-metadata', 'title=' + value])
        self.assertEqual(tags(self.paths[0])['title'], value)
        self.assertEqual(self.assert_art(self.paths[0]), cover.read_bytes())
        self.assertEqual(audio_hash(self.paths[0]), self.original_audio[self.paths[0]])

    def test_downloader_arguments_and_description(self):
        bindir = self.root / 'bin'
        bindir.mkdir()
        mock = bindir / 'yt-dlp'
        args_file = self.root / 'args.json'
        mock.write_text('#!/usr/bin/env python3\nimport json,sys\n'
                        f'open({str(args_file)!r},"w").write(json.dumps(sys.argv[1:]))\n')
        mock.chmod(0o755)
        env = dict(os.environ, PATH=str(bindir) + ':' + os.environ['PATH'])
        self.script('audio-youtube-download.sh', 'https://example.invalid/video', env=env)
        args = json.loads(args_file.read_text())
        self.assertEqual(args[args.index('-f') + 1], 'bestaudio')
        self.assertEqual(args[args.index('--audio-format') + 1], 'best')
        self.assertIn('--embed-metadata', args)
        self.assertIn('--embed-thumbnail', args)
        self.assertNotIn('--audio-quality', args)
        self.assertTrue(any('%(acodec)s' in a and '%(abr|unknown)s' in a for a in args))
        self.assertTrue(any('after_move:Saved:' in a for a in args))

    def test_real_downloader_with_local_source(self):
        # Feed yt-dlp local media through an info JSON, without contacting YouTube.
        real_downloader = shutil.which('yt-dlp')
        if not real_downloader:
            self.skipTest('yt-dlp not installed')
        webm = self.root / 'source.webm'
        run(['ffmpeg', '-v', 'error', '-i', str(self.paths[0]), '-c:a', 'copy', str(webm)])
        bindir = self.root / 'bin'
        bindir.mkdir()
        info_path = self.root / 'info.json'
        mock = bindir / 'yt-dlp'
        mock.write_text('#!/usr/bin/env python3\nimport os,sys\n'
                        f'args=[{real_downloader!r}, "--ignore-config", "--enable-file-urls",'
                        f' "--load-info-json", {str(info_path)!r}]+sys.argv[1:-2]\n'
                        'os.execv(args[0],args)\n')
        mock.chmod(0o755)
        env = dict(os.environ, PATH=str(bindir) + ':' + os.environ['PATH'])
        for ext, codec, source, abr in [
                ('webm', 'opus', webm, 128),
                ('m4a', 'mp4a.40.2', self.paths[1], None)]:
            info_path.write_text(json.dumps({
                'id': ext, 'title': 'Downloaded ' + ext, 'artist': 'Old Artist',
                'extractor': 'generic', 'extractor_key': 'Generic',
                'webpage_url': 'https://example.invalid/video',
                'thumbnail': self.cover.as_uri(),
                'thumbnails': [{'url': self.cover.as_uri(), 'id': '0', 'ext': 'png'}],
                'formats': [{'format_id': 'audio', 'url': source.as_uri(),
                             'ext': ext, 'acodec': codec, 'vcodec': 'none', 'abr': abr}],
            }))
            result = self.script('audio-youtube-download.sh', 'unused-url', env=env)
            output_ext = 'opus' if codec == 'opus' else 'm4a'
            output = self.album / f'Downloaded {ext} [{ext}].{output_ext}'
            self.assertTrue(output.exists(), result.stdout)
            self.assertEqual(audio_hash(output), self.original_audio[self.paths[0 if codec == 'opus' else 1]])
            self.assertEqual(tags(output)['artist'], 'Old Artist')
            self.assert_art(output)
            self.assertIn(codec, result.stdout)
            self.assertIn('128 kbps' if abr else 'unknown kbps', result.stdout)


if __name__ == '__main__':
    unittest.main()

"""Verify installation and cleanup in an isolated home and repository."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


class SetupTests(unittest.TestCase):
    def test_cleanup_preserves_unrelated_files_and_is_repeatable(self):
        with tempfile.TemporaryDirectory() as temp:
            home = Path(temp)
            repo = home / 'Code' / 'navidrome-tools'
            scripts = repo / 'scripts'
            scripts.mkdir(parents=True)
            source = Path(__file__).resolve().parents[1]
            shutil.copyfile(source / 'setup.sh', repo / 'setup.sh')
            (scripts / 'navidrome-tools.sh').write_text('#!/bin/bash\n')
            bin_dir = home / 'bin'
            bin_dir.mkdir()
            old = home / 'Code' / 'navidrome-stack' / 'scripts'
            for name in ('audio-backup', 'audio-loudness', 'audio-trim'):
                (bin_dir / name).symlink_to(old / (name + '.sh'))
            (bin_dir / 'audio-album-fix').symlink_to(scripts / 'audio-album-fix.sh')
            unrelated = bin_dir / 'audio-publish'
            unrelated.symlink_to('/unrelated/audio-publish.sh')
            regular = bin_dir / 'audio-cover-art-fix'
            regular.write_text('keep me')
            for _ in range(2):
                result = subprocess.run(['bash', str(repo / 'setup.sh')],
                                        env=dict(os.environ, HOME=str(home)),
                                        capture_output=True, text=True)
                self.assertEqual(result.returncode, 0, result.stderr)
                for name in ('audio-backup', 'audio-loudness', 'audio-trim',
                             'audio-album-fix'):
                    self.assertFalse((bin_dir / name).is_symlink())
                self.assertEqual(unrelated.readlink(), Path('/unrelated/audio-publish.sh'))
                self.assertEqual(regular.read_text(), 'keep me')
                self.assertEqual((bin_dir / 'navidrome-tools').readlink(),
                                 scripts / 'navidrome-tools.sh')

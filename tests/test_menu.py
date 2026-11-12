"""Exercise menu routing with fake tools, without processing media."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


class MenuTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.scripts = self.root / 'tool scripts'
        self.scripts.mkdir()
        source = Path(__file__).resolve().parents[1] / 'scripts/navidrome-tools.sh'
        shutil.copyfile(source, self.scripts / source.name)
        self.launcher = self.root / 'navidrome-tools'
        self.launcher.symlink_to(Path('tool scripts') / source.name)
        self.album = self.root / 'Artist - Album'
        self.album.mkdir()
        self.log = self.root / 'calls.jsonl'
        for name in ('youtube-download', 'filename-fix', 'flac-to-m4a',
                     'alac-to-aac', 'album-fix', 'cover-art-fix', 'trim',
                     'metadata-normalize', 'publish'):
            (self.scripts / f'audio-{name}.sh').write_text(
                '#!/bin/bash\npython3 - "$0" "$@" <<\'PY\'\n'
                'import json, os, sys\n'
                'with open(os.environ["MENU_TEST_LOG"], "a") as f:\n'
                '    f.write(json.dumps([os.getcwd(), sys.argv[1:]]) + "\\n")\n'
                'PY\n'
                + ('exit 7\n' if name == 'filename-fix' else '')
            )

    def run_menu(self, text, status=0):
        result = subprocess.run(
            ['bash', str(self.launcher)], input=text, text=True,
            cwd=self.album, env=dict(os.environ, MENU_TEST_LOG=str(self.log)),
            capture_output=True, timeout=10,
        )
        self.assertEqual(result.returncode, status, result.stderr)
        return result.stdout

    def calls(self):
        return [json.loads(line) for line in self.log.read_text().splitlines()]

    def test_actions_exit_after_one_command(self):
        cases = [
            ('1\nhttps://example.test/watch?v=1&list=2\n',
             'audio-youtube-download', ['https://example.test/watch?v=1&list=2']),
            ('3\n', 'audio-flac-to-m4a', []),
            ('4\n', 'audio-alac-to-aac', []),
            ('5\nMy Album\nMy Artist\nSoundtrack\n', 'audio-album-fix',
             ['--album', 'My Album', '--artist', 'My Artist', '--genre', 'Soundtrack']),
            ('5\n\n\n\n', 'audio-album-fix', []),
            ('6\nart work.jpg\n', 'audio-cover-art-fix', ['art work.jpg']),
            ('7\ninput song.opus\n00:01\n02:30\noutput song.m4a\n',
             'audio-trim', ['input song.opus', '00:01', '02:30', 'output song.m4a']),
            ('8\n1\n', 'audio-metadata-normalize', ['--dry-run']),
            ('8\n2\n', 'audio-metadata-normalize', []),
            ('9\n', 'audio-publish', []),
        ]
        for text, name, arguments in cases:
            with self.subTest(name=name, arguments=arguments):
                self.log.unlink(missing_ok=True)
                output = self.run_menu(text + '9\n0\n')
                self.assertEqual(output.count('Navidrome tools — folder:'), 1)
                calls = self.calls()
                self.assertEqual(len(calls), 1)
                folder, args = calls[0]
                self.assertEqual(folder, str(self.album.resolve()))
                self.assertEqual(Path(args[0]).stem, name)
                self.assertEqual(args[1:], arguments)

    def test_invalid_input_retries(self):
        output = self.run_menu('invalid\n0\n')
        self.assertIn('Invalid option', output)
        self.assertFalse(self.log.exists())

    def test_cancellation_and_eof_exit(self):
        for text in ('', '0\n', '1\n\n', '6\n\n', '7\n\n', '8\n0\n'):
            with self.subTest(text=text):
                output = self.run_menu(text + ('9\n' if text else ''))
                self.assertEqual(output.count('Navidrome tools — folder:'), 1)
                self.assertFalse(self.log.exists())

    def test_failure_exits_with_command_status(self):
        output = self.run_menu('2\n9\n0\n', status=7)
        self.assertIn('exit code 7', output)
        self.assertEqual(output.count('Navidrome tools — folder:'), 1)
        self.assertEqual(len(self.calls()), 1)


if __name__ == '__main__':
    unittest.main()

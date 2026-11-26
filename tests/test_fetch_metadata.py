import os
from pathlib import Path
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / 'git-fetch-remote.sh'


class FetchMetadataTest(unittest.TestCase):
    def test_fetch_url_survives_other_metadata(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / 'source'
            source.mkdir()
            def git(*args):
                return subprocess.run(['git', '-C', str(source), *args], check=True,
                                      capture_output=True, text=True)
            git('init', '-b', 'master')
            git('-c', 'user.name=Test', '-c', 'user.email=test@example.invalid',
                'commit', '--allow-empty', '-m', 'Initial')
            (root / 'build').mkdir()
            subprocess.run(['sh', str(SCRIPT), 'checkout', str(source),
                            str(source), '-', 'master', '-'], cwd=root,
                           check=True, capture_output=True, text=True)
            result = subprocess.run(['sh', '-c',
                '. ./build/prop.checkout; printf "%s\\n%s\\n" "$fetch_url" "$git_repo"'],
                cwd=root, check=True, capture_output=True, text=True)
            self.assertEqual(result.stdout.splitlines(), [str(source), 'source'])

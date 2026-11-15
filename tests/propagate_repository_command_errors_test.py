from pathlib import Path
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / 'repos_cmd'

class RepositoryCommandStatusTest(unittest.TestCase):
    def test_failed_repository_is_not_hidden_by_a_later_success(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'build').mkdir()
            for name in ('a', 'b'):
                (root / 'sources' / name).mkdir(parents=True)
                (root / 'build' / ('prop.' + name)).write_text('')
            for quiet in ([], ['-q']):
                result = subprocess.run(['sh', str(SCRIPT), *quiet,
                    'echo "$repo"; test "$repo" != sources/a'], cwd=root,
                    capture_output=True, text=True)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn('sources/b', result.stdout)
                result = subprocess.run(['sh', str(SCRIPT), *quiet, 'true'],
                    cwd=root, capture_output=True, text=True)
                self.assertEqual(result.returncode, 0)

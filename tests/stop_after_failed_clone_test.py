from pathlib import Path
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / 'git-fetch-remote.sh'

class FailedCloneTest(unittest.TestCase):
    def test_failed_clone_does_not_retarget_existing_repository(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            target = root / 'target'
            (root / 'build').mkdir()
            subprocess.run(['git', 'init', '-b', 'master', str(target)], check=True,
                           capture_output=True)
            subprocess.run(['git', '-C', str(target), 'remote', 'add', 'origin',
                            '/original/fetch'], check=True)
            subprocess.run(['git', '-C', str(target), 'remote', 'set-url', '--push',
                            'origin', '/original/push'], check=True)
            result = subprocess.run(['sh', str(SCRIPT), 'target', str(root/'missing'),
                '/replacement/push', '-', '-', '-'], cwd=root, capture_output=True)
            self.assertNotEqual(result.returncode, 0)
            push = subprocess.check_output(['git', '-C', str(target), 'remote',
                                           'get-url', '--push', 'origin'], text=True)
            self.assertEqual(push.strip(), '/original/push')

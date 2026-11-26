from pathlib import Path
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / 'git-fetch-remote.sh'

class UpstreamBranchPathTest(unittest.TestCase):
    def test_slash_containing_branch_is_preserved(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / 'source'
            source.mkdir()
            subprocess.run(['git', 'init', '-b', 'master', str(source)], check=True,
                           capture_output=True)
            subprocess.run(['git', '-C', str(source), '-c', 'user.name=Test',
                '-c', 'user.email=test@example.invalid', 'commit', '--allow-empty',
                '-m', 'Initial'], check=True, capture_output=True)
            (root / 'build').mkdir()
            subprocess.run(['sh', str(SCRIPT), 'checkout', str(source), str(source),
                str(source), 'master', 'origin/feature/test'], cwd=root,
                check=True, capture_output=True)
            result = subprocess.run(['sh', '-c', '. ./build/prop.checkout; '
                'printf "%s\n%s\n" "$upstream_full_branch" "$upstream_branch"'],
                cwd=root, check=True, capture_output=True, text=True)
            self.assertEqual(result.stdout.splitlines(),
                             ['origin/feature/test', 'feature/test'])

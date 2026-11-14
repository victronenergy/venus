"""Exercise real recipe methods and temp files without network downloads."""
import ast
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch


def load_recipe():
    script = Path(__file__).resolve().parents[1] / 'update-recipe.py'
    tree = ast.parse(script.read_text())
    definitions = [n for n in tree.body if isinstance(n, (
        ast.Import, ast.ImportFrom, ast.FunctionDef, ast.ClassDef))]
    namespace = {'verbose': False, 'git': False}
    exec(compile(ast.Module(body=definitions, type_ignores=[]), str(script), 'exec'), namespace)
    return namespace['Recipe']


class DownloadCleanupTests(unittest.TestCase):
    def exercise(self, failure=None):
        recipe_class = load_recipe()
        with tempfile.TemporaryDirectory() as root:
            root = Path(root)
            scratch = root / 'scratch'
            scratch.mkdir()
            recipe_file = root / 'package_1.0.bb'
            original = 'SRC_URI = "https://example.invalid/package-${PV}.tar.gz"\nSRC_URI[sha256sum] = "old"\n'
            recipe_file.write_text(original)
            recipe = recipe_class(str(recipe_file))
            descriptors = []
            mkstemp = tempfile.mkstemp

            def tracked_mkstemp(*args, **kwargs):
                fd, name = mkstemp(*args, **kwargs)
                descriptors.append(fd)
                return fd, name

            def run(command, **kwargs):
                if command[0] == 'wget':
                    Path(command[2]).write_bytes(b'partial or complete archive')
                    if failure == 'exception':
                        raise OSError('synthetic download error')
                    return subprocess.CompletedProcess(command, int(failure == 'download'))
                self.assertEqual(command[0], 'sha256sum')
                return subprocess.CompletedProcess(command, int(failure == 'checksum'),
                                                   stdout='newhash  archive\n')

            try:
                with patch.object(tempfile, 'tempdir', str(scratch)), \
                     patch.object(tempfile, 'mkstemp', tracked_mkstemp), \
                     patch.object(subprocess, 'run', run):
                    if failure == 'exception':
                        with self.assertRaises(OSError):
                            recipe.update_https_by_pv('2.0')
                    else:
                        self.assertEqual(recipe.update_https_by_pv('2.0'), failure is None)
                if failure is not None:
                    self.assertEqual(recipe._content, original)
                    self.assertEqual(recipe._known_pv, '1.0')
                else:
                    self.assertIn('newhash', recipe._content)
                    self.assertEqual(recipe._known_pv, '2.0')
                open_descriptors = []
                for fd in descriptors:
                    try:
                        os.fstat(fd)
                        open_descriptors.append(fd)
                    except OSError:
                        pass
                self.assertEqual((list(scratch.iterdir()), open_descriptors), ([], []))
            finally:
                for fd in descriptors:
                    try:
                        os.close(fd)
                    except OSError:
                        pass

    def test_success(self):
        self.exercise()

    def test_download_failure(self):
        self.exercise('download')

    def test_checksum_failure(self):
        self.exercise('checksum')

    def test_download_exception(self):
        self.exercise('exception')


if __name__ == '__main__':
    unittest.main()

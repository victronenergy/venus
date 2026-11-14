"""Resolve source tags against a real local Git repository, without network access."""

import ast
from pathlib import Path
import subprocess
import tempfile
import unittest


def load_get_src_rev():
    script = Path(__file__).resolve().parents[1] / 'update-recipe.py'
    tree = ast.parse(script.read_text())
    function = next(node for node in tree.body if isinstance(node, ast.FunctionDef) and node.name == 'get_src_rev')
    namespace = {'subprocess': subprocess, 'info': lambda *args: None}
    exec(compile(ast.Module(body=[function], type_ignores=[]), str(script), 'exec'), namespace)
    return namespace['get_src_rev']


class SourceTagRevisionTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.get_src_rev = staticmethod(load_get_src_rev())

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.git('init', '-q')
        self.git('config', 'user.name', 'Synthetic Test')
        self.git('config', 'user.email', 'test@example.invalid')
        self.git('config', 'commit.gpgsign', 'false')
        self.git('config', 'tag.gpgsign', 'false')
        (self.root / 'version').write_text('release')
        self.git('add', 'version')
        self.git('commit', '-qm', 'release')
        self.release = self.git('rev-parse', 'HEAD')

    def git(self, *args):
        return subprocess.check_output(['git', *args], cwd=self.root, text=True).strip()

    def test_lightweight_tag(self):
        self.git('tag', 'v1.0')
        self.assertEqual(self.get_src_rev(str(self.root), 'v1.0'), self.release)

    def test_annotated_tag_resolves_to_commit(self):
        self.git('tag', '-a', 'v1.0', '-m', 'release tag')
        self.assertEqual(self.get_src_rev(str(self.root), 'v1.0'), self.release)

    def test_same_named_branch_cannot_override_tag(self):
        self.git('tag', 'v1.0')
        (self.root / 'version').write_text('unreleased')
        self.git('commit', '-qam', 'unreleased branch work')
        self.git('branch', 'v1.0')
        self.assertNotEqual(self.git('rev-parse', 'refs/heads/v1.0'), self.release)
        self.assertEqual(self.get_src_rev(str(self.root), 'v1.0'), self.release)

    def test_branch_without_tag_is_not_a_release_tag(self):
        self.git('branch', 'v1.0')
        self.assertIsNone(self.get_src_rev(str(self.root), 'v1.0'))

    def test_missing_tag(self):
        self.assertIsNone(self.get_src_rev(str(self.root), 'missing'))

    def test_qualified_tag_name(self):
        self.git('tag', 'v1.0')
        self.assertEqual(self.get_src_rev(str(self.root), 'refs/tags/v1.0'), self.release)


if __name__ == '__main__':
    unittest.main()

"""Run the real recipe updater against temporary recipes and synthetic Git replies."""

import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


REVISION = '1234567890abcdef1234567890abcdef12345678'


class RecipeTagLookupFailureTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.script = Path(__file__).resolve().parents[1] / 'update-recipe.py'
        bindir = self.root / 'bin'
        bindir.mkdir()
        git = bindir / 'git'
        git.write_text('''#!/bin/sh
if [ "$1" != ls-remote ]; then exit 99; fi
if [ "$TEST_TAG_FOUND" = yes ]; then
    printf '%s\\trefs/tags/v1.0\\n' "$TEST_REVISION"
fi
''')
        git.chmod(0o755)
        self.env = dict(os.environ, PATH=str(bindir) + os.pathsep + os.environ['PATH'], TEST_REVISION=REVISION)

    def run_update(self, found, extra=''):
        self.recipe = self.root / 'demo_1.0.bb'
        self.original = 'SRC_URI = "git://example.invalid/demo;tag=v${PV}"\n' + extra
        self.recipe.write_text(self.original)
        return subprocess.run([sys.executable, str(self.script), '--save', str(self.recipe)],
                              cwd=self.root, env=dict(self.env, TEST_TAG_FOUND='yes' if found else 'no'),
                              capture_output=True, text=True, timeout=10)

    def test_missing_tag_fails_without_changing_recipe(self):
        result = self.run_update(False)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.recipe.read_text(), self.original)

    def test_missing_tag_does_not_change_existing_revision_recipe(self):
        result = self.run_update(False, 'SRCREV = "old-revision"\n')
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.recipe.read_text(), self.original)

    def test_found_tag_saves_pinned_revision(self):
        result = self.run_update(True)
        self.assertEqual(result.returncode, 0, result.stderr)
        contents = self.recipe.read_text()
        self.assertNotIn(';tag=', contents)
        self.assertIn('SRCREV = "' + REVISION + '"', contents)

    def test_found_tag_updates_existing_revision(self):
        result = self.run_update(True, 'SRCREV = "old-revision"\n')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn('old-revision', self.recipe.read_text())
        self.assertIn('SRCREV = "' + REVISION + '"', self.recipe.read_text())


if __name__ == '__main__':
    unittest.main()

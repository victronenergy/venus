"""Run backport helpers against disposable local Git repositories."""
import ast
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch


def load_helpers():
    script = Path(__file__).resolve().parents[1] / 'backport.py'
    tree = ast.parse(script.read_text())
    definitions = [n for n in tree.body if isinstance(n, (
        ast.Import, ast.ImportFrom, ast.FunctionDef))]
    namespace = {}
    exec(compile(ast.Module(body=definitions, type_ignores=[]), str(script), 'exec'), namespace)
    return namespace


class BackportGitErrorsTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.repo = Path(self.temp.name) / 'repo'
        self.repo.mkdir()
        self.git('init', '-q')
        for key, value in (
            ('user.name', 'Synthetic Test'), ('user.email', 'test@example.invalid'),
            ('commit.gpgsign', 'false'), ('core.hooksPath', str(self.repo / 'hooks')),
        ):
            self.git('config', key, value)
        (self.repo / 'initial').write_text('initial')
        self.git('add', '.')
        self.git('commit', '-qm', 'initial')
        self.initial = self.git('rev-parse', 'HEAD')
        self.helpers = load_helpers()
        self.editor = patch.dict(os.environ, {'GIT_EDITOR': 'true'})
        self.editor.start()
        self.addCleanup(self.editor.stop)

    def git(self, *args):
        return subprocess.check_output(['git', '-C', str(self.repo), *args],
                                       text=True, stderr=subprocess.PIPE).strip()

    def test_import_rejects_missing_revision(self):
        target = Path(self.temp.name) / 'target'
        target.mkdir()
        with self.assertRaises(subprocess.CalledProcessError):
            self.helpers['import_bb_dir'](str(self.repo), str(target), 'missing-revision', 'initial')
        self.assertEqual(list(target.iterdir()), [])

    def test_import_rejects_missing_path(self):
        target = Path(self.temp.name) / 'target'
        target.mkdir()
        with self.assertRaises(subprocess.CalledProcessError):
            self.helpers['import_bb_dir'](str(self.repo), str(target), 'HEAD', 'absent')

    def test_successful_import(self):
        target = Path(self.temp.name) / 'target'
        target.mkdir()
        self.helpers['import_bb_dir'](str(self.repo), str(target), 'HEAD', 'initial')
        self.assertEqual((target / 'initial').read_text(), 'initial')

    def test_failed_add_does_not_commit_unrelated_staged_work(self):
        (self.repo / 'unrelated').write_text('keep staged')
        self.git('add', 'unrelated')
        with self.assertRaises(subprocess.CalledProcessError):
            self.helpers['git_commit_dir'](str(self.repo), 'absent', 'import failed')
        self.assertEqual(self.git('rev-parse', 'HEAD'), self.initial)
        self.assertEqual(self.git('diff', '--cached', '--name-only'), 'unrelated')

    def test_failed_commit_is_reported(self):
        (self.repo / 'package').write_text('new recipe')
        hooks = self.repo / 'hooks'
        hooks.mkdir()
        hook = hooks / 'pre-commit'
        hook.write_text('#!/bin/sh\nexit 1\n')
        hook.chmod(0o755)
        with self.assertRaises(subprocess.CalledProcessError):
            self.helpers['git_commit_dir'](str(self.repo), 'package', 'import package')
        self.assertEqual(self.git('rev-parse', 'HEAD'), self.initial)

    def test_successful_commit(self):
        (self.repo / 'package').write_text('new recipe')
        self.helpers['git_commit_dir'](str(self.repo), 'package', 'import package')
        self.assertEqual(self.git('log', '-1', '--format=%s'), 'import package')
        self.assertEqual(self.git('show', 'HEAD:package'), 'new recipe')


if __name__ == '__main__':
    unittest.main()

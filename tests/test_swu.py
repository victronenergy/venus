"""Exercise the actual upload script with synthetic files and an SSH stand-in."""

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


class SwuExitStatusTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        shutil.copyfile(Path(__file__).resolve().parents[1] / 'swu.sh', self.root / 'swu.sh')
        bindir = self.root / 'bin'
        bindir.mkdir()
        ssh = bindir / 'ssh'
        ssh.write_text('''#!/bin/sh
case "$*" in *root@offline*) exit 42 ;; esac
case "$*" in
    *image-type*) echo normal ;;
    *swu-name*) echo venus-image ;;
    *venus/machine*) echo test-machine ;;
    *check-updates.sh*)
        cat >/dev/null
        printf '%s\\n' "$*" >> "$SWU_TEST_CALLS"
        case "$*" in *root@bad*) exit 42 ;; *) exit 0 ;; esac
        ;;
    *) exit 99 ;;
esac
''')
        ssh.chmod(0o755)
        self.calls = self.root / 'calls'
        self.env = dict(os.environ, PATH=str(bindir) + os.pathsep + os.environ['PATH'], SWU_TEST_CALLS=str(self.calls))

    def add_update(self):
        directory = self.root / 'deploy/venus/images/test-machine'
        directory.mkdir(parents=True)
        filename = 'venus-image-20261114000000-test-machine.swu'
        (directory / filename).write_bytes(b'synthetic update data')
        (directory / 'venus-image-test-machine.swu').symlink_to(filename)

    def run_upload(self, *hosts):
        return subprocess.run(['bash', './swu.sh', *hosts], cwd=self.root, env=self.env,
                              capture_output=True, text=True, timeout=10)

    def test_no_targets_keeps_usage_success(self):
        result = self.run_upload()
        self.assertEqual(result.returncode, 0)
        self.assertIn('host1 [host2 ...]', result.stdout)
        self.assertFalse(self.calls.exists())

    def test_missing_update_is_failure(self):
        result = self.run_upload('good')
        self.assertIn("the file doesn't exist", result.stdout)
        self.assertNotEqual(result.returncode, 0)

    def test_failed_metadata_query_is_failure(self):
        self.add_update()
        self.assertNotEqual(self.run_upload('offline').returncode, 0)

    def test_failed_upload_is_failure(self):
        self.add_update()
        self.assertNotEqual(self.run_upload('bad').returncode, 0)

    def test_all_successful_uploads_succeed(self):
        self.add_update()
        self.assertEqual(self.run_upload('good', 'also-good').returncode, 0)
        self.assertEqual(len(self.calls.read_text().splitlines()), 2)

    def test_mixed_results_fail_and_wait_for_all_targets(self):
        self.add_update()
        for hosts in (('bad', 'good'), ('good', 'bad')):
            with self.subTest(hosts=hosts):
                self.calls.unlink(missing_ok=True)
                self.assertNotEqual(self.run_upload(*hosts).returncode, 0)
                self.assertEqual(len(self.calls.read_text().splitlines()), 2)


if __name__ == '__main__':
    unittest.main()

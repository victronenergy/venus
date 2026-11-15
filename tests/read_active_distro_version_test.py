from pathlib import Path
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / 'venus-version.sh'

class ActiveVersionTest(unittest.TestCase):
    def test_only_active_version_is_reported(self):
        for folder in ('checkout', 'checkout with spaces'):
            with self.subTest(folder=folder), tempfile.TemporaryDirectory() as directory:
                root = Path(directory) / folder
                conf = root/'sources/meta-victronenergy/meta-venus/conf/distro/venus.conf'
                conf.parent.mkdir(parents=True)
                conf.write_text('# DISTRO_VERSION = "old"\n'
                    'MY_DISTRO_VERSION = "other"\n'
                    '  DISTRO_VERSION = "v3.99" # release\n')
                script = root/'venus-version.sh'
                script.write_text(SCRIPT.read_text())
                result = subprocess.run(['sh', str(script)], check=True,
                                        capture_output=True, text=True)
                self.assertEqual(result.stdout, 'v3.99\n')

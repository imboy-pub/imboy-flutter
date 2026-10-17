"""Native host setup resolves the selected package on Linux and macOS."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[2] / '.github/scripts/ci_build_vod.sh'


class HostCryptoBuildTest(unittest.TestCase):
    def test_builds_resolved_package_for_each_host(self):
        for host, suffix in [('Linux', 'so'), ('Darwin', 'dylib')]:
            with self.subTest(host=host), tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp)
                repo = root / 'app'
                repo.mkdir()
                subprocess.run(['git', 'init', '-q', str(repo)], check=True)
                config = repo / '.dart_tool'
                config.mkdir()
                crate = root / 'custom pub cache' / 'selected plugin' / 'rust'
                crate.mkdir(parents=True)
                (crate / 'Cargo.toml').write_text('[package]\nname="fixture"\n')
                (config / 'package_config.json').write_text(json.dumps({
                    'packages': [{'name': 'flutter_vodozemac',
                                  'rootUri': crate.parent.as_uri() + '/'}],
                }))
                bin_dir = root / 'bin'
                bin_dir.mkdir()
                (bin_dir / 'uname').write_text(f'#!/bin/sh\necho {host}\n')
                (bin_dir / 'cargo').write_text('''#!/usr/bin/env python3
import os
from pathlib import Path
import sys
args = sys.argv
assert Path(args[args.index('--manifest-path') + 1]) == Path(os.environ['EXPECTED_CRATE']) / 'Cargo.toml'
release = Path(args[args.index('--target-dir') + 1]) / 'release'
release.mkdir(parents=True)
(release / ('libvodozemac_bindings_dart.' + os.environ['EXPECTED_SUFFIX'])).write_text('synthetic-library')
''')
                for stub in bin_dir.iterdir():
                    stub.chmod(0o755)
                env_file = root / 'github_env'
                env = dict(os.environ, PATH=f'{bin_dir}:{os.environ["PATH"]}',
                           GITHUB_ENV=str(env_file), EXPECTED_CRATE=str(crate),
                           EXPECTED_SUFFIX=suffix)
                subprocess.run(['bash', str(SCRIPT)], cwd=repo, env=env,
                               check=True, capture_output=True, text=True)
                destination = root / 'spikes/e2ee-group/rust/target/release'
                self.assertEqual(
                    (destination / f'libvodozemac_bindings_dart.{suffix}').read_text(),
                    'synthetic-library',
                )
                self.assertEqual(env_file.read_text(),
                                 f'FRB_DART_LOAD_EXTERNAL_LIBRARY_NATIVE_LIB_DIR={destination}/\n')


if __name__ == '__main__':
    unittest.main()

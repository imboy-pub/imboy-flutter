"""Pinned submodule checkout retries transport errors and rejects false success."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[2] / '.github/scripts/ci_checkout_submodules.sh'
MODULE = 'plugin/chat'

GIT_WRAPPER = r'''#!/usr/bin/env python3
import json
import os
from pathlib import Path
import subprocess
import sys

args = sys.argv[1:]
real = os.environ['FIXTURE_REAL_GIT']
if any(args[i:i + 2] == ['submodule', 'update'] for i in range(len(args))):
    record = Path(os.environ['FIXTURE_CALLS'])
    previous = record.read_text().splitlines() if record.exists() else []
    with record.open('a') as output:
        output.write(json.dumps(args) + '\n')
    mode = os.environ['FIXTURE_MODE']
    if mode == 'fail_always' or (mode == 'fail_once' and not previous):
        print('fatal: synthetic transport failure', file=sys.stderr)
        sys.exit(128)
    if mode == 'missing':
        sys.exit(0)
    if mode in ('wrong', 'dirty', 'index_override'):
        code = subprocess.call([real, *args])
        if code:
            sys.exit(code)
        module = os.environ['FIXTURE_MODULE']
        if mode == 'dirty':
            Path(module, 'content.txt').write_text('unexpected source change\n')
        else:
            newer = os.environ['FIXTURE_NEWER']
            subprocess.run([real, '-C', module, 'checkout', '-q', '--detach', newer], check=True)
            if mode == 'index_override':
                subprocess.run([real, 'update-index', '--cacheinfo',
                                f'160000,{newer},{module}'], check=True)
        sys.exit(0)
os.execv(real, [real, *args])
'''


class SubmoduleCheckoutTest(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.real_git = shutil.which('git')
        self.env = dict(os.environ, GIT_CONFIG_GLOBAL=os.devnull,
                        GIT_CONFIG_NOSYSTEM='1', GIT_ALLOW_PROTOCOL='file',
                        GIT_TERMINAL_PROMPT='0')
        source = self.root / 'source'
        self.app = self.root / 'app'
        for repository in (source, self.app):
            self.git('init', '-q', str(repository))
            self.git('-C', str(repository), 'config', 'user.name', 'CI Fixture')
            self.git('-C', str(repository), 'config', 'user.email', 'fixture@example.invalid')
        content = source / 'content.txt'
        content.write_text('pinned source\n')
        self.git('-C', str(source), 'add', 'content.txt')
        self.git('-C', str(source), 'commit', '-qm', 'Pinned source')
        self.pinned = self.git('-C', str(source), 'rev-parse', 'HEAD').strip()
        content.write_text('newer source must not replace the pin\n')
        self.git('-C', str(source), 'commit', '-qam', 'Newer source')
        newer = self.git('-C', str(source), 'rev-parse', 'HEAD').strip()
        remote = self.root / 'remote.git'
        self.git('clone', '--bare', '-q', str(source), str(remote))
        self.gitmodules = f'[submodule "{MODULE}"]\n\tpath = {MODULE}\n\turl = {remote.as_uri()}\n'
        (self.app / '.gitmodules').write_text(self.gitmodules)
        self.git('add', '.gitmodules', cwd=self.app)
        self.git('update-index', '--add', '--cacheinfo', f'160000,{self.pinned},{MODULE}', cwd=self.app)
        self.git('commit', '-qm', 'Pin dependency', cwd=self.app)
        bin_dir = self.root / 'bin'
        bin_dir.mkdir()
        (bin_dir / 'git').write_text(GIT_WRAPPER)
        (bin_dir / 'sleep').write_text('#!/bin/sh\nprintf "%s\\n" "$1" >> "$FIXTURE_DELAYS"\n')
        for executable in bin_dir.iterdir():
            executable.chmod(0o755)
        self.calls_file = self.root / 'calls.jsonl'
        self.delays_file = self.root / 'delays.txt'
        self.env.update(PATH=f'{bin_dir}:{os.environ["PATH"]}',
                        FIXTURE_REAL_GIT=self.real_git, FIXTURE_CALLS=str(self.calls_file),
                        FIXTURE_DELAYS=str(self.delays_file), FIXTURE_MODULE=MODULE,
                        FIXTURE_NEWER=newer)

    def git(self, *args, cwd=None):
        return subprocess.run([self.real_git, *args], cwd=cwd, env=self.env,
                              check=True, capture_output=True, text=True).stdout

    def run_checkout(self, mode='ok', args=()):
        result = subprocess.run(['bash', str(SCRIPT), *args], cwd=self.app,
                                env=dict(self.env, FIXTURE_MODE=mode),
                                capture_output=True, text=True, timeout=30)
        calls = [json.loads(line) for line in self.calls_file.read_text().splitlines()] \
            if self.calls_file.exists() else []
        delays = self.delays_file.read_text().splitlines() if self.delays_file.exists() else []
        self.assertEqual((self.app / '.gitmodules').read_text(), self.gitmodules)
        self.assertEqual(self.git('rev-parse', f'HEAD:{MODULE}', cwd=self.app).strip(), self.pinned)
        return result, calls, delays

    def assert_pinned(self):
        self.assertEqual(self.git('-C', str(self.app / MODULE), 'rev-parse', 'HEAD').strip(), self.pinned)
        self.assertEqual((self.app / MODULE / 'content.txt').read_text(), 'pinned source\n')

    def test_default_depth_fetches_exact_pin_once(self):
        result, calls, delays = self.run_checkout()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assert_pinned()
        self.assertEqual(len(calls), 1)
        self.assertIn('--depth=1', calls[0])
        self.assertEqual(delays, [])
        self.assertEqual(self.git('-C', str(self.app / MODULE), 'rev-parse', '--is-shallow-repository').strip(), 'true')

    def test_zero_depth_keeps_full_history(self):
        result, calls, delays = self.run_checkout(args=('0',))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assert_pinned()
        self.assertEqual(len(calls), 1)
        self.assertFalse(any(arg.startswith('--depth') for arg in calls[0]))
        self.assertEqual(delays, [])
        self.assertEqual(self.git('-C', str(self.app / MODULE), 'rev-parse', '--is-shallow-repository').strip(), 'false')

    def test_transient_failure_recovers_at_same_commit(self):
        result, calls, delays = self.run_checkout('fail_once')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assert_pinned()
        self.assertEqual(len(calls), 2)
        self.assertEqual(delays, ['10'])
        self.assertIn('synthetic transport failure', result.stderr)

    def test_failure_exhausts_budget_and_preserves_git_exit_code(self):
        result, calls, delays = self.run_checkout('fail_always')
        self.assertEqual(result.returncode, 128, result.stderr)
        self.assertEqual(len(calls), 3)
        self.assertEqual(delays, ['10', '20'])
        self.assertIn('::error::Submodule checkout failed after 3 attempts', result.stderr)

    def test_missing_remote_commit_fails_without_using_branch_tip(self):
        self.pinned = 'f' * 40
        self.git('update-index', '--cacheinfo', f'160000,{self.pinned},{MODULE}', cwd=self.app)
        self.git('commit', '-qm', 'Unavailable pin', cwd=self.app)
        result, calls, delays = self.run_checkout()
        self.assertEqual(result.returncode, 128, result.stderr)
        self.assertEqual(len(calls), 3)
        self.assertEqual(delays, ['10', '20'])
        self.assertIn(self.pinned, result.stdout + result.stderr)
        self.assertNotIn('[ci_submodules] Verified', result.stdout)

    def assert_integrity_failure(self, mode):
        result, calls, delays = self.run_checkout(mode)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(len(calls), 1)
        self.assertEqual(delays, [])
        self.assertIn('::error::', result.stderr)

    def test_rejects_uninitialized_submodule_after_false_success(self):
        self.assert_integrity_failure('missing')

    def test_rejects_wrong_commit_after_update(self):
        self.assert_integrity_failure('wrong')

    def test_checks_parent_commit_even_when_index_matches_wrong_commit(self):
        self.assert_integrity_failure('index_override')

    def test_rejects_modified_tracked_source(self):
        self.assert_integrity_failure('dirty')

    def test_rejects_invalid_arguments_without_fetching(self):
        for args in [('2',), ('0', '1')]:
            with self.subTest(args=args):
                result, calls, delays = self.run_checkout(args=args)
                self.assertEqual(result.returncode, 64)
                self.assertEqual(calls, [])
                self.assertEqual(delays, [])


if __name__ == '__main__':
    unittest.main()

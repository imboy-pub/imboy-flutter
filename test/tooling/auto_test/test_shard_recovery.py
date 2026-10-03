"""Read-only recovery tests use synthetic journals and log files."""
import hashlib
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[3] / 'scripts'))
from auto_test_lib import shard_recovery


class ShardRecoveryTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / 'synthetic').mkdir()
        self.start = {'attempt_id': 'synthetic-1', 'fingerprint': {'synthetic': True}}
        self.write('starts.jsonl', [self.start])
        (self.root / 'synthetic/events').write_bytes(b'synthetic log')
        self.record = dict(self.start, events='synthetic/events',
                           events_sha256=hashlib.sha256(b'synthetic log').hexdigest())

    def write(self, name, rows):
        (self.root / 'synthetic' / name).write_text(''.join(json.dumps(r) + '\n' for r in rows))

    def audit(self):
        before = {p: p.read_bytes() for p in self.root.rglob('*') if p.is_file()}
        result = shard_recovery.inspect_target_journal(self.root, 'synthetic')
        self.assertEqual(before, {p: p.read_bytes() for p in self.root.rglob('*') if p.is_file()})
        self.assertIs(result['product_pass'], False)
        return result

    def test_started_without_completion_is_incomplete(self):
        self.assertEqual(self.audit()['state'], 'INCOMPLETE')

    def test_completed_matches_start_and_actual_log(self):
        self.write('attempts.jsonl', [self.record])
        self.assertEqual(self.audit()['state'], 'COMPLETED')

    def test_missing_tail_completion_is_incomplete(self):
        self.write('starts.jsonl', [self.start, dict(self.start, attempt_id='synthetic-2')])
        self.write('attempts.jsonl', [self.record])
        result = self.audit()
        self.assertEqual((result['state'], result['unfinished']), ('INCOMPLETE', 1))

    def test_unknown_duplicate_and_changed_fingerprint_are_invalid(self):
        for rows in [[dict(self.record, attempt_id='unknown')], [self.record] * 2,
                     [dict(self.record, fingerprint={'changed': True})],
                     [dict(self.record, fingerprint={'synthetic': 1})]]:
            self.write('attempts.jsonl', rows)
            self.assertEqual(self.audit()['state'], 'INVALID')

    def test_event_tamper_and_escape_are_invalid(self):
        self.write('attempts.jsonl', [self.record])
        (self.root / 'synthetic/events').write_text('modified')
        self.assertEqual(self.audit()['state'], 'INVALID')
        self.write('attempts.jsonl', [dict(self.record, events='../secret-marker')])
        result = self.audit()
        self.assertEqual(result['state'], 'INVALID')
        self.assertNotIn('secret-marker', str(result))

    def test_journal_symlink_is_rejected(self):
        p = self.root / 'synthetic/attempts.jsonl'
        p.symlink_to(self.root / 'synthetic/starts.jsonl')
        self.assertEqual(self.audit()['state'], 'INVALID')

    def test_cli_is_read_only_and_never_product_pass(self):
        scripts = str(Path(__file__).resolve().parents[3] / 'scripts')
        for completed in [False, True]:
            if completed:
                self.write('attempts.jsonl', [self.record])
            before = {p: p.read_bytes() for p in self.root.rglob('*') if p.is_file()}
            run = subprocess.run([sys.executable, '-m', 'auto_test_lib.shard_recovery',
                '--evidence-root', str(self.root), '--target-directory', 'synthetic'],
                env=dict(os.environ, PYTHONPATH=scripts), capture_output=True,
                text=True, timeout=10)
            self.assertEqual(run.returncode, 0 if completed else 2)
            self.assertIs(json.loads(run.stdout)['product_pass'], False)
            self.assertEqual(before, {p: p.read_bytes() for p in self.root.rglob('*') if p.is_file()})


if __name__ == '__main__':
    unittest.main()

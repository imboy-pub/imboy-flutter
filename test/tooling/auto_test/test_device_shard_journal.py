"""Durability tests mock Flutter subprocesses; no devices are accessed."""
import importlib.util
import json
import subprocess
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

SCRIPT = Path(__file__).resolve().parents[3] / 'scripts' / 'auto_test_device_shard.py'
spec = importlib.util.spec_from_file_location('device_shard_journal_fixture', SCRIPT)
shard = importlib.util.module_from_spec(spec)
spec.loader.exec_module(shard)


class ShardJournalTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)

    def run_target(self, target, timeout_first=False):
        launches = []

        def run(argv, **kwargs):
            if argv[0] == 'git':
                return SimpleNamespace(stdout='a' * 40)
            starts = list(self.root.glob('*/starts.jsonl'))
            self.assertTrue(starts, 'start transition must exist before Flutter launches')
            launches.append(argv)
            if timeout_first and len(launches) == 1:
                raise subprocess.TimeoutExpired(argv, 1800, output=b'partial synthetic output')
            return SimpleNamespace(stdout='synthetic pass', returncode=0)

        def parsed(lines, code, tail):
            return SimpleNamespace(test_status='PASS', executed=1, skipped=0,
                                   failed=0, oracle_count=1, reason_code='NONE',
                                   failure_class='none')

        with patch.object(shard.subprocess, 'run', side_effect=run), \
                patch.object(shard, 'sha256_file', return_value='b' * 64), \
                patch.object(shard, 'parse_machine_events', side_effect=parsed):
            return shard.run_target(target, 'synthetic-device', 'android', self.root, 'synthetic')

    def test_timeout_retains_partial_output_and_both_attempts(self):
        result = self.run_target('test/a.dart', timeout_first=True)
        self.assertEqual(result['final']['test_status'], 'FLAKY')
        records = [json.loads(line) for line in next(self.root.glob('*/attempts.jsonl')).read_text().splitlines()]
        self.assertEqual([r['exit_code'] for r in records], [124, 0])
        self.assertEqual((self.root / records[0]['events']).read_text(), 'partial synthetic output')
        self.assertEqual(len(next(self.root.glob('*/starts.jsonl')).read_text().splitlines()), 2)

    def test_same_basename_targets_have_distinct_logs(self):
        first = self.run_target('test/a/same.dart')
        second = self.run_target('test/b/same.dart')
        self.assertNotEqual(first['attempts'][0]['events'], second['attempts'][0]['events'])
        self.assertEqual(len(list(self.root.glob('*/attempts.jsonl'))), 2)

    def test_repeated_target_cannot_overwrite_existing_evidence(self):
        self.run_target('test/a.dart')
        before = {p: p.read_bytes() for p in self.root.rglob('*') if p.is_file()}
        with self.assertRaises(FileExistsError):
            self.run_target('test/a.dart')
        self.assertEqual(before, {p: p.read_bytes() for p in self.root.rglob('*') if p.is_file()})

    def test_timeout_cannot_retry_observed_business_failure_with_real_parser(self):
        events = [{'type': 'testStart', 'test': {'id': 1, 'name': 'synthetic'}},
                  {'type': 'error', 'testID': 1, 'isFailure': True,
                   'message': 'synthetic assertion failed'},
                  {'type': 'testDone', 'testID': 1, 'result': 'success'}]
        for terminated in [False, True]:
            stream = events + ([{'type': 'done', 'success': True}] if terminated else [])
            output = '\n'.join(json.dumps(e) for e in stream)
            launches = []

            def run(argv, **kwargs):
                if argv[0] == 'git':
                    return SimpleNamespace(stdout='a' * 40)
                launches.append(argv)
                raise subprocess.TimeoutExpired(argv, 1800, output=output)

            with self.subTest(terminated=terminated), \
                    patch.object(shard.subprocess, 'run', side_effect=run), \
                    patch.object(shard, 'sha256_file', return_value='b' * 64):
                result = shard.run_target(f'test/business-{terminated}.dart',
                    'synthetic-device', 'android', self.root, 'synthetic')
                self.assertEqual(result['final']['test_status'], 'FAIL')
                self.assertEqual(len(launches), 1, '业务失败不得自动重试')
                self.assertEqual(result['attempts'][0]['parsed']['failure_class'], 'business')


if __name__ == '__main__':
    unittest.main()

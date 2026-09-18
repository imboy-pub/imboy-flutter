"""Step 6 tooling tests: state layer, fresh-clone plan, leases.

ATF-501 缺少历史 reports 时仍能生成完整计划（全 UNKNOWN，不伪造 PASS）。
ATF-503 state schema 拒绝凭证字段、未知状态；lease 并发获取唯一赢家、
空 owner/截断 JSON => CORRUPT_LEASE fail-closed、重复释放报错。
"""
from __future__ import annotations

import contextlib
import json
import sys
import tempfile
import threading
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / 'scripts'))

from auto_test_lib import state  # noqa: E402

SCHEMA_PATH = ROOT / 'test' / 'auto_test' / 'state' / 'schema.json'


def _valid_run_document(**overrides):
    doc = {
        'schema_version': 1,
        'run_id': 'hardening-20260918T151153Z',
        'scheduler_state': 'RUNNING',
        'scope_verdict': '',
        'steps': [{'step': 6, 'scheduler_state': 'RUNNING', 'scope_verdict': ''}],
        'targets': [
            {'target': 'integration_test/app_test.dart', 'test_status': state.UNKNOWN},
            {'target': 'integration_test/chat/conversation_test.dart', 'test_status': 'PASS'},
        ],
    }
    doc.update(overrides)
    return doc


class TestSchemaSync(unittest.TestCase):
    """schema.json（tracked 稳定 schema）与模块枚举保持一致。"""

    def test_enums_in_sync_with_module(self):
        schema = json.loads(SCHEMA_PATH.read_text(encoding='utf-8'))
        layers = schema['layers']
        self.assertEqual(tuple(layers['scheduler_state']), state.SCHEDULER_STATES)
        self.assertEqual(tuple(layers['test_status']), state.TEST_STATUSES)
        self.assertEqual(
            tuple(layers['test_status_with_unknown']),
            state.TEST_STATUSES_WITH_UNKNOWN,
        )
        self.assertEqual(tuple(layers['scope_verdict']), state.SCOPE_VERDICTS)
        lease = schema['lease']
        self.assertEqual(
            tuple(lease['owner_required_fields']),
            state.LEASE_OWNER_REQUIRED_FIELDS,
        )


class TestFreshClonePlan(unittest.TestCase):
    """ATF-501：无历史 reports 时的完整 UNKNOWN 计划。"""

    def _tmp_root(self, tmp: Path) -> Path:
        # fresh clone：tracked 文件存在，但没有任何 reports/ 历史
        root = tmp / 'fresh_clone_repo'
        (root / 'test' / 'auto_test' / 'state').mkdir(parents=True)
        return root

    def test_fresh_plan_from_synthetic_catalog_is_all_unknown(self):
        catalog = {
            'entries': [
                {'id': 'test:a', 'target': 'integration_test/a_test.dart'},
                {'id': 'test:b', 'target': 'integration_test/b/c_test.dart'},
                {'not-an-entry': True},
            ],
            'pages': [{'page': 'lib/page/x/x_page.dart', 'mapped_targets': ['integration_test/a_test.dart']}],
        }
        plan = state.fresh_clone_plan(catalog)
        self.assertEqual(plan['source'], 'catalog-v1')
        self.assertEqual(plan['scheduler_state'], 'READY')
        self.assertEqual(len(plan['targets']), 2)
        for row in plan['targets']:
            self.assertEqual(row['test_status'], state.UNKNOWN)
            self.assertNotEqual(row['test_status'], 'PASS')
        self.assertEqual(
            [row['target'] for row in plan['targets']],
            ['integration_test/a_test.dart', 'integration_test/b/c_test.dart'],
        )
        # 生成的是合法 state 文档
        document = _valid_run_document(
            targets=plan['targets'], scheduler_state=plan['scheduler_state']
        )
        self.assertEqual(state.validate_state_document(document), [])

    def test_atf501_real_catalog_covers_every_integration_test(self):
        with tempfile_dir() as tmp:
            self._tmp_root(tmp)
            catalog = json.loads(
                (ROOT / 'test' / 'auto_test' / 'catalog.json').read_text(encoding='utf-8')
            )
            plan = state.fresh_clone_plan(catalog)
            targets = [row['target'] for row in plan['targets']]
            self.assertEqual(len(targets), len(set(targets)), 'targets 必须唯一')
            self.assertEqual(len(plan['pages']), len(catalog['pages']))
            # catalog 收录的每个 target 都在计划里且为 UNKNOWN
            self.assertEqual(
                sorted(targets), sorted(e['target'] for e in catalog['entries'])
            )
            self.assertTrue(all(row['test_status'] == 'UNKNOWN' for row in plan['targets']))


class TestStateValidation(unittest.TestCase):
    """ATF-503：state schema 拒绝凭证字段与未知状态。"""

    def test_valid_document_passes(self):
        self.assertEqual(state.validate_state_document(_valid_run_document()), [])

    def test_unknown_scheduler_state_rejected(self):
        doc = _valid_run_document()
        doc['scheduler_state'] = 'PAUSED'
        errors = state.validate_state_document(doc)
        self.assertTrue(any('UNKNOWN_STATE' in e for e in errors), errors)

    def test_unknown_step_scheduler_state_rejected(self):
        doc = _valid_run_document()
        doc['steps'][0]['scheduler_state'] = 'FINISHED'
        errors = state.validate_state_document(doc)
        self.assertTrue(any('UNKNOWN_STATE' in e for e in errors), errors)

    def test_unknown_test_status_rejected(self):
        doc = _valid_run_document()
        doc['targets'][1]['test_status'] = 'GREENISH'
        errors = state.validate_state_document(doc)
        self.assertTrue(any('UNKNOWN_STATE' in e for e in errors), errors)

    def test_unknown_scope_verdict_rejected(self):
        doc = _valid_run_document()
        doc['scope_verdict'] = 'MOSTLY_FINE'
        errors = state.validate_state_document(doc)
        self.assertTrue(any('UNKNOWN_STATE' in e for e in errors), errors)

    def test_credential_fields_rejected_at_any_layer(self):
        for field in ('password', 'api_key', 'bearer_token', 'client_secret'):
            doc = _valid_run_document()
            doc[field] = 'x'
            errors = state.validate_state_document(doc)
            self.assertTrue(
                any('CREDENTIAL_FIELD_REJECTED' in e for e in errors), (field, errors)
            )
        doc = _valid_run_document()
        doc['targets'][0]['session_token'] = 'x'
        errors = state.validate_state_document(doc)
        self.assertTrue(any('CREDENTIAL_FIELD_REJECTED' in e for e in errors), errors)

    def test_missing_run_id_rejected(self):
        doc = _valid_run_document()
        del doc['run_id']
        self.assertTrue(state.validate_state_document(doc))


class TestLegacyTaskState(unittest.TestCase):
    def test_legacy_task_state_read_only_compat(self):
        # 只读兼容：能读取现有 task_state.json，且加载函数不写回任何内容
        path = ROOT / 'test' / 'auto_test' / 'task_state.json'
        before = path.read_bytes()
        data = state.load_legacy_task_state(path)
        self.assertIsInstance(data, dict)
        self.assertIn('goal', data)
        self.assertEqual(path.read_bytes(), before, 'task_state.json 必须保持只读')

    def test_missing_file_returns_empty_and_corrupt_raises(self):
        with tempfile_dir() as tmp:
            missing = tmp / 'none.json'
            self.assertEqual(state.load_legacy_task_state(missing), {})
            corrupt = tmp / 'corrupt.json'
            corrupt.write_text('{"trunc', encoding='utf-8')
            with self.assertRaises(state.StateError):
                state.load_legacy_task_state(corrupt)


class TestLeases(unittest.TestCase):
    def _owner(self, agent='agent-1', **overrides):
        payload = {
            'run': 'hardening-20260918T151153Z',
            'step': 6,
            'agent': agent,
            'process': 4242,
        }
        payload.update(overrides)
        return payload

    def test_acquire_read_release_cycle(self):
        with tempfile_dir() as tmp:
            leases = tmp / 'leases'
            state.acquire_lease(leases, 'CONTROL_ENTRY', self._owner())
            owner = state.read_lease(leases, 'CONTROL_ENTRY')
            self.assertEqual(owner['agent'], 'agent-1')
            self.assertEqual(owner['resource'], 'CONTROL_ENTRY')
            self.assertIn('heartbeat', owner)
            state.release_lease(leases, 'CONTROL_ENTRY', 'agent-1')
            with self.assertRaises(state.StateError) as ctx:
                state.read_lease(leases, 'CONTROL_ENTRY')
            self.assertIn('LEASE_NOT_HELD', str(ctx.exception))

    def test_concurrent_acquire_has_single_winner(self):
        with tempfile_dir() as tmp:
            leases = tmp / 'leases'
            winners: list[str] = []
            losers: list[str] = []
            barrier = threading.Barrier(6)

            def compete(index: int) -> None:
                barrier.wait()
                try:
                    state.acquire_lease(leases, 'ANDROID_DEVICE:dev1', self._owner(f'agent-{index}'))
                    winners.append(f'agent-{index}')
                except state.StateError as exc:
                    if 'LEASE_ALREADY_HELD' in str(exc):
                        losers.append(f'agent-{index}')
                    else:
                        raise

            threads = [threading.Thread(target=compete, args=(i,)) for i in range(6)]
            for thread in threads:
                thread.start()
            for thread in threads:
                thread.join()
            self.assertEqual(len(winners), 1, f'唯一赢家，got {winners}')
            self.assertEqual(len(losers), 5)
            owner = state.read_lease(leases, 'ANDROID_DEVICE:dev1')
            self.assertEqual(owner['agent'], winners[0])

    def test_empty_owner_fail_closed(self):
        with tempfile_dir() as tmp:
            leases = tmp / 'leases'
            resource = 'GIT_COMMIT'
            directory = leases / resource
            directory.mkdir(parents=True)
            with self.assertRaises(state.StateError) as ctx:
                state.read_lease(leases, resource)
            self.assertIn('CORRUPT_LEASE', str(ctx.exception))

    def test_truncated_json_fail_closed(self):
        with tempfile_dir() as tmp:
            leases = tmp / 'leases'
            directory = leases / 'BACKEND_EXEC'
            directory.mkdir(parents=True)
            (directory / 'owner.json').write_text('{"agent": "a", "ru', encoding='utf-8')
            with self.assertRaises(state.StateError) as ctx:
                state.read_lease(leases, 'BACKEND_EXEC')
            self.assertIn('CORRUPT_LEASE', str(ctx.exception))

    def test_owner_schema_missing_fields_fail_closed(self):
        with tempfile_dir() as tmp:
            leases = tmp / 'leases'
            directory = leases / 'MACOS_DEVICE'
            directory.mkdir(parents=True)
            (directory / 'owner.json').write_text(
                json.dumps({'agent': 'a'}), encoding='utf-8'
            )
            with self.assertRaises(state.StateError) as ctx:
                state.read_lease(leases, 'MACOS_DEVICE')
            self.assertIn('CORRUPT_LEASE', str(ctx.exception))
            with self.assertRaises(state.StateError) as ctx2:
                state.acquire_lease(leases, 'MACOS_DEVICE', {'agent': 'b'})
            self.assertIn('CORRUPT_LEASE', str(ctx2.exception))

    def test_double_release_raises(self):
        with tempfile_dir() as tmp:
            leases = tmp / 'leases'
            state.acquire_lease(leases, 'FIXTURE_NAMESPACE:run/shard1', self._owner())
            state.release_lease(leases, 'FIXTURE_NAMESPACE:run/shard1', 'agent-1')
            with self.assertRaises(state.StateError) as ctx:
                state.release_lease(leases, 'FIXTURE_NAMESPACE:run/shard1', 'agent-1')
            self.assertIn('LEASE_NOT_HELD', str(ctx.exception))

    def test_release_by_non_owner_rejected(self):
        with tempfile_dir() as tmp:
            leases = tmp / 'leases'
            state.acquire_lease(leases, 'DOC_GENERATOR', self._owner('agent-1'))
            with self.assertRaises(state.StateError) as ctx:
                state.release_lease(leases, 'DOC_GENERATOR', 'agent-2')
            self.assertIn('LEASE_OWNER_MISMATCH', str(ctx.exception))

    def test_heartbeat_updates_and_stale_is_mark_only(self):
        with tempfile_dir() as tmp:
            leases = tmp / 'leases'
            state.acquire_lease(leases, 'CATALOG_GENERATOR', self._owner())
            self.assertFalse(state.lease_stale(leases, 'CATALOG_GENERATOR'))
            state.heartbeat_lease(leases, 'CATALOG_GENERATOR', 'agent-1')
            owner = state.read_lease(leases, 'CATALOG_GENERATOR')
            self.assertGreaterEqual(owner['heartbeat'], owner['acquired_at'])
            # stale 只标记不抢占：目录仍在，不能被他人 acquire/release
            self.assertTrue((leases / 'CATALOG_GENERATOR' / 'owner.json').is_file())
            with self.assertRaises(state.StateError):
                state.acquire_lease(leases, 'CATALOG_GENERATOR', self._owner('agent-9'))
            with self.assertRaises(state.StateError):
                state.heartbeat_lease(leases, 'CATALOG_GENERATOR', 'agent-9')


class TestScopeVerdictRollup(unittest.TestCase):
    def test_scope_verdicts_constant_matches_plan(self):
        self.assertEqual(state.SCOPE_VERDICTS, ('PASS', 'PARTIAL', 'BLOCKED'))
        self.assertIn(state.UNKNOWN, state.TEST_STATUSES_WITH_UNKNOWN)
        self.assertNotIn(state.UNKNOWN, state.TEST_STATUSES)


@contextlib.contextmanager
def tempfile_dir():
    with tempfile.TemporaryDirectory() as name:
        yield Path(name)


if __name__ == '__main__':
    unittest.main()

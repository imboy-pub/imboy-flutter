"""Step 6 tooling tests: exact-hit cache and compatibility rebind.

ATF-502：精确 HEAD/输入相同才命中 cache；任一 HEAD、源码、测试、环境或
设备变化都会 miss；B/C compatibility rebind 只在完整 closure 哈希相同且
evidence HEAD 是最终 HEAD 祖先时通过；A/local-write 永远拒绝 rebind。
"""
from __future__ import annotations

import contextlib
import json
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / 'scripts'))

from auto_test_lib import cache as ca  # noqa: E402

HEAD = 'a' * 40
HEAD2 = 'b' * 40
BHEAD = 'c' * 40
BHEAD2 = 'd' * 40
SHA = 'e' * 64
SHA2 = 'f' * 64

RUN_BINDINGS = {
    'run_id': 'hardening-20260918T151153Z',
    'fixture_namespace': 'run/shard1',
    'marker': 'REDACTED',
    'account_fingerprint': 'anon-1',
    'seed_generation': 'seed-1',
    'session_state_generation': 'sess-1',
}


@contextlib.contextmanager
def tempfile_dir():
    with tempfile.TemporaryDirectory() as name:
        yield Path(name)


def make_key(**overrides):
    kwargs = dict(
        app_head=HEAD,
        backend_head=BHEAD,
        target_sha256=SHA,
        runner_sha256=SHA,
        config_sha256=SHA,
        dependency_content_sha256=SHA,
        environment_fingerprint='env-fp-1',
        device_fingerprint='dev-fp-1',
        level='B',
        local_write=False,
        extra_binding={},
    )
    kwargs.update(overrides)
    return ca.CacheKey(**kwargs)


def a_key(**overrides):
    kwargs = dict(level='A', extra_binding=dict(RUN_BINDINGS))
    kwargs.update(overrides)
    return make_key(**kwargs)


def lw_key(**overrides):
    kwargs = dict(level='C', local_write=True, extra_binding=dict(RUN_BINDINGS))
    kwargs.update(overrides)
    return make_key(**kwargs)


def evidence_for(key: ca.CacheKey, head=HEAD, status='PASS'):
    return {
        'schema_version': 1,
        'run_id': 'hardening-20260918T151153Z',
        'head': head,
        'backend_head': key.backend_head,
        'target': 'integration_test/app_test.dart',
        'result': {'status': status, 'executed': 1, 'skipped': 0, 'failed': 0},
    }


class TestExactHit(unittest.TestCase):
    def test_full_equality_hits(self):
        with tempfile_dir() as tmp:
            store = ca.CacheStore(tmp / 'cache' / 'cache.json')
            key = make_key()
            ca.record_hit(key, evidence_for(key), store)
            hit = ca.exact_hit(make_key(), store)
            self.assertIsNotNone(hit)
            self.assertEqual(hit['result']['status'], 'PASS')

    def test_any_field_change_misses(self):
        mutations = {
            'app_head': HEAD2,
            'backend_head': BHEAD2,
            'target_sha256': SHA2,
            'runner_sha256': SHA2,
            'config_sha256': SHA2,
            'dependency_content_sha256': SHA2,
            'environment_fingerprint': 'env-fp-2',
            'device_fingerprint': 'dev-fp-2',
            'level': 'C',
        }
        for field, value in mutations.items():
            with self.subTest(field=field), tempfile_dir() as tmp:
                store = ca.CacheStore(tmp / 'cache.json')
                ca.record_hit(make_key(), evidence_for(make_key()), store)
                self.assertIsNone(ca.exact_hit(make_key(**{field: value}), store))

    def test_extra_binding_change_misses(self):
        with tempfile_dir() as tmp:
            store = ca.CacheStore(tmp / 'cache.json')
            key = make_key(extra_binding={'smoke': '1'})
            ca.record_hit(key, evidence_for(key), store)
            self.assertIsNone(
                ca.exact_hit(make_key(extra_binding={'smoke': '2'}), store)
            )
            self.assertIsNone(ca.exact_hit(make_key(extra_binding={}), store))

    def test_empty_store_misses(self):
        with tempfile_dir() as tmp:
            store = ca.CacheStore(tmp / 'cache.json')
            self.assertIsNone(ca.exact_hit(make_key(), store))


class TestRunScopedKeys(unittest.TestCase):
    def test_level_a_is_run_scoped_and_not_rebindable(self):
        key = a_key()
        self.assertTrue(key.run_scoped())
        self.assertFalse(key.is_rebindable())
        self.assertEqual(
            key.required_run_bindings(),
            ('run_id', 'fixture_namespace', 'marker', 'account_fingerprint',
             'seed_generation', 'session_state_generation'),
        )

    def test_local_write_is_run_scoped_even_at_level_c(self):
        key = lw_key()
        self.assertTrue(key.run_scoped())
        self.assertFalse(key.is_rebindable())

    def test_level_b_is_rebindable(self):
        key = make_key()
        self.assertFalse(key.run_scoped())
        self.assertTrue(key.is_rebindable())

    def test_missing_run_bindings_fail_closed(self):
        key = ca.CacheKey(
            app_head=HEAD, backend_head=BHEAD, target_sha256=SHA,
            runner_sha256=SHA, config_sha256=SHA, dependency_content_sha256=SHA,
            environment_fingerprint='env', device_fingerprint='dev', level='A',
        )
        errors = key.binding_errors()
        self.assertEqual(len(errors), 6, errors)
        self.assertTrue(all('RUN_BINDING_MISSING' in e for e in errors))
        with tempfile_dir() as tmp:
            store = ca.CacheStore(tmp / 'cache.json')
            with self.assertRaises(ValueError):
                ca.exact_hit(key, store)
            with self.assertRaises(ValueError):
                ca.record_hit(key, {}, store)

    def test_run_scoped_hit_only_within_same_run(self):
        with tempfile_dir() as tmp:
            store = ca.CacheStore(tmp / 'cache.json')
            key = a_key()
            ca.record_hit(key, evidence_for(key), store)
            # 同 run 全字段相等才命中
            self.assertIsNotNone(ca.exact_hit(a_key(), store))
            # 换 run_id / marker / seed_generation => miss（跨 run 不可复用）
            for field in ('run_id', 'marker', 'seed_generation',
                          'session_state_generation'):
                with self.subTest(field=field):
                    changed = dict(RUN_BINDINGS)
                    changed[field] = changed[field] + '-other'
                    self.assertIsNone(ca.exact_hit(a_key(extra_binding=changed), store))

    def test_level_d_key_rejected(self):
        key = make_key(level='D')
        errors = key.binding_errors()
        self.assertEqual(len(errors), 1)
        self.assertIn('REBIND_FORBIDDEN_LEVEL', errors[0])
        self.assertIn('D evidence is never cacheable', errors[0])


class TestCompatibilityRebind(unittest.TestCase):
    def _old_evidence(self, head=HEAD):
        return evidence_for(make_key(), head=head)

    def test_bc_level_rebind_success(self):
        for level in ('B', 'C'):
            with self.subTest(level=level):
                record, reason = ca.compatibility_rebind(
                    self._old_evidence(), HEAD2,
                    closure_hash_match=True, level=level,
                    is_ancestor=lambda a, d: a == HEAD and d == HEAD2,
                )
                self.assertIsNone(reason)
                self.assertEqual(record['kind'], 'compatibility_rebind')
                self.assertEqual(record['head'], HEAD2)
                self.assertEqual(record['original']['head'], HEAD)
                self.assertEqual(record['level'], level)
                self.assertTrue(all(record['hash_checks'].values()))

    def test_ancestor_required(self):
        record, reason = ca.compatibility_rebind(
            self._old_evidence(), HEAD2,
            closure_hash_match=True, level='B',
            is_ancestor=lambda a, d: False,
        )
        self.assertIsNone(record)
        self.assertIn('REBIND_ANCESTOR_REQUIRED', reason)

    def test_level_a_always_refused(self):
        record, reason = ca.compatibility_rebind(
            self._old_evidence(), HEAD2,
            closure_hash_match=True, level='A',
            is_ancestor=lambda a, d: True,
        )
        self.assertIsNone(record)
        self.assertIn('REBIND_FORBIDDEN_LEVEL', reason)

    def test_local_write_always_refused(self):
        record, reason = ca.compatibility_rebind(
            self._old_evidence(), HEAD2,
            closure_hash_match=True, level='C', local_write=True,
            is_ancestor=lambda a, d: True,
        )
        self.assertIsNone(record)
        self.assertIn('REBIND_FORBIDDEN_LOCAL_WRITE', reason)

    def test_level_d_refused(self):
        record, reason = ca.compatibility_rebind(
            self._old_evidence(), HEAD2,
            closure_hash_match=True, level='D',
        )
        self.assertIsNone(record)
        self.assertIn('REBIND_FORBIDDEN_LEVEL', reason)

    def test_hash_mismatch_refused(self):
        cases = [
            {'closure_hash_match': False},
            {'runner_hash_match': False},
            {'config_hash_match': False},
            {'env_fingerprint_match': False},
        ]
        for case in cases:
            with self.subTest(**case):
                kwargs = {'closure_hash_match': True}
                kwargs.update(case)
                record, reason = ca.compatibility_rebind(
                    self._old_evidence(), HEAD2,
                    level='B', is_ancestor=lambda a, d: True, **kwargs,
                )
                self.assertIsNone(record)
                self.assertIn('REBIND_HASH_MISMATCH', reason)
                self.assertIn(sorted(case)[0], reason)

    def test_same_head_is_not_a_rebind(self):
        record, reason = ca.compatibility_rebind(
            self._old_evidence(head=HEAD2), HEAD2,
            closure_hash_match=True, level='B',
            is_ancestor=lambda a, d: True,
        )
        self.assertIsNone(record)
        self.assertIn('REBIND_EVIDENCE_INVALID', reason)

    def test_malformed_evidence_refused(self):
        record, reason = ca.compatibility_rebind(
            {'head': 'short'}, HEAD2,
            closure_hash_match=True, level='B',
        )
        self.assertIsNone(record)
        self.assertIn('REBIND_EVIDENCE_INVALID', reason)

    def test_bad_final_head_refused(self):
        record, reason = ca.compatibility_rebind(
            self._old_evidence(), 'main',
            closure_hash_match=True, level='B',
        )
        self.assertIsNone(record)
        self.assertIn('REBIND_INVALID_HEAD', reason)

    def test_predicate_failure_fails_closed(self):
        def boom(a, d):
            raise RuntimeError('git unavailable')
        record, reason = ca.compatibility_rebind(
            self._old_evidence(), HEAD2,
            closure_hash_match=True, level='B',
            is_ancestor=boom,
        )
        self.assertIsNone(record)
        self.assertIn('REBIND_ANCESTOR_REQUIRED', reason)

    def test_shared_gate_refuses_e2ee_style_real_client_via_level_a(self):
        # E2EE 真客户端证据以 A 级表达：共享判定函数必须拒绝
        self.assertIsNotNone(ca.shared_reuse_gate('A', False, 'rebind'))
        self.assertIsNotNone(ca.shared_reuse_gate('B', True, 'rebind'))
        self.assertIsNone(ca.shared_reuse_gate('B', False, 'rebind'))
        self.assertIsNone(ca.shared_reuse_gate('C', False, 'rebind'))
        self.assertIsNone(ca.shared_reuse_gate('A', False, 'exact'))


class TestGitAncestorHelper(unittest.TestCase):
    def test_default_git_helper(self):
        import subprocess
        real_head = subprocess.run(
            ['git', '-C', str(ROOT), 'rev-parse', 'HEAD'],
            capture_output=True, text=True, check=True,
        ).stdout.strip()
        # 同一 commit 互为祖先（git 语义）；未知 sha 永远不是祖先
        self.assertTrue(ca.git_is_ancestor(real_head, real_head, repo=ROOT))
        self.assertFalse(ca.git_is_ancestor(HEAD2, real_head, repo=ROOT))


class TestCacheStore(unittest.TestCase):
    def test_store_roundtrip_and_atomic_json(self):
        with tempfile_dir() as tmp:
            store = ca.CacheStore(tmp / 'nested' / 'cache.json')
            key = make_key()
            ca.record_hit(key, evidence_for(key), store)
            self.assertTrue(store.path.is_file())
            data = json.loads(store.path.read_text(encoding='utf-8'))
            self.assertEqual(data['schema_version'], 1)
            self.assertEqual(len(data['records']), 1)
            self.assertEqual(data['records'][0]['key'], key.to_dict())
            self.assertEqual(data['records'][0]['key_fingerprint'], key.fingerprint())
            # 无 tmp 残留（原子写）
            leftovers = [p.name for p in store.path.parent.iterdir()
                         if p.name != store.path.name]
            self.assertEqual(leftovers, [])
            # corrupt 文件 => 空 store（fail closed）
            store.path.write_text('{"records": [', encoding='utf-8')
            self.assertEqual(store.load(), [])

    def test_fingerprint_stable_and_input_sensitive(self):
        base = make_key()
        self.assertEqual(base.fingerprint(), make_key().fingerprint())
        self.assertNotEqual(base.fingerprint(), make_key(app_head=HEAD2).fingerprint())
        self.assertNotEqual(
            base.fingerprint(), make_key(extra_binding={'x': 1}).fingerprint()
        )


if __name__ == '__main__':
    unittest.main()

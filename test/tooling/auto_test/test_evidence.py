"""Step 6 tooling tests: evidence manifest build + fail-closed validation.

ATF-503：evidence schema 拒绝凭证字段、缺失 closure/hash、非法
NOT_APPLICABLE、降级证据等级、D 级单独 PASS、0 executed PASS、非 40 位 head。
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

from auto_test_lib import evidence as ev  # noqa: E402

SHA1 = 'a' * 40
SHA1_OTHER = 'b' * 40
SHA256 = 'c' * 64
BACKEND_SHA1 = 'd' * 40


@contextlib.contextmanager
def tempfile_dir():
    with tempfile.TemporaryDirectory() as name:
        yield Path(name)


def _closure():
    return {
        'algorithm': 'catalog-v1',
        'manifest_path': 'closure.json',
        'manifest_sha256': SHA256,
        'content_sha256': SHA256,
    }


def _result(status='PASS', executed=1, skipped=0, failed=0):
    return {'status': status, 'executed': executed, 'skipped': skipped, 'failed': failed}


def build(**overrides):
    kwargs = dict(
        run_id='hardening-20260918T151153Z',
        head=SHA1,
        backend_head=BACKEND_SHA1,
        target='integration_test/app_test.dart',
        result_dict=_result(),
        environment={'app_env': 'local', 'api_host': '127.0.0.1', 'ws_host': '127.0.0.1',
                     'backend_profile': 'fp-local-1'},
        device={'id': 'REDACTED', 'platform': 'android', 'state_generation': 'gen-1'},
        fixture={'namespace': 'run/shard1', 'marker': 'REDACTED', 'generation': 'gen-1',
                 'accounts': 'anon-fp-1'},
        artifacts=[{'path': 'events.jsonl', 'sha256': SHA256}],
        dependency_closure=_closure(),
        tested_tree_sha256=SHA256,
        catalog_sha256=SHA256,
        target_sha256=SHA256,
        runner_sha256=SHA256,
        config_sha256=SHA256,
        command_fingerprint=SHA256,
    )
    kwargs.update(overrides)
    return ev.build_evidence(**kwargs)


class TestBuildEvidence(unittest.TestCase):
    def test_manifest_has_all_section_43_fields(self):
        manifest = build()
        expected = {
            'schema_version', 'run_id', 'head', 'backend_head',
            'tested_tree_sha256', 'catalog_sha256', 'target', 'target_sha256',
            'runner_sha256', 'config_sha256', 'dependency_closure',
            'environment', 'device', 'fixture', 'result',
            'command_fingerprint', 'artifacts',
        }
        self.assertEqual(expected, set(manifest.keys()))
        self.assertEqual(manifest['dependency_closure']['algorithm'], 'catalog-v1')
        # 构造本身不做判定；合法输入应通过 validate
        self.assertEqual(
            ev.validate_evidence(manifest, requirements=['backend.local']), []
        )

    def test_valid_not_applicable_without_backend_requirements(self):
        manifest = build(backend_head='NOT_APPLICABLE')
        self.assertEqual(
            ev.validate_evidence(manifest, requirements=['device.android']), []
        )


class TestHeadAndHashValidation(unittest.TestCase):
    def test_short_head_rejected(self):
        manifest = build(head=SHA1[:39])
        errors = ev.validate_evidence(manifest, requirements=[])
        self.assertTrue(any('INVALID_HEAD' in e for e in errors), errors)

    def test_missing_hashes_rejected(self):
        manifest = build(target_sha256='')
        errors = ev.validate_evidence(manifest, requirements=[])
        self.assertTrue(any('MISSING_HASH' in e for e in errors), errors)
        for field in ('runner_sha256', 'config_sha256', 'tested_tree_sha256',
                      'catalog_sha256', 'command_fingerprint'):
            with self.subTest(field=field):
                bad = build(**{field: ''})
                self.assertTrue(
                    any('MISSING_HASH' in e for e in ev.validate_evidence(bad, requirements=[]))
                )

    def test_missing_closure_rejected(self):
        manifest = build(dependency_closure={})
        errors = ev.validate_evidence(manifest, requirements=[])
        self.assertTrue(any('MISSING_DEPENDENCY_CLOSURE' in e for e in errors), errors)
        partial = build()
        partial['dependency_closure'] = {k: v for k, v in _closure().items()
                                         if k != 'content_sha256'}
        errors2 = ev.validate_evidence(partial, requirements=[])
        self.assertTrue(any('dependency_closure.content_sha256' in e for e in errors2), errors2)

    def test_bad_backend_head_rejected(self):
        manifest = build(backend_head='main')
        errors = ev.validate_evidence(manifest, requirements=[])
        self.assertTrue(any('INVALID_BACKEND_HEAD' in e for e in errors), errors)


class TestNotApplicableRule(unittest.TestCase):
    def test_backend_requirement_forbids_not_applicable(self):
        manifest = build(backend_head='NOT_APPLICABLE')
        for reqs in (['backend.local'], ['backend.strict_e2ee'],
                     ['credentials.primary'], ['fixture.existing_group'],
                     ['device.android', 'backend.local']):
            with self.subTest(reqs=reqs):
                errors = ev.validate_evidence(manifest, requirements=reqs)
                self.assertTrue(
                    any('NOT_APPLICABLE_FORBIDDEN' in e for e in errors), errors
                )

    def test_pure_local_requirements_allow_not_applicable(self):
        manifest = build(backend_head='NOT_APPLICABLE')
        self.assertEqual(ev.validate_evidence(manifest, requirements=[]), [])

    def test_not_applicable_without_requirements_fails_closed(self):
        manifest = build(backend_head='NOT_APPLICABLE')
        errors = ev.validate_evidence(manifest, requirements=None)
        self.assertTrue(
            any('NOT_APPLICABLE_FORBIDDEN' in e for e in errors), errors
        )


class TestCredentialFields(unittest.TestCase):
    def test_credential_field_names_rejected(self):
        for field in ('password', 'user_token', 'client_secret', 'api_key',
                      'apiKey', 'bearer', 'PASSWORD'):
            manifest = build()
            manifest[field] = 'x'
            errors = ev.validate_evidence(manifest, requirements=[])
            self.assertTrue(
                any('CREDENTIAL_FIELD_REJECTED' in e for e in errors), (field, errors)
            )

    def test_nested_credential_fields_rejected(self):
        manifest = build()
        manifest['environment']['access_token'] = 'x'
        errors = ev.validate_evidence(manifest, requirements=[])
        self.assertTrue(any('CREDENTIAL_FIELD_REJECTED' in e for e in errors), errors)

        manifest2 = build()
        manifest2['artifacts'][0]['secret_ref'] = 'x'
        errors2 = ev.validate_evidence(manifest2, requirements=[])
        self.assertTrue(any('CREDENTIAL_FIELD_REJECTED' in e for e in errors2), errors2)

    def test_credential_hit_is_terminal(self):
        manifest = build()
        manifest['head'] = 'short'
        manifest['api_key'] = 'x'
        errors = ev.validate_evidence(manifest, requirements=[])
        self.assertEqual(len(errors), 1, errors)


class TestResultStatus(unittest.TestCase):
    def test_unknown_status_rejected(self):
        manifest = build(result_dict=_result(status='FINE'))
        errors = ev.validate_evidence(manifest, requirements=[])
        self.assertTrue(any('INVALID_RESULT_STATUS' in e for e in errors), errors)

    def test_pass_with_zero_executed_rejected(self):
        manifest = build(result_dict=_result(status='PASS', executed=0))
        errors = ev.validate_evidence(manifest, requirements=[])
        self.assertTrue(any('PASS_WITH_ZERO_EXECUTED' in e for e in errors), errors)

    def test_all_section_41_statuses_accepted(self):
        for status in ('PASS', 'PASS_WITH_SKIPS', 'BLOCKED', 'FAIL', 'FLAKY', 'PLANNED'):
            with self.subTest(status=status):
                manifest = build(
                    result_dict=_result(status=status, executed=0 if status != 'PASS' else 1)
                )
                errors = ev.validate_evidence(manifest, requirements=[])
                self.assertFalse(
                    any('INVALID_RESULT_STATUS' in e for e in errors), errors
                )


class TestEvidenceLevelFloor(unittest.TestCase):
    def test_minimum_levels(self):
        self.assertEqual(ev.minimum_required_level(requirements=[]), 'C')
        self.assertEqual(
            ev.minimum_required_level(requirements=['backend.local']), 'B'
        )
        self.assertEqual(
            ev.minimum_required_level(requirements=['credentials.primary']), 'B'
        )
        self.assertEqual(
            ev.minimum_required_level(requirements=['fixture.disposable_account']), 'B'
        )
        self.assertEqual(
            ev.minimum_required_level(requirements=['device.android']), 'A'
        )
        self.assertEqual(
            ev.minimum_required_level(requirements=[], risk='local-write'), 'A'
        )
        # device 优先级高于 backend：真设备操作最低 A
        self.assertEqual(
            ev.minimum_required_level(
                requirements=['device.android', 'backend.local']
            ),
            'A',
        )

    def test_downgrade_rejected(self):
        manifest = build(required_evidence_level='C')
        errors = ev.validate_evidence(
            manifest, requirements=['device.android']
        )
        self.assertTrue(any('EVIDENCE_LEVEL_DOWNGRADED' in e for e in errors), errors)

        manifest_b = build(required_evidence_level='C')
        errors_b = ev.validate_evidence(manifest_b, requirements=['backend.local'])
        self.assertTrue(any('EVIDENCE_LEVEL_DOWNGRADED' in e for e in errors_b), errors_b)

    def test_upgrade_allowed(self):
        manifest = build(required_evidence_level='A')
        self.assertEqual(
            ev.validate_evidence(manifest, requirements=['backend.local']), []
        )
        manifest_eq = build(required_evidence_level='B')
        self.assertEqual(
            ev.validate_evidence(manifest_eq, requirements=['backend.local']), []
        )

    def test_level_d_cannot_carry_pass(self):
        manifest = build(required_evidence_level='D')
        errors = ev.validate_evidence(manifest, requirements=[])
        self.assertTrue(any('EVIDENCE_LEVEL_D_CANNOT_PASS' in e for e in errors), errors)
        self.assertTrue(any('EVIDENCE_LEVEL_DOWNGRADED' in e for e in errors), errors)
        blocked = build(
            required_evidence_level='D',
            result_dict=_result(status='BLOCKED', executed=0),
        )
        errors_blocked = ev.validate_evidence(blocked, requirements=[])
        self.assertFalse(
            any('EVIDENCE_LEVEL_D_CANNOT_PASS' in e for e in errors_blocked)
        )

    def test_invalid_level_value_rejected(self):
        manifest = build(required_evidence_level='E')
        errors = ev.validate_evidence(manifest, requirements=[])
        self.assertTrue(any('EVIDENCE_LEVEL_DOWNGRADED' in e for e in errors), errors)


class TestSchemaFileSync(unittest.TestCase):
    def test_schema_json_evidence_section_matches_module(self):
        schema = json.loads(
            (ROOT / 'test' / 'auto_test' / 'state' / 'schema.json').read_text(
                encoding='utf-8'
            )
        )
        section = schema['evidence']
        self.assertEqual(
            section['credential_field_name_pattern'],
            ev.SECRET_FIELD_RE.pattern,
        )
        self.assertEqual(sorted(section['result_statuses']),
                         sorted(ev.TEST_STATUSES))
        self.assertEqual(
            tuple(section['dependency_closure_fields']),
            ('algorithm', 'manifest_path', 'manifest_sha256', 'content_sha256'),
        )


if __name__ == '__main__':
    unittest.main()

"""Step 9 tooling tests: domain matrix / fixtures contract（DOM-002 / DOM-003 面）。

覆盖：
- matrix 连续生成两次字节一致；--check 只比较；真实 target 存在性。
- 启用 feature 无 capability 映射 => 报错；缺 app/backend target 未标 BLOCKED => 报错。
- 证据等级下调 / D 级填充 => 报错。
- fixtures contract 六匿名账号 + 互异设备身份 + 无凭证字段。
"""
from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / 'scripts'))

from auto_test_lib import domain  # noqa: E402

FIXTURES_DOC = json.loads((ROOT / 'test' / 'auto_test' / 'fixtures_contract.json').read_text(encoding='utf-8'))


class DomainGenerationTest(unittest.TestCase):
    """真实仓库：确定性 + 校验 + 在盘 --check。"""

    @classmethod
    def setUpClass(cls):
        cls.root = ROOT
        first = domain.generate_domain_matrix(cls.root)
        second = domain.generate_domain_matrix(cls.root)
        cls.first = first
        cls.first_text = domain.render_json(first)
        cls.second_text = domain.render_json(second)

    def test_deterministic_bytes(self):
        self.assertEqual(self.first_text, self.second_text)

    def test_disk_file_matches_check(self):
        self.assertEqual(domain.check_domain(self.root), [])

    def test_capability_and_feature_counts(self):
        self.assertEqual(len(self.first['capabilities']), 44)
        self.assertEqual(set(self.first['feature_mapping']),
                         set(domain.load_selected_features(ROOT)))
        for feature, item in self.first['feature_mapping'].items():
            self.assertEqual(item['disposition'], 'mapped', feature)
            self.assertTrue(item['capabilities'], feature)

    def test_all_capabilities_have_real_targets(self):
        for cap in self.first['capabilities']:
            self.assertTrue(cap['app_targets'], cap['capability_id'])
            self.assertTrue(cap['backend_targets'], cap['capability_id'])
            self.assertIsNone(cap['blocked_code'])
            for target in cap['app_targets']:
                self.assertTrue((self.root / target).is_file(), f'{cap["capability_id"]}: {target}')

    def test_level_distribution(self):
        levels = {c['required_evidence_level'] for c in self.first['capabilities']}
        self.assertTrue(levels <= {'A', 'B'})
        e2ee_true_chat = {'e2ee.c2c_olm', 'e2ee.c2g_megolm_roomkey', 'e2ee.multi_device_fanout',
                          'e2ee.attachment', 'e2ee.backup_recovery', 'e2ee.history_member_boundary',
                          'group.e2ee'}
        by_id = {c['capability_id']: c for c in self.first['capabilities']}
        for cap in e2ee_true_chat:
            self.assertEqual(by_id[cap]['required_evidence_level'], 'A', cap)

    def test_make_target_special_form(self):
        e2ee_caps = [c for c in self.first['capabilities'] if c['domain'] == 'e2ee']
        self.assertTrue(any('make:e2ee-verify' in c['backend_targets'] for c in e2ee_caps))


class DomainValidationTest(unittest.TestCase):
    def setUp(self):
        self.matrix = domain.generate_domain_matrix(ROOT)
        self.assertEqual(domain.validate_domain(ROOT, self.matrix), [])

    def _mutated(self):
        return json.loads(json.dumps(self.matrix))

    def test_feature_without_mapping(self):
        matrix = self._mutated()
        del matrix['feature_mapping']['e2ee']
        errors = domain.validate_domain(ROOT, matrix)
        self.assertTrue(any('无 capability 映射' in e and 'e2ee' in e for e in errors), errors)

    def test_feature_mapping_dangling_capability(self):
        matrix = self._mutated()
        matrix['feature_mapping']['e2ee']['capabilities'] = ['e2ee.ghost']
        errors = domain.validate_domain(ROOT, matrix)
        self.assertTrue(any('指向不存在 capability' in e for e in errors), errors)

    def test_missing_capability_from_matrix(self):
        matrix = self._mutated()
        matrix['capabilities'] = [c for c in matrix['capabilities']
                                  if c['capability_id'] != 'e2ee.policy_gate']
        errors = domain.validate_domain(ROOT, matrix)
        self.assertTrue(any('缺少必须覆盖 capability: e2ee.policy_gate' in e for e in errors), errors)

    def test_missing_app_target_without_blocked(self):
        matrix = self._mutated()
        cap = next(c for c in matrix['capabilities'] if c['capability_id'] == 'e2ee.policy_gate')
        cap['app_targets'] = []
        errors = domain.validate_domain(ROOT, matrix)
        self.assertTrue(any('缺 app target 且未 BLOCKED' in e for e in errors), errors)

    def test_missing_backend_target_without_blocked(self):
        matrix = self._mutated()
        cap = next(c for c in matrix['capabilities'] if c['capability_id'] == 'org.lifecycle')
        cap['backend_targets'] = []
        errors = domain.validate_domain(ROOT, matrix)
        self.assertTrue(any('缺 backend target 且未 BLOCKED' in e for e in errors), errors)

    def test_nonexistent_targets_rejected(self):
        matrix = self._mutated()
        cap = next(c for c in matrix['capabilities'] if c['capability_id'] == 'moment.visibility')
        cap['app_targets'] = ['test/unit_test/ghost_test.dart']
        cap['backend_targets'] = ['test/logic/ghost_tests.erl']
        errors = domain.validate_domain(ROOT, matrix)
        self.assertTrue(any('app target 不存在' in e for e in errors), errors)
        self.assertTrue(any('backend target 不存在' in e for e in errors), errors)

    def test_level_downgrade_rejected(self):
        matrix = self._mutated()
        cap = next(c for c in matrix['capabilities'] if c['capability_id'] == 'e2ee.c2c_olm')
        cap['required_evidence_level'] = 'B'
        errors = domain.validate_domain(ROOT, matrix)
        self.assertTrue(any('证据等级低于类型最低值' in e for e in errors), errors)

    def test_level_d_rejected(self):
        matrix = self._mutated()
        cap = next(c for c in matrix['capabilities'] if c['capability_id'] == 'bot.webhook_delivery')
        cap['required_evidence_level'] = 'D'
        errors = domain.validate_domain(ROOT, matrix)
        self.assertTrue(any('非法证据等级' in e or 'D 级不得作为要求等级' in e for e in errors), errors)

    def test_blocked_marker_allows_missing_targets(self):
        matrix = self._mutated()
        cap = next(c for c in matrix['capabilities'] if c['capability_id'] == 'location.share')
        cap['app_targets'] = []
        cap['backend_targets'] = []
        cap['blocked_code'] = 'BLOCKED_PRODUCT_DRIFT'
        errors = domain.validate_domain(ROOT, matrix)
        self.assertFalse(any('target' in e for e in errors), errors)


class FeatureManifestMappingTest(unittest.TestCase):
    def test_selected_features_all_mapped(self):
        selected = domain.load_selected_features(ROOT)
        self.assertIn('project', selected)
        for feature in selected:
            self.assertIn(feature, domain.FEATURE_CAPABILITY_MAP, feature)
            self.assertTrue(domain.FEATURE_CAPABILITY_MAP[feature], feature)

    def test_project_feature_maps_all_six_project_capabilities(self):
        expected = {
            'project.create_update_status',
            'project.member_invite_remove_owner_transfer',
            'project.task_assign_status', 'project.milestone',
            'project.channel_link', 'project.aggregations_workspace_boundary',
        }
        self.assertEqual(set(domain.FEATURE_CAPABILITY_MAP.get('project', [])), expected)
        specs = [s for s in domain.CAPABILITY_SPECS
                 if s['capability_id'] in expected]
        self.assertEqual(len(specs), 6)
        self.assertTrue(all(s['feature_key'] == 'project' for s in specs))

    def test_feature_key_values_are_manifest_or_core(self):
        selected = set(domain.load_selected_features(ROOT))
        for spec in domain.CAPABILITY_SPECS:
            self.assertIn(spec['feature_key'], selected | {'core'}, spec['capability_id'])


class FixturesContractTest(unittest.TestCase):
    """DOM-003：六匿名账号 + 互异设备身份 + 无凭证。"""

    def test_real_contract_valid(self):
        self.assertEqual(domain.validate_fixtures_contract(FIXTURES_DOC), [])

    def test_six_anonymous_accounts(self):
        aliases = sorted(a['alias'] for a in FIXTURES_DOC['accounts'])
        self.assertEqual(aliases, [
            'orgA_admin', 'orgA_member', 'orgA_nonmember', 'orgA_owner', 'orgB_member', 'orgB_owner',
        ])

    def test_device_identities_distinct_pair(self):
        devices = FIXTURES_DOC['device_identities']
        self.assertEqual(sorted(d['account_alias'] for d in devices), ['orgA_member', 'orgA_owner'])
        self.assertEqual(len({d['device_alias'] for d in devices}), 2)
        self.assertEqual({d['platform'] for d in devices}, {'android', 'macos'})

    def test_missing_account_rejected(self):
        bad = json.loads(json.dumps(FIXTURES_DOC))
        bad['accounts'] = bad['accounts'][:5]
        errors = domain.validate_fixtures_contract(bad)
        self.assertTrue(any('六匿名账号' in e for e in errors), errors)

    def test_credential_field_rejected(self):
        for key, value in (
            ('access_token', 'x'), ('password', 'x'), ('api_key', 'x'),
            ('private_key', 'x'), ('phone_number', '13800000000'),
        ):
            bad = json.loads(json.dumps(FIXTURES_DOC))
            bad['accounts'][0][key] = value
            errors = domain.validate_fixtures_contract(bad)
            self.assertTrue(any('凭证字段' in e for e in errors), (key, errors))

    def test_device_identity_must_be_owner_and_member(self):
        bad = json.loads(json.dumps(FIXTURES_DOC))
        bad['device_identities'] = [
            {'device_alias': 'user_device_a', 'account_alias': 'orgA_admin', 'platform': 'android'},
        ]
        errors = domain.validate_fixtures_contract(bad)
        self.assertTrue(any('device_identities' in e for e in errors), errors)

    def test_marker_and_namespace_rules_required(self):
        bad = json.loads(json.dumps(FIXTURES_DOC))
        del bad['run_marker_rule']
        errors = domain.validate_fixtures_contract(bad)
        self.assertTrue(any('run_marker_rule' in e for e in errors), errors)


if __name__ == '__main__':
    unittest.main()

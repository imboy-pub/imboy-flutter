"""Owned native fixtures must reach the real adapter without changing legacy inputs."""
import json
from pathlib import Path
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / 'scripts'))
from auto_test_lib import execution_adapters as adapters
from auto_test_lib.execution_catalog import ContractError, build_plan

TARGETS = [
    'integration_test/chat/j18a_send_retry_test.dart',
    'integration_test/chat_multi_select_test.dart',
    'integration_test/chat_multi_bundle_roundtrip_test.dart',
]


class OwnedChatVariantTests(unittest.TestCase):
    def test_owned_fixture_fields_reach_actual_adapter_command(self):
        plan = build_plan(ROOT, profile='full', platforms=['android'],
                          products=['full-selected'], targets=TARGETS, variants=['owned'])
        rows = [row for row in plan['instances'] if row['selected']]
        self.assertEqual(set(TARGETS), {row['target'] for row in rows})
        for row in rows:
            names = set(row['required_env']) | set(row['required_true_env'])
            env = {name: 'synthetic-' + name.lower() for name in names}
            env.update({name: 'true' for name in row['required_true_env']})
            env.update(APP_ENV='local', API_BASE_URL='http://127.0.0.1:9800',
                       WS_URL_OVERRIDE='ws://127.0.0.1:9800/ws', UX_RESTORE_STORAGE='true',
                       WEB_BASE_URL='http://127.0.0.1:9800',
                       IMBOY_LOCAL_MAP_REQUESTS_ALLOWED='false')
            for name in names:
                for alias in adapters.ENV_ALIASES.get(name, ()):
                    env[alias] = env[name]
            with tempfile.TemporaryDirectory() as directory:
                invocation = adapters.build_invocation(
                    ROOT, row, env, Path(directory), devices=[])
            defines = dict(argument[len('--dart-define='):].split('=', 1)
                           for argument in invocation['command']
                           if argument.startswith('--dart-define='))
            with self.subTest(target=row['target']):
                for name in names:
                    self.assertEqual(env[name], defines.get(name), name)
                self.assertEqual('false', defines['IMBOY_LOCAL_MAP_REQUESTS_ALLOWED'])
                self.assertIn('--no-uninstall', invocation['command'])
                self.assertEqual('local', defines['APP_ENV'])
                self.assertEqual('true', defines['IMBOY_LOCAL_EXTERNAL_SERVICES_DISABLED'])

    def test_owned_variants_do_not_add_macos_or_ios_obligations(self):
        for platform in ['macos', 'ios']:
            with self.assertRaises(ContractError) as caught:
                build_plan(ROOT, profile='full', platforms=[platform],
                           products=['full-selected'], targets=TARGETS, variants=['owned'])
            self.assertEqual(['EMPTY_EXECUTION_PLAN'], caught.exception.errors)
            legacy = build_plan(ROOT, profile='full', platforms=[platform],
                                products=['phase1_delivery'], targets=TARGETS,
                                variants=['default'])
            self.assertEqual(3, sum(row['selected'] for row in legacy['instances']))

    def test_owned_platforms_must_be_a_nonempty_parent_subset(self):
        config = json.loads((ROOT / 'test/auto_test/execution_contract.json').read_text())
        for platforms in [None, 1, 'android', [{}], [], ['linux']]:
            config['overrides'][TARGETS[0]]['variants'][1]['platforms'] = platforms
            with self.assertRaises(ContractError) as caught:
                build_plan(ROOT, profile='full', platforms=['android'],
                           products=['full-selected'], targets=TARGETS,
                           variants=['owned'], contract=config)
            self.assertTrue(any('INVALID_VARIANT_PLATFORMS' in error
                                for error in caught.exception.errors))

    def test_default_legacy_variant_keeps_its_original_fixture_contract(self):
        config = json.loads((ROOT / 'test/auto_test/execution_contract.json').read_text())
        for target in TARGETS:
            variants = config['overrides'][target]['variants']
            self.assertEqual({'variant': 'default'}, variants[0])
        plan = build_plan(ROOT, profile='full', platforms=['android'],
                          products=['phase1_delivery'], targets=TARGETS, variants=['default'])
        rows = [row for row in plan['instances'] if row['selected']]
        self.assertEqual(3, len(rows))
        for row in rows:
            self.assertNotIn('UX_STORAGE_TAG', row.get('required_env', []))
            self.assertNotIn('CHAT_MULTI_RUN_NONCE', row.get('required_env', []))


if __name__ == '__main__':
    unittest.main()

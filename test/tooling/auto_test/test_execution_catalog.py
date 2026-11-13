"""Execution governance contracts use real temporary Git indexes, not mocks."""
from __future__ import annotations

from pathlib import Path
import hashlib
import json
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / 'scripts'))
from auto_test_lib.execution_catalog import (  # noqa: E402
    ContractError, build_catalog, build_plan, load_contract, validate_catalog,
)

UNIT = "import 'package:flutter_test/flutter_test.dart';\nvoid main() { test('logic', () { expect(1, 1); }); }\n"
WIDGET = "import 'package:flutter_test/flutter_test.dart';\nvoid main() { testWidgets('view', (tester) async {}); }\n"
DEVICE = "import 'package:integration_test/integration_test.dart';\nvoid main() { IntegrationTestWidgetsFlutterBinding.ensureInitialized(); testWidgets('device', (tester) async {}); }\n"


class ExecutionCatalogTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='imboy-execution-contract-')
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.git('init', '-q')
        self.put('scripts/auto_test_lib/execution_runner.py', 'def run_plan(): pass\n')
        self.cfg = {
            'schema_version': 1,
            'platforms': ['linux', 'macos', 'android', 'web'],
            'products': {'phase1_delivery': {}, 'full-selected': {}},
            'runners': {name: {'entrypoint': 'scripts/auto_test_lib/execution_runner.py',
                               'adapter': name, 'callable': 'run_plan'}
                        for name in ['flutter-machine', 'flutter-device', 'device-pair', 'python-unittest']},
            'suites': {
                name: {'runner': runner, 'platforms': platforms,
                       'products': ['phase1_delivery'], 'dependencies': [],
                       'coverage': coverage}
                for name, runner, platforms, coverage in [
                    ('unit', 'flutter-machine', ['linux', 'macos'], True),
                    ('widget', 'flutter-machine', ['linux', 'macos'], True),
                    ('component', 'flutter-machine', ['linux', 'macos'], True),
                    ('sqlite-ffi', 'flutter-machine', ['linux', 'macos'], True),
                    ('crypto-ffi', 'flutter-machine', ['linux', 'macos'], True),
                    ('golden', 'flutter-machine', ['macos'], False),
                    ('route-smoke', 'flutter-machine', ['linux', 'macos'], False),
                    ('backend-contract', 'flutter-machine', ['linux', 'macos'], False),
                    ('device-single', 'flutter-device', ['android', 'macos'], False),
                    ('device-pair', 'device-pair', ['android', 'macos'], False),
                    ('tooling', 'python-unittest', ['linux'], False),
                ]},
            'rules': [
                {'id': 'host', 'prefixes': ['test/unit_test/'], 'classifier': 'host-dart'},
                {'id': 'device', 'prefixes': ['integration_test/'], 'classifier': 'device-dart'},
                {'id': 'python', 'prefixes': ['test/tooling/'], 'classifier': 'python-test'},
            ],
            'overrides': {},
            'profiles': {
                'pr': {'suites': ['unit', 'widget', 'component', 'sqlite-ffi', 'crypto-ffi', 'tooling'],
                       'platforms': ['linux', 'macos', 'web'], 'products': ['phase1_delivery']},
                'full': {'suites': ['*'], 'platforms': ['*'], 'products': ['*']},
                'device-single': {'suites': ['device-single'], 'platforms': ['android', 'macos'],
                                  'products': ['phase1_delivery']},
            },
        }
        self.put('test/unit_test/base_test.dart', UNIT)

    def test_product_specific_runtime_feature_mapping_rejects_malformed_values(self):
        target = 'test/api_test.dart'
        self.put(target, UNIT)
        self.cfg['overrides'][target] = {'suite': 'backend-contract', 'basis': 'synthetic positive branch',
            'products': ['phase1_delivery', 'full-selected'],
            'required_features_by_product': {'full-selected': ['e2ee']}}
        self.assertFalse(build_catalog(self.root, contract=self.cfg)['errors'])
        for mapping in (None, [], {'unknown': ['e2ee']}, {'full-selected': 'e2ee'},
                        {'full-selected': [False]}, {'full-selected': ['bad capability']}):
            with self.subTest(mapping=mapping):
                self.cfg['overrides'][target]['required_features_by_product'] = mapping
                self.assertTrue(any('INVALID_PRODUCT_REQUIRED_FEATURES' in error
                    for error in build_catalog(self.root, contract=self.cfg)['errors']))

    def git(self, *args):
        return subprocess.run(['git', '-C', str(self.root), *args], check=True,
                              capture_output=True, text=True)

    def put(self, path, text, tracked=True):
        destination = self.root / path
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_text(text)
        if tracked:
            self.git('add', '--', path)

    def fail(self, code):
        with self.assertRaisesRegex(ContractError, code):
            validate_catalog(self.root, self.cfg)

    def plan(self, **kwargs):
        return build_plan(self.root, contract=self.cfg, **kwargs)

    def test_new_unknown_directory_is_rejected(self):
        self.put('test/new_business/forgotten_test.dart', UNIT)
        self.fail('UNASSIGNED_TEST_SOURCE')

    def test_ci_dependency_check_preserves_current_frozen_inputs(self):
        for path in ('pubspec.yaml', 'pubspec.lock'):
            self.put(path, (ROOT / path).read_text())
        before = {path: (self.root / path).read_bytes() for path in ('pubspec.yaml', 'pubspec.lock')}
        completed = subprocess.run(['bash', str(ROOT / '.github/scripts/ci_patch_path_deps.sh'), '--check'],
                                   cwd=self.root, capture_output=True, text=True)
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
        self.assertEqual(before, {path: (self.root / path).read_bytes() for path in before})

    def test_ci_dependency_check_blocks_old_transport_without_mutating_it(self):
        original = (ROOT / 'pubspec.yaml').read_text().replace(
            'https://gitee.com/imboy-tripartite-deps/jverify-flutter-plugin.git',
            'git@gitee.com:imboy-tripartite-deps/jverify-flutter-plugin.git')
        self.put('pubspec.yaml', original)
        completed = subprocess.run(['bash', str(ROOT / '.github/scripts/ci_patch_path_deps.sh'), '--check'],
                                   cwd=self.root, capture_output=True, text=True)
        self.assertEqual(completed.returncode, 2, completed.stdout + completed.stderr)
        self.assertIn('update the source explicitly before planning', completed.stderr)
        self.assertEqual((self.root / 'pubspec.yaml').read_text(), original)

    def test_new_file_under_legal_rule_enters_plan_without_registration(self):
        self.put('test/unit_test/future_model/new_test.dart', UNIT)
        selected = [r for r in self.plan()['instances'] if r['selected']]
        self.assertEqual({r['platform'] for r in selected
                          if r['target'].endswith('/new_test.dart')}, {'linux', 'macos'})

    def test_git_index_not_filesystem_drives_discovery(self):
        self.put('test/unowned/not_added_test.dart', UNIT, tracked=False)
        self.assertFalse(build_catalog(self.root, self.cfg)['errors'])
        self.git('add', '-N', '--', 'test/unowned/not_added_test.dart')
        self.fail('UNASSIGNED_TEST_SOURCE')

    def test_two_primary_rule_owners_are_rejected(self):
        self.cfg['rules'].append({'id': 'conflicting-widget',
                                  'prefixes': ['test/unit_test/'],
                                  'classifier': 'host-dart', 'suite': 'widget'})
        self.fail('MULTIPLE_PRIMARY_OWNERS')

    def test_reviewed_target_override_replaces_one_directory_owner(self):
        self.cfg['rules'][0]['suite'] = 'unit'
        self.cfg['overrides']['test/unit_test/base_test.dart'] = {
            'suite': 'component', 'basis': ['Reviewed in-process transport fixture']}
        self.assertEqual(validate_catalog(self.root, self.cfg)['targets'][0]['suite'], 'component')

    def add_registered_font_contract(self):
        from auto_test_lib.execution_adapters import REGISTERED_GOLDEN_FONT_SOURCE
        target = 'test/uiux/contract/font_contract_test.dart'
        self.put(target, (ROOT / target).read_text())
        self.put(REGISTERED_GOLDEN_FONT_SOURCE, (ROOT / REGISTERED_GOLDEN_FONT_SOURCE).read_text())
        self.cfg['rules'].append({'id': 'font-support', 'paths': [REGISTERED_GOLDEN_FONT_SOURCE],
                                  'classifier': 'support'})
        self.cfg['overrides'][target] = load_contract(ROOT)['overrides'][target]
        return target, REGISTERED_GOLDEN_FONT_SOURCE

    def test_registered_font_contract_stays_in_pr_full_and_coverage_without_pixel_baselines(self):
        target, source = self.add_registered_font_contract()
        pr, full, covered = self.plan(), self.plan(profile='full'), self.plan(coverage=True)
        for plan in (pr, full, covered):
            rows = [row for row in plan['instances'] if row['selected'] and row['target'] == target]
            self.assertEqual({'macos'}, {row['platform'] for row in rows})
            self.assertTrue(rows)
            for row in rows:
                self.assertEqual('component', row['suite'])
                self.assertEqual('flutter-machine', row['runner'])
                self.assertIn('registered-golden-font', row['dependencies'])
                self.assertIn(source, row['source_dependencies'])
                self.assertNotIn('golden-baseline', row['dependencies'])
                self.assertNotIn('test_name', row)  # The complete five-case file executes.
        self.assertEqual({row['id'] for row in pr['instances'] if row['selected']},
                         {row['id'] for row in covered['instances'] if row['selected']})
        self.assertEqual(pr['counts']['assigned_targets'], full['counts']['assigned_targets'])

    def test_linux_font_na_preserves_the_required_macos_obligation(self):
        target, _ = self.add_registered_font_contract()
        plan = self.plan(platforms=['linux'])
        rows = {row['platform']: row for row in plan['instances'] if row['target'] == target}
        self.assertEqual('PLATFORM_NA', rows['linux']['reason_code'])
        self.assertEqual('NOT_APPLICABLE', rows['linux']['status'])
        self.assertFalse(rows['linux']['required'])
        self.assertEqual('OUT_OF_SCOPE', rows['macos']['reason_code'])
        self.assertTrue(rows['macos']['required'])
        self.assertNotEqual(rows['linux']['id'], rows['macos']['id'])

    def test_changed_font_registration_shape_fails_the_ownership_gate(self):
        _, source = self.add_registered_font_contract()
        self.put(source, (self.root / source).read_text().replace(
            'kGoldenFontAssets = [', 'kGoldenFontAssets = buildFontRegistry(['))
        self.fail('REGISTERED_GOLDEN_FONT_REGISTRY_INVALID')

    def test_untracked_font_registry_cannot_supply_an_execution_dependency(self):
        _, source = self.add_registered_font_contract()
        self.cfg['rules'].pop()  # Isolate the dependency check from dangling rule checks.
        self.git('rm', '--cached', '--', source)
        self.fail('REGISTERED_GOLDEN_FONT_REGISTRY_UNTRACKED')

    def test_dangling_target_reference_is_rejected(self):
        self.cfg['profiles']['pr']['targets'] = ['test/unit_test/missing_test.dart']
        self.fail('UNKNOWN_PROFILE_TARGET')

    def test_profile_prefix_must_be_a_relative_directory_with_executable_targets(self):
        for prefix, error in [('test/unit_test/missing/', 'UNKNOWN_PROFILE_PREFIX'),
                              ('test/unit_test', 'INVALID_PROFILE_PREFIX'),
                              ('/test/unit_test/', 'INVALID_PROFILE_PREFIX'),
                              ('test/../unit_test/', 'INVALID_PROFILE_PREFIX')]:
            with self.subTest(prefix=prefix):
                self.cfg['profiles']['pr']['prefixes'] = [prefix]
                self.fail(error)
        self.put('test/unit_test/support/helper.dart', 'const fixtureValue = 1;\n')
        self.cfg['profiles']['pr']['prefixes'] = ['test/unit_test/support/']
        self.fail('UNKNOWN_PROFILE_PREFIX')

    def test_web_shell_prefix_automatically_selects_new_owned_tests_on_their_platforms(self):
        self.cfg['profiles']['web-shell'] = load_contract(ROOT)['profiles']['web-shell']
        host = 'test/unit_test/page/web_shell/new_view_test.dart'
        browser = 'test/unit_test/page/web_shell/new_browser_test.dart'
        self.put(host, WIDGET)
        self.put(browser, "@TestOn('browser')\n" + WIDGET)
        plan = self.plan(profile='web-shell', platforms=['linux', 'web'])
        selected = [r for r in plan['instances'] if r['selected']]
        self.assertEqual({(host, 'linux'), (browser, 'web')},
                         {(r['target'], r['platform']) for r in selected})
        self.assertNotIn('test/unit_test/base_test.dart', {r['target'] for r in selected})
        mac = next(r for r in plan['instances'] if r['target'] == host and r['platform'] == 'macos')
        self.assertTrue(mac['required'])
        self.assertEqual('OUT_OF_SCOPE', mac['reason_code'])
        browser_host = next(r for r in plan['instances']
                            if r['target'] == browser and r['platform'] == 'linux')
        self.assertEqual('PLATFORM_NA', browser_host['reason_code'])

    def test_repository_web_shell_profile_preserves_host_and_chrome_obligations(self):
        plan = build_plan(ROOT, profile='web-shell')
        selected = [r for r in plan['instances'] if r['selected']]
        self.assertGreaterEqual(len({r['target'] for r in selected}), 16)
        chrome = [r for r in selected
                  if r['target'].endswith('/web_shell_chrome_e2e_smoke_test.dart')]
        self.assertEqual(['web'], [r['platform'] for r in chrome])
        for platform in ('linux', 'macos'):
            subset = build_plan(ROOT, profile='web-shell', platforms=[platform, 'web'])
            self.assertEqual({r['id'] for r in selected if r['platform'] in {platform, 'web'}},
                             {r['id'] for r in subset['instances'] if r['selected']})

    def add_kill_replay_contract(self):
        from auto_test_lib.execution_adapters import KILL_REPLAY_TARGET
        self.put(KILL_REPLAY_TARGET, (ROOT / KILL_REPLAY_TARGET).read_text())
        self.cfg['overrides'][KILL_REPLAY_TARGET] = load_contract(ROOT)['overrides'][KILL_REPLAY_TARGET]
        self.put('scripts/auto_test_lib/execution_adapters.py',
                 'def run_kill_replay(): pass\ndef verify_kill_replay_evidence(): pass\n')
        return KILL_REPLAY_TARGET

    def test_kill_replay_has_one_real_android_controller_and_preserves_its_obligation(self):
        target = self.add_kill_replay_contract()
        rows = [r for r in self.plan(profile='full')['instances'] if r['target'] == target]
        selected = [r for r in rows if r['selected']]
        self.assertEqual(1, len(selected))
        self.assertEqual('android', selected[0]['platform'])
        self.assertEqual('sqlite-kill-replay', selected[0]['orchestration'])
        self.assertNotIn('isolated-backend', selected[0]['dependencies'])
        self.assertEqual('any', selected[0]['product_contract']['manifest_profile'])
        rows = {r['platform']: r for r in self.plan(profile='full', platforms=['macos'])['instances']
                if r['target'] == target}
        self.assertEqual('PLATFORM_NA', rows['macos']['reason_code'])
        self.assertEqual('OUT_OF_SCOPE', rows['android']['reason_code'])
        self.assertTrue(rows['android']['required'])

    def test_kill_replay_cannot_fall_back_to_ordinary_single_device_invocation(self):
        target = self.add_kill_replay_contract()
        del self.cfg['overrides'][target]
        self.fail('KILL_REPLAY_ORCHESTRATION_REQUIRED')

    def test_kill_replay_cannot_claim_an_unimplemented_platform(self):
        target = self.add_kill_replay_contract()
        self.cfg['overrides'][target]['platforms'].append('macos')
        self.fail('KILL_REPLAY_ORCHESTRATION_REQUIRED')

    def test_kill_replay_requires_both_a_real_controller_and_evidence_verifier(self):
        target = self.add_kill_replay_contract()
        self.put('scripts/auto_test_lib/execution_adapters.py', 'def run_kill_replay(): pass\n')
        self.fail('ORCHESTRATION_CALLABLE_MISSING')
        self.cfg['overrides'][target]['orchestration_entrypoint']['entrypoint'] = 'scripts/missing.py'
        self.fail('ORCHESTRATION_ENTRYPOINT_MISSING')

    def test_dangling_explicit_override_is_rejected(self):
        self.cfg['overrides']['test/missing_test.dart'] = {'suite': 'unit', 'basis': ['reviewed']}
        self.fail('DANGLING_OVERRIDE')

    def test_suite_without_runner_is_rejected(self):
        del self.cfg['suites']['unit']['runner']
        self.fail('SUITE_RUNNER_MISSING')

    def test_runner_without_real_entrypoint_is_rejected(self):
        self.cfg['runners']['flutter-machine']['entrypoint'] = 'scripts/no_runner.py'
        self.fail('RUNNER_ENTRYPOINT_MISSING')

    def test_existing_file_without_runner_callable_is_rejected(self):
        self.put('scripts/auto_test_lib/execution_runner.py', '# documentation only\n')
        self.fail('RUNNER_CALLABLE_MISSING')

    def test_duplicate_json_ownership_keys_are_rejected(self):
        self.put('test/auto_test/execution_contract.json', '{"overrides": {}, "overrides": {}}')
        with self.assertRaisesRegex(ContractError, 'DUPLICATE_CONFIG_KEY'):
            load_contract(self.root)

    def test_unknown_runner_adapter_is_rejected(self):
        self.cfg['runners']['flutter-machine']['adapter'] = 'exit-zero-only'
        self.fail('RUNNER_ADAPTER_MISMATCH')

    def test_tracked_target_removed_from_worktree_is_dangling(self):
        (self.root / 'test/unit_test/base_test.dart').unlink()
        self.fail('TRACKED_TARGET_MISSING')

    def test_sqlite_classification_follows_test_helper_imports(self):
        self.put('test/unit_test/helper.dart', "import 'package:sqflite_common_ffi/sqflite_ffi.dart';\nvoid prepare() {}\n")
        self.put('test/unit_test/model_test.dart', "import 'helper.dart';\n" + UNIT)
        rows = {r['target']: r for r in validate_catalog(self.root, self.cfg)['entries']}
        self.assertEqual(rows['test/unit_test/model_test.dart']['suite'], 'sqlite-ffi')
        self.assertEqual(rows['test/unit_test/helper.dart']['kind'], 'helper')

    def test_dependency_names_in_comments_or_strings_are_not_native_dependencies(self):
        self.put('test/unit_test/documentation_test.dart',
                 "// import 'package:vodozemac/vodozemac.dart';\n" +
                 "const source = \"matchesGoldenFile('x.png')\";\n" + UNIT)
        rows = {r['target']: r for r in validate_catalog(self.root, self.cfg)['targets']}
        self.assertEqual(rows['test/unit_test/documentation_test.dart']['suite'], 'unit')

    def test_raw_dart_backslash_literal_does_not_hide_main(self):
        self.put('test/unit_test/parser_test.dart', "const slash = r'\\';\n" + UNIT)
        self.assertFalse(build_catalog(self.root, self.cfg)['errors'])

    def test_platform_na_and_out_of_scope_preserve_other_platform_obligation(self):
        self.put('test/unit_test/mac_only_test.dart', UNIT)
        self.cfg['overrides']['test/unit_test/mac_only_test.dart'] = {
            'platforms': ['macos'], 'basis': ['Uses a declared macOS-only fixture']}
        plan = self.plan(profile='full', platforms=['linux'])
        rows = {r['platform']: r for r in plan['instances']
                if r['target'].endswith('mac_only_test.dart')}
        self.assertEqual(rows['linux']['reason_code'], 'PLATFORM_NA')
        self.assertFalse(rows['linux']['applicable'])
        self.assertEqual(rows['macos']['reason_code'], 'OUT_OF_SCOPE')
        self.assertTrue(rows['macos']['applicable'])
        self.assertTrue(rows['macos']['required'])
        self.assertFalse(plan['full_regression'])

    def test_two_device_target_never_enters_single_device_plan(self):
        self.put('integration_test/single_test.dart', DEVICE)
        self.put('integration_test/pair_test.dart', DEVICE)
        self.cfg['overrides']['integration_test/pair_test.dart'] = {
            'suite': 'device-pair', 'pair_group': 'real-pair',
            'orchestration': 'dual-concurrent',
            'roles': [{'role': 'sender', 'platforms': ['android']},
                      {'role': 'receiver', 'platforms': ['macos']}],
            'basis': ['Explicit paired sender/receiver fixture']}
        plan = self.plan(profile='device-single')
        selected = [r for r in plan['instances'] if r['selected']]
        self.assertTrue(selected)
        self.assertEqual({r['target'] for r in selected}, {'integration_test/single_test.dart'})
        pairs = [r for r in plan['instances'] if r['target'].endswith('pair_test.dart') and r['applicable']]
        self.assertEqual({r['reason_code'] for r in pairs}, {'OUT_OF_SCOPE'})

    def test_new_two_client_family_cannot_default_to_single_device(self):
        self.cfg['rules'][1]['review_prefixes'] = ['integration_test/two_client/']
        self.put('integration_test/two_client/new_peer_test.dart', DEVICE)
        self.fail('SPECIALIST_TOPOLOGY_REQUIRES_REVIEW')

    def test_pair_needs_real_orchestration_and_complete_roles(self):
        target = 'integration_test/pair_test.dart'
        self.put(target, DEVICE)
        self.cfg['overrides'][target] = {'suite': 'device-pair',
            'pair_group': 'synthetic-pair', 'basis': ['Two native peer roles']}
        self.fail('PAIR_ORCHESTRATION_MISSING')
        self.cfg['overrides'][target].update(orchestration='dual-concurrent')
        self.fail('PAIR_ROLES_MISSING')
        self.cfg['overrides'][target]['roles'] = [{'role': 'sender', 'platforms': ['android']}]
        self.fail('PAIR_TOPOLOGY_INVALID')

    def test_pair_platform_selector_includes_the_required_companion(self):
        target = 'integration_test/pair_test.dart'
        self.put(target, DEVICE)
        self.cfg['overrides'][target] = {'suite': 'device-pair',
            'pair_group': 'synthetic-pair', 'orchestration': 'dual-concurrent',
            'roles': [{'role': 'sender', 'platforms': ['android']},
                      {'role': 'receiver', 'platforms': ['macos']}],
            'basis': ['The Android step requires the macOS response']}
        plan = self.plan(profile='full', platforms=['android'], targets=[target])
        selected = [r for r in plan['instances'] if r['selected']]
        self.assertEqual({r['platform'] for r in selected}, {'android', 'macos'})
        self.assertEqual(next(r for r in selected if r['platform'] == 'macos')['selected_via'], 'pair-companion')
        self.assertFalse(plan['full_regression'])

    def test_independent_same_platform_pairs_do_not_pull_another_platform(self):
        target = 'integration_test/pair_test.dart'
        self.put(target, DEVICE)
        self.cfg['overrides'][target] = {'suite': 'device-pair',
            'pair_group': 'synthetic-pair', 'orchestration': 'dual-sequential',
            'pair_topology': 'same-platform', 'roles': ['sender', 'receiver'],
            'basis': ['Each host runs an independent sequential pair']}
        plan = self.plan(profile='full', platforms=['android'], targets=[target])
        selected = [r for r in plan['instances'] if r['selected']]
        self.assertEqual(len(selected), 2)
        self.assertEqual({r['platform'] for r in selected}, {'android'})
        mac = [r for r in plan['instances'] if r['target'] == target and r['platform'] == 'macos']
        self.assertTrue(all(r['reason_code'] == 'OUT_OF_SCOPE' for r in mac))

    def test_pr_and_coverage_select_identical_declared_targets(self):
        self.put('test/unit_test/view_test.dart', WIDGET)
        self.put('test/unit_test/golden_test.dart', WIDGET.replace(
            "async {}", "async { await expectLater(1, matchesGoldenFile('baseline.png')); }"))
        plain, covered = self.plan(), self.plan(coverage=True)
        selected = lambda p: {r['id'] for r in p['instances'] if r['selected']}
        self.assertEqual(selected(plain), selected(covered))
        self.assertFalse(any(r['selected'] and r['suite'] == 'golden' for r in covered['instances']))
        self.assertTrue(all(r['coverage_eligible'] for r in plain['instances'] if r['selected']))
        self.assertTrue(all(r['coverage'] for r in covered['instances'] if r['selected']))

    def test_platform_product_and_role_matrices_are_not_file_deduplicated(self):
        self.cfg['suites']['unit']['products'] = ['phase1_delivery', 'full-selected']
        self.cfg['overrides']['test/unit_test/base_test.dart'] = {
            'roles': ['sender', 'receiver'], 'basis': ['Synthetic matrix contract']}
        selected = [r for r in self.plan(profile='full')['instances'] if r['selected']]
        self.assertEqual(len(selected), 8)
        self.assertEqual(len({r['id'] for r in selected}), 8)
        self.assertEqual({r['product_profile'] for r in selected}, {'phase1_delivery', 'full-selected'})

    def test_empty_roles_or_variants_cannot_silently_remove_target(self):
        target = 'test/unit_test/base_test.dart'
        for field, code in [('roles', 'INVALID_TARGET_ROLES'),
                            ('variants', 'INVALID_TARGET_VARIANTS')]:
            with self.subTest(field=field):
                self.cfg['overrides'][target] = {field: [], 'basis': ['Malformed matrix']}
                self.fail(code)

    def test_role_platforms_cannot_hide_undeclared_topology(self):
        self.cfg['overrides']['test/unit_test/base_test.dart'] = {
            'roles': [{'role': 'unexpected-device', 'platforms': ['android']}],
            'basis': ['Invalid role matrix']}
        self.fail('INVALID_ROLE_PLATFORMS')

    def route_contract(self, routes):
        target = 'test/unit_test/smoke/route_smoke_test.dart'
        registry = 'test/unit_test/smoke/route_registry.dart'
        self.put(target, "import 'package:flutter_test/flutter_test.dart';\n"
                 "void main() { group('Route smoke test', () { testWidgets('x', (t) async {}); }); "
                 "test('registry remains complete', () {}); }\n")
        self.put(registry, "class SmokeRoute { const SmokeRoute({required String name}); }\n"
                 "final smokeRoutes = [" + ','.join("SmokeRoute(name: '" + name + "')" for name in routes) + "];\n")
        self.cfg['overrides'][target] = {'suite': 'route-smoke',
            'route_registry': {'path': registry, 'test_group': 'Route smoke test'},
            'basis': ['Existing process-isolated route registry contract']}
        return target, registry

    def test_route_addition_automatically_gets_isolated_execution_instance(self):
        target, _ = self.route_contract(['first', 'second'])
        selected = [r for r in self.plan(profile='full')['instances']
                    if r['selected'] and r['target'] == target]
        self.assertEqual(len(selected), 6)
        self.assertEqual({r['variant'] for r in selected},
                         {'route:first', 'route:second', 'non-route-contracts'})
        self.assertTrue(all(r['process_isolation'] == 'variant' and r['test_name'] for r in selected))
        self.route_contract(['first', 'second', 'new_route'])
        after = [r for r in self.plan(profile='full')['instances']
                 if r['selected'] and r['target'] == target]
        self.assertEqual(len(after), 8)
        self.assertEqual(len({r['id'] for r in after}), 8)

    def test_dynamic_or_duplicate_route_names_require_review(self):
        _, registry = self.route_contract(['first', 'first'])
        self.fail('ROUTE_REGISTRY_REQUIRES_REVIEW')
        self.put(registry, "final smokeRoutes = [SmokeRoute(name: dynamicName)];\n")
        self.fail('ROUTE_REGISTRY_REQUIRES_REVIEW')

    def test_route_group_change_cannot_silently_omit_contracts(self):
        target, _ = self.route_contract(['first'])
        self.put(target, UNIT)
        self.fail('ROUTE_TEST_GROUP_CHANGED')

    def test_explicit_variant_filter_is_scoped_and_preserves_other_obligations(self):
        target, _ = self.route_contract(['first', 'second'])
        plan = self.plan(profile='full', variants=['route:first'])
        selected = [r for r in plan['instances'] if r['selected']]
        self.assertEqual({r['target'] for r in selected}, {target})
        self.assertEqual({r['variant'] for r in selected}, {'route:first'})
        self.assertEqual(plan['selectors']['variants'], ['route:first'])
        self.assertFalse(plan['full_regression'])
        unselected = [r for r in plan['instances'] if r['target'] == target
                      and r['variant'] == 'route:second' and r['applicable']]
        self.assertTrue(all(r['required'] and r['reason_code'] == 'OUT_OF_SCOPE' for r in unselected))
        with self.assertRaisesRegex(ContractError, 'UNKNOWN_SELECTED_VARIANT'):
            self.plan(variants=['route:never_registered'])

    def test_empty_full_regression_is_rejected(self):
        self.git('rm', '-f', '--', 'test/unit_test/base_test.dart')
        with self.assertRaisesRegex(ContractError, 'EMPTY_EXECUTION_PLAN'):
            self.plan(profile='full')

    def test_nonempty_catalog_but_empty_selection_is_rejected(self):
        with self.assertRaisesRegex(ContractError, 'EMPTY_EXECUTION_PLAN'):
            self.plan(targets=[])

    def test_disabled_is_not_an_execution_owner(self):
        self.cfg['overrides']['test/unit_test/base_test.dart'] = {
            'enabled': False, 'basis': ['Not actually a runner']}
        self.fail('DISABLED_OWNERSHIP_NOT_ALLOWED')

    def test_business_test_cannot_be_hidden_as_helper(self):
        self.cfg['overrides']['test/unit_test/base_test.dart'] = {
            'kind': 'helper', 'basis': ['Incorrect classification']}
        self.fail('EXECUTABLE_MISCLASSIFIED_AS_SUPPORT')

    def test_browser_annotation_never_goes_to_host_vm(self):
        self.put('test/unit_test/browser_test.dart', "@TestOn('chrome')\nlibrary;\n" + UNIT)
        plan = self.plan(profile='full')
        selected = [r for r in plan['instances'] if r['selected'] and r['target'].endswith('browser_test.dart')]
        self.assertEqual([r['platform'] for r in selected], ['web'])
        self.assertIn('chrome', selected[0]['dependencies'])
        pr_rows = self.plan()['instances']
        pr_web = next(r for r in pr_rows
                      if r['target'].endswith('browser_test.dart') and r['platform'] == 'web')
        self.assertTrue(pr_web['selected'])
        self.assertTrue(pr_web['required'])
        host_web = next(r for r in pr_rows if r['target'].endswith('base_test.dart')
                        and r['platform'] == 'web')
        self.assertEqual('PLATFORM_NA', host_web['reason_code'])
        for profile in ('pr', 'full'):
            with self.subTest(profile=profile):
                scoped = self.plan(profile=profile, platforms=['linux'])['instances']
                browser = {r['platform']: r for r in scoped
                           if r['target'].endswith('browser_test.dart')}
                self.assertEqual('PLATFORM_NA', browser['linux']['reason_code'])
                self.assertEqual('OUT_OF_SCOPE', browser['web']['reason_code'])
                self.assertTrue(browser['web']['required'])
                self.assertFalse(browser['web']['selected'])

    def test_repository_pr_and_web_profiles_retain_browser_obligations(self):
        selected = {profile: [r for r in build_plan(ROOT, profile=profile)['instances']
                              if r['selected']]
                    for profile in ('pr', 'full', 'web')}
        browser = selected['web']
        known_targets = {
            'test/unit_test/page/chat/chat/chat_provider_chrome_import_smoke_test.dart',
            'test/unit_test/page/chat/chat/chat_provider_chrome_runtime_smoke_test.dart',
            'test/unit_test/page/web_shell/web_shell_chrome_e2e_smoke_test.dart',
            'test/unit_test/service/migration_v38_fts_web_test.dart',
            'test/unit_test/service/offline_group_wire_web_test.dart',
        }
        self.assertLessEqual(known_targets, {r['target'] for r in browser})
        browser_ids = {r['id'] for r in browser}
        self.assertEqual(browser_ids, {r['id'] for r in selected['pr'] if r['platform'] == 'web'})
        self.assertLessEqual(browser_ids, {r['id'] for r in selected['full']})
        for row in browser:
            with self.subTest(target=row['target']):
                self.assertEqual('web', row['platform'])
                self.assertEqual('flutter-machine', row['runner'])
                self.assertIn('chrome', row['dependencies'])
                self.assertFalse({'isolated-backend', 'isolated-accounts', 'native-sqlcipher'}
                                 & set(row['dependencies']))
                self.assertFalse(row.get('required_env'))
                self.assertFalse(row['coverage'])
                self.assertEqual('phase1_delivery', row['product_profile'])

    def add_wasm_web_fixtures(self):
        targets = ('test/unit_test/service/migration_v38_fts_web_test.dart',
                   'test/unit_test/service/offline_group_wire_web_test.dart')
        fixture = 'test/fixtures/sqlite3.wasm'
        source = 'web/sqlite3.wasm'
        actual = load_contract(ROOT)
        for target in targets:
            self.put(target, (ROOT / target).read_text())
        destination = self.root / source
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes((ROOT / source).read_bytes())
        self.git('add', '--', source)
        alias = self.root / fixture
        alias.parent.mkdir(parents=True, exist_ok=True)
        alias.symlink_to((ROOT / fixture).readlink())
        self.git('add', '--', fixture)
        for path in (*targets, fixture):
            self.cfg['overrides'][path] = actual['overrides'][path]
        self.cfg['profiles']['web'] = actual['profiles']['web']
        return targets, fixture, source

    def test_browser_sqlite_plans_share_tracked_same_origin_application_wasm(self):
        targets, fixture, source = self.add_wasm_web_fixtures()
        self.assertEqual('fixture', self.cfg['overrides'][fixture]['kind'])
        for profile in ('pr', 'full', 'web'):
            selected = [r for r in self.plan(profile=profile)['instances']
                        if r['selected'] and r['target'] in targets]
            self.assertEqual({(t, 'web') for t in targets},
                             {(r['target'], r['platform']) for r in selected})
            for item in selected:
                with self.subTest(profile=profile, target=item['target']):
                    self.assertEqual('flutter-machine', item['runner'])
                    self.assertEqual({'SQLITE_WASM_URL': '/fixtures/sqlite3.wasm'}, item['dart_defines'])
                    self.assertEqual({fixture, source}, set(item['source_dependencies']))
                    served = self.root / 'test' / item['dart_defines']['SQLITE_WASM_URL'].lstrip('/')
                    self.assertTrue(served.samefile(self.root / source))
                    self.assertEqual(b'\x00asm\x01\x00\x00\x00', served.read_bytes()[:8])
                    self.assertFalse(item.get('required_env'))

    def test_wasm_fixture_must_be_tracked_and_resolve_to_a_present_asset(self):
        _, fixture, source = self.add_wasm_web_fixtures()
        self.git('rm', '--cached', '--', fixture)
        self.fail('DANGLING_OVERRIDE')
        self.git('add', '--', fixture)
        (self.root / source).unlink()
        self.fail('DANGLING_OVERRIDE')

    def test_wasm_source_change_invalidates_the_frozen_browser_plan(self):
        from auto_test_lib import execution_catalog, execution_cli
        _, _, source = self.add_wasm_web_fixtures()
        self.put('test/auto_test/execution_contract.json', json.dumps(self.cfg))
        self.git('-c', 'user.name=fixture', '-c', 'user.email=fixture@example.invalid',
                 'commit', '-qm', 'synthetic WASM baseline')
        original = self.plan(profile='web')
        self.assertEqual(original, execution_cli.validate_saved_plan(self.root, original, execution_catalog))
        with (self.root / source).open('ab') as asset:
            asset.write(b'synthetic-change')
        changed = self.plan(profile='web')
        self.assertNotEqual(original['source_fingerprint'], changed['source_fingerprint'])
        with self.assertRaisesRegex(ValueError, 'PLAN_SOURCE_FINGERPRINT_MISMATCH'):
            execution_cli.validate_saved_plan(self.root, original, execution_catalog)

    def test_sqlcipher_fts_offline_contract_retains_each_native_platform(self):
        target = 'integration_test/sqlcipher_fts_v38_draft_test.dart'
        self.put(target, (ROOT / target).read_text())
        self.cfg['platforms'].append('ios')
        self.cfg['overrides'][target] = load_contract(ROOT)['overrides'][target]
        native = [row for row in self.plan(profile='full')['instances']
                  if row['selected'] and row['target'] == target]
        self.assertEqual({'android', 'ios', 'macos'}, {row['platform'] for row in native})
        for row in native:
            self.assertEqual('device-single', row['suite'])
            self.assertEqual('flutter-device', row['runner'])
            self.assertTrue(row['offline'])
            self.assertEqual('any', row['product_contract']['manifest_profile'])
            self.assertIn('native-sqlcipher', row['dependencies'])
            self.assertFalse({'isolated-backend', 'isolated-accounts'} & set(row['dependencies']))
        scoped = {row['platform']: row for row in self.plan(profile='full', platforms=['linux'])['instances']
                  if row['target'] == target}
        self.assertEqual('PLATFORM_NA', scoped['linux']['reason_code'])
        for platform in ('android', 'ios', 'macos'):
            self.assertEqual('OUT_OF_SCOPE', scoped[platform]['reason_code'])
            self.assertTrue(scoped[platform]['required'])

    def test_saved_selectors_and_coverage_eligibility_are_explicit(self):
        plan = self.plan(platforms=['linux'])
        self.assertEqual(plan['selectors']['platforms'], ['linux'])
        self.assertEqual(plan['profile'], 'pr')
        self.assertNotIn('profile', plan['selectors'])
        self.assertFalse(plan['full_regression'])
        self.assertTrue(all(r['coverage_eligible'] for r in plan['instances'] if r['selected']))

    def test_product_artifacts_cannot_hide_arbitrary_runtime_changes(self):
        from auto_test_lib.execution_adapters import PRODUCT_ARTIFACTS
        self.cfg['product_artifacts'] = list(PRODUCT_ARTIFACTS) + ['lib/arbitrary.dart']
        self.fail('PRODUCT_ARTIFACT_SET_INVALID')

    def test_python_tooling_is_independent_of_application_product_artifacts(self):
        self.put('test/tooling/test_contract.py',
                 'import unittest\nclass Contract(unittest.TestCase):\n    def test_contract(self): pass\n')
        self.cfg['suites']['tooling']['product_independent'] = True
        rows = [r for r in self.plan()['instances'] if r['selected'] and r['suite'] == 'tooling']
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]['product_contract']['manifest_profile'], 'any')
        self.assertEqual(rows[0]['product_profile'], 'phase1_delivery')

    def test_application_tests_cannot_bypass_product_verification(self):
        self.cfg['suites']['unit']['product_independent'] = True
        self.fail('PRODUCT_INDEPENDENCE_REQUIRES_REVIEWED_OFFLINE_NATIVE_OR_TOOLING')

    def test_rtc_widget_contract_retains_both_real_product_obligations(self):
        target = 'test/unit_test/page/contact/people_info_rtc_feature_gate_test.dart'
        actual = load_contract(ROOT)
        self.put(target, WIDGET)
        self.cfg['overrides'][target] = actual['overrides'][target]
        self.cfg['products']['full-selected'] = actual['products']['full-selected']
        selected = lambda plan: [r for r in plan['instances'] if r['selected'] and r['target'] == target]
        pr, full = selected(self.plan()), selected(self.plan(profile='full'))
        self.assertEqual({r['product_profile'] for r in pr}, {'phase1_delivery'})
        self.assertEqual(len(full), 4)
        self.assertEqual({r['product_profile'] for r in full}, {'phase1_delivery', 'full-selected'})
        rtc = [r for r in full if r['product_profile'] == 'full-selected']
        self.assertTrue(all('rtc' in r['product_contract']['required_features'] for r in rtc))

    def test_native_product_independence_is_bound_to_offline_reviewed_source(self):
        target = 'integration_test/native_test.dart'
        self.put(target, DEVICE)
        self.cfg['overrides'][target] = {'suite': 'device-single',
            'offline': True, 'product_independent': True,
            'reviewed_source_sha256': hashlib.sha256(DEVICE.encode()).hexdigest(),
            'basis': ['Synthetic native channel harness without app bootstrap or product behavior']}
        native = [r for r in self.plan(profile='full')['instances'] if r['selected'] and r['target'] == target]
        self.assertTrue(native)
        self.assertTrue(all(r['product_contract']['manifest_profile'] == 'any' for r in native))
        changed = "import 'package:imboy/main.dart' as app;\n" + DEVICE
        self.put(target, changed)
        self.fail('PRODUCT_INDEPENDENCE_REQUIRES_REVIEWED_OFFLINE_NATIVE_OR_TOOLING')
        self.cfg['overrides'][target]['reviewed_source_sha256'] = hashlib.sha256(changed.encode()).hexdigest()
        self.fail('PRODUCT_INDEPENDENCE_REQUIRES_REVIEWED_OFFLINE_NATIVE_OR_TOOLING')

    def test_diagnostic_driver_cannot_hide_new_business_assertions(self):
        target = 'integration_test/diagnostic_test.dart'
        self.put(target, DEVICE)
        self.cfg['overrides'][target] = {'kind': 'driver', 'non_asserting_utility': True,
            'reviewed_source_sha256': hashlib.sha256(DEVICE.encode()).hexdigest(),
            'basis': ['Explicit diagnostic with no business oracle']}
        self.assertFalse(build_catalog(self.root, self.cfg)['errors'])
        changed = DEVICE.replace('async {}', 'async { expect(1, 1); }')
        self.put(target, changed)
        self.cfg['overrides'][target]['reviewed_source_sha256'] = hashlib.sha256(changed.encode()).hexdigest()
        self.fail('EXECUTABLE_MISCLASSIFIED_AS_SUPPORT')

    def test_product_matrix_accepts_separate_generated_artifacts_but_pins_other_source(self):
        from auto_test_lib.execution_adapters import PRODUCT_ARTIFACTS
        self.cfg['product_artifacts'] = list(PRODUCT_ARTIFACTS)
        artifact = PRODUCT_ARTIFACTS[0]
        self.put(artifact, '// phase1 generated artifact\n')
        self.put('lib/logic.dart', 'const value = 1;\n')
        self.git('-c', 'user.name=fixture', '-c', 'user.email=fixture@example.invalid',
                 'commit', '-qm', 'synthetic baseline')
        baseline = self.plan(profile='full')
        (self.root / artifact).write_text('// separately generated full-selected artifact\n')
        next_profile = self.plan(profile='full')
        self.assertEqual(baseline['source_fingerprint'], next_profile['source_fingerprint'])
        self.assertIn('fingerprints required', next_profile['product_artifact_validation'])
        (self.root / 'lib/logic.dart').write_text('const value = 2;\n')
        self.assertNotEqual(baseline['source_fingerprint'], self.plan(profile='full')['source_fingerprint'])


class BackendProductContractTests(unittest.TestCase):
    def test_real_full_matrix_pairs_api_targets_with_matching_backend_profiles(self):
        planned = build_plan(ROOT, profile='full')
        rows = [r for r in planned['instances'] if r['selected']]
        self.assertEqual(3457, len(rows))
        self.assertEqual(1502, len({r['target'] for r in rows}))
        for platform in ('linux', 'macos'):
            api = [r for r in rows if r['platform'] == platform and r['suite'] == 'backend-contract']
            self.assertEqual({'phase1_delivery': 37, 'full-selected': 9},
                             {p: sum(r['product_profile'] == p for r in api)
                              for p in ('phase1_delivery', 'full-selected')})
            for row in api:
                expected = 'community' if row['product_profile'] == 'full-selected' else 'phase1_delivery'
                self.assertEqual(expected, row['product_contract']['backend_runtime_profile'])
            backup = [r for r in api if r['target'].endswith('/e2ee_backup_api_test.dart')]
            self.assertEqual(2, len(backup))
            self.assertEqual([[], ['e2ee']],
                             [r.get('required_features', []) for r in sorted(backup,
                              key=lambda r: r['product_profile'], reverse=True)])


if __name__ == '__main__':
    unittest.main()

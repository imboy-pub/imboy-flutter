"""Execution adapter contracts: offline safety, real device roles and evidence."""
from __future__ import annotations

import base64
import copy
import hashlib
import json
import os
import subprocess
import sys
import tempfile
import threading
import time
import unittest
from pathlib import Path
from unittest.mock import Mock, patch

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / 'scripts'))
from auto_test_lib import execution_adapters as adapters
from auto_test_lib.devices import qualify_device


DEVICES = [
    {'id': 'android-a', 'targetPlatform': 'android-arm64', 'emulator': False},
    {'id': 'android-b', 'targetPlatform': 'android-arm64', 'emulator': False},
    {'id': 'mac', 'targetPlatform': 'darwin', 'emulator': False},
    {'id': 'ios-a', 'targetPlatform': 'ios', 'emulator': False},
]
ENV = {
    'IMBOY_TEST_ISOLATED': 'true', 'APP_ENV': 'local',
    'API_BASE_URL': 'http://127.0.0.1:9800', 'WS_URL_OVERRIDE': 'ws://127.0.0.1:9800/ws',
    'TEST_PHONE': 'synthetic-account', 'TEST_PASSWORD': 'synthetic-password',
    'IMBOY_SOLIDIFIED_KEY': 'synthetic-key', 'IMBOY_SOLIDIFIED_KEY_IV_OVERRIDE': 'synthetic-iv',
    'TEST_ALLOW_BUSINESS_WRITES': 'true',
}


def instance(role='primary', platform='android', method=None, target='integration_test/fixture_test.dart'):
    return {'id': json.dumps([target, platform, role]), 'target': target, 'role': role,
            'platform': platform, 'suite': 'device-pair' if method else 'device-single',
            'runner': 'device-pair' if method else 'flutter-device',
            'orchestration': method, 'product_profile': 'current', 'dependencies': [],
            'device_id': 'mac' if platform == 'macos' else 'android-a', 'offline': True}


class AdapterEnvironmentTests(unittest.TestCase):
    def setUp(self):
        self.item = instance()
        self.item['offline'] = False

    def test_loopback_and_explicit_fixture_credentials_are_required(self):
        self.assertEqual([], adapters.backend_environment_errors(self.item, ENV))
        for missing, expected in [('IMBOY_TEST_ISOLATED', 'ISOLATED_FIXTURE_OPT_IN'),
                                  ('TEST_PHONE', 'ISOLATED_TEST_ACCOUNT'),
                                  ('IMBOY_SOLIDIFIED_KEY', 'ISOLATED_SIGNING_KEY'),
                                  ('IMBOY_SOLIDIFIED_KEY_IV_OVERRIDE', 'ISOLATED_SIGNING_IV')]:
            env = {k: v for k, v in ENV.items() if k != missing}
            self.assertTrue(any(expected in e for e in adapters.backend_environment_errors(self.item, env)))

    def test_no_network_probe_when_any_isolation_contract_is_missing(self):
        with patch.object(adapters.socket, 'create_connection') as connect:
            env = {**ENV, 'IMBOY_TEST_ISOLATED': 'false'}
            self.assertTrue(adapters.backend_environment_errors(self.item, env, probe=True))
            connect.assert_not_called()
            env = {**ENV, 'WS_URL_OVERRIDE': 'wss://pro.imboy.pub/ws'}
            self.assertTrue(adapters.backend_environment_errors(self.item, env, probe=True))
            connect.assert_not_called()

    def test_remote_urls_and_url_credentials_are_rejected(self):
        for url in ('https://pro.imboy.pub', 'http://localhost:9800',
                    'http://127.0.0.1@remote.example', 'http://user:pass@127.0.0.1:9800', ''):
            errors = adapters.backend_environment_errors(self.item, {**ENV, 'API_BASE_URL': url})
            self.assertIn('ISOLATED_LOOPBACK_URL_REQUIRED:API_BASE_URL', errors)

    def test_offline_native_harness_needs_no_accounts_or_backend(self):
        self.item['offline'] = True
        self.item['dependencies'] = ['backend', 'accounts', 'native-crypto']
        self.assertEqual([], adapters.backend_environment_errors(self.item, {}))

    def test_role_credentials_and_history_device_reuse_are_explicit(self):
        i = {**self.item, 'role': 'history-sender', 'account_role': 'sender', 'device_role': 'sender'}
        env = {**ENV, 'TEST_PHONE': '', 'TEST_PASSWORD': '',
               'IMBOY_SENDER_TEST_PHONE': 'synthetic-sender', 'IMBOY_SENDER_TEST_PASSWORD': 'secret',
               'IMBOY_EXECUTION_DEVICE_SENDER': 'android-b'}
        i.pop('device_id')
        self.assertEqual([], adapters.backend_environment_errors(i, env))
        self.assertEqual('android-b', adapters.device_id_for(i, env))

    def test_ios_remains_excluded_from_legacy_qualifier_but_explicit_adapter_allows_it(self):
        self.assertEqual(('', ['IOS_DEVICE_NOT_IN_PLATFORM_SET']), qualify_device('ios-a', DEVICES))
        self.assertEqual(('ios', []), qualify_device('ios-a', DEVICES, allowed_platforms={'ios'}))
        i = {**instance(platform='ios'), 'device_id': 'ios-a'}
        with patch.object(adapters.shutil, 'which', return_value='/fake/flutter'):
            self.assertEqual([], adapters.preflight_instance(ROOT, i, {}, DEVICES))

    def test_ios_simulator_and_android_emulator_cannot_masquerade_as_real_devices(self):
        self.assertIn('IOS_SIMULATOR_FORBIDDEN', qualify_device('sim', [
            {'id': 'sim', 'targetPlatform': 'ios', 'emulator': True}], allowed_platforms={'ios'})[1])
        self.assertIn('ANDROID_EMULATOR_FORBIDDEN', qualify_device('em', [
            {'id': 'em', 'targetPlatform': 'android-arm64', 'emulator': True}])[1])

    def test_product_alias_uses_manifest_contract_not_display_profile(self):
        i = {'product_profile': 'phase1_delivery-channel-disabled',
             'product_contract': {'manifest_profile': 'phase1_delivery'}}
        evidence = {'manifest_profile': 'phase1_delivery', 'compiled_features': ['core'],
                    'fingerprint': 'verified', 'errors': []}
        with patch.object(adapters, '_validated_product_artifacts', return_value=evidence):
            self.assertEqual([], adapters.product_artifact_evidence(ROOT, i, {})['errors'])
            i['product_contract']['required_features'] = ['rtc']
            self.assertIn('COMPILED_FEATURE_MISSING:rtc', adapters.product_artifact_evidence(ROOT, i, {})['errors'])
            i['product_contract']['manifest_profile'] = 'full-selected'
            self.assertIn('PRODUCT_PROFILE_BUILD_REQUIRED:full-selected', adapters.product_artifact_evidence(ROOT, i, {})['errors'])

    def test_product_drift_signature_changes_when_an_artifact_changes(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            artifact = root / adapters.PRODUCT_ARTIFACTS[0]
            artifact.parent.mkdir(parents=True)
            artifact.write_text('one')
            with patch.object(adapters, '_validated_product_artifacts', return_value={'errors': ['DRIFT']}) as render:
                adapters.product_artifact_evidence(root, {'product_profile': 'phase1_delivery'}, {})
                first = render.call_args.args[2]
                artifact.write_text('two')
                adapters.product_artifact_evidence(root, {'product_profile': 'phase1_delivery'}, {})
                self.assertNotEqual(first, render.call_args.args[2])

    def test_flutter_invocation_never_runs_implicit_pub_and_forwards_required_opt_in(self):
        with tempfile.TemporaryDirectory() as tmp, patch.object(adapters, 'preflight_instance', return_value=[]):
            for runner in ('flutter-machine', 'flutter-device'):
                item = {**instance(target='test/synthetic_test.dart'), 'runner': runner,
                        'required_true_env': ['IMBOY_REAL_CAMERA_SMOKE']}
                invocation = adapters.build_invocation(ROOT, item, {'IMBOY_REAL_CAMERA_SMOKE': 'true'}, Path(tmp), DEVICES)
                self.assertIn('--no-pub', invocation['command'])
                self.assertIn('--dart-define=IMBOY_REAL_CAMERA_SMOKE=true', invocation['command'])


class AcceptancePreparationTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        self.item = {**instance(target='integration_test/full_acceptance/billing/plan_list_device_test.dart'),
            'product_profile': 'phase1_delivery', 'acceptance_preflight': True,
            'acceptance_fixture_fields': ['TEST_EXPECTED_UID', 'ACCEPTANCE_PLAN_NAME', 'ACCEPTANCE_PLAN_PRICE']}
        self.lease = {'run': 'synthetic-run', 'step': 'preparation', 'agent': 'fixture-owner',
                      'process': str(os.getpid()), 'resource': 'ANDROID_DEVICE:android-a'}
        adapters.state.acquire_lease(self.root / 'leases', self.lease['resource'], self.lease)
        self.heads = {name: char * 40 for name, char in [('imboy', 'a'), ('imboyapp', 'b'), ('imboyadmin', 'c')]}
        self.case = {'case_id': 'synthetic-preparation', 'platform': 'android', 'profile': 'phase1_delivery',
            'role_variant': 'primary', 'parent_acceptance_ids': ['synthetic-parent'],
            'seed_ids': ['synthetic-seed'], 'oracle': 'synthetic preparation only', 'applicability': 'REQUIRED'}
        self.runtime = {'app_env': 'local', 'api_url': ENV['API_BASE_URL'], 'ws_url': ENV['WS_URL_OVERRIDE'],
                        'external_services_disabled': True, 'heads': self.heads}
        self.fixture = {'synthetic': True, 'fixture_id': 'synthetic-billing',
            'values': {'TEST_EXPECTED_UID': '123', 'ACCEPTANCE_PLAN_NAME': 'Synthetic plan', 'ACCEPTANCE_PLAN_PRICE': 100}}
        self.device = {'device_id': 'android-a', 'platform': 'android', 'lease': self.lease, 'logical_width': 400}
        self.authorization = {'approved': True, 'approved_by': 'synthetic-test-coordinator',
            'approval_ref': 'synthetic-authorized-fixture', 'scope': 'isolated-device-preparation',
            'expires_at': time.time() + 600, 'device_id': 'android-a', 'expected_uid': '123', 'lease': self.lease,
            **{key: self.item[key] for key in ('target', 'platform', 'product_profile', 'role')}}
        self.env = {**ENV, 'IMBOY_ACCEPTANCE_EVIDENCE_ROOT': str(self.root),
                    'IMBOY_ACCEPTANCE_LEASES_DIR': str(self.root / 'leases')}
        # Candidate validation has separate real Git tests. This test exercises
        # the actual remaining preparation validators and real lease filesystem.
        patcher = patch('auto_test_lib.acceptance_contract.audit_candidate_repositories', return_value=[])
        self.candidate = patcher.start()
        self.addCleanup(patcher.stop)
        self.publish()

    def artifact(self, name, data):
        path = self.root / (name + '.json')
        path.write_text(json.dumps(data, sort_keys=True))
        return {'path': path.name, 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}

    def publish(self):
        runtime = self.artifact('runtime', self.runtime)
        fixture = self.artifact('fixture', self.fixture)
        self.authorization.update(runtime_sha256=runtime['sha256'], fixture_sha256=fixture['sha256'])
        records = {'runtime': runtime, 'fixture': fixture, 'device': self.artifact('device', self.device),
                   'authorization': self.artifact('authorization', self.authorization)}
        bindings = [{'binding_id': name, 'kind': kind, 'artifact': records[name]} for name, kind in
                    [('runtime', 'config'), ('authorization', 'config'), ('fixture', 'fixture'), ('device', 'device')]]
        bindings += [{'binding_id': kind, 'kind': kind, 'artifact': self.artifact(kind, {'synthetic': kind})}
                     for kind in ('source', 'build')]
        candidates = {name: {'head': head, 'required_ancestors': [head]} for name, head in self.heads.items()}
        self.frozen = {'schema_version': 2, 'acceptance_ids': ['synthetic-parent'], 'required_cases': [self.case],
            'candidates': candidates, 'runtime_bindings': bindings,
            'required_runtime_binding_ids': [row['binding_id'] for row in bindings], 'attempt_index': []}
        self.report = {'required_cases': [self.case], 'candidates': candidates,
                       'runtime_bindings': bindings, 'attempts': []}
        context = {'schema_version': 1, 'frozen': self.artifact('frozen', self.frozen),
            'report': self.artifact('report', self.report),
            'instances': [{**{key: self.item[key] for key in ('target', 'platform', 'product_profile', 'role')},
                           'case': self.case, **records}]}
        self.context = self.artifact('context', context)
        self.env.update(IMBOY_ACCEPTANCE_CONTEXT=self.context['path'],
                        IMBOY_ACCEPTANCE_CONTEXT_SHA256=self.context['sha256'])

    def audit(self):
        return adapters.acceptance_environment_evidence(self.root, self.item, self.env)

    def test_verified_defines_require_pinned_records_and_active_matching_lease(self):
        result = self.audit()
        self.assertEqual([], result['errors'])
        self.assertEqual('true', result['defines']['ACCEPTANCE_RUNNER_VERIFIED'])
        self.assertEqual('123', result['defines']['TEST_EXPECTED_UID'])
        self.assertEqual('100', result['defines']['ACCEPTANCE_PLAN_PRICE'])
        self.assertIs(result['product_pass'], False)
        self.candidate.assert_called_once()

    def test_boolean_and_hash_shapes_without_verified_records_do_not_unlock(self):
        result = adapters.acceptance_environment_evidence(self.root, self.item,
            {**ENV, 'ACCEPTANCE_RUNNER_VERIFIED': 'true', 'ACCEPTANCE_AUTH_SHA256': 'a' * 64})
        self.assertTrue(result['errors'])
        self.assertEqual({}, result['defines'])

    def test_expired_or_wrong_identity_approval_remains_blocked(self):
        for changes in ({'expires_at': time.time() - 1}, {'device_id': 'foreign-device'}, {'approved': False}):
            original = dict(self.authorization)
            self.authorization.update(changes)
            self.publish()
            self.assertIn('ACCEPTANCE_AUTHORIZATION_SCOPE_INVALID', self.audit()['errors'])
            self.assertEqual({}, self.audit()['defines'])
            self.authorization = original

    def test_changed_fixture_or_missing_live_lease_is_not_runner_verified(self):
        (self.root / 'fixture.json').write_text('{}')
        self.assertTrue(self.audit()['errors'])
        self.publish()
        adapters.state.release_lease(self.root / 'leases', self.lease['resource'], self.lease['agent'])
        self.assertIn('ACCEPTANCE_LEASE_MISSING_OR_INVALID', self.audit()['errors'])

    def test_existing_candidate_failure_cannot_be_hidden_by_valid_artifact_shapes(self):
        self.candidate.return_value = ['CANDIDATE_TRACKED_SOURCE_DIRTY:imboyapp']
        self.assertIn('CANDIDATE_TRACKED_SOURCE_DIRTY:imboyapp', self.audit()['errors'])
        self.assertEqual({}, self.audit()['defines'])

    def test_initial_empty_history_does_not_relax_existing_execution_gate(self):
        frozen, report = self.artifact('frozen', self.frozen), self.artifact('report', self.report)
        strict = adapters.acceptance_preflight.audit_preparation_inputs(self.root, frozen, report, {})
        self.assertIn('FROZEN_ATTEMPT_INDEX_INVALID', strict['errors'])
        self.report.pop('attempts')
        missing = adapters.acceptance_preflight.audit_preparation_inputs(self.root, frozen,
            self.artifact('report', self.report), {}, allow_initial_empty_history=True)
        self.assertTrue(missing['errors'])

    def test_acceptance_contract_failure_precedes_all_network_probes(self):
        item = {**self.item, 'product_profile': 'current', 'offline': False}
        with patch.object(adapters.shutil, 'which', return_value='/fake/flutter'), patch.object(adapters.socket, 'create_connection') as connect:
            self.assertTrue(adapters.preflight_instance(self.root, item, ENV, DEVICES, probe=True))
            connect.assert_not_called()

    def test_navigation_expectation_must_match_frozen_real_runtime(self):
        self.item.update(target='integration_test/full_acceptance/navigation/bottom_navigation_device_test.dart',
            product_profile='phase1_delivery-channel-disabled', acceptance_fixture_fields=['TEST_EXPECTED_UID'],
            dart_defines={'ACCEPTANCE_NAV_CHANNEL_PROFILE': 'disabled'})
        self.authorization.update({key: self.item[key] for key in ('target', 'product_profile')})
        self.case['profile'] = 'disabled'
        self.runtime.update(channel_enabled=True, experience='chat')
        self.publish()
        self.assertIn('ACCEPTANCE_NAVIGATION_RUNTIME_MISMATCH', self.audit()['errors'])
        self.runtime['channel_enabled'] = False
        self.publish()
        self.assertEqual([], self.audit()['errors'])
        self.assertNotIn('channel_enabled', self.audit()['defines'])


class OwnedFixtureAndCoordinatorTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        self.item = {**instance(target='integration_test/micro_community_owned_android_negative_test.dart'),
            'offline': False, 'session_mode': 'mc-owned', 'orchestration': 'mc-owned-coordinator',
            'variant': 'live', 'dart_defines': {'MC_OWNED_NEGATIVE_MODE': 'live'}}
        self.lease = {'run': 'owned-run', 'step': 'live', 'agent': 'synthetic-owner',
                      'process': str(os.getpid()), 'resource': 'ANDROID_DEVICE:android-a'}
        adapters.state.acquire_lease(self.root / 'leases', self.lease['resource'], self.lease)
        self.context = {'package': 'pub.imboy.app.gzcustomer', 'negative_mode': 'live',
            'api_port': 19800, 'bootstrap_port': 19801, 'group_id': '123', 'uid': '124',
            'channel_id': '125', 'channel_name': 'Synthetic channel', 'bootstrap_key': 'a' * 64,
            'phase_path': '/mc-owned/android/phase', 'control_path': '/mc-owned/android/control',
            'phase_key': 'b' * 64, 'control_key': 'c' * 64, 'device_id': 'android-a', 'lease': self.lease}
        self.env = {**ENV, 'TEST_PHONE': '', 'TEST_PASSWORD': '',
                    'IMBOY_MC_OWNED_LEASES_DIR': str(self.root / 'leases')}
        self.publish()

    def publish(self):
        path = self.root / 'private-context.json'
        path.write_text(json.dumps(self.context))
        path.chmod(0o600)
        self.env.update(IMBOY_MC_OWNED_CONTEXT_LIVE=str(path),
            IMBOY_MC_OWNED_CONTEXT_LIVE_SHA256=hashlib.sha256(path.read_bytes()).hexdigest())

    def test_owned_session_uses_private_local_context_and_no_phone_login(self):
        env, evidence = adapters.mc_owned_environment(self.item, self.env)
        self.assertEqual([], evidence['errors'])
        self.assertEqual('http://127.0.0.1:19800', env['IMBOY_API_BASE_URL_OVERRIDE'])
        self.assertEqual('124', env['MC_OWNED_UID'])
        self.assertEqual([], adapters.backend_environment_errors(self.item, env))
        self.assertNotIn('bootstrap_key', evidence)

    def test_owned_fixture_defines_cannot_be_overridden_by_remote_environment_aliases(self):
        env = {**self.env, 'IMBOY_MC_OWNED_SESSION_URL': 'https://pro.imboy.pub/session',
               'MC_OWNED_NEGATIVE_MODE': 'reconnect'}
        with patch.object(adapters, 'preflight_instance', return_value=[]):
            invocation = adapters.build_invocation(ROOT, self.item, env, self.root / 'command', DEVICES)
        self.assertIn('--dart-define=MC_OWNED_SESSION_URL=http://127.0.0.1:19801/mc-owned/android/session', invocation['command'])
        self.assertIn('--dart-define=MC_OWNED_NEGATIVE_MODE=live', invocation['command'])
        self.assertFalse(any('pro.imboy.pub' in argument for argument in invocation['command']))

    def test_wrong_variant_public_context_or_lease_cannot_start_coordinator(self):
        self.context['negative_mode'] = 'reconnect'
        self.publish()
        self.assertTrue(adapters.mc_owned_environment(self.item, self.env)[1]['errors'])
        self.context['negative_mode'] = 'live'
        self.publish()
        Path(self.env['IMBOY_MC_OWNED_CONTEXT_LIVE']).chmod(0o644)
        self.assertTrue(adapters.mc_owned_environment(self.item, self.env)[1]['errors'])
        self.publish()
        adapters.state.release_lease(self.root / 'leases', self.lease['resource'], self.lease['agent'])
        self.assertTrue(adapters.mc_owned_environment(self.item, self.env)[1]['errors'])

    def phases(self, mode='live'):
        return (['view_sent', 'handled:joined', 'handled:warm', 'handled:before_received',
                 'view_sent', 'handled:chat_denied', 'handled:cache_denied', 'coordinator_verified']
                if mode == 'live' else
                ['view_sent', 'handled:joined', 'handled:warm', 'link_removed', 'handled:before_received',
                 'handled:disconnected', 'link_restored', 'handled:offline_queued', 'view_sent',
                 'handled:reconnected', 'handled:queued_denied', 'coordinator_verified'])

    def gate(self, mode='live'):
        log, evidence, process = (self.root / name for name in ('process.log', 'phases.jsonl', 'process.json'))
        log.write_text('synthetic coordinator log')
        evidence.write_text(''.join(json.dumps({'event': event, 'monotonic': index}) + '\n'
                                   for index, event in enumerate(self.phases(mode))))
        receipt = {'kind': 'coordinator-gate', 'mode': mode, 'exit_code': 0,
            'instance_id': self.item['id'], 'target': self.item['target'], 'context_sha256': 'a' * 64,
            'command': [sys.executable, '/source/scripts/mc22_owned_coordinator.py', '--context',
                        '/private/context.json', '--device', 'android-a', '--events', str(evidence)],
            'log': str(log), 'evidence': str(evidence)}
        process.write_text(json.dumps(receipt))
        receipt.update(process_receipt=str(process), hashes={name: hashlib.sha256(path.read_bytes()).hexdigest()
            for name, path in [('log', log), ('evidence', evidence), ('process_receipt', process)]})
        return receipt

    def test_both_coordinator_variants_require_full_structured_phase_evidence(self):
        for mode in ('live', 'reconnect'):
            receipt = self.gate(mode)
            self.assertEqual([], adapters.verify_coordinator_evidence(receipt, Path))
            receipt['exit_code'] = 1
            self.assertTrue(adapters.verify_coordinator_evidence(receipt, Path))
            receipt = self.gate(mode)
            path = Path(receipt['evidence'])
            path.write_text(path.read_text().splitlines()[-1] + '\n')
            receipt['hashes']['evidence'] = hashlib.sha256(path.read_bytes()).hexdigest()
            self.assertIn('COORDINATOR_PHASE_EVIDENCE_INCOMPLETE', adapters.verify_coordinator_evidence(receipt, Path))

    def test_coordinator_status_cannot_hide_tampered_or_missing_artifacts(self):
        receipt = self.gate()
        receipt['status'] = 'PASS'
        Path(receipt['evidence']).write_text('{}\n')
        self.assertTrue(adapters.verify_coordinator_evidence(receipt, Path))
        receipt = self.gate()
        Path(receipt['log']).unlink()
        self.assertTrue(adapters.verify_coordinator_evidence(receipt, Path))

    def test_coordinator_gate_replays_after_artifact_relocation(self):
        receipt = self.gate()
        relocated = self.root / 'downloaded'
        relocated.mkdir()
        for key in ('log', 'evidence', 'process_receipt'):
            source = Path(receipt[key])
            (relocated / source.name).write_bytes(source.read_bytes())
            source.unlink()
        self.assertEqual([], adapters.verify_coordinator_evidence(receipt,
            lambda path: relocated / Path(path).name))

    def test_coordinator_failure_blocks_otherwise_successful_flutter_result(self):
        def start(command, **kwargs):
            Path(command[-1]).write_text('')
            return Mock(wait=Mock(return_value=0))
        invocation = {'errors': [], 'command': ['flutter', 'test'], 'env': self.env,
                      'log_path': str(self.root / 'flutter.log')}
        with patch.object(adapters, 'preflight_instance', return_value=[]), \
             patch.object(adapters, 'build_invocation', return_value=invocation), \
             patch.object(adapters.subprocess, 'Popen', side_effect=start):
            result = adapters.run_coordinated(ROOT, self.item, self.env, self.root / 'output',
                lambda item, command: {'status': 'PASS', 'attempts': [{'synthetic': True}]}, DEVICES)
        self.assertEqual('BLOCKED', result['status'])
        self.assertEqual('UPSTREAM_FAILED', result['reason_code'])
        self.assertTrue(result['attempts'])
        self.assertEqual('coordinator-gate', result['companion_evidence']['kind'])


class RegisteredFontEnvironmentTests(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory(prefix='imboy-font-prerequisite-')
        self.addCleanup(tmp.cleanup)
        self.root = Path(tmp.name) / 'repo'
        # Synthetic bytes exercise only the read-only hash prerequisite, not a
        # replacement for the real Dart glyph or FontLoader assertions.
        self.font = Path(tmp.name) / 'synthetic-font.bin'
        self.font.write_bytes(b'synthetic-preflight-fixture')
        self.digest = hashlib.sha256(self.font.read_bytes()).hexdigest()
        self.registry = self.root / adapters.REGISTERED_GOLDEN_FONT_SOURCE
        self.registry.parent.mkdir(parents=True)
        self.source = ("const List<GoldenFontAsset> kGoldenFontAssets = [\n"
                       "  GoldenFontAsset(\n"
                       f"    path: '{self.font}',\n"
                       "    // A temporary local test fixture, never distributed.\n"
                       f"    sha256Hex:\n        '{self.digest}',\n"
                       "    licenseNote: 'synthetic fixture; ' 'https://example.invalid/license',\n"
                       "  ),\n];\n")
        self.registry.write_text(self.source)
        self.item = {'suite': 'component', 'runner': 'flutter-machine', 'platform': 'macos',
                     'target': 'test/uiux/contract/font_contract_test.dart',
                     'dependencies': ['registered-golden-font']}

    def test_current_dart_registry_is_the_only_source_of_asset_pins(self):
        asset = adapters.registered_golden_font_asset(ROOT)
        self.assertTrue(Path(asset['path']).is_absolute())
        self.assertRegex(asset['sha256'], r'^[0-9a-f]{64}$')
        self.assertTrue(asset['license'].strip())

    def test_matching_external_registered_font_needs_no_pixel_environment(self):
        self.assertFalse(self.font.is_relative_to(self.root))
        before = {path: path.read_bytes() for path in (self.font, self.registry)}
        with patch.object(adapters.shutil, 'which', return_value='/fixture/flutter'), \
             patch.object(adapters.subprocess, 'run') as run:
            self.assertEqual([], adapters.preflight_instance(self.root, self.item, {}))
        run.assert_not_called()
        self.assertEqual(before, {path: path.read_bytes() for path in before})

    def test_missing_or_mismatched_font_blocks_preflight(self):
        with patch.object(adapters.shutil, 'which', return_value='/fixture/flutter'):
            self.font.write_bytes(b'different-synthetic-bytes')
            self.assertIn('REGISTERED_GOLDEN_FONT_HASH_MISMATCH:' + str(self.font),
                          adapters.preflight_instance(self.root, self.item, {}))
            self.font.unlink()
            self.assertIn('REGISTERED_GOLDEN_FONT_MISSING:' + str(self.font),
                          adapters.preflight_instance(self.root, self.item, {}))
            self.assertFalse(self.font.exists())

    def test_unknown_registration_shape_never_uses_an_inferred_font(self):
        invalid = [self.source + self.source,
                   self.source.replace('kGoldenFontAssets = [', 'kGoldenFontAssets = <GoldenFontAsset>['),
                   self.source.replace(f"path: '{self.font}'", 'path: findFont()'),
                   self.source.replace(f"path: '{self.font}'", "path: 'relative.ttf'"),
                   self.source.replace(self.digest, 'invalid-hash'),
                   self.source.replace("'synthetic fixture; ' 'https://example.invalid/license'", "''"),
                   self.source.replace('  GoldenFontAsset(\n',
                       "  GoldenFontAsset(path: '/another.ttf', sha256Hex: '0', licenseNote: 'fixture'),\n"
                       '  GoldenFontAsset(\n')]
        for source in invalid:
            with self.subTest(source=source):
                self.registry.write_text(source)
                errors = adapters.registered_golden_font_errors(self.root, self.item)
                self.assertTrue(any('REGISTRY_INVALID' in error for error in errors), errors)

    def test_missing_registry_blocks_only_a_declared_font_dependency(self):
        self.registry.unlink()
        errors = adapters.registered_golden_font_errors(self.root, self.item)
        self.assertTrue(any('REGISTRY_UNREADABLE' in error for error in errors), errors)
        self.assertEqual([], adapters.registered_golden_font_errors(
            self.root, {**self.item, 'dependencies': []}))

    def golden_contract(self):
        self.icons = [self.font.with_name('synthetic-material.otf'),
                      self.font.with_name('synthetic-cupertino.ttf')]
        for index, icon in enumerate(self.icons):
            icon.write_bytes(f'synthetic-icon-{index}'.encode())
        self.golden_source = self.source + (
            "const String kFlutterVersionPin = '99.12.3';\n"
            'const List<(String, String)> kGoldenIconFontAssets = <(String, String)>[\n'
            f"  ('{self.icons[0].parent}/' '{self.icons[0].name}', 'MaterialIcons',),\n"
            f"  ('{self.icons[1]}', 'packages/cupertino_icons/CupertinoIcons',),\n"
            f"  ('{self.icons[1]}', 'CupertinoIcons',),\n];\n")
        self.registry.write_text(self.golden_source)
        self.golden_item = {'suite': 'golden', 'target': 'test/uiux/golden/synthetic_test.dart',
                            'source_dependencies': [adapters.REGISTERED_GOLDEN_FONT_SOURCE]}
        self.baseline = self.root / 'baseline.png'
        self.baseline.write_bytes(b'synthetic-pixel-fixture')
        self.golden_data = {
            'platform': {'darwin': 'macos', 'win32': 'windows'}.get(sys.platform, sys.platform),
            'frameworkRevision': 'fixture-framework', 'engineRevision': 'fixture-engine',
            'fonts': {str(path): hashlib.sha256(path.read_bytes()).hexdigest()
                      for path in [self.font, *self.icons]},
            'baselines': {self.golden_item['target']: {
                'baseline.png': hashlib.sha256(self.baseline.read_bytes()).hexdigest()}}}
        self.golden_manifest = self.root / 'environment.json'
        self.golden_manifest.write_text(json.dumps(self.golden_data))
        self.golden_version = {**self.golden_data, 'frameworkVersion': '99.12.3'}

    def golden_errors(self, data=None, version=None):
        self.golden_manifest.write_text(json.dumps(self.golden_data if data is None else data))
        completed = subprocess.CompletedProcess(
            [], 0, json.dumps(self.golden_version if version is None else version), '')
        with patch.object(adapters.subprocess, 'run', return_value=completed):
            return adapters.golden_environment_errors(
                self.root, self.golden_item, {'IMBOY_GOLDEN_ENVIRONMENT': str(self.golden_manifest)})

    def test_actual_golden_targets_retain_the_real_loader_dependency_and_literal_pins(self):
        from auto_test_lib import execution_catalog
        catalog = execution_catalog.build_catalog(ROOT)
        self.assertEqual([], catalog['errors'])
        targets = {row['target']: row for row in catalog['targets']}
        paths = [f'test/uiux/golden/{page}_golden_test.dart' for page in ('p1', 'p2', 'p3')]
        paths.append('test/enterprise_oa/t15_enterprise_layout_test.dart')
        for path in paths:
            row = targets[path]
            self.assertEqual('golden', row['suite'])
            self.assertIn(adapters.REGISTERED_GOLDEN_FONT_SOURCE, row['source_dependencies'])
        asset = adapters.registered_golden_font_asset(ROOT, include_environment=True)
        self.assertRegex(asset['flutter_version'], r'^\d+\.\d+\.\d+$')
        self.assertEqual(2, len(asset['icon_fonts']))
        self.assertEqual(3, sum(len(families) for families in asset['icon_fonts'].values()))

    def test_registered_external_golden_inputs_pass_without_copying_or_updating_assets(self):
        self.golden_contract()
        assets = [self.font, *self.icons, self.registry, self.baseline, self.golden_manifest]
        before = {path: path.read_bytes() for path in assets}
        self.assertEqual([], self.golden_errors())
        self.assertEqual(before, {path: path.read_bytes() for path in assets})
        parsed = adapters.registered_golden_font_asset(self.root, include_environment=True)
        self.assertEqual(2, len(parsed['icon_fonts']))
        self.assertEqual(2, len(parsed['icon_fonts'][str(self.icons[1])]))

    def test_one_font_manifest_can_cover_loader_users_and_other_golden_targets(self):
        self.golden_contract()
        self.assertEqual([], self.golden_errors())
        self.golden_data['baselines']['test/other_golden_test.dart'] = {
            'baseline.png': hashlib.sha256(self.baseline.read_bytes()).hexdigest()}
        self.golden_item = {'suite': 'golden', 'target': 'test/other_golden_test.dart'}
        self.assertEqual([], self.golden_errors())

    def test_manifest_cannot_substitute_unrelated_fonts_or_change_registered_text_pin(self):
        self.golden_contract()
        unrelated = self.root / 'unrelated.ttf'
        unrelated.write_bytes(b'unrelated-font')
        data = copy.deepcopy(self.golden_data)
        data['fonts'].pop(str(self.font))
        data['fonts']['unrelated.ttf'] = hashlib.sha256(unrelated.read_bytes()).hexdigest()
        self.assertIn('GOLDEN_REGISTERED_FONT_CONTRACT_MISSING:' + str(self.font), self.golden_errors(data))
        self.font.write_bytes(b'replaced-font-with-new-manifest-hash')
        data['fonts'][str(self.font)] = hashlib.sha256(self.font.read_bytes()).hexdigest()
        self.assertIn('GOLDEN_REGISTERED_FONT_PIN_MISMATCH:' + str(self.font), self.golden_errors(data))

    def test_icon_manifest_entries_are_required_even_when_dart_would_skip_missing_icons(self):
        self.golden_contract()
        for icon in self.icons:
            with self.subTest(icon=icon):
                data = copy.deepcopy(self.golden_data)
                data['fonts'].pop(str(icon))
                self.assertIn('GOLDEN_REGISTERED_ICON_FONT_CONTRACT_MISSING:' + str(icon), self.golden_errors(data))
                data['fonts'][str(icon)] = 'not-a-sha256'
                self.assertIn('GOLDEN_REGISTERED_ICON_FONT_HASH_INVALID:' + str(icon), self.golden_errors(data))

    def test_missing_or_modified_registered_golden_assets_block_without_recreation(self):
        self.golden_contract()
        for asset in [self.font, *self.icons]:
            with self.subTest(asset=asset):
                original = asset.read_bytes()
                asset.write_bytes(b'modified-fixture')
                self.assertIn('GOLDEN_FONT_HASH_MISMATCH:' + str(asset), self.golden_errors())
                asset.unlink()
                self.assertIn('GOLDEN_FONT_MISSING:' + str(asset), self.golden_errors())
                self.assertFalse(asset.exists())
                asset.write_bytes(original)

    def test_font_exception_does_not_allow_unknown_paths_aliases_or_external_baselines(self):
        self.golden_contract()
        foreign = self.font.with_name('unregistered.ttf')
        foreign.write_bytes(self.font.read_bytes())
        (self.root / 'linked-font.ttf').symlink_to(self.font)
        for name in (str(foreign), str(self.font.parent) + '/./' + self.font.name, 'linked-font.ttf'):
            with self.subTest(name=name):
                data = copy.deepcopy(self.golden_data)
                data['fonts'][name] = self.digest
                self.assertIn('GOLDEN_FONT_PATH_OUTSIDE_REPO', self.golden_errors(data))
        data = copy.deepcopy(self.golden_data)
        data['baselines'][self.golden_item['target']] = {str(self.font): self.digest}
        self.assertIn('GOLDEN_BASELINE_PATH_OUTSIDE_REPO', self.golden_errors(data))

    def test_registered_sdk_version_cannot_be_replaced_by_a_self_consistent_manifest(self):
        self.golden_contract()
        version = {**self.golden_version, 'frameworkVersion': '99.12.4'}
        self.assertIn('GOLDEN_REGISTERED_FLUTTER_VERSION_MISMATCH:expected=99.12.3',
                      self.golden_errors(version=version))
        self.registry.write_text(self.golden_source.replace("'99.12.3'", 'findSdkVersion()'))
        self.assertTrue(any('REGISTERED_GOLDEN_FLUTTER_PIN_INVALID' in error for error in self.golden_errors()))

    def test_icon_registry_requires_literal_absolute_paths_and_nonempty_families(self):
        self.golden_contract()
        invalid = [self.golden_source.replace("'MaterialIcons'", "''"),
                   self.golden_source.replace(f"'{self.icons[1]}'", 'findIconFont()'),
                   self.golden_source.replace(f"'{self.icons[1]}'", "'relative.ttf'"),
                   self.golden_source.replace('kGoldenIconFontAssets', 'removedIconRegistry')]
        for source in invalid:
            with self.subTest(source=source):
                self.registry.write_text(source)
                self.assertTrue(any('REGISTERED_GOLDEN_ICON_REGISTRY_INVALID' in error
                                    for error in self.golden_errors()))


class GoldenAndPatrolEvidenceTests(unittest.TestCase):
    def test_missing_golden_contract_blocks_without_creating_baselines(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            errors = adapters.golden_environment_errors(root, {'suite': 'golden', 'target': 'test/a_test.dart'}, {})
            self.assertIn('GOLDEN_ENVIRONMENT_MANIFEST_MISSING:IMBOY_GOLDEN_ENVIRONMENT', errors)
            self.assertEqual([], list(root.iterdir()))

    def test_golden_requires_pinned_versions_fonts_and_existing_matching_baselines(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / 'font.ttf').write_bytes(b'synthetic-font')
            (root / 'a.png').write_bytes(b'synthetic-pixels')
            data = {'platform': {'darwin': 'macos', 'win32': 'windows'}.get(sys.platform, sys.platform),
                    'frameworkRevision': 'flutter-commit', 'engineRevision': 'engine-commit',
                    'fonts': {'font.ttf': hashlib.sha256(b'synthetic-font').hexdigest()},
                    'baselines': {'test/a_test.dart': {'a.png': hashlib.sha256(b'synthetic-pixels').hexdigest()}}}
            manifest = root / 'environment.json'
            manifest.write_text(json.dumps(data))
            env = {'IMBOY_GOLDEN_ENVIRONMENT': str(manifest)}
            completed = subprocess.CompletedProcess([], 0, json.dumps(data), '')
            with patch.object(adapters.subprocess, 'run', return_value=completed):
                self.assertEqual([], adapters.golden_environment_errors(root, {'suite': 'golden', 'target': 'test/a_test.dart'}, env))
                (root / 'a.png').unlink()
                errors = adapters.golden_environment_errors(root, {'suite': 'golden', 'target': 'test/a_test.dart'}, env)
                self.assertIn('GOLDEN_BASELINE_MISSING:a.png', errors)
                self.assertFalse((root / 'a.png').exists())
                data['engineRevision'] = 'wrong'
                manifest.write_text(json.dumps(data))
                self.assertIn('GOLDEN_FLUTTER_VERSION_MISMATCH', adapters.golden_environment_errors(root, {'suite': 'golden', 'target': 'test/a_test.dart'}, env))

    def junit(self, body, exit_code=0, encoding='utf-8'):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / 'result.xml'
            path.write_text(body, encoding=encoding)
            return adapters.parse_patrol_junit([path], exit_code)

    def test_native_dart_case_success_requires_machine_correspondence_and_zero_exit(self):
        xml = '<testsuite tests="1"><testcase classname="pub.imboy.MainActivityTest" name="runDartTest[flow]"/></testsuite>'
        for encoding in ('utf-8', 'utf-16'):
            with self.subTest(encoding=encoding):
                self.assertEqual('PASS', self.junit(xml, encoding=encoding)['test_status'])
                self.assertNotEqual('PASS', self.junit(xml, 1, encoding)['test_status'])
                self.assertNotEqual('PASS', self.junit(xml, None, encoding)['test_status'])

    def test_native_junit_rejects_doctype_declarations(self):
        xml = '<!DOCTYPE testsuite><testsuite tests="1"><testcase classname="MainActivityTest" name="runDartTest[flow]"/></testsuite>'
        for encoding in ('utf-8', 'utf-16'):
            with self.subTest(encoding=encoding):
                result = self.junit(xml, encoding=encoding)
                self.assertEqual('FAIL', result['test_status'])
                self.assertIn('PATROL_RESULT_INVALID', result['errors'])
                self.assertEqual(0, result['executed'])

    def test_native_junit_missing_hardened_parser_fails_closed(self):
        xml = '<testsuite tests="1"><testcase classname="MainActivityTest" name="runDartTest[flow]"/></testsuite>'
        with patch.dict(sys.modules, {'defusedxml': None}):
            result = self.junit(xml)
        self.assertEqual('FAIL', result['test_status'])
        self.assertIn('PATROL_XML_PARSER_MISSING:defusedxml (scripts/requirements-tooling.txt)', result['errors'])
        self.assertEqual(0, result['executed'])

    def test_native_preflight_requires_hardened_xml_parser(self):
        item = {'runner': 'patrol', 'platform': 'android', 'offline': True,
                'target': 'integration_test/patrol/handshake_test.dart'}
        with patch.dict(sys.modules, {'defusedxml': None}), \
                patch.object(adapters.shutil, 'which', return_value='/synthetic/patrol'):
            errors = adapters.preflight_instance(
                ROOT, item, {'IMBOY_EXECUTION_DEVICE_ANDROID': 'android-a'}, DEVICES)
        self.assertIn('PATROL_XML_PARSER_MISSING:defusedxml (scripts/requirements-tooling.txt)', errors)

    def test_native_bootstrap_empty_skipped_or_inconsistent_evidence_never_passes(self):
        for xml in ('<testsuite', '<testsuite tests="0"/>',
                    '<testsuite tests="1"><testcase classname="Bootstrap" name="start"/></testsuite>',
                    '<testsuite tests="1"><testcase classname="MainActivityTest" name="runDartTest[a]"><skipped/></testcase></testsuite>',
                    '<testsuite tests="2"><testcase classname="MainActivityTest" name="runDartTest[a]"/></testsuite>',
                    '<testsuite tests="1" skipped="1"><testcase classname="MainActivityTest" name="runDartTest[a]"/></testsuite>'):
            self.assertNotEqual('PASS', self.junit(xml)['test_status'])
        self.assertNotEqual('PASS', adapters.parse_patrol_junit([], 0)['test_status'])

    def test_only_fresh_native_results_are_selected(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            stale = root / 'build/app/outputs/androidTest-results/old.xml'
            stale.parent.mkdir(parents=True)
            stale.write_text('<testsuite/>')
            before = adapters.junit_snapshot(root)
            self.assertEqual([], adapters.fresh_junit_paths(root, before))
            fresh = stale.with_name('new.xml')
            fresh.write_text('<testsuite tests="0"/>')
            self.assertEqual([str(fresh)], adapters.fresh_junit_paths(root, before))


class PairOrchestrationTests(unittest.TestCase):
    def fake_invocation(self, root, item, env, output, devices=None, **kwargs):
        output.mkdir(parents=True, exist_ok=True)
        return {'log_path': str(output / 'process.log'), 'command': ['fixture'], 'env': env}

    def run_pair(self, items, execute, env=None):
        with tempfile.TemporaryDirectory() as tmp, patch.object(adapters, 'preflight_instance', return_value=[]), patch.object(adapters, 'build_invocation', side_effect=self.fake_invocation):
            return adapters.run_pair(ROOT, items, env or {}, Path(tmp), execute, DEVICES)

    def test_known_pair_cannot_be_invoked_as_single_device(self):
        item = instance(target='integration_test/e2ee_cross_platform_interop_test.dart')
        with tempfile.TemporaryDirectory() as tmp:
            with self.assertRaisesRegex(ValueError, 'PAIR_TARGET_REQUIRES_PAIR_ORCHESTRATION'):
                adapters.build_invocation(ROOT, item, {}, Path(tmp), DEVICES)

    def test_pair_empty_missing_duplicate_roles_and_same_device_are_rejected(self):
        self.assertEqual(['PAIR_PLAN_EMPTY'], adapters.pair_environment_errors([], {}))
        a, b = instance('sender', method='dual-concurrent'), instance('receiver', method='dual-concurrent')
        self.assertIn('PAIR_ROLE_SET_INCOMPLETE', adapters.pair_environment_errors([a], {}))
        self.assertIn('PAIR_ROLE_SET_INCOMPLETE', adapters.pair_environment_errors([a, a], {}))
        self.assertIn('PAIR_DEVICES_MUST_BE_DISTINCT', adapters.pair_environment_errors([a, b], {}))

    def test_sequential_upstream_failure_blocks_all_dependent_roles(self):
        items = [instance('sender', 'android', 'e2ee-vector'), instance('receiver', 'macos', 'e2ee-vector'), instance('final', 'android', 'e2ee-vector')]
        called = []
        def execute(i, invocation):
            called.append(i['role'])
            return {'status': 'FAIL', 'attempts': [{'test_status': 'FAIL'}]}
        results = self.run_pair(items, execute)
        self.assertEqual(['sender'], called)
        self.assertEqual('UPSTREAM_FAILED', results[items[1]['id']]['reason_code'])
        self.assertEqual([items[0]['id']], results[items[2]['id']]['upstream'])

    def test_successful_process_without_vector_does_not_unlock_receiver(self):
        items = [instance('sender', 'android', 'e2ee-vector'), instance('receiver', 'macos', 'e2ee-vector'), instance('final', 'android', 'e2ee-vector')]
        results = self.run_pair(items, lambda i, invocation: {'status': 'PASS', 'attempts': [{'parsed': 'machine-pass'}]})
        self.assertEqual('EVIDENCE_INVALID', results[items[0]['id']]['reason_code'])
        self.assertEqual('FAIL', results[items[0]['id']]['status'])
        self.assertTrue(results[items[0]['id']]['attempts'])
        self.assertEqual('UPSTREAM_FAILED', results[items[1]['id']]['reason_code'])

    def test_local_dual_runs_all_same_platform_topologies_without_deduplication(self):
        items = [instance(role, platform, 'dual-sequential') for platform in ['android', 'macos'] for role in ['sender', 'receiver']]
        calls = []
        results = self.run_pair(items, lambda i, invocation: calls.append((i['platform'], i['role'])) or {'status': 'PASS'})
        self.assertEqual(4, len(results))
        self.assertEqual([('android', 'sender'), ('android', 'receiver'), ('macos', 'sender'), ('macos', 'receiver')], calls)

    def test_rtc_group_requires_same_group_distinct_members_and_two_results(self):
        items = [instance('sender', method='rtc-group-concurrent'), instance('receiver', method='rtc-group-concurrent')]
        items[1]['device_id'] = 'android-b'
        env = {'TEST_GROUP_ID': '123', 'IMBOY_SENDER_TEST_EXPECTED_UID': '124',
               'IMBOY_RECEIVER_TEST_EXPECTED_UID': '125'}
        results = self.run_pair(items, lambda i, invocation: {'status': 'PASS'}, env)
        self.assertEqual(2, len(results))
        self.assertEqual({'PASS'}, {result['status'] for result in results.values()})
        env['IMBOY_RECEIVER_TEST_EXPECTED_UID'] = '124'
        results = self.run_pair(items, lambda i, invocation: self.fail('duplicate account must not run'), env)
        self.assertEqual({'ENV_MISSING'}, {result['reason_code'] for result in results.values()})
        env['IMBOY_RECEIVER_TEST_EXPECTED_UID'] = '125'
        env['IMBOY_RECEIVER_TEST_GROUP_ID'] = '999'
        results = self.run_pair(items, lambda i, invocation: self.fail('different groups must not run'), env)
        self.assertTrue(all('PAIR_GROUP_FIXTURE_MUST_MATCH' in result['errors'] for result in results.values()))

    def test_h2_group_releases_mac_receiver_before_new_member_while_sender_lives(self):
        items = [instance('sender', 'android', 'h2-c2g'), instance('receiver', 'macos', 'h2-c2g'), instance('new-member', 'macos', 'h2-c2g')]
        receiver_done, new_member_done, sender_started = threading.Event(), threading.Event(), threading.Event()
        def execute(i, invocation):
            if i['role'] == 'receiver':
                receiver_done.set()
            elif i['role'] == 'sender':
                sender_started.set()
                self.assertTrue(new_member_done.wait(2))
            else:
                self.assertTrue(receiver_done.is_set())
                self.assertTrue(sender_started.wait(2))
                new_member_done.set()
            return {'status': 'PASS'}
        results = self.run_pair(items, execute)
        self.assertEqual({'PASS'}, {r['status'] for r in results.values()})

    def test_h2_history_waits_for_both_successful_roles_and_reuses_devices(self):
        items = [instance('sender', 'android', 'h2-c2c'), instance('receiver', 'macos', 'h2-c2c'),
                 instance('history-sender', 'android', 'h2-c2c'), instance('history-receiver', 'macos', 'h2-c2c')]
        calls = []
        def execute(i, invocation):
            if i['role'].startswith('history'):
                self.assertIn('sender', calls)
                self.assertIn('receiver', calls)
            calls.append(i['role'])
            return {'status': 'PASS'}
        self.assertEqual(4, len(self.run_pair(items, execute)))
        items[2]['device_id'] = 'android-b'
        self.assertIn('PAIR_HISTORY_DEVICE_MUST_REUSE_PERSISTED_STORAGE', adapters.pair_environment_errors(items, {}))

    def test_role_runner_crash_is_blocked_and_stops_sequential_dependents(self):
        items = [instance('sender', method='dual-sequential'), instance('receiver', method='dual-sequential')]
        def execute(i, invocation):
            raise OSError('synthetic runner launch failure')
        results = self.run_pair(items, execute)
        self.assertEqual('RUNNER_CRASH', results[items[0]['id']]['reason_code'])
        self.assertEqual('UPSTREAM_FAILED', results[items[1]['id']]['reason_code'])

    def test_external_driver_is_absolute_hashed_and_missing_is_explicit(self):
        i = instance('new-client', method='legacy-fixture')
        self.assertIn('EXTERNAL_COMPANION_MISSING:IMBOY_LEGACY_PAIR_DRIVER', adapters.companion_environment_errors(i, {}))
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / 'fixture.py'
            path.write_text('print("synthetic protocol fixture")\n')
            env = {'IMBOY_LEGACY_PAIR_DRIVER': str(path)}
            self.assertTrue(adapters.companion_environment_errors(i, env))
            env['IMBOY_LEGACY_PAIR_DRIVER_SHA256'] = hashlib.sha256(path.read_bytes()).hexdigest()
            self.assertEqual([], adapters.companion_environment_errors(i, env))
            path.write_text('changed')
            self.assertTrue(adapters.companion_environment_errors(i, env))

    def test_external_companion_failure_prevents_primary_machine_pass(self):
        item = instance('new-client', method='legacy-fixture')
        with tempfile.TemporaryDirectory() as tmp:
            driver = Path(tmp) / 'fixture.py'
            driver.write_text('# synthetic fixture\n')
            env = {'IMBOY_LEGACY_PAIR_DRIVER': str(driver)}
            def execute(i, invocation):
                return {'status': 'FAIL' if i['role'] == 'external-fixture' else 'PASS', 'attempts': [{}]}
            results = self.run_pair([item], execute, env)
            self.assertEqual('UPSTREAM_FAILED', results[item['id']]['reason_code'])
            self.assertEqual('FAIL', results[item['id']]['companion_evidence']['status'])

    def test_vector_chunks_require_complete_consistent_base64_json(self):
        vector = base64.urlsafe_b64encode(json.dumps({'fixture': 'synthetic'}).encode()).decode()
        cut = len(vector) // 2
        log = f'E2EE_INTEROP_VECTOR_B64_CHUNK:1/2:{vector[:cut]}\nE2EE_INTEROP_VECTOR_B64_CHUNK:2/2:{vector[cut:]}'
        self.assertEqual(vector, adapters.reassemble_vector(log))
        for bad in [f'E2EE_INTEROP_VECTOR_B64_CHUNK:1/2:{vector}',
                    log + '\nE2EE_INTEROP_VECTOR_B64_CHUNK:1/2:AAAA',
                    'E2EE_INTEROP_VECTOR_B64_CHUNK:1/1:bm90anNvbg==']:
            with self.assertRaises(ValueError):
                adapters.reassemble_vector(bad)


class KillReplayTests(unittest.TestCase):
    def setUp(self):
        from auto_test_lib import execution_runner, execution_cli
        self.runner, self.cli = execution_runner, execution_cli
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name).resolve()
        self.output = self.root / 'evidence'
        self.item = {**instance(target=adapters.KILL_REPLAY_TARGET), 'orchestration': 'sqlite-kill-replay',
                     'flavor': 'standard', 'selected': True, 'variant': 'default'}
        target = self.root / self.item['target']
        target.parent.mkdir(parents=True)
        target.write_text('// isolated synthetic target\n')
        self.env = {**ENV, 'IMBOY_KILL_REPLAY_ATTEMPT': '23'}
        self.planned = {'commit': 'a' * 40, 'profile': 'device-single', 'instances': [self.item],
                        'source_fingerprint': 'b' * 64, 'gates': []}
        self.commands = []
        self.scenario = 'success'
        self.verify_calls = 0

    def marker(self, step, **fields):
        return json.dumps({'type': 'print', 'message': '[WP7-EVIDENCE] step=' + step +
                          ' attempt=23' + ''.join(' ' + key + '=' + str(value) for key, value in fields.items())})

    def persist(self, command, output, lines, code=0, error=None, log_path=None):
        output.mkdir(parents=True, exist_ok=True)
        path = Path(log_path) if log_path else output / 'machine.jsonl'
        path.write_text('\n'.join(lines) + '\n')
        return self.runner._persist_process_receipt({'command': list(command), 'exit_code': code,
            'log': str(path), 'machine': str(path), 'lines': lines, 'error': error}, output)

    def process(self, command, env, output, **kwargs):
        self.commands.append(command)
        if command[0] == 'flutter':
            lines = [json.dumps({'type': 'suite', 'suite': {'id': 1, 'path': self.item['target']}}),
                     json.dumps({'type': 'testStart', 'test': {'id': 1, 'suiteID': 1, 'name': 'prepare'}}),
                     self.marker('kill_seeded', contact=8000, user_tag=8000, user_collect=4000, seed_ms=1)]
            if self.scenario != 'missing_ready':
                ready = {'db': '/data/user/0/pub.imboy.app/files/imboy_wp7_kill/replay_23.db',
                         'protocol': 2, 'transaction': 'active', 'from': 16, 'reached': 17, 'to': 31}
                if self.scenario == 'legacy_ready':
                    ready = {'db': ready['db']}
                for scenario, key, value in (
                        ('old_protocol', 'protocol', 1), ('future_protocol', 'protocol', 3),
                        ('transaction_not_started', 'transaction', 'pending'),
                        ('transaction_committed', 'transaction', 'committed'),
                        ('no_migration_write', 'reached', 16), ('wrong_start', 'from', 17),
                        ('wrong_destination', 'to', 38)):
                    if self.scenario == scenario:
                        ready[key] = value
                lines.append(self.marker('kill_ready', **ready))
            if self.scenario == 'window_before_stop':
                lines.append(self.marker('kill_done_window_missed', user_version=31, **{'from': 16, 'to': 31}))
            live = Path(kwargs['log_path'])
            live.parent.mkdir(parents=True, exist_ok=True)
            live.write_text('\n'.join(lines) + '\n')
            self.live_prepare = live
            try:
                reason = kwargs['observer'](live)
            except ValueError as exc:
                reason = 'RUNNER_OBSERVER_FAILED:' + type(exc).__name__
            if self.scenario == 'prepare_transport_lost_after_stop':
                with live.open('a') as stream:
                    stream.write(json.dumps({'type': 'error', 'testID': 1, 'isFailure': False,
                                             'error': 'synthetic lost device transport'}) + '\n')
                    stream.write(json.dumps({'type': 'testDone', 'testID': 1, 'result': 'error', 'skipped': False}) + '\n')
                    stream.write(json.dumps({'type': 'done', 'success': False}) + '\n')
            elif self.scenario in ('prepare_assertion_after_stop', 'prepare_skip_after_stop', 'prepare_unknown_error_after_stop'):
                with live.open('a') as stream:
                    if self.scenario != 'prepare_skip_after_stop':
                        stream.write(json.dumps({'type': 'error', 'testID': 1,
                            'isFailure': self.scenario == 'prepare_assertion_after_stop',
                            'error': 'synthetic prepare assertion failed'}) + '\n')
                    stream.write(json.dumps({'type': 'testDone', 'testID': 1,
                        'result': 'failure' if self.scenario == 'prepare_assertion_after_stop' else 'success',
                        'skipped': self.scenario == 'prepare_skip_after_stop'}) + '\n')
                    stream.write(json.dumps({'type': 'done', 'success': False}) + '\n')
            # Model an owned interrupted process or the existing bounded timeout.
            return self.persist(command, output, live.read_text().splitlines(),
                code=130 if reason else 124, error=reason or 'RUNNER_TIMEOUT', log_path=live)
        if output.name == 'pid_before':
            if self.scenario == 'window_after_pid':
                with self.live_prepare.open('a') as stream:
                    stream.write(self.marker('kill_done_window_missed', user_version=31, **{'from': 16, 'to': 31}) + '\n')
            return self.persist(command, output, [] if self.scenario == 'pid_missing' else ['1234'],
                                code=1 if self.scenario == 'pid_missing' else 0)
        if output.name == 'force_stop':
            return self.persist(command, output, [], code=1 if self.scenario == 'force_stop_failed' else 0)
        return self.persist(command, output, ['1234'] if self.scenario == 'pid_stays' else [], code=0)

    def execute(self, item, invocation):
        self.verify_calls += 1
        if self.scenario == 'verify_runner_crash':
            raise RuntimeError('synthetic runner crash')
        code = 7 if self.scenario == 'verify_nonzero' else 0
        lines = [json.dumps({'type': 'suite', 'suite': {'id': 1, 'path': item['target']}})]
        if self.scenario != 'verify_zero':
            lines.append(json.dumps({'type': 'testStart', 'test': {'id': 2, 'suiteID': 1, 'name': 'verify'}}))
            if self.scenario != 'verify_marker_missing':
                missed = self.scenario == 'verify_window_missed'
                lines.append(self.marker('kill_verify', user_version=31 if missed else 16,
                    outcome='WINDOW_MISSED_COMPLETED' if missed else 'KILLED_ROLLED_BACK',
                    quick_check='ok', rowsPreserved='true'))
            if self.scenario == 'verify_assertion':
                lines.append(json.dumps({'type': 'error', 'testID': 2, 'error': 'synthetic assertion failed'}))
            lines.append(json.dumps({'type': 'testDone', 'testID': 2,
                                     'result': 'failure' if self.scenario == 'verify_assertion' else 'success',
                                     'skipped': self.scenario == 'verify_skip'}))
        lines.append(json.dumps({'type': 'done', 'success': self.scenario != 'verify_assertion'}))
        output = Path(invocation['log_path']).parent
        receipt = self.persist(invocation['command'], output, lines, code=code)
        attempt = self.runner._record_attempt(self.root, self.planned, item, receipt, lines)
        return self.runner._finish(self.planned, item, [attempt])

    def run_fixture(self, scenario='success'):
        self.scenario = scenario
        with patch.object(adapters.shutil, 'which', return_value='/synthetic/tool'):
            return adapters.run_kill_replay(self.root, self.item, self.env, self.output / scenario,
                self.execute, execute_process=self.process, devices=DEVICES)

    def test_success_uses_only_verify_cases_and_portable_phase_receipts(self):
        result = self.run_fixture()
        self.assertEqual('PASS', result['status'])
        self.assertEqual(1, result['counts']['actually_run'])
        self.assertEqual(1, len(result['attempts']))
        self.assertIn('--dart-define=KILL_PHASE=verify', result['attempts'][0]['command'])
        self.assertEqual(2, result['companion_evidence']['protocol'])
        self.assertEqual([], adapters.verify_kill_replay_evidence(result['companion_evidence'], Path))
        candidate = self.output / 'results.json'
        payload = {'artifact_root': str(self.output), 'results': [result]}
        candidate.write_text(json.dumps(payload))
        relocated = self.root / 'downloaded'
        import shutil
        shutil.copytree(self.output, relocated)
        self.assertEqual('PASS', self.cli.load_results([relocated])[0]['status'])

    def test_missing_environment_never_starts_prepare_or_adb(self):
        for key in ('IMBOY_KILL_REPLAY_ATTEMPT', 'IMBOY_TEST_ISOLATED'):
            with self.subTest(key=key), patch.object(adapters.shutil, 'which', return_value='/synthetic/tool'):
                result = adapters.run_kill_replay(self.root, self.item,
                    {k: v for k, v in self.env.items() if k != key}, self.output,
                    self.execute, execute_process=self.process, devices=DEVICES)
                self.assertEqual('ENV_MISSING', result['reason_code'])
        self.item.pop('device_id')
        with patch.object(adapters, 'discover_devices') as discover:
            result = adapters.run_kill_replay(self.root, self.item, self.env, self.output,
                self.execute, execute_process=self.process)
        discover.assert_not_called()
        self.assertEqual('ENV_MISSING', result['reason_code'])
        self.assertEqual([], self.commands)

    def test_prepare_transport_loss_after_owned_stop_is_coordination_not_business_success(self):
        result = self.run_fixture('prepare_transport_lost_after_stop')
        self.assertEqual('PASS', result['status'])
        self.assertEqual(1, result['counts']['actually_run'])
        gate = result['companion_evidence']
        self.assertEqual([], adapters.verify_kill_replay_evidence(gate, Path))
        self.assertNotIn('lost device transport', Path(gate['ready_evidence']['path']).read_text())

    def test_prepare_assertion_skip_and_unknown_error_after_ready_are_never_ignored(self):
        for scenario, reason in (('prepare_assertion_after_stop', 'BUSINESS_ASSERTION_FAIL'),
                                 ('prepare_skip_after_stop', 'UNEXPECTED_SKIP'),
                                 ('prepare_unknown_error_after_stop', 'ERROR_NOT_INFRA')):
            with self.subTest(scenario=scenario):
                result = self.run_fixture(scenario)
                self.assertEqual('BLOCKED', result['status'])
                self.assertEqual(0, self.verify_calls)
                self.assertTrue(any(reason in error for error in result['companion_evidence']['errors']))

    def test_verify_runner_crash_retains_completed_interruption_phase_evidence(self):
        result = self.run_fixture('verify_runner_crash')
        self.assertEqual('BLOCKED', result['status'])
        self.assertEqual({'prepare', 'pid_before', 'force_stop', 'pid_after'},
                         set(result['companion_evidence']['phases']))
        self.assertTrue(any('RUNNER_CRASH' in error for error in result['companion_evidence']['errors']))

    def test_plain_single_device_invocation_cannot_bypass_coordinator(self):
        with self.assertRaisesRegex(ValueError, 'KILL_REPLAY_REQUIRES_ORCHESTRATION'):
            adapters.build_invocation(self.root, self.item, self.env, self.output, DEVICES)

    def test_missing_ready_or_missed_window_never_calls_force_stop_or_verify(self):
        for scenario in ('missing_ready', 'window_before_stop', 'window_after_pid', 'pid_missing'):
            with self.subTest(scenario=scenario):
                self.commands = []
                result = self.run_fixture(scenario)
                self.assertEqual('BLOCKED', result['status'])
                self.assertEqual(0, self.verify_calls)
                self.assertFalse(any('force-stop' in command for command in self.commands))
                self.assertIn('prepare', result['companion_evidence']['phases'])

    def test_unsuccessful_force_stop_cannot_start_verify(self):
        for scenario in ('force_stop_failed', 'pid_stays'):
            with self.subTest(scenario=scenario):
                result = self.run_fixture(scenario)
                self.assertEqual('BLOCKED', result['status'])
                self.assertEqual(0, self.verify_calls)

    def test_ready_without_an_active_partly_applied_transaction_never_touches_device(self):
        for scenario in ('legacy_ready', 'old_protocol', 'future_protocol', 'transaction_not_started',
                         'transaction_committed', 'no_migration_write', 'wrong_start', 'wrong_destination'):
            with self.subTest(scenario=scenario):
                self.commands = []
                result = self.run_fixture(scenario)
                self.assertEqual('BLOCKED', result['status'])
                self.assertEqual(0, self.verify_calls)
                self.assertFalse(any(command[0] == 'adb' for command in self.commands))
                self.assertIn('KILL_REPLAY_TRANSACTION_NOT_PROVEN', result['companion_evidence']['errors'])

    def test_replay_rejects_old_ready_even_with_consistent_file_hashes(self):
        result = self.run_fixture()
        gate = result['companion_evidence']
        process = json.loads(Path(gate['phases']['prepare']['path']).read_text())
        lines = Path(process['machine']).read_text().replace('protocol=2', 'protocol=1').splitlines()
        receipt = self.persist(process['command'], Path(gate['phases']['prepare']['path']).parent,
                               lines, code=process['exit_code'], error=process['error'], log_path=process['log'])
        ready = Path(gate['ready_evidence']['path'])
        ready.write_text(ready.read_text().replace('protocol=2', 'protocol=1'))

        def reference(path):
            return {'path': str(path), 'sha256': hashlib.sha256(Path(path).read_bytes()).hexdigest()}

        gate['phases']['prepare'] = reference(receipt['process_receipt'])
        gate['ready_evidence'] = reference(ready)
        coordinator = Path(gate['receipt']['path'])
        coordinator.write_text(json.dumps({key: value for key, value in gate.items()
                                          if key not in ('receipt', 'status', 'reason_code', 'errors')}))
        gate['receipt'] = reference(coordinator)
        self.assertEqual(['KILL_REPLAY_TRANSACTION_NOT_PROVEN'], adapters.verify_kill_replay_evidence(gate, Path))

    def test_replay_requires_the_transaction_protocol_on_the_coordinator(self):
        gate = self.run_fixture()['companion_evidence']
        gate.pop('protocol', None)
        self.assertEqual(['KILL_REPLAY_RECEIPT_INVALID'], adapters.verify_kill_replay_evidence(gate, Path))

    def test_verify_skip_zero_nonzero_and_window_miss_cannot_be_green(self):
        for scenario in ('verify_skip', 'verify_zero', 'verify_nonzero', 'verify_marker_missing', 'verify_window_missed', 'verify_assertion'):
            with self.subTest(scenario=scenario):
                result = self.run_fixture(scenario)
                self.assertNotEqual('PASS', result['status'])
                self.assertEqual('BLOCKED', result['companion_evidence']['status'])
                self.assertEqual(1, len(result['attempts']))
                if scenario == 'verify_assertion':
                    self.assertEqual('FAIL', result['status'])
        self.assertEqual(6, self.verify_calls, 'no assertion/skip retry is permitted')

    def test_missing_or_changed_phase_file_invalidates_a_successful_receipt(self):
        result = self.run_fixture()
        payload = {'artifact_root': str(self.output), 'results': [result]}
        candidate = self.output / 'results.json'
        gate = result['companion_evidence']
        process = json.loads(Path(gate['phases']['force_stop']['path']).read_text())
        Path(process['machine']).write_text('changed after receipt\n')
        self.assertEqual('BLOCKED', self.cli.verify_result_files(result, payload, candidate)['status'])
        Path(gate['phases']['pid_before']['path']).unlink()
        self.assertTrue(adapters.verify_kill_replay_evidence(gate, Path))

    def test_verify_receipt_is_bound_to_the_actual_business_attempt(self):
        result = self.run_fixture()
        result['companion_evidence']['phases']['verify'] = result['companion_evidence']['phases']['prepare']
        checked = self.cli.verify_result_files(result, {'artifact_root': str(self.output)}, self.output / 'results.json')
        self.assertEqual('BLOCKED', checked['status'])
        self.assertIn('actual test attempt', checked['evidence_error'])


if __name__ == '__main__':
    unittest.main()

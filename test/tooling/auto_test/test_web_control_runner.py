"""Oracle runner lifecycle and scope regressions; Flutter receipts are synthetic."""
from pathlib import Path
import subprocess
import unittest
from unittest.mock import patch

import test_execution_runner as support
from auto_test_lib import execution_adapters as adapters
from auto_test_lib import execution_catalog as catalog
from auto_test_lib import execution_runner as runner


ROOT = Path(__file__).resolve().parents[3]
TARGET = 'test/service/web_control_fixture_oracle_test.dart'
CHROME_TARGETS = frozenset({
    'test/service/web_control_fetch_chrome_test.dart',
    'test/service/web_control_production_wrapper_chrome_test.dart',
    'test/service/browser_received_attachment_chrome_test.dart',
    'test/service/web_message_content_security_chrome_test.dart',
})
FIXTURE_INPUTS = (
    'scripts/auto_test_lib/execution_runner.py',
    'scripts/auto_test_lib/owned_node_fixture.py',
    'scripts/auto_test_lib/web_control_fixture.py',
    'test/fixtures/web_control_fetch_server.cjs',
)


class SyntheticFixture:
    origin = 'http://127.0.0.1:10000'
    nonce = 'c' * 64

    def __init__(self, *_):
        self.stop_calls = 0

    def start(self):
        return self

    def observer(self, _):
        return None

    def stop(self):
        self.stop_calls += 1
        return True


class WebControlRunnerTest(unittest.TestCase):
    def setUp(self):
        self.helper = support.RunnerTest('runTest')
        self.helper.setUp()
        self.addCleanup(self.helper.doCleanups)
        for name in {TARGET} | CHROME_TARGETS:
            target = self.helper.root / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text('// synthetic owned fixture target\n')

    def test_owned_origin_replaces_old_define_and_does_not_reach_other_target(self):
        calls, fixtures = [], []

        class Fixture(SyntheticFixture):
            def __init__(self, *args):
                super().__init__(*args)
                fixtures.append(self)

        def invocation(root, instance, env, output):
            command = ['flutter', 'test', instance['target'], '--machine']
            if instance['target'] == TARGET:
                command.append('--dart-define=WEB_CONTROL_TEST_ORIGIN=http://127.0.0.1:65311')
            return {'command': command, 'env': env}

        def process(command, env, output, **kwargs):
            calls.append((list(command), kwargs))
            return self.helper.process(command, env, output, **kwargs)

        # Equal grouping inputs: isolation must come from the owned target,
        # not from accidentally different dart-defines or dependencies.
        declared = support.plan(support.instance(TARGET), support.instance('test/b_test.dart'))
        with self.helper.mock_execution(process), \
                patch.object(adapters, 'build_invocation', side_effect=invocation), \
                patch.object(runner, 'WebControlFixture', Fixture):
            result = runner.run_plan(self.helper.root, declared, self.helper.output)

        self.assertEqual(len(calls), 2)
        self.assertEqual(len(fixtures), 1)
        oracle, other = (next(item for item in calls if target in item[0])
                         for target in (TARGET, 'test/b_test.dart'))
        self.assertNotIn('test/b_test.dart', oracle[0])
        self.assertNotIn(TARGET, other[0])
        self.assertEqual([arg for arg in oracle[0] if 'WEB_CONTROL_TEST_ORIGIN=' in arg],
                         [f'--dart-define=WEB_CONTROL_TEST_ORIGIN={fixtures[0].origin}'])
        self.assertFalse(any('WEB_CONTROL_TEST_ORIGIN=' in arg for arg in other[0]))
        self.assertIs(oracle[1]['observer'].__self__, fixtures[0])
        self.assertNotIn('observer', other[1])
        self.assertGreaterEqual(fixtures[0].stop_calls, 1)
        self.assertTrue(all(row['status'] == 'PASS' for row in result['results']), result)

    def test_start_failure_blocks_without_launching_flutter(self):
        with self.helper.mock_execution(self.helper.process), \
                patch.object(runner, 'WebControlFixture') as fixture, \
                patch.object(runner, 'execute_process') as process:
            fixture.return_value.start.side_effect = runner.FixtureFailure('synthetic startup failure')
            result = runner.run_plan(self.helper.root, support.plan(support.instance(TARGET)),
                                     self.helper.output)
        process.assert_not_called()
        self.assertEqual(result['results'][0]['status'], 'BLOCKED')
        self.assertEqual(result['results'][0]['reason_code'], 'WEB_CONTROL_FIXTURE_START_FAILED')
        self.assertNotEqual(result['exit_code'], 0)

    def test_wrong_platform_blocks_before_fixture_and_flutter_start(self):
        pairs = [(TARGET, 'web')] + [(target, 'linux') for target in sorted(CHROME_TARGETS)]
        for target, platform in pairs:
            with self.subTest(target=target), self.helper.mock_execution(self.helper.process), \
                    patch.object(runner, 'WebControlFixture') as fixture, \
                    patch.object(runner, 'execute_process') as process:
                result = runner.run_plan(self.helper.root,
                                         support.plan(support.instance(target, platform=platform)),
                                         self.helper.output)
            fixture.assert_not_called()
            process.assert_not_called()
            self.assertEqual(result['results'][0]['reason_code'], 'WEB_CONTROL_FIXTURE_SCOPE_INVALID')

    def test_chrome_consumers_get_separate_owned_listeners_and_actual_origins(self):
        calls, fixtures = [], []

        class Fixture(SyntheticFixture):
            def __init__(self, *args):
                super().__init__(*args)
                self.origin = f'http://127.0.0.1:{10000 + len(fixtures)}'
                fixtures.append(self)

        def process(command, env, output, **kwargs):
            calls.append((list(command), kwargs))
            return self.helper.process(command, env, output, **kwargs)

        declared = support.plan(*(support.instance(target, platform='web')
                                  for target in sorted(CHROME_TARGETS | {'test/b_test.dart'})))
        with self.helper.mock_execution(process), patch.object(runner, 'WebControlFixture', Fixture):
            result = runner.run_plan(self.helper.root, declared, self.helper.output)
        self.assertEqual(result['status'], 'PASS', result)
        self.assertEqual(len(fixtures), len(CHROME_TARGETS))
        self.assertEqual(len({fixture.origin for fixture in fixtures}), len(fixtures))
        self.assertEqual(len(calls), len(CHROME_TARGETS) + 1)
        for command, options in calls:
            selected = [target for target in CHROME_TARGETS if target in command]
            if selected:
                self.assertEqual(len(selected), 1)
                fixture = options['observer'].__self__
                self.assertIn('--dart-define=WEB_CONTROL_TEST_ORIGIN=' + fixture.origin, command)
                self.assertGreaterEqual(fixture.stop_calls, 1)
            else:
                self.assertNotIn('observer', options)
                self.assertFalse(any('WEB_CONTROL_TEST_ORIGIN=' in arg for arg in command))

        config = catalog.load_contract(ROOT)
        for target in CHROME_TARGETS:
            override = config['overrides'][target]
            self.assertEqual(override['platforms'], ['web'])
            self.assertNotIn('WEB_CONTROL_TEST_ORIGIN', override.get('dart_defines', {}))
            self.assertIn('node', override['dependencies'])
            self.assertTrue(set(FIXTURE_INPUTS).issubset(override['source_dependencies']))

    def test_fixture_exit_or_cleanup_failure_vetoes_successful_machine_events(self):
        for failure in ('exit', 'cleanup'):
            with self.subTest(failure=failure):
                fixtures = []

                class Fixture(SyntheticFixture):
                    def __init__(self, *args):
                        super().__init__(*args)
                        self.exited = False
                        fixtures.append(self)

                    def observer(self, _):
                        return 'WEB_CONTROL_FIXTURE_EXITED' if self.exited else None

                    def stop(self):
                        super().stop()
                        return failure != 'cleanup'

                def process(command, env, output, **kwargs):
                    self.assertIsNone(kwargs['observer'](None))
                    receipt = self.helper.process(command, env, output, **kwargs)
                    fixtures[0].exited = failure == 'exit'
                    return receipt

                with self.helper.mock_execution(process), \
                        patch.object(runner, 'WebControlFixture', Fixture):
                    result = runner.run_plan(self.helper.root, support.plan(support.instance(TARGET)),
                                             self.helper.output / failure)
                row = result['results'][0]
                self.assertEqual(row['attempts'][0]['parsed']['test_status'], 'PASS')
                self.assertNotEqual(row['status'], 'PASS')
                self.assertEqual(row['reason_code'], 'WEB_CONTROL_FIXTURE_CLEANUP_OR_EXIT_FAILED')
                self.assertGreaterEqual(fixtures[0].stop_calls, 1)
                self.assertNotEqual(result['exit_code'], 0)

    def test_each_infrastructure_attempt_gets_a_fresh_fixture(self):
        fixtures, commands = [], []

        class Fixture(SyntheticFixture):
            def __init__(self, *args):
                super().__init__(*args)
                if fixtures:
                    self_outer.assertGreaterEqual(fixtures[-1].stop_calls, 1)
                self.origin = f'http://127.0.0.1:{10000 + len(fixtures)}'
                fixtures.append(self)

        self_outer = self

        def process(command, env, output, **kwargs):
            commands.append(list(command))
            receipt = self.helper.process(command, env, output, **kwargs)
            if len(commands) == 1:
                receipt.update(exit_code=137, lines=support.events(TARGET, done=False))
                Path(receipt['machine']).write_text('\n'.join(receipt['lines']) + '\n')
                runner._persist_process_receipt(receipt, output)
            return receipt

        with self.helper.mock_execution(process), patch.object(runner, 'WebControlFixture', Fixture):
            result = runner.run_plan(self.helper.root, support.plan(support.instance(TARGET)),
                                     self.helper.output, max_infra_attempts=3)
        self.assertEqual(len(fixtures), 2)
        self.assertEqual(len(commands), 2)
        for command, fixture in zip(commands, fixtures):
            self.assertIn(f'--dart-define=WEB_CONTROL_TEST_ORIGIN={fixture.origin}', command)
            self.assertGreaterEqual(fixture.stop_calls, 1)
        self.assertNotEqual(fixtures[0].origin, fixtures[1].origin)
        row = result['results'][0]
        self.assertEqual(len(row['attempts']), 2)
        self.assertEqual(row['status'], 'FLAKY')
        self.assertNotEqual(result['exit_code'], 0)

    def test_node_and_fixture_preflight_are_specific_to_owned_oracle(self):
        path = self.helper.root / runner.WEB_CONTROL_FIXTURE
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text('// synthetic Node fixture\n')
        instance = support.instance(TARGET)
        with patch('shutil.which', side_effect=lambda binary, **kwargs: None if binary == 'node' else 'synthetic'):
            errors = runner._default_preflight(self.helper.root, instance, {})
            self.assertTrue(any('web-control-fixture' in error for error in errors))
            errors = runner._default_preflight(self.helper.root, support.instance('test/b_test.dart'), {})
            self.assertFalse(any('web-control-fixture' in error for error in errors))
        path.unlink()
        with patch('shutil.which', return_value='synthetic'):
            errors = runner._default_preflight(self.helper.root, instance, {})
            self.assertTrue(any('web-control-fixture' in error for error in errors))

    def _plan_inputs(self):
        config = catalog.load_contract(ROOT)
        target = dict(target=TARGET, suite='unit', runner='flutter-machine',
                      platforms=['linux', 'macos'], products=['phase1_delivery'], dependencies=[])
        other = dict(target, target='test/b_test.dart')
        fake_catalog = dict(targets=[target, other], entries=[], commit='synthetic', counts={})
        for name in FIXTURE_INPUTS:
            path = self.helper.root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text('v1')
        return config, fake_catalog

    def test_fixture_inputs_change_only_the_selected_oracle_fingerprint(self):
        config, fake_catalog = self._plan_inputs()
        with patch.object(catalog, 'validate_catalog', return_value=fake_catalog), \
                patch.object(catalog.subprocess, 'run', return_value=subprocess.CompletedProcess([], 0, stdout=b'')):
            initial = catalog.build_plan(self.helper.root, contract=config, targets=[TARGET], platforms=['linux'])
            other = catalog.build_plan(self.helper.root, contract=config, targets=['test/b_test.dart'], platforms=['linux'])
            for name in FIXTURE_INPUTS:
                with self.subTest(input=name):
                    path = self.helper.root / name
                    path.write_text('v2')
                    changed = catalog.build_plan(self.helper.root, contract=config, targets=[TARGET], platforms=['linux'])
                    unchanged = catalog.build_plan(self.helper.root, contract=config, targets=['test/b_test.dart'], platforms=['linux'])
                    self.assertNotEqual(initial['source_fingerprint'], changed['source_fingerprint'])
                    self.assertEqual(other['source_fingerprint'], unchanged['source_fingerprint'])
                    path.write_text('v1')

    def test_exact_target_keeps_pr_gates_and_does_not_expand_specialist_profiles(self):
        config, fake_catalog = self._plan_inputs()
        self.assertEqual(runner.WEB_CONTROL_TARGETS, frozenset({TARGET}) | CHROME_TARGETS)
        override = config['overrides'][TARGET]
        self.assertNotIn('WEB_CONTROL_TEST_ORIGIN', override.get('dart_defines', {}))
        self.assertEqual(set(override['platforms']), {'linux', 'macos'})
        self.assertTrue(override['offline'])
        self.assertIn('node', override['dependencies'])
        self.assertTrue(set(FIXTURE_INPUTS).issubset(override['source_dependencies']))
        # Read the actual source and admission rule so a move to a specialist
        # suite cannot hide behind the synthetic planner catalog below.
        rule, = [rule for rule in config['rules'] if catalog._matches(TARGET, rule)]
        classified = catalog._classify(ROOT, TARGET, rule, {TARGET: (ROOT / TARGET).read_text()})
        self.assertEqual(override.get('suite', rule.get('suite', classified['suite'])), 'unit')
        expected_gates = ['ownership', 'static-analysis', 'framework', 'sqlite-generator', 'contracts']
        with patch.object(catalog, 'validate_catalog', return_value=fake_catalog), \
                patch.object(catalog.subprocess, 'run', return_value=subprocess.CompletedProcess([], 0, stdout=b'')):
            for profile in ('pr', 'full'):
                planned = catalog.build_plan(self.helper.root, contract=config, profile=profile, targets=[TARGET])
                selected = [row for row in planned['instances'] if row['selected']]
                self.assertEqual({(row['target'], row['platform']) for row in selected},
                                 {(TARGET, 'linux'), (TARGET, 'macos')})
                self.assertEqual(planned['gates'], expected_gates)
                self.assertTrue(all(row['upstream'] == expected_gates for row in selected))
                self.assertFalse(planned['full_regression'])
            for profile in ('backend', 'web', 'web-shell'):
                with self.subTest(profile=profile), self.assertRaisesRegex(catalog.ContractError, 'EMPTY_EXECUTION_PLAN'):
                    catalog.build_plan(self.helper.root, contract=config, profile=profile, targets=[TARGET])


if __name__ == '__main__':
    unittest.main()

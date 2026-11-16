"""Source-binding regression checks using three disposable Git repositories."""
import copy
import json
import os
from pathlib import Path
import runpy
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / '.github/scripts'))
import ci_source_lock as source  # noqa: E402


class SourceLockTest(unittest.TestCase):
    def setUp(self):
        environment = mock.patch.dict(os.environ, {'GITHUB_ACTIONS': 'false'})
        environment.start()
        self.addCleanup(environment.stop)
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.roots = {name: self.base / name for name in ('app', 'backend', 'admin')}
        for root in self.roots.values():
            root.mkdir()
            self.git(root, 'init', '-q')
            self.git(root, 'config', 'user.name', 'Source fixture')
            self.git(root, 'config', 'user.email', 'source-fixture@example.test')
            self.put(root / 'source.txt', 'tracked input\n')
        generator = '''from pathlib import Path
import hashlib
import json
GENERATED = %r
def read_manifest(path):
    return json.loads(path.read_text())
def require_profile(manifest, profile):
    if manifest['profile'] != profile:
        raise ValueError('fixture profile mismatch')
def source_catalog(root):
    return {}
def validate(manifest, catalog):
    return dict(manifest, schema_version=1, compiled_features=['fixture'],
        manifest_hash=hashlib.sha256(json.dumps(manifest, sort_keys=True).encode()).hexdigest())
def render(contract, *, app_dir, admin_dir):
    roots = {'app': app_dir, 'admin': admin_dir, 'backend': Path(__file__).resolve().parents[1]}
    return {roots[name] / path: contract['profile'] + ':' + path + '\\n'
            for name, paths in GENERATED.items() for path in paths}
''' % source.GENERATED
        self.put(self.roots['backend'] / 'scripts/generate_product_features.py', generator)
        self.put(self.roots['backend'] / source.PRODUCT_MANIFEST, '{"profile":"phase1_delivery"}\n')
        self.put(self.roots['app'] / source.FULL_MANIFEST, '{"profile":"full-selected"}\n')
        for relative in source.PRODUCT_VALIDATION_INPUTS[2:]:
            self.put(self.roots['backend'] / relative, 'fixture source catalog\n')
        self.prepare_product('phase1_delivery')
        backend_sha = self.commit(self.roots['backend'])
        admin_sha = self.commit(self.roots['admin'])
        self.lock = {'schema_version': 1, 'app_repository': 'example/app', 'repositories': {
            'backend': {'repository': 'example/backend', 'sha': backend_sha},
            'admin': {'repository': 'example/admin', 'sha': admin_sha}}}
        source.write_json(self.roots['app'] / source.LOCK_PATH, self.lock)
        app_sha = self.commit(self.roots['app'])
        rows = [dict(id=product, target='test/' + product + '_test.dart', selected=True,
                     platform='linux', suite='unit', runner='flutter-machine',
                     product_profile=product, coverage_eligible=True, commit=app_sha,
                     profile='full', source_fingerprint='fixture-source')
                for product in ('phase1_delivery', 'full-selected')]
        self.full = dict(commit=app_sha, profile='full', source_fingerprint='fixture-source',
                         scope='full', full_regression=True, gates=['ownership'], instances=rows)
        offline = dict(copy.deepcopy(self.full), scope='scoped', full_regression=False)
        self.plan_dir = self.base / 'plan'
        self.full_path = self.plan_dir / 'full-plan.json'
        self.offline_path = self.plan_dir / 'offline-plan.json'
        self.candidate = self.plan_dir / 'candidate.json'
        self.matrix = self.plan_dir / 'matrix.json'
        self.results = self.base / 'results'
        source.write_json(self.full_path, self.full)
        source.write_json(self.offline_path, offline)
        frozen = source.freeze(self.roots, self.full_path, self.offline_path, self.candidate)
        source.write_json(self.matrix, {'include': frozen['workers']})

    @staticmethod
    def git(root, *arguments):
        return subprocess.run(['git', '-C', str(root), *arguments], check=True,
                              capture_output=True, text=True).stdout.strip()

    @staticmethod
    def put(path, text):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding='utf-8')

    def commit(self, root):
        self.git(root, 'add', '--', '.')
        self.git(root, 'commit', '-qm', 'Synthetic source fixture')
        return self.git(root, 'rev-parse', 'HEAD')

    def prepare_product(self, product):
        backend = self.roots['backend']
        if product == 'full-selected':
            (backend / source.PRODUCT_MANIFEST).write_bytes((self.roots['app'] / source.FULL_MANIFEST).read_bytes())
        generator = runpy.run_path(str(backend / 'scripts/generate_product_features.py'))
        manifest = generator['read_manifest'](backend / source.PRODUCT_MANIFEST)
        contract = generator['validate'](manifest, {})
        for path, content in generator['render'](contract, app_dir=self.roots['app'], admin_dir=self.roots['admin']).items():
            self.put(path, content)

    def capture(self, partition, product='phase1_delivery'):
        directory = self.results / partition.replace(':', '-')
        path = directory / 'source_snapshot.json'
        source.capture(self.roots, self.candidate, product, partition, path)
        return directory

    def collect(self, partition, product='phase1_delivery', change=None):
        directory = self.capture(partition, product)
        if partition == 'gates':
            collection = {'ownership': {key: self.full[key] for key in ('commit', 'profile', 'source_fingerprint')}}
            collection['ownership']['status'] = 'PASS'
            path = directory / 'gates.json'
        else:
            state = source.read_json(directory / 'source_snapshot.json')['source_state']
            row = copy.deepcopy(next(row for row in self.full['instances'] if row['product_profile'] == product))
            row['status'] = 'PASS'
            artifacts = {name: state['repositories']['app']['files'][name]['sha256'] for name in source.PRODUCT_ARTIFACTS}
            inputs = {'app:' + name: value for name, value in artifacts.items()}
            inputs.update({'backend:' + name: state['repositories']['backend']['files'][name]['sha256']
                           for name in source.PRODUCT_VALIDATION_INPUTS})
            row['product_artifact'] = {'artifacts': artifacts, 'validation_inputs': inputs, 'manifest_profile': product}
            collection = {'results': [row]}
            path = directory / 'results.json'
        if change:
            change(collection)
        source.write_json(path, collection)
        source.seal(self.roots, directory / 'source_snapshot.json', directory)
        return directory

    def complete(self):
        self.collect('gates')
        self.collect('linux:unit:phase1_delivery')
        self.prepare_product('full-selected')
        self.collect('linux:unit:full-selected', 'full-selected')

    def verify(self, directory=None):
        return source.verify(self.roots['app'], self.candidate, self.matrix, directory or self.results)

    def test_outputs_and_partial_checkout_use_the_single_lock(self):
        target = self.base / 'github-output'
        values = source.outputs(self.roots['app'], target)
        self.assertEqual(values['backend_sha'], self.lock['repositories']['backend']['sha'])
        self.assertIn('admin_sha=' + self.lock['repositories']['admin']['sha'], target.read_text())
        receipt = source.checkout(self.roots['app'], self.roots['backend'], None, self.base / 'checkout.json')
        self.assertEqual(set(receipt['repositories']), {'app', 'backend'})
        self.assertEqual(receipt['scope'], 'source-checkout-only')

    def test_symbolic_pin_is_rejected(self):
        self.lock['repositories']['backend']['sha'] = 'main'
        source.write_json(self.roots['app'] / source.LOCK_PATH, self.lock)
        with self.assertRaisesRegex(ValueError, 'SOURCE_LOCK_REF_INVALID'):
            source.outputs(self.roots['app'])

    def test_all_partitions_and_generated_diffs_survive_artifact_relocation(self):
        self.complete()
        relocated = self.base / 'downloaded'
        shutil.copytree(self.results, relocated)
        report = self.verify(relocated)
        self.assertEqual(report['status'], 'PASS', report)
        self.assertFalse(report['complete_regression'])
        snapshot = source.read_json(relocated / 'linux-unit-full-selected/source_snapshot.json')
        for name in ('app', 'backend', 'admin'):
            self.assertTrue(snapshot['source_state']['repositories'][name]['changed_paths'])
            self.assertTrue((relocated / 'linux-unit-full-selected/sources' / (name + '.patch')).read_bytes())

    def test_missing_or_duplicate_partitions_are_blocked(self):
        self.collect('gates')
        missing = self.verify()
        self.assertEqual(missing['status'], 'BLOCKED')
        self.assertIn('SOURCE_RECEIPT_MISSING:linux:unit:full-selected', missing['issues'])
        self.collect('linux:unit:phase1_delivery')
        self.prepare_product('full-selected')
        self.collect('linux:unit:full-selected', 'full-selected')
        shutil.copytree(self.results / 'gates', self.results / 'duplicate-gates')
        duplicate = self.verify()
        self.assertTrue(any('DUPLICATE_SOURCE_RECEIPT' in item for item in duplicate['issues']))

    def test_wrong_backend_head_is_rejected_even_with_identical_product_files(self):
        self.put(self.roots['backend'] / 'source.txt', 'a different backend commit\n')
        self.commit(self.roots['backend'])
        with self.assertRaisesRegex(ValueError, 'SOURCE_HEAD_MISMATCH'):
            self.capture('gates')

    def test_hidden_and_untracked_source_changes_are_rejected(self):
        self.git(self.roots['app'], 'update-index', '--assume-unchanged', 'source.txt')
        self.put(self.roots['app'] / 'source.txt', 'hidden modification\n')
        with self.assertRaisesRegex(ValueError, 'INDEX_HIDES_SOURCE_CHANGES'):
            self.capture('gates')
        self.git(self.roots['app'], 'update-index', '--no-assume-unchanged', 'source.txt')
        self.git(self.roots['app'], 'restore', '--', 'source.txt')
        self.put(self.roots['admin'] / 'untracked.ts', 'export const accidental = true\n')
        with self.assertRaisesRegex(ValueError, 'UNTRACKED_SOURCE_PRESENT'):
            self.capture('gates')

    def test_full_selected_allows_only_verified_generator_changes(self):
        self.prepare_product('full-selected')
        self.put(self.roots['backend'] / 'source.txt', 'non-generated modification\n')
        with self.assertRaisesRegex(ValueError, 'UNAPPROVED_SOURCE_CHANGE'):
            self.capture('linux:unit:full-selected', 'full-selected')
        self.git(self.roots['backend'], 'restore', '--', 'source.txt')
        self.put(self.roots['app'] / source.PRODUCT_ARTIFACTS[0], 'wrong generated bytes\n')
        with self.assertRaisesRegex(ValueError, 'PRODUCT_GENERATED_ARTIFACT_DRIFT'):
            self.capture('linux:unit:full-selected', 'full-selected')

    def test_changes_during_execution_cannot_be_sealed(self):
        directory = self.capture('gates')
        self.put(self.roots['admin'] / 'source.txt', 'changed while tests ran\n')
        with self.assertRaisesRegex(ValueError, 'UNAPPROVED_SOURCE_CHANGE'):
            source.seal(self.roots, directory / 'source_snapshot.json', directory)
        self.assertFalse((directory / 'source_receipt.json').exists())

    def test_result_bytes_and_generated_source_bytes_are_verified(self):
        self.complete()
        result = self.results / 'linux-unit-phase1_delivery/results.json'
        result.write_text(result.read_text() + '\n')
        report = self.verify()
        self.assertTrue(any('COLLECTION_HASH_MISMATCH' in item for item in report['issues']))
        source_file = self.results / 'linux-unit-full-selected/sources/backend.patch'
        source_file.write_text('tampered diff\n')
        report = self.verify()
        self.assertTrue(any('SOURCE_FILE_HASH_MISMATCH' in item for item in report['issues']))

    def test_result_identity_and_cross_repo_inputs_must_match_capture(self):
        self.collect('gates')
        self.collect('linux:unit:phase1_delivery', change=lambda value:
                     value['results'][0].update(commit='f' * 40))
        self.prepare_product('full-selected')
        self.collect('linux:unit:full-selected', 'full-selected', change=lambda value:
                     value['results'][0]['product_artifact']['validation_inputs'].update(
                         {'backend:scripts/generate_product_features.py': '0' * 64}))
        report = self.verify()
        self.assertTrue(any('RESULT_SOURCE_IDENTITY_MISMATCH' in item for item in report['issues']))
        self.assertTrue(any('RESULT_PRODUCT_SOURCE_MISMATCH' in item for item in report['issues']))

    def test_changed_plan_or_candidate_pin_is_rejected(self):
        value = source.read_json(self.full_path)
        value['source_fingerprint'] = 'different-source'
        source.write_json(self.full_path, value)
        with self.assertRaisesRegex(ValueError, 'CANDIDATE_PLAN_HASH_MISMATCH'):
            self.capture('gates')
        source.write_json(self.full_path, self.full)
        candidate = source.read_json(self.candidate)
        candidate['repositories']['backend']['head'] = 'f' * 40
        source.write_json(self.candidate, candidate)
        with self.assertRaisesRegex(ValueError, 'CANDIDATE_PIN_MISMATCH'):
            self.capture('gates')

    def test_new_execution_cannot_reuse_same_sha_old_receipts(self):
        self.collect('gates')
        original = source.read_json(self.candidate)
        replacement = source.freeze(self.roots, self.full_path, self.offline_path, self.candidate)
        self.assertEqual(original['repositories'], replacement['repositories'])
        self.assertNotEqual(original['execution'], replacement['execution'])
        report = self.verify()
        self.assertEqual(report['status'], 'BLOCKED')
        self.assertTrue(any('RECEIPT_CANDIDATE_MISMATCH' in item for item in report['issues']))

    def test_github_run_and_attempt_must_match_the_frozen_execution(self):
        environment = {'GITHUB_ACTIONS': 'true', 'GITHUB_RUN_ID': '123',
                       'GITHUB_RUN_ATTEMPT': '1', 'GITHUB_REPOSITORY': 'example/app',
                       'GITHUB_EVENT_NAME': 'pull_request'}
        with mock.patch.dict(os.environ, environment):
            frozen = source.freeze(self.roots, self.full_path, self.offline_path, self.candidate)
            self.assertEqual(frozen['execution']['github_run_attempt'], '1')
            self.capture('gates')
            for key, value in (('GITHUB_RUN_ID', '124'), ('GITHUB_RUN_ATTEMPT', '2')):
                with self.subTest(key=key), mock.patch.dict(os.environ, {key: value}):
                    with self.assertRaisesRegex(ValueError, 'EXECUTION_IDENTITY_MISMATCH:' + key):
                        source.load_candidate(self.candidate, self.roots['app'])

    def test_wrong_product_partition_and_reused_receipt_are_rejected(self):
        with self.assertRaisesRegex(ValueError, 'WORKER_PRODUCT_MISMATCH'):
            self.capture('linux:unit:full-selected')
        directory = self.collect('gates')
        with self.assertRaisesRegex(ValueError, 'SOURCE_RECEIPT_ALREADY_EXISTS'):
            source.seal(self.roots, directory / 'source_snapshot.json', directory)


if __name__ == '__main__':
    unittest.main()

"""Bind CI checkouts and UIUX evidence to one reviewed source combination.

This is a source receipt around the existing execution runner, not a test runner.
Only the existing product generator's outputs may differ from the frozen commits.
"""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import uuid

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'scripts'))
from auto_test_lib.execution_adapters import (  # noqa: E402
    PRODUCT_ARTIFACTS, PRODUCT_VALIDATION_INPUTS,
)
from uiux_full_matrix import matrix  # noqa: E402

LOCK_PATH = '.github/ci-source-lock.json'
PRODUCT_MANIFEST = 'config/product-feature-manifest.json'
FULL_MANIFEST = '.github/scripts/uiux_full_product_manifest.json'
GENERATED = {
    'app': tuple(PRODUCT_ARTIFACTS),
    'backend': ('include/generated/imboy_product_features.hrl',
                'include/generated/imboy_product_features_erlc.mk'),
    'admin': ('src/generated/productFeatures.ts',
              'src/generated/generatedFeatureComposition.tsx'),
}
SHA = re.compile(r'[a-f0-9]{40}')
REPOSITORY = re.compile(r'[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+')


def require(condition, reason):
    if not condition:
        raise ValueError(reason)


def digest(content):
    return hashlib.sha256(content).hexdigest()


def json_bytes(value):
    return (json.dumps(value, ensure_ascii=False, sort_keys=True, indent=2) + '\n').encode()


def read_json(path):
    def unique(pairs):
        result = {}
        for key, value in pairs:
            require(key not in result, 'DUPLICATE_JSON_KEY')
            result[key] = value
        return result
    return json.loads(Path(path).read_text(encoding='utf-8'), object_pairs_hook=unique)


def write_json(path, value):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(json_bytes(value))


def execution_identity():
    identity = {'kind': 'local', 'invocation_id': uuid.uuid4().hex}
    if os.environ.get('GITHUB_ACTIONS') == 'true':
        identity.update(kind='github-actions')
        for name in ('GITHUB_RUN_ID', 'GITHUB_RUN_ATTEMPT', 'GITHUB_REPOSITORY', 'GITHUB_EVENT_NAME'):
            value = os.environ.get(name, '')
            require(bool(value), 'GITHUB_EXECUTION_IDENTITY_MISSING:' + name)
            identity[name.lower()] = value
    return identity


def verify_execution(identity):
    require(isinstance(identity, dict)
            and identity.get('kind') in {'local', 'github-actions'}
            and isinstance(identity.get('invocation_id'), str)
            and re.fullmatch(r'[0-9a-f]{32}', identity['invocation_id']),
            'EXECUTION_IDENTITY_INVALID')
    if os.environ.get('GITHUB_ACTIONS') == 'true':
        require(identity['kind'] == 'github-actions', 'EXECUTION_KIND_MISMATCH')
        for name in ('GITHUB_RUN_ID', 'GITHUB_RUN_ATTEMPT', 'GITHUB_REPOSITORY', 'GITHUB_EVENT_NAME'):
            require(bool(os.environ.get(name)) and identity.get(name.lower()) == os.environ[name],
                    'EXECUTION_IDENTITY_MISMATCH:' + name)


def git(root, *args):
    return subprocess.run(
        ['git', '--no-replace-objects', '-C', str(root), *args],
        capture_output=True, check=True, timeout=30,
        env=dict(os.environ, GIT_GRAFT_FILE=os.devnull),
    ).stdout


def lock_data(app):
    path = Path(app) / LOCK_PATH
    lock = read_json(path)
    require(set(lock) == {'schema_version', 'app_repository', 'repositories'}
            and type(lock['schema_version']) is int and lock['schema_version'] == 1,
            'SOURCE_LOCK_SCHEMA_INVALID')
    require(isinstance(lock['app_repository'], str)
            and REPOSITORY.fullmatch(lock['app_repository']), 'APP_REPOSITORY_INVALID')
    require(set(lock['repositories']) == {'backend', 'admin'}, 'SOURCE_LOCK_REPOSITORIES_INVALID')
    for row in lock['repositories'].values():
        require(isinstance(row, dict) and set(row) == {'repository', 'sha'}
                and isinstance(row['repository'], str) and REPOSITORY.fullmatch(row['repository'])
                and isinstance(row['sha'], str) and SHA.fullmatch(row['sha']), 'SOURCE_LOCK_REF_INVALID')
    return lock, digest(path.read_bytes())


def outputs(app, github_output=None):
    lock, lock_hash = lock_data(app)
    values = {'lock_sha256': lock_hash, 'app_sha': git(app, 'rev-parse', 'HEAD').decode().strip()}
    for name, row in lock['repositories'].items():
        values.update({name + '_repository': row['repository'], name + '_sha': row['sha']})
    if github_output:
        with Path(github_output).open('a', encoding='utf-8') as stream:
            stream.writelines(f'{key}={value}\n' for key, value in values.items())
    return values


def repositories(app, backend, admin):
    roots = {name: Path(path).resolve() for name, path in
             (('app', app), ('backend', backend), ('admin', admin))}
    require(len(set(roots.values())) == 3, 'DISTINCT_REPOSITORIES_REQUIRED')
    return roots


def repo_state(root, expected=None, allowed=()):
    require(Path(git(root, 'rev-parse', '--show-toplevel').decode().strip()).resolve() == root,
            'REPOSITORY_ROOT_MISMATCH')
    head = git(root, 'rev-parse', 'HEAD').decode().strip()
    require(SHA.fullmatch(head) and (expected is None or head == expected), 'SOURCE_HEAD_MISMATCH')
    flags = git(root, 'ls-files', '-v', '-z').decode().split('\0')
    require(not any(row and (row[0].islower() or row[0] == 'S') for row in flags),
            'INDEX_HIDES_SOURCE_CHANGES')
    untracked = git(root, 'ls-files', '--others', '--exclude-standard', '-z')
    require(not untracked, 'UNTRACKED_SOURCE_PRESENT')
    changed = git(root, 'diff', '--name-only', '--no-renames', 'HEAD', '--').decode().splitlines()
    require(set(changed).issubset(set(allowed)), 'UNAPPROVED_SOURCE_CHANGE')
    patch = git(root, 'diff', '--binary', '--full-index', '--no-ext-diff', '--no-textconv',
                '--no-renames', 'HEAD', '--')
    state = {'head': head, 'tree': git(root, 'rev-parse', 'HEAD^{tree}').decode().strip(),
             'changed_paths': sorted(changed), 'diff_sha256': digest(patch)}
    return state, patch


def freeze(roots, full_path, offline_path, output):
    lock, lock_hash = lock_data(roots['app'])
    states = {}
    for name, root in roots.items():
        expected = lock['repositories'][name]['sha'] if name != 'app' else None
        states[name] = repo_state(root, expected)[0]
    full, offline = read_json(full_path), read_json(offline_path)
    require(full.get('commit') == states['app']['head'], 'PLAN_APP_SHA_MISMATCH')
    require(full.get('profile') == offline.get('profile') == 'full', 'PLAN_PROFILE_INVALID')
    workers = matrix(full, offline)['include']
    destination = Path(output).resolve()
    plans = {}
    for name, value in (('full', full_path), ('offline', offline_path)):
        path = Path(value).resolve()
        require(path.parent == destination.parent, 'PLANS_MUST_SHARE_CANDIDATE_DIRECTORY')
        plans[name] = {'path': path.name, 'sha256': digest(path.read_bytes())}
    candidate = {'schema_version': 1, 'execution': execution_identity(),
                 'lock': lock, 'lock_sha256': lock_hash,
                 'repositories': states, 'plans': plans, 'workers': workers,
                 'source_fingerprint': full['source_fingerprint']}
    write_json(destination, candidate)
    return candidate


def checkout(app, backend, admin, output):
    """Record the source-only subset needed by an ordinary CI job."""
    lock, lock_hash = lock_data(app)
    roots = {'app': Path(app).resolve(), 'backend': Path(backend).resolve()}
    if admin:
        roots['admin'] = Path(admin).resolve()
    require(len(set(roots.values())) == len(roots), 'DISTINCT_REPOSITORIES_REQUIRED')
    states = {name: repo_state(root, lock['repositories'][name]['sha'] if name != 'app' else None)[0]
              for name, root in roots.items()}
    receipt = {'schema_version': 1, 'scope': 'source-checkout-only', 'status': 'BOUND',
               'lock_sha256': lock_hash, 'repositories': states}
    write_json(output, receipt)
    return receipt


def load_candidate(path, app):
    candidate = read_json(path)
    verify_execution(candidate.get('execution'))
    lock, lock_hash = lock_data(app)
    require(candidate.get('schema_version') == 1 and candidate.get('lock') == lock
            and candidate.get('lock_sha256') == lock_hash, 'CANDIDATE_LOCK_MISMATCH')
    require(set(candidate['repositories']) == {'app', 'backend', 'admin'}, 'CANDIDATE_REPOSITORIES_INVALID')
    for name, pinned in lock['repositories'].items():
        require(candidate['repositories'][name]['head'] == pinned['sha'], 'CANDIDATE_PIN_MISMATCH')
    require(git(app, 'rev-parse', 'HEAD').decode().strip() == candidate['repositories']['app']['head'],
            'CANDIDATE_APP_HEAD_MISMATCH')
    plans = {}
    for name, meta in candidate['plans'].items():
        source = safe_file(Path(path).resolve().parent, meta['path'])
        require(digest(source.read_bytes()) == meta['sha256'], 'CANDIDATE_PLAN_HASH_MISMATCH')
        plans[name] = read_json(source)
    require(set(plans) == {'full', 'offline'} and matrix(plans['full'], plans['offline'])['include']
            == candidate['workers'], 'CANDIDATE_MATRIX_MISMATCH')
    require(plans['full'].get('commit') == candidate['repositories']['app']['head']
            and plans['full'].get('source_fingerprint') == candidate['source_fingerprint'],
            'CANDIDATE_PLAN_IDENTITY_MISMATCH')
    return candidate, plans


def safe_file(root, relative):
    require(isinstance(relative, str) and relative and not Path(relative).is_absolute()
            and '..' not in Path(relative).parts, 'EVIDENCE_PATH_INVALID')
    path = root / relative
    require(path.is_file() and not path.is_symlink()
            and path.resolve().is_relative_to(root.resolve()), 'EVIDENCE_FILE_MISSING_OR_ESCAPED')
    return path


def worker_key(row):
    return ':'.join(row[key] for key in ('platform', 'suite', 'product'))


def partition_product(candidate, partition):
    if partition == 'gates':
        return 'phase1_delivery'
    rows = [row for row in candidate['workers'] if worker_key(row) == partition]
    require(len(rows) == 1, 'UNDECLARED_WORKER_PARTITION')
    return rows[0]['product']


def generated_outputs(roots, product):
    require(product in {'phase1_delivery', 'full-selected'}, 'PRODUCT_PROFILE_INVALID')
    backend = roots['backend']
    script = backend / 'scripts/generate_product_features.py'
    spec = importlib.util.spec_from_file_location('ci_locked_product_generator', script)
    generator = importlib.util.module_from_spec(spec)
    previous_bytecode = sys.dont_write_bytecode
    try:
        sys.dont_write_bytecode = True
        spec.loader.exec_module(generator)
    finally:
        sys.dont_write_bytecode = previous_bytecode
    manifest_path = backend / PRODUCT_MANIFEST
    manifest = generator.read_manifest(manifest_path)
    generator.require_profile(manifest, product)
    if product == 'full-selected':
        require(manifest_path.read_bytes() == (roots['app'] / FULL_MANIFEST).read_bytes(),
                'FULL_SELECTED_MANIFEST_MISMATCH')
    # Source-only render: never starts Erlang or rewrites a product artifact.
    contract = generator.validate(manifest, generator.source_catalog(backend))
    rendered = generator.render(contract, app_dir=roots['app'], admin_dir=roots['admin'])
    expected = {roots[name] / path for name, paths in GENERATED.items() for path in paths}
    require(set(rendered) == expected, 'PRODUCT_OUTPUT_SET_CHANGED')
    for path, content in rendered.items():
        require(path.is_file() and not path.is_symlink() and path.read_bytes() == content.encode(),
                'PRODUCT_GENERATED_ARTIFACT_DRIFT')
    return {'manifest_profile': product, 'manifest_hash': contract['manifest_hash'],
            'compiled_features': contract['compiled_features']}


def measure(roots, candidate, product):
    states, blobs = {}, {}
    for name, root in roots.items():
        allowed = GENERATED[name] if product == 'full-selected' else ()
        if name == 'backend' and product == 'full-selected':
            allowed += (PRODUCT_MANIFEST,)
        state, patch = repo_state(root, candidate['repositories'][name]['head'], allowed)
        require(state['tree'] == candidate['repositories'][name]['tree'], 'SOURCE_TREE_MISMATCH')
        diff_path = f'sources/{name}.patch'
        state['diff_path'] = diff_path
        blobs[diff_path] = patch
        states[name] = state
    product_identity = generated_outputs(roots, product)
    for name, root in roots.items():
        paths = set(GENERATED[name])
        if name == 'backend':
            paths.update(PRODUCT_VALIDATION_INPUTS)
        files = {}
        for relative in sorted(paths):
            path = safe_file(root, relative)
            metadata = git(root, 'ls-tree', 'HEAD', '--', relative).decode().split()
            require(metadata and metadata[0] in {'100644', '100755'}, 'PRODUCT_INPUT_NOT_TRACKED')
            require(bool(path.stat().st_mode & 0o111) == (metadata[0] == '100755'), 'PRODUCT_FILE_MODE_CHANGED')
            content = path.read_bytes()
            content_path = f'sources/files/{digest(content)}'
            blobs[content_path] = content
            files[relative] = {'sha256': digest(content), 'path': content_path,
                               'head_sha256': digest(git(root, 'show', f'HEAD:{relative}'))}
        states[name]['files'] = files
    return {'repositories': states, 'product': product_identity}, blobs


def capture(roots, candidate_path, product, partition, output):
    candidate, _ = load_candidate(candidate_path, roots['app'])
    require(product == partition_product(candidate, partition), 'WORKER_PRODUCT_MISMATCH')
    state, blobs = measure(roots, candidate, product)
    destination = Path(output).resolve()
    require(not destination.exists(), 'SOURCE_SNAPSHOT_ALREADY_EXISTS')
    for name, content in blobs.items():
        path = destination.parent / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(content)
    value = {'schema_version': 1, 'candidate': candidate,
             'candidate_sha256': digest(Path(candidate_path).read_bytes()),
             'partition': partition, 'source_state': state,
             'files': {name: digest(content) for name, content in blobs.items()}}
    write_json(destination, value)
    return value


def seal(roots, sources, evidence_dir):
    sources, output = Path(sources).resolve(), Path(evidence_dir).resolve()
    require(sources.parent == output, 'SOURCE_SNAPSHOT_LOCATION_INVALID')
    snapshot = read_json(sources)
    verify_execution(snapshot['candidate'].get('execution'))
    product = partition_product(snapshot['candidate'], snapshot['partition'])
    require(lock_data(roots['app'])[1] == snapshot['candidate']['lock_sha256'], 'SOURCE_LOCK_CHANGED')
    state, _ = measure(roots, snapshot['candidate'], product)
    require(state == snapshot['source_state'], 'SOURCES_CHANGED_DURING_EXECUTION')
    for relative, expected in snapshot['files'].items():
        require(digest(safe_file(output, relative).read_bytes()) == expected, 'SOURCE_SNAPSHOT_TAMPERED')
    collection = 'gates.json' if snapshot['partition'] == 'gates' else 'results.json'
    evidence = safe_file(output, collection)
    receipt = {'schema_version': 1, 'status': 'BOUND', 'partition': snapshot['partition'],
               'candidate_sha256': snapshot['candidate_sha256'],
               'source_snapshot': {'path': sources.name, 'sha256': digest(sources.read_bytes())},
               'collection': {'path': collection, 'sha256': digest(evidence.read_bytes())}}
    destination = output / 'source_receipt.json'
    require(not destination.exists(), 'SOURCE_RECEIPT_ALREADY_EXISTS')
    write_json(destination, receipt)
    return receipt


def verify_product(row, state):
    product = row.get('product_artifact') or {}
    if not product.get('artifacts'):
        return
    expected = {path: state['repositories']['app']['files'][path]['sha256'] for path in PRODUCT_ARTIFACTS}
    require(product['artifacts'] == expected, 'RESULT_PRODUCT_ARTIFACT_MISMATCH')
    expected_inputs = {'app:' + path: value for path, value in expected.items()}
    expected_inputs.update({'backend:' + path: state['repositories']['backend']['files'][path]['sha256']
                           for path in PRODUCT_VALIDATION_INPUTS})
    require(product.get('validation_inputs') == expected_inputs, 'RESULT_PRODUCT_SOURCE_MISMATCH')
    require(product.get('manifest_profile') == state['product']['manifest_profile'], 'RESULT_PRODUCT_PROFILE_MISMATCH')


def verify_snapshot_files(snapshot, root, product):
    state = snapshot['source_state']
    require(set(state['repositories']) == set(GENERATED), 'SNAPSHOT_REPOSITORIES_INVALID')
    bound_files = set()
    for name, repo in state['repositories'].items():
        expected = set(GENERATED[name])
        if name == 'backend':
            expected.update(PRODUCT_VALIDATION_INPUTS)
        require(set(repo['files']) == expected, 'SNAPSHOT_FILE_SET_INVALID')
        allowed = set(GENERATED[name]) if product == 'full-selected' else set()
        if name == 'backend' and product == 'full-selected':
            allowed.add(PRODUCT_MANIFEST)
        require(set(repo['changed_paths']).issubset(allowed), 'SNAPSHOT_UNAPPROVED_SOURCE_CHANGE')
        require(snapshot['files'].get(repo['diff_path']) == repo['diff_sha256'], 'SOURCE_DIFF_UNBOUND')
        bound_files.add(repo['diff_path'])
        for relative, item in repo['files'].items():
            require(snapshot['files'].get(item['path']) == item['sha256'], 'SOURCE_ARTIFACT_UNBOUND')
            if relative not in allowed:
                require(item['sha256'] == item['head_sha256'], 'SNAPSHOT_INPUT_NOT_FROM_HEAD')
            bound_files.add(item['path'])
    require(set(snapshot['files']) == bound_files, 'SNAPSHOT_BLOB_SET_INVALID')
    for relative, expected_hash in snapshot['files'].items():
        require(digest(safe_file(root, relative).read_bytes()) == expected_hash, 'SOURCE_FILE_HASH_MISMATCH')


def verify_collection(collection, partition, full, snapshot):
    if partition == 'gates':
        require(isinstance(collection, dict) and set(collection) == set(full['gates']), 'GATE_COLLECTION_INCOMPLETE')
        rows = list(collection.values())
    else:
        require(isinstance(collection, dict) and isinstance(collection.get('results'), list), 'RESULT_COLLECTION_INVALID')
        rows = collection['results']
        platform, suite, product = partition.split(':')
        expected = {row['id'] for row in full['instances'] if row.get('selected')
                    and (row['platform'], row['suite'], row['product_profile']) == (platform, suite, product)}
        require(len(rows) == len(expected) and {row.get('id') for row in rows} == expected,
                'RESULT_PARTITION_INCOMPLETE_OR_DUPLICATE')
    for row in rows:
        require(all(row.get(key) == full.get(key) for key in ('commit', 'profile', 'source_fingerprint')),
                'RESULT_SOURCE_IDENTITY_MISMATCH')
        verify_product(row, snapshot['source_state'])
        for attempt in row.get('attempts', []):
            verify_product(attempt, snapshot['source_state'])


def verify(app, candidate_path, matrix_path, results, output=None):
    issues, observed = [], {}
    try:
        candidate, plans = load_candidate(candidate_path, app)
        require(read_json(matrix_path) == {'include': candidate['workers']}, 'FROZEN_MATRIX_MISMATCH')
        expected = {'gates', *(worker_key(row) for row in candidate['workers'])}
        candidate_hash = digest(Path(candidate_path).read_bytes())
        for path in sorted(Path(results).rglob('source_receipt.json')):
            try:
                require(not path.is_symlink(), 'RECEIPT_SYMLINK_REJECTED')
                receipt = read_json(path)
                key = receipt.get('partition')
                require(key in expected and key not in observed, 'UNEXPECTED_OR_DUPLICATE_SOURCE_RECEIPT')
                require(receipt.get('schema_version') == 1 and receipt.get('status') == 'BOUND'
                        and receipt.get('candidate_sha256') == candidate_hash, 'RECEIPT_CANDIDATE_MISMATCH')
                root = path.parent.resolve()
                meta = receipt['source_snapshot']
                source_file = safe_file(root, meta['path'])
                require(digest(source_file.read_bytes()) == meta['sha256'], 'SOURCE_SNAPSHOT_HASH_MISMATCH')
                snapshot = read_json(source_file)
                require(snapshot.get('candidate') == candidate and snapshot.get('candidate_sha256') == candidate_hash
                        and snapshot.get('partition') == key, 'SOURCE_SNAPSHOT_IDENTITY_MISMATCH')
                state = snapshot['source_state']
                require(state['product']['manifest_profile'] == partition_product(candidate, key), 'SNAPSHOT_PRODUCT_MISMATCH')
                for name, original in candidate['repositories'].items():
                    require(all(state['repositories'][name].get(field) == original[field] for field in ('head', 'tree')),
                            'SNAPSHOT_REPOSITORY_MISMATCH')
                verify_snapshot_files(snapshot, root, partition_product(candidate, key))
                meta = receipt['collection']
                require(meta['path'] == ('gates.json' if key == 'gates' else 'results.json'), 'COLLECTION_PATH_INVALID')
                collection = safe_file(root, meta['path'])
                require(digest(collection.read_bytes()) == meta['sha256'], 'COLLECTION_HASH_MISMATCH')
                verify_collection(read_json(collection), key, plans['full'], snapshot)
                observed[key] = str(path.relative_to(Path(results)))
            except (OSError, ValueError, KeyError, TypeError, AttributeError) as error:
                issues.append(type(error).__name__ + ':' + str(error))
        missing = sorted(expected - set(observed))
        issues.extend('SOURCE_RECEIPT_MISSING:' + key for key in missing)
    except (OSError, ValueError, KeyError, TypeError, AttributeError, subprocess.SubprocessError) as error:
        issues.append(type(error).__name__ + ':' + str(error))
    summary = {'schema_version': 1, 'scope': 'source-binding-only',
               'status': 'BLOCKED' if issues else 'PASS', 'complete_regression': False,
               'partitions_verified': sorted(observed), 'issues': issues,
               'exit_code': 2 if issues else 0}
    if output:
        write_json(output, summary)
    return summary


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command', required=True)
    for command in ('outputs', 'checkout', 'freeze', 'capture', 'seal', 'verify'):
        child = commands.add_parser(command)
        child.add_argument('--app', default='.')
        if command in {'freeze', 'capture', 'seal'}:
            child.add_argument('--backend', required=True)
            child.add_argument('--admin', required=True)
        if command == 'checkout':
            child.add_argument('--backend', required=True)
            child.add_argument('--admin')
        if command == 'outputs':
            child.add_argument('--github-output')
        if command == 'freeze':
            child.add_argument('--full-plan', required=True)
            child.add_argument('--offline-plan', required=True)
        if command in {'checkout', 'freeze', 'capture', 'verify'}:
            child.add_argument('--output', required=True)
        if command in {'capture', 'verify'}:
            child.add_argument('--candidate', required=True)
        if command == 'capture':
            child.add_argument('--product', required=True)
            child.add_argument('--partition', required=True)
        if command == 'seal':
            child.add_argument('--sources', required=True)
            child.add_argument('--evidence-dir', required=True)
        if command == 'verify':
            child.add_argument('--matrix', required=True)
            child.add_argument('--results', required=True)
    args = parser.parse_args(argv)
    try:
        roots = repositories(args.app, args.backend, args.admin) if args.command in {'freeze', 'capture', 'seal'} else None
        if args.command == 'outputs':
            print(json.dumps(outputs(args.app, args.github_output), sort_keys=True))
        elif args.command == 'checkout':
            checkout(args.app, args.backend, args.admin, args.output)
        elif args.command == 'freeze':
            freeze(roots, args.full_plan, args.offline_plan, args.output)
        elif args.command == 'capture':
            capture(roots, args.candidate, args.product, args.partition, args.output)
        elif args.command == 'seal':
            seal(roots, args.sources, args.evidence_dir)
        else:
            summary = verify(args.app, args.candidate, args.matrix, args.results, args.output)
            print(json.dumps(summary, sort_keys=True))
            return summary['exit_code']
        return 0
    except (OSError, ValueError, KeyError, TypeError, AttributeError, subprocess.SubprocessError) as error:
        print('SOURCE_BINDING_BLOCKED: ' + type(error).__name__ + ': ' + str(error), file=sys.stderr)
        return 2


if __name__ == '__main__':
    raise SystemExit(main())

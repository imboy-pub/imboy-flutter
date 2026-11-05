"""Tracked test ownership and execution plans for the existing auto-test runner.

Directory rules admit a known test family; source/import evidence selects its
runner requirements. Rules never silently disable a newly discovered test.
Plans are declarations, not execution receipts.
"""
from __future__ import annotations

import ast
import copy
import hashlib
import json
import re
import subprocess
from collections import Counter
from pathlib import Path, PurePosixPath

from .discovery import git_head

CONTRACT_PATH = 'test/auto_test/execution_contract.json'
SCHEMA_VERSION = 1
RUNNERS = {'flutter-machine', 'flutter-device', 'device-pair', 'patrol',
           'python-unittest', 'python-cases', 'python-recovery'}
CLASSIFIERS = {'host-dart', 'device-dart', 'python-test', 'support'}
AUXILIARY_KINDS = {'helper', 'fixture', 'driver', 'aggregate', 'included-test'}
# Keep quoted URLs intact while removing comments. Classification inspects code
# tokens separately so a source-code assertion or a comment is not a dependency.
_LEX = re.compile(r"r'''[\s\S]*?'''|r\"\"\"[\s\S]*?\"\"\"|r'[^']*'|r\"[^\"]*\"|'''[\s\S]*?'''|\"\"\"[\s\S]*?\"\"\"|'(?:\\.|[^'\\])*'|\"(?:\\.|[^\"\\])*\"|//[^\n]*|/\*[\s\S]*?\*/")
_IMPORT = re.compile(r"\b(?:import|export|part)\s+['\"]([^'\"]+)['\"]")
_MAIN = re.compile(r'^(?:void|Future(?:<void>)?)\s+main\s*\(|^main\s*\(', re.M)
_TEST = re.compile(r'\b(?:test|testWidgets|patrolTest|testGoldens)\s*\(')


class ContractError(ValueError):
    def __init__(self, errors: list[str]):
        self.errors = errors
        super().__init__('\n'.join(errors))


def load_contract(root: Path) -> dict:
    def unique_object(pairs):
        result = {}
        for key, value in pairs:
            if key in result:
                raise ContractError([f'DUPLICATE_CONFIG_KEY: {key}'])
            result[key] = value
        return result
    return json.loads((Path(root) / CONTRACT_PATH).read_text(encoding='utf-8'),
                      object_pairs_hook=unique_object)


def tracked_files(root: Path) -> list[str]:
    """Use the Git index, including explicit intent-to-add entries; never rglob."""
    return sorted(filter(None, subprocess.run(
        ['git', '-C', str(root), 'ls-files', '-z'], check=True,
        capture_output=True, text=True).stdout.split('\0')))


def _source_file(path: str) -> bool:
    p = PurePosixPath(path)
    in_roots = path.startswith(('test/', 'integration_test/', 'test_driver/'))
    return ((in_roots and p.suffix in {'.dart', '.py'}) or
            (p.suffix == '.py' and
             (p.name.startswith('test_') or p.name.endswith('_test.py'))))


def _syntax(text: str) -> tuple[str, str]:
    comments_removed = _LEX.sub(
        lambda m: ' ' if m[0].startswith(('//', '/*')) else m[0], text)
    code = _LEX.sub(lambda m: '\n' * m[0].count('\n') or ' ', text)
    return comments_removed, code


def _matches(path: str, rule: dict) -> bool:
    return path in rule.get('paths', []) or any(
        path.startswith(prefix) for prefix in rule.get('prefixes', []))


def _relative_import(root: Path, path: str, uri: str) -> str | None:
    if ':' in uri:
        return None
    resolved = (root / path).parent.joinpath(uri).resolve()
    try:
        rel = resolved.relative_to(root.resolve()).as_posix()
    except ValueError:
        return None
    return rel if rel.startswith(('test/', 'integration_test/')) else None


def _dart_facts(root: Path, path: str, sources: dict[str, str]) -> dict:
    seen, pending, imports, tokens = set(), [path], set(), []
    while pending:
        current = pending.pop()
        if current in seen or current not in sources:
            continue
        seen.add(current)
        text, code = _syntax(sources[current])
        tokens.append(code)
        for uri in _IMPORT.findall(text):
            imports.add(uri)
            rel = _relative_import(root, current, uri)
            if rel:
                pending.append(rel)
    text, own_code = _syntax(sources[path])
    code = '\n'.join(tokens)
    sqlite = any(uri.startswith(('package:sqflite_common_ffi/',
                                  'package:sqflite_common_ffi_web/',
                                  'package:sqlite3/')) for uri in imports)
    crypto = (any(uri.startswith(('package:vodozemac/',
                                  'package:flutter_vodozemac/')) for uri in imports)
              or bool(re.search(r'\bensureVodozemac\w*\b', code)))
    golden = bool(re.search(r'\b(?:matchesGoldenFile|testGoldens)\s*\(', code))
    widget = bool(re.search(r'\btestWidgets\s*\(', own_code))
    # A real API client is deliberately declared in one subtree. Its synthetic
    # safety test is an explicit override, not a broad name-based exclusion.
    backend = any(uri.endswith('api_test_client.dart') for uri in imports)
    binding = bool(re.search(r'\bIntegrationTestWidgetsFlutterBinding\s*\.\s*ensureInitialized\s*\(', code))
    patrol = bool(re.search(r'\bpatrolTest\s*\(', code))
    annotation = re.findall(r"@TestOn\(\s*['\"]([^'\"]+)['\"]\s*\)", text)
    return {'sqlite': sqlite, 'crypto': crypto, 'golden': golden,
            'widget': widget, 'backend': backend, 'device': binding,
            'patrol': patrol, 'annotations': annotation,
            'has_main': bool(_MAIN.search(own_code)),
            'has_tests': bool(_TEST.search(own_code)),
            'source_dependencies': sorted(seen - {path}),
            'imports': sorted(imports), 'code': own_code}


def _classify(root: Path, path: str, rule: dict, sources: dict[str, str]) -> dict:
    classifier = rule.get('classifier', 'support')
    if path.endswith('.py'):
        tree = ast.parse(sources[path], filename=path)
        cases = [n for n in ast.walk(tree) if isinstance(n, ast.ClassDef) and any(
            (isinstance(b, ast.Attribute) and b.attr == 'TestCase') or
            (isinstance(b, ast.Name) and b.id == 'TestCase') for b in n.bases)]
        if cases:
            return {'kind': 'test', 'suite': 'tooling', 'runner': 'python-unittest',
                    'basis': ['Python unittest.TestCase declarations']}
        if any(
                isinstance(n, (ast.FunctionDef, ast.AsyncFunctionDef)) and
                any(isinstance(d, ast.Name) and d.id == 'case' for d in n.decorator_list)
                for n in ast.walk(tree)):
            return {'kind': 'test', 'suite': 'tooling', 'runner': 'python-cases',
                    'basis': ['Existing CASES/@case contract runner']}
        if PurePosixPath(path).name == '__init__.py':
            return {'kind': 'helper', 'basis': ['Python package initializer']}
        raise ContractError([f'PYTHON_ENTRYPOINT_UNDECLARED: {path}'])
    facts = _dart_facts(root, path, sources)
    if not facts['has_main']:
        if path.endswith('_test.dart'):
            raise ContractError([f'TEST_MAIN_MISSING: {path}'])
        return {'kind': 'fixture' if '/fixtures/' in path else 'helper',
                'basis': ['Imported Dart support; no top-level main']}
    if classifier == 'support':
        raise ContractError([f'EXECUTABLE_IN_SUPPORT_RULE: {path}'])
    evidence, dependencies = [], []
    if facts['sqlite']:
        dependencies.append('sqlite-ffi')
        evidence.append('SQLite FFI import in test/fixture dependency closure')
    if facts['crypto']:
        dependencies.append('crypto-ffi')
        evidence.append('Native vodozemac initialization/import in test/fixture closure')
    if classifier == 'device-dart':
        if facts['backend'] and not facts['device'] and not facts['patrol']:
            suite = 'backend-contract'
            evidence.append('Real API client with no device binding; host backend contract')
        elif not facts['device'] and not facts['patrol']:
            raise ContractError([f'DEVICE_ENTRYPOINT_REQUIRES_REVIEW: {path}'])
        else:
            suite = 'native-ui' if facts['patrol'] else 'device-single'
            evidence.append('Patrol/native interaction' if facts['patrol'] else
                            'IntegrationTestWidgetsFlutterBinding in dependency closure')
    elif facts['device'] or facts['patrol']:
        raise ContractError([f'DEVICE_TEST_UNDER_HOST_RULE: {path}'])
    elif facts['golden']:
        suite = 'golden'
        evidence.append('matchesGoldenFile/testGoldens pixel oracle')
    elif facts['backend']:
        suite = 'backend-contract'
        evidence.append('Real API test client import; synthetic exceptions require review')
    elif facts['crypto']:
        suite = 'crypto-ffi'
    elif facts['sqlite']:
        suite = 'sqlite-ffi'
    elif path.startswith('test/unit_test/integration/'):
        suite = 'component'
        evidence.append('Existing host integration family with no device binding')
    elif re.search(r'\b(?:HttpClientAdapter|MockAdapter|adapterForTest|HttpServer)\b', facts['code']):
        suite = 'component'
        evidence.append('Mock/in-process transport dependency')
    elif facts['widget']:
        suite = 'widget'
        evidence.append('testWidgets entrypoints')
    else:
        suite = 'unit'
        evidence.append('Host Dart tests without widget/native/network requirements')
    result = {'kind': 'test', 'suite': suite, 'dependencies': dependencies,
              'basis': evidence, 'source_dependencies': facts['source_dependencies']}
    annotations = facts['annotations']
    if any(a not in {'vm', 'browser', 'chrome'} for a in annotations):
        raise ContractError([f'PLATFORM_ANNOTATION_REQUIRES_REVIEW: {path}: {annotations}'])
    if any(a in {'browser', 'chrome'} for a in annotations):
        result['platforms'] = ['web']
        result['dependencies'] = [d for d in dependencies if d != 'sqlite-ffi'] + ['chrome']
        if facts['sqlite']:
            result['dependencies'].append('sqlite-wasm')
        result['basis'].append('Explicit @TestOn browser/chrome restriction')
    return result


def _route_variants(root: Path, target: str, row: dict, files: set[str]) -> list[dict]:
    """Reuse the smoke registry, retaining one Flutter process per route.

    The final complement selects the registry/redirect assertions in the same
    test file. It also admits new non-route assertions without a second list.
    Existing quarantine cases remain selected and therefore cannot certify PASS.
    """
    spec = row['route_registry']
    registry = spec.get('path', '')
    group = spec.get('test_group', '')
    if registry not in files or not (root / registry).is_file() or not group:
        raise ContractError([f'ROUTE_REGISTRY_MISSING: {target}: {registry}'])
    registry_text, _ = _syntax((root / registry).read_text(encoding='utf-8'))
    # Exclude the constructor declaration itself (SmokeRoute({ ... })). Each
    # constructor call must retain a literal name, otherwise require review.
    constructors = re.findall(r'\bSmokeRoute\(\s*(?!\{)(?=\S)', registry_text)
    names = re.findall(r"\bSmokeRoute\(\s*name:\s*['\"]([a-z_][a-z0-9_]*)['\"]", registry_text)
    if not names or len(names) != len(set(names)) or len(names) != len(constructors):
        raise ContractError([f'ROUTE_REGISTRY_REQUIRES_REVIEW: {registry}'])
    source_text, _ = _syntax((root / target).read_text(encoding='utf-8'))
    if not re.search(r"\bgroup\(\s*['\"]" + re.escape(group) + r"['\"]", source_text):
        raise ContractError([f'ROUTE_TEST_GROUP_CHANGED: {target}'])
    variants = [{'variant': 'route:' + name,
                 'test_name': r'(^| )' + re.escape(name) + r' \(|\[quarantine\] ' + re.escape(name) + ' —'}
                for name in sorted(names)]
    variants.append({'variant': 'non-route-contracts',
                     'test_name': '^(?!.*' + re.escape(group) + ' ).*$'})
    return variants


def _config_errors(root: Path, cfg: dict, files: set[str]) -> list[str]:
    errors = []
    if cfg.get('schema_version') != SCHEMA_VERSION:
        errors.append('UNSUPPORTED_EXECUTION_CONTRACT_SCHEMA')
    if cfg.get('product_artifacts'):
        from .execution_adapters import PRODUCT_ARTIFACTS
        if set(cfg['product_artifacts']) != set(PRODUCT_ARTIFACTS):
            errors.append('PRODUCT_ARTIFACT_SET_INVALID')
    rule_ids = [r.get('id') for r in cfg.get('rules', [])]
    if len(rule_ids) != len(set(rule_ids)) or None in rule_ids:
        errors.append('RULE_IDS_MUST_BE_UNIQUE')
    entrypoints = {}
    for name, runner in cfg.get('runners', {}).items():
        if name not in RUNNERS or not runner.get('entrypoint') or not (
                root / runner.get('entrypoint', '')).is_file():
            errors.append(f'RUNNER_ENTRYPOINT_MISSING: {name}')
        else:
            path = runner['entrypoint']
            if path not in entrypoints:
                try:
                    tree = ast.parse((root / path).read_text(encoding='utf-8'))
                    entrypoints[path] = {node.name for node in tree.body
                                         if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef))}
                except (SyntaxError, UnicodeError):
                    entrypoints[path] = set()
            if runner.get('callable') not in entrypoints[path]:
                errors.append(f'RUNNER_CALLABLE_MISSING: {name}: {runner.get("callable")}')
        if runner.get('adapter') != name:
            errors.append(f'RUNNER_ADAPTER_MISMATCH: {name}')
    for name, suite in cfg.get('suites', {}).items():
        if suite.get('runner') not in cfg.get('runners', {}):
            errors.append(f'SUITE_RUNNER_MISSING: {name}')
        if not suite.get('platforms') or not suite.get('products'):
            errors.append(f'SUITE_MATRIX_MISSING: {name}')
    for rule in cfg.get('rules', []):
        if rule.get('classifier', 'support') not in CLASSIFIERS:
            errors.append(f'UNKNOWN_CLASSIFIER: {rule.get("id")}')
        if rule.get('suite') and rule['suite'] not in cfg.get('suites', {}):
            errors.append(f'UNKNOWN_RULE_SUITE: {rule.get("id")}')
        for path in rule.get('paths', []):
            if path not in files or not (root / path).is_file():
                errors.append(f'DANGLING_RULE_PATH: {path}')
        for prefix in rule.get('prefixes', []):
            if not prefix.endswith('/') or prefix.startswith('/') or '..' in prefix.split('/'):
                errors.append(f'INVALID_RULE_PREFIX: {prefix}')
    for path, override in cfg.get('overrides', {}).items():
        if path not in files or not (root / path).is_file():
            errors.append(f'DANGLING_OVERRIDE: {path}')
        if not override.get('basis'):
            errors.append(f'OVERRIDE_BASIS_MISSING: {path}')
        if 'disabled' in override or 'enabled' in override or 'safe_to_execute' in override:
            errors.append(f'DISABLED_OWNERSHIP_NOT_ALLOWED: {path}')
    for profile, spec in cfg.get('profiles', {}).items():
        for suite in spec.get('suites', []):
            if suite != '*' and suite not in cfg.get('suites', {}):
                errors.append(f'UNKNOWN_PROFILE_SUITE: {profile}: {suite}')
        for platform in spec.get('platforms', []):
            if platform != '*' and platform not in cfg.get('platforms', []):
                errors.append(f'UNKNOWN_PROFILE_PLATFORM: {profile}: {platform}')
        for product in spec.get('products', []):
            if product != '*' and product not in cfg.get('products', {}):
                errors.append(f'UNKNOWN_PROFILE_PRODUCT: {profile}: {product}')
    return errors


def _pair_contract_errors(targets: list[dict]) -> list[str]:
    """Validate declared topology with the same adapter used for execution.

    Synthetic device identifiers exercise only its pure shape validator. This
    does not probe a device, credentials, a backend, or claim a runtime PASS.
    """
    from .execution_adapters import PAIR_TARGETS, pair_environment_errors
    errors, groups = [], {}
    for target in targets:
        path = target['target']
        paired = target.get('suite') == 'device-pair' or target.get('runner') == 'device-pair'
        if path in PAIR_TARGETS and not paired:
            errors.append(f'PAIR_TARGET_OWNED_BY_SINGLE_RUNNER: {path}')
        if not paired:
            continue
        if target.get('suite') != 'device-pair' or target.get('runner') != 'device-pair':
            errors.append(f'PAIR_RUNNER_MISMATCH: {path}')
        if not target.get('roles'):
            errors.append(f'PAIR_ROLES_MISSING: {path}')
        method = target.get('orchestration')
        if method not in set(PAIR_TARGETS.values()):
            errors.append(f'PAIR_ORCHESTRATION_MISSING: {path}')
            continue
        if path in PAIR_TARGETS and method != PAIR_TARGETS[path]:
            errors.append(f'PAIR_ORCHESTRATION_MISMATCH: {path}')
        if method in {'dnd-fixture', 'legacy-fixture'} and (
                not target.get('external_roles') or any(
                    not all(role.get(key) for key in ('role', 'driver_env', 'checksum_env'))
                    for role in target['external_roles'])):
            errors.append(f'PAIR_EXTERNAL_ROLE_CONTRACT_MISSING: {path}')
        for role in target.get('roles', []):
            role = {'role': role} if isinstance(role, str) else role
            for platform in role.get('platforms', target['platforms']):
                for product in target['products']:
                    for variant in target.get('variants', [{'variant': 'default'}]):
                        key = (target['pair_group'], product, variant['variant'])
                        item = {**target, **role, **variant, 'platform': platform,
                                'product_profile': product,
                                'device_id': 'static-fixture:' + platform + ':' + str(role.get('device_role') or role['role'])}
                        groups.setdefault(key, []).append(item)
    for key, group in groups.items():
        synthetic_env = {'TEST_GROUP_ID': '1'}
        accounts = sorted({str(item.get('account_role') or item['role']) for item in group})
        for number, role in enumerate(accounts, 1):
            synthetic_env['IMBOY_' + role.upper().replace('-', '_') + '_TEST_EXPECTED_UID'] = str(number)
        errors.extend(f'PAIR_TOPOLOGY_INVALID: {key}: {error}'
                      for error in pair_environment_errors(group, synthetic_env))
    return errors


def build_catalog(root: Path, contract: dict | None = None,
                  tracked_files: list[str] | None = None) -> dict:
    root = Path(root)
    cfg = contract if contract is not None else load_contract(root)
    files = set(tracked_files if tracked_files is not None else globals()['tracked_files'](root))
    discovered = sorted(f for f in files if _source_file(f))
    sources = {f: (root / f).read_text(encoding='utf-8')
               for f in discovered if (root / f).is_file()}
    errors = _config_errors(root, cfg, files)
    entries = []
    for path in discovered:
        rules = [r for r in cfg.get('rules', []) if _matches(path, r)]
        override = cfg.get('overrides', {}).get(path, {})
        entry = {'target': path, 'kind': 'unassigned', 'rule': None}
        if path not in sources:
            errors.append(f'TRACKED_TARGET_MISSING: {path}')
        elif len(rules) > 1:
            errors.append(f'MULTIPLE_PRIMARY_OWNERS: {path}: ' + ','.join(r['id'] for r in rules))
        elif not rules and not override:
            errors.append(f'UNASSIGNED_TEST_SOURCE: {path}')
        else:
            rule = rules[0] if rules else {'id': 'explicit-override'}
            try:
                if override.get('kind') in AUXILIARY_KINDS:
                    row = copy.deepcopy(override)
                    if path.endswith('.dart'):
                        _, own_code = _syntax(sources[path])
                        reviewed_utility = (row['kind'] == 'driver' and row.get('non_asserting_utility') is True
                            and row.get('reviewed_source_sha256') == hashlib.sha256(sources[path].encode()).hexdigest()
                            and not re.search(r'\b(?:expect|expectLater|assert)\s*\(', own_code))
                        if row['kind'] in {'helper', 'fixture', 'driver'} and _TEST.search(own_code) and not reviewed_utility:
                            raise ContractError([f'EXECUTABLE_MISCLASSIFIED_AS_SUPPORT: {path}'])
                elif override.get('suite'):
                    row = {'kind': 'test', **copy.deepcopy(override)}
                    if path.endswith('.dart') and not _MAIN.search(_syntax(sources[path])[1]):
                        raise ContractError([f'TEST_MAIN_MISSING: {path}'])
                else:
                    if (rule.get('review_prefixes') and any(path.startswith(p) for p in rule['review_prefixes'])
                            and _MAIN.search(_syntax(sources[path])[1]) and not override.get('basis')):
                        raise ContractError([f'SPECIALIST_TOPOLOGY_REQUIRES_REVIEW: {path}'])
                    row = _classify(root, path, rule, sources)
                    row.update(copy.deepcopy(override))
                row['suite'] = override.get('suite', rule.get('suite', row.get('suite')))
                if row['kind'] == 'test':
                    suite_name = row.get('suite')
                    suite = cfg.get('suites', {}).get(suite_name)
                    if suite is None:
                        raise ContractError([f'UNKNOWN_TARGET_SUITE: {path}: {suite_name}'])
                    # Dependency overrides are deliberate, evidence-backed exceptions.
                    row['dependencies'] = sorted(set(
                        suite.get('dependencies', []) + row.get('dependencies', [])))
                    row = {**copy.deepcopy(suite), **row}
                    if row.get('runner') not in cfg.get('runners', {}):
                        raise ContractError([f'TARGET_RUNNER_MISSING: {path}'])
                    if row['runner'] in {'flutter-device', 'device-pair', 'patrol'}:
                        from .execution_adapters import needs_backend
                        if needs_backend(row):
                            row['dependencies'] = sorted(set(row['dependencies']) |
                                                         {'isolated-backend', 'isolated-accounts'})
                    if row.get('product_independent') and not row['runner'].startswith('python-'):
                        facts = _dart_facts(root, path, sources) if path.endswith('.dart') else {}
                        reviewed_native = (row['runner'] in {'flutter-device', 'device-pair', 'patrol'}
                            and row.get('offline') is True
                            and row.get('reviewed_source_sha256') == hashlib.sha256(sources[path].encode()).hexdigest()
                            and not facts.get('backend')
                            and not any(uri.endswith(('/main.dart', '/app_launcher.dart'))
                                        or 'generated_product_feature' in uri
                                        for uri in facts.get('imports', [])))
                        if not reviewed_native:
                            raise ContractError([f'PRODUCT_INDEPENDENCE_REQUIRES_REVIEWED_OFFLINE_NATIVE_OR_TOOLING: {path}'])
                    for p in row.get('platforms', []):
                        if p not in cfg.get('platforms', []):
                            raise ContractError([f'UNKNOWN_TARGET_PLATFORM: {path}: {p}'])
                    for p in row.get('products', []):
                        if p not in cfg.get('products', {}):
                            raise ContractError([f'UNKNOWN_TARGET_PRODUCT: {path}: {p}'])
                    if not row.get('platforms') or not row.get('products'):
                        raise ContractError([f'EMPTY_TARGET_MATRIX: {path}'])
                    roles = row.get('roles', [{'role': 'primary'}])
                    roles = [{'role': role} if isinstance(role, str) else role for role in roles]
                    role_names = [role.get('role') for role in roles]
                    if not roles or not all(role_names) or len(role_names) != len(set(role_names)):
                        raise ContractError([f'INVALID_TARGET_ROLES: {path}'])
                    for role in roles:
                        allowed = role.get('platforms', row['platforms'])
                        if not allowed or set(allowed) - set(row['platforms']):
                            raise ContractError([f'INVALID_ROLE_PLATFORMS: {path}: {role["role"]}'])
                    if row.get('runner') == 'device-pair' and not row.get('pair_group'):
                        raise ContractError([f'PAIR_METADATA_MISSING: {path}'])
                    if row.get('route_registry'):
                        if row.get('suite') != 'route-smoke' or row.get('variants'):
                            raise ContractError([f'ROUTE_VARIANT_CONTRACT_INVALID: {path}'])
                        row['variants'] = _route_variants(root, path, row, files)
                        row['process_isolation'] = 'variant'
                    variants = row.get('variants', [{'variant': 'default'}])
                    variant_names = [variant.get('variant') for variant in variants]
                    if not variants or not all(variant_names) or len(variant_names) != len(set(variant_names)):
                        raise ContractError([f'INVALID_TARGET_VARIANTS: {path}'])
                entry.update(row, rule=rule['id'], source_sha256=hashlib.sha256(
                    sources[path].encode()).hexdigest())
            except (ContractError, SyntaxError) as error:
                errors.extend(error.errors if isinstance(error, ContractError) else [str(error)])
        entries.append(entry)
    by_path = {e['target']: e for e in entries}
    targets = [e for e in entries if e['kind'] == 'test']
    errors.extend(_pair_contract_errors(targets))
    for entry in entries:
        for reference in entry.get('included_by', []) + entry.get('members', []):
            if reference not in by_path or by_path[reference]['kind'] != 'test':
                errors.append(f'AUXILIARY_TARGET_REFERENCE_MISSING: {entry["target"]}: {reference}')
        if entry['kind'] == 'included-test' and not entry.get('included_by'):
            errors.append(f'INCLUDED_TEST_HAS_NO_EXECUTABLE_OWNER: {entry["target"]}')
    for profile, spec in cfg.get('profiles', {}).items():
        for target in spec.get('targets', []):
            if target not in by_path or by_path[target]['kind'] != 'test':
                errors.append(f'UNKNOWN_PROFILE_TARGET: {profile}: {target}')
    kinds = Counter(e['kind'] for e in entries)
    suites = Counter(e['suite'] for e in targets)
    return {'schema_version': SCHEMA_VERSION, 'commit': git_head(root),
            'discovery': 'git ls-files; Dart/Python under test/, integration_test/, test_driver/; named Python tests elsewhere',
            'entries': entries, 'targets': targets, 'errors': sorted(set(errors)),
            'counts': {'discovered_files': len(entries), 'assigned_targets': len(targets),
                       'auxiliary_files': sum(kinds[k] for k in AUXILIARY_KINDS),
                       'unassigned_files': kinds['unassigned'],
                       'by_kind': dict(sorted(kinds.items())), 'by_suite': dict(sorted(suites.items()))}}


def validate_catalog(root: Path, contract: dict | None = None,
                     tracked_files: list[str] | None = None) -> dict:
    catalog = build_catalog(root, contract, tracked_files)
    if catalog['errors']:
        raise ContractError(catalog['errors'])
    return catalog


def _values(values: list[str], all_values) -> set[str]:
    return set(all_values if '*' in values else values)


def instance_id(target: str, platform: str, product: str,
                role: str = 'primary', variant: str = 'default') -> str:
    """Identity retains all execution dimensions, never just the file path."""
    return json.dumps([target, platform, product, role, variant], ensure_ascii=False,
                      separators=(',', ':'))


def build_plan(root: Path, profile: str = 'pr', platforms: list[str] | None = None,
               products: list[str] | None = None, suites: list[str] | None = None,
               targets: list[str] | None = None, variants: list[str] | None = None,
               contract: dict | None = None,
               coverage: bool = False, tracked_files: list[str] | None = None) -> dict:
    root = Path(root)
    cfg = contract if contract is not None else load_contract(root)
    catalog = validate_catalog(root, cfg, tracked_files)
    if profile not in cfg['profiles']:
        raise ContractError([f'UNKNOWN_EXECUTION_PROFILE: {profile}'])
    spec = cfg['profiles'][profile]
    profile_platforms = _values(spec.get('platforms', ['*']), cfg['platforms'])
    profile_products = _values(spec.get('products', ['*']), cfg['products'])
    wanted_platforms = set(platforms) if platforms is not None else profile_platforms
    wanted_products = set(products) if products is not None else profile_products
    known_targets = {e['target'] for e in catalog['targets']}
    known_variants = {v['variant'] for e in catalog['targets']
                      for v in e.get('variants', [{'variant': 'default'}])}
    for label, values, allowed in (
            ('PLATFORM', wanted_platforms, set(cfg['platforms'])),
            ('PRODUCT', wanted_products, set(cfg['products'])),
            ('SUITE', set(suites or []), set(cfg['suites'])),
            ('TARGET', set(targets or []), known_targets),
            ('VARIANT', set(variants or []), known_variants)):
        if values - allowed:
            raise ContractError([f'UNKNOWN_SELECTED_{label}: {value}' for value in sorted(values - allowed)])
    profile_suites = _values(spec.get('suites', []), cfg['suites'])
    instances = []
    for target in catalog['targets']:
        in_profile = (target['suite'] in profile_suites or
                      target['target'] in spec.get('targets', []) or
                      any(target['target'].startswith(p) for p in spec.get('prefixes', [])))
        in_filter = ((suites is None or target['suite'] in suites) and
                     (targets is None or target['target'] in targets))
        roles = target.get('roles', [{'role': 'primary'}])
        if roles and isinstance(roles[0], str):
            roles = [{'role': role} for role in roles]
        target_variants = target.get('variants', [{'variant': 'default'}])
        for role in roles:
            applicable_platforms = role.get('platforms', target['platforms'])
            # Keep applicable obligations even when the caller filters to another
            # platform; add N/A rows to explain the requested platform accurately.
            matrix_platforms = sorted(set(applicable_platforms) | wanted_platforms)
            for platform in matrix_platforms:
                for product in target['products']:
                    for variant in target_variants:
                        applicable = platform in applicable_platforms
                        selected = (applicable and in_profile and in_filter and
                                    platform in wanted_platforms and product in wanted_products and
                                    (variants is None or variant['variant'] in variants))
                        reason = ('PLATFORM_NA' if not applicable else
                                  None if selected else 'OUT_OF_SCOPE')
                        row = {**copy.deepcopy(target), **copy.deepcopy(role),
                               **copy.deepcopy(variant), 'commit': catalog['commit'],
                               'profile': profile, 'platform': platform,
                               'product_profile': product, 'role': role.get('role', 'primary'),
                               'variant': variant.get('variant', 'default'),
                               'applicable': applicable,
                               'required': (selected or (applicable and in_profile and platform in profile_platforms
                                                         and product in profile_products)),
                               'selected': selected, 'reason_code': reason,
                               'status': 'PLANNED' if selected else
                               'NOT_APPLICABLE' if not applicable else 'NOT_SELECTED',
                               'upstream': list(spec.get('gates', [])),
                               'coverage': coverage and bool(target.get('coverage', False)),
                               'coverage_eligible': bool(target.get('coverage', False)),
                               'product_contract': ({'manifest_profile': 'any', 'product_independent': True}
                                   if target.get('product_independent') else copy.deepcopy(cfg['products'][product]))}
                        row['dart_defines'] = {**cfg['products'][product].get('dart_defines', {}),
                                               **target.get('dart_defines', {}),
                                               **role.get('dart_defines', {}),
                                               **variant.get('dart_defines', {})}
                        row['id'] = instance_id(row['target'], platform, product,
                                                row['role'], row['variant'])
                        instances.append(row)
    # A platform/target selector chooses a paired topology, never just one
    # unexecutable half. Separate same-platform topologies remain independent.
    def pair_key(row):
        platform = row['platform'] if row.get('pair_topology') == 'same-platform' else None
        return row.get('pair_group'), row['product_profile'], row['variant'], platform

    selected_pairs = {pair_key(row) for row in instances
                      if row['selected'] and row['runner'] == 'device-pair'}
    for row in instances:
        row['selected_via'] = 'profile' if row['selected'] else None
        if (not row['selected'] and row['applicable'] and row['runner'] == 'device-pair'
                and pair_key(row) in selected_pairs):
            row.update(selected=True, required=True, status='PLANNED', reason_code=None,
                       selected_via='pair-companion')
    ids = [i['id'] for i in instances]
    if len(ids) != len(set(ids)):
        raise ContractError(['DUPLICATE_EXECUTION_INSTANCE'])
    selected = [i for i in instances if i['selected']]
    if not selected:
        raise ContractError(['EMPTY_EXECUTION_PLAN'])
    scoped = any(value is not None for value in (platforms, products, suites, targets, variants))
    # HEAD alone does not identify an uncommitted implementation. Bind plans to
    # tracked runtime inputs as well; ordinary evidence/log output is excluded.
    diff = subprocess.run(
        ['git', '-C', str(root), 'diff', '--binary', 'HEAD', '--',
         'lib', 'scripts', 'test', 'integration_test', 'test_driver', 'tool',
         '.github', 'android', 'ios', 'macos', 'linux', 'windows', 'web',
         'pubspec.yaml', 'pubspec.lock',
         *[':(exclude)' + path for path in cfg.get('product_artifacts', [])]],
        capture_output=True).stdout
    digest = hashlib.sha256(json.dumps({'contract': cfg, 'entries': catalog['entries']},
                                     sort_keys=True).encode() + diff).hexdigest()
    return {'schema_version': SCHEMA_VERSION, 'commit': catalog['commit'],
            'profile': profile, 'scope': 'scoped' if scoped else profile,
            'full_regression': profile == 'full' and not scoped,
            'product_artifacts': cfg.get('product_artifacts', []),
            'product_artifact_validation': 'existing-generator-read-only-render; fingerprints required per attempt',
            'source_fingerprint': digest, 'contract_path': CONTRACT_PATH,
            'selectors': {'platforms': platforms, 'products': products,
                          'suites': suites, 'targets': targets, 'variants': variants,
                          'coverage': coverage},
            'instances': instances, 'gates': list(spec.get('gates', [])),
            'counts': {**catalog['counts'], 'instances': len(instances),
                       'selected_instances': len(selected),
                       'selected_targets': len({i['target'] for i in selected})},
            'errors': []}


def migration_report(catalog: dict, plan: dict, contract: dict) -> dict:
    """Compare selectors, never claim the historical selection actually ran."""
    prior = contract.get('legacy_selection', {})
    selected = {i['target'] for i in plan['instances'] if i['selected']}
    rows = []
    for target in catalog['targets']:
        path = target['target']
        old_main = path.startswith('test/unit_test/') and path.endswith('_test.dart') and not (
            any(path.startswith(p) for p in prior.get('excluded_prefixes', [])) or
            path in prior.get('excluded_targets', []))
        old_coverage = path.startswith('test/unit_test/') and path.endswith('_test.dart')
        current = path in selected
        rows.append({'target': path, 'suite': target['suite'], 'previous_main_selected': old_main,
                     'previous_coverage_selected': old_coverage, 'current_pr_selected': current,
                     'change': 'newly-selected' if current and not old_main else
                     'moved-to-specialist' if old_main and not current else 'retained' if current else
                     'specialist-owned'})
    return {'baseline_commit': prior.get('commit'), 'scope': 'selector comparison, not execution proof',
            'counts': dict(Counter(r['change'] for r in rows)), 'targets': rows}


def render_catalog_markdown(catalog: dict, plan: dict | None = None,
                            contract: dict | None = None) -> str:
    counts = catalog['counts']
    lines = ['# Test execution ownership / 测试执行归属', '',
             f"Commit: `{catalog['commit']}`", '',
             'This inventory proves ownership only; it is not a business-test PASS.', '',
             f"Source files: {counts['discovered_files']}; executable targets: {counts['assigned_targets']}; "
             f"helpers/fixtures/drivers/aggregates: {counts['auxiliary_files']}; unassigned: {counts['unassigned_files']}.", '',
             '| Suite | Targets |', '|---|---:|']
    lines += [f'| {s} | {n} |' for s, n in counts['by_suite'].items()]
    migration = migration_report(catalog, plan, contract) if plan and contract else None
    changes = {r['target']: r['change'] for r in migration['targets']} if migration else {}
    if migration:
        lines += ['', f"Compared with selector at `{migration['baseline_commit']}`: " +
                  ', '.join(f'{k}={v}' for k, v in sorted(migration['counts'].items())), '']
    lines += ['', '| File | Kind / suite | Platforms | Rule / reason | Selector change |',
              '|---|---|---|---|---|']
    for row in catalog['entries']:
        lines.append(f"| `{row['target']}` | {row.get('suite') or row['kind']} | "
                     f"{', '.join(row.get('platforms', []))} | {row.get('rule')} / "
                     f"{'; '.join(row.get('basis', [])).replace('|', '/')} | {changes.get(row['target'], '')} |")
    if catalog['errors']:
        lines += ['', '## Errors', ''] + ['- ' + error for error in catalog['errors']]
    return '\n'.join(lines) + '\n'

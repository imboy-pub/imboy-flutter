"""Execute the shared catalog plan and reconcile structured per-instance evidence.

``executed`` includes skips; ``actually_run`` excludes them. Workers never alter
selection in the saved plan. Only the final reconciler can certify that every
selected instance and prerequisite has a matching successful receipt.
"""
from __future__ import annotations

import contextlib
import ctypes.util
import hashlib
import importlib.util
import io
import json
import os
import re
import shutil
import signal
import subprocess
import sys
import tempfile
import time
import unittest
from collections import Counter, defaultdict
from pathlib import Path
from urllib.parse import unquote, urlparse

from .machine_events import parse_machine_events
from .result import classify_attempts, overall_exit_code

IDENTITY = ('id', 'commit', 'profile', 'suite', 'target', 'platform',
            'product_profile', 'role', 'variant', 'selected')
GOOD_UPSTREAM = {'PASS', 'success', 'passed'}
COUNT_KEYS = ('passed', 'failed', 'skipped', 'executed', 'actually_run')
HOST_BATCH_MAX_TARGETS = 64


def _write_json(path, value):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(path.name + f'.tmp.{os.getpid()}')
    tmp.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    tmp.replace(path)


def _base(plan, instance, status=None, reason=None):
    row = {key: instance.get(key, plan.get(key)) for key in IDENTITY}
    row.update(status=status or instance.get('status', 'PLANNED'), reason_code=reason,
               upstream=list(instance.get('upstream', [])), counts=dict.fromkeys(COUNT_KEYS, 0),
               logs=[], evidence=[], attempts=[], source_fingerprint=plan.get('source_fingerprint'),
               product_contract=instance.get('product_contract', {}))
    return row


def _upstream_failures(names, upstream):
    return [{'dependency': name, 'status': (upstream or {}).get(name, 'MISSING')}
            for name in names if (upstream or {}).get(name, 'MISSING') not in GOOD_UPSTREAM]


def _counts(parsed):
    executed, skipped, failed = (int(parsed.get(key, 0)) for key in ('executed', 'skipped', 'failed'))
    return dict(passed=max(0, executed - skipped - failed), failed=failed, skipped=skipped,
                executed=executed, actually_run=max(0, executed - skipped))


def _verdict(attempts):
    verdict = classify_attempts(attempts)
    if verdict['test_status'] in ('PASS', 'FLAKY', 'PASS_WITH_SKIPS'):
        # The parser's cached exit code and the process receipt are independent
        # fields. Both must exist and agree; checking just the parsed claim lets
        # a crash be hidden by an otherwise successful machine stream.
        for attempt in attempts:
            parsed = attempt.get('parsed', {})
            code = attempt.get('process_exit_code')
            if (type(code) is not int or type(parsed.get('process_exit_code')) is not int or
                    not all(isinstance(attempt.get(key), str) and attempt[key].strip()
                            for key in ('log', 'evidence', 'process_receipt')) or
                    not all(isinstance(attempt.get(key), str) and
                            re.fullmatch(r'[a-f0-9]{64}', attempt[key])
                            for key in ('log_sha256', 'evidence_sha256', 'process_receipt_sha256')) or
                    not isinstance(attempt.get('command'), list) or not attempt['command'] or
                    not all(isinstance(arg, str) and arg for arg in attempt['command'])):
                return dict(verdict, test_status='BLOCKED', reason_code='INCOMPLETE_EVIDENCE')
            if code != parsed['process_exit_code']:
                return dict(verdict, test_status='BLOCKED', reason_code='PROCESS_RECEIPT_MISMATCH')
        parsed = attempts[-1]['parsed']
        if (parsed.get('process_exit_code') != 0 or not parsed.get('done_event_seen') or
                any(type(parsed.get(key)) is not int or parsed[key] < 0
                    for key in ('executed', 'skipped', 'failed')) or
                parsed.get('executed', 0) <= 0 or parsed.get('failed', 0) or
                parsed.get('skipped', 0) > parsed.get('executed', 0) or
                parsed.get('invalid_events', 0)):
            verdict.update(test_status='BLOCKED', reason_code='INCOMPLETE_EVIDENCE')
        elif parsed.get('skipped', 0):
            verdict.update(test_status='BLOCKED', reason_code='UNEXPECTED_SKIP')
        elif any(a.get('execution_errors') for a in attempts):
            reason = next(a['execution_errors'][0] for a in attempts if a.get('execution_errors'))
            verdict.update(test_status='BLOCKED', reason_code=reason)
    if verdict['test_status'] == 'PASS_WITH_SKIPS' or verdict.get('reason_code') == 'ALL_SKIPPED':
        verdict.update(test_status='BLOCKED', reason_code='UNEXPECTED_SKIP')
    return verdict


def _worker_instances(plan, worker_platform=None, worker_suites=None, worker_product_profile=None,
                      *, coverage_only=False):
    suites = set(worker_suites or [])
    products = ({worker_product_profile} if isinstance(worker_product_profile, str)
                else set(worker_product_profile or []))
    return [i for i in plan.get('instances', []) if i.get('selected')
            and (worker_platform is None or i.get('platform') == worker_platform)
            and (not suites or i.get('suite') in suites)
            and (not products or i.get('product_profile') in products)
            and (not coverage_only or i.get('coverage_eligible', i.get('coverage')))]


def host_worker_matrix(plan, coverage_platform='linux'):
    """Partition VM and browser obligations without rediscovering targets."""
    selected = _worker_instances(plan)
    if not selected:
        raise ValueError('EMPTY_PLAN: host workers require selected execution instances')
    if len(selected) != len({i['id'] for i in selected}):
        raise ValueError('DUPLICATE_EXECUTION_INSTANCE')
    operating_systems = {'linux': 'ubuntu-latest', 'macos': 'macos-latest',
                         'web': 'ubuntu-latest'}
    host_runners = {'flutter-machine', 'python-unittest', 'python-cases', 'python-recovery'}
    for item in selected:
        if (item.get('platform') not in operating_systems or _runner_name(item) not in host_runners
                or (item.get('platform') == 'web' and _runner_name(item) != 'flutter-machine')):
            raise ValueError(f'HOST_WORKER_UNSUPPORTED: {item["id"]}; use its declared specialist orchestrator')
    workers = []
    for platform, suite in sorted({(i['platform'], i['suite']) for i in selected}):
        instances = _worker_instances(plan, platform, [suite])
        covered = platform == coverage_platform and any(
            i.get('coverage_eligible', i.get('coverage')) for i in instances)
        workers.append({'os': operating_systems[platform], 'platform': platform, 'suite': suite,
                        'coverage': '--coverage' if covered else ''})
    return {'include': workers}


def _instance_upstream(plan, instance, upstream, require_gates):
    names = list(instance.get('upstream', []))
    if not require_gates:
        names = [n for n in names if n not in plan.get('gates', []) or n in (upstream or {})]
    # Explicit worker dependency failures are never deferred with common gates.
    names += list(upstream or {})
    return _upstream_failures(dict.fromkeys(names), upstream)


def _missing_product_evidence(instance, row):
    if row.get('status') not in ('PASS', 'FLAKY', 'PASS_WITH_SKIPS'):
        return False
    contract = instance.get('product_contract') or {}
    profile = contract.get('manifest_profile') or instance.get('product_profile')
    if profile in (None, '', 'current', 'any', 'all', 'host', 'default') and not (
            contract.get('required_features') or instance.get('required_features')):
        return False
    evidence = row.get('product_artifact') or {}
    return (bool(evidence.get('errors')) or not evidence.get('fingerprint') or
            evidence.get('manifest_profile') != profile or not evidence.get('validation') or
            not evidence.get('artifacts') or
            any(a.get('product_artifact') != evidence for a in row.get('attempts', [])))


def _companion_issue(instance, row):
    method = instance.get('orchestration')
    required = (method in ('mc-owned-coordinator', 'legacy-fixture', 'sqlite-kill-replay') or
                (method == 'dnd-fixture' and instance.get('role') == 'receiver'))
    companion = row.get('companion_evidence')
    if not companion:
        return 'MISSING_COMPANION_EVIDENCE' if required else None
    if not isinstance(companion, dict) or companion.get('status') != 'PASS':
        return 'UPSTREAM_FAILED'
    if method == 'sqlite-kill-replay':
        phases = companion.get('phases') or {}
        if (companion.get('kind') != 'kill-replay-gate'
                or companion.get('instance_id') != instance['id']
                or set(phases) != {'prepare', 'pid_before', 'force_stop', 'pid_after', 'verify'}
                or not all(isinstance(value, dict) and value.get('path') and
                           re.fullmatch(r'[a-f0-9]{64}', str(value.get('sha256', '')))
                           for value in [*phases.values(), companion.get('observations', {}),
                                         companion.get('receipt', {}), companion.get('ready_evidence', {})])):
            return 'INCOMPLETE_COMPANION_EVIDENCE'
        return None
    if companion.get('kind') == 'coordinator-gate':
        # Phase semantics and downloaded files are verified by the existing
        # adapter and CLI resolver. Here require a complete portable receipt.
        if type(companion.get('exit_code')) is not int or companion['exit_code'] != 0:
            return 'UPSTREAM_FAILED'
        hashes = companion.get('hashes') or {}
        if (not isinstance(companion.get('command'), list) or not companion['command'] or
                not all(isinstance(arg, str) and arg for arg in companion['command']) or
                not companion.get('mode') or not re.fullmatch(r'[a-f0-9]{64}', str(companion.get('context_sha256', ''))) or
                not all(isinstance(companion.get(key), str) and companion[key].strip() and
                        re.fullmatch(r'[a-f0-9]{64}', str(hashes.get(key, '')))
                        for key in ('log', 'evidence', 'process_receipt'))):
            return 'INCOMPLETE_COMPANION_EVIDENCE'
        return None
    return None if _verdict(companion.get('attempts', []))['test_status'] == 'PASS' else 'UPSTREAM_FAILED'


def reconcile(plan, results, upstream=None, *, worker_platform=None, worker_suites=None,
              worker_product_profile=None, require_gates=True, coverage_only=False):
    """Reconcile a complete plan (or explicitly named worker) without path dedup.

    No disk writes occur here. Missing, duplicate, stale, unexpected, or unsupported
    successful receipts are failures of evidence, never successful business tests.
    ``require_gates=False`` is only for a worker; final summaries use the default.
    """
    expected = _worker_instances(plan, worker_platform, worker_suites, worker_product_profile,
                                 coverage_only=coverage_only)
    is_worker = bool(worker_platform or worker_suites or worker_product_profile or coverage_only)
    declared = {i.get('id'): i for i in plan.get('instances', [])}
    by_id, issues = defaultdict(list), []
    for row in results:
        if not isinstance(row, dict) or row.get('id') not in declared:
            issues.append('UNEXPECTED_RESULT')
        else:
            by_id[row['id']].append(row)
    rows, missing = [], []
    for instance in expected:
        found = by_id.get(instance['id'], [])
        bad_upstream = _instance_upstream(plan, instance, upstream, require_gates)
        if not found:
            missing.append(instance['id'])
            row = _base(plan, instance, 'BLOCKED', 'UPSTREAM_FAILED' if bad_upstream else 'MISSING_RESULT')
        elif len(found) != 1:
            row = _base(plan, instance, 'BLOCKED', 'DUPLICATE_RESULT')
        else:
            row = dict(found[0])
            if any(row.get(key) != instance.get(key, plan.get(key)) for key in IDENTITY):
                row = _base(plan, instance, 'BLOCKED', 'RESULT_IDENTITY_MISMATCH')
            elif row.get('source_fingerprint') != plan.get('source_fingerprint'):
                row = _base(plan, instance, 'BLOCKED', 'STALE_PLAN_RESULT')
            elif row.get('product_contract', {}) != instance.get('product_contract', {}):
                row = _base(plan, instance, 'BLOCKED', 'PRODUCT_CONTRACT_MISMATCH')
            elif _missing_product_evidence(instance, row):
                row = _base(plan, instance, 'BLOCKED', 'PRODUCT_EVIDENCE_MISSING')
            elif row.get('status') in ('PASS', 'FLAKY', 'PASS_WITH_SKIPS'):
                verdict = _verdict(row.get('attempts', []))
                row.update(status=verdict['test_status'], reason_code=verdict['reason_code'])
                if row['status'] in ('PASS', 'FLAKY') and (
                        row.get('logs') != [a.get('log') for a in row['attempts']] or
                        row.get('evidence') != [a.get('evidence') for a in row['attempts']]):
                    row.update(status='BLOCKED', reason_code='INCOMPLETE_EVIDENCE')
                elif row['status'] == 'PASS' and row.get('counts') != _counts(row['attempts'][-1]['parsed']):
                    row.update(status='BLOCKED', reason_code='RESULT_COUNT_MISMATCH')
                elif row['status'] == 'PASS' and _companion_issue(instance, row):
                    row.update(status='BLOCKED', reason_code=_companion_issue(instance, row))
            if bad_upstream and row.get('status') != 'FAIL':
                row.update(status='BLOCKED', reason_code='UPSTREAM_FAILED')
        if bad_upstream:
            row['upstream_failed'] = bad_upstream
        rows.append(row)
    if len(expected) != len({i['id'] for i in expected}):
        issues.append('DUPLICATE_EXECUTION_INSTANCE')
    gate_names = list(plan.get('gates', [])) if require_gates else []
    gate_failures = _upstream_failures(dict.fromkeys(gate_names + list(upstream or {})), upstream)
    verdicts = [{'test_status': r.get('status')} for r in rows]
    exit_code = overall_exit_code(verdicts)
    if issues or gate_failures:
        exit_code = exit_code or 2
    reason = ('EMPTY_PLAN' if not expected else 'INVALID_RESULT_SET' if issues else
              'UPSTREAM_FAILED' if gate_failures else 'INCOMPLETE_EXECUTION' if exit_code == 2 else
              'TEST_FAILED' if exit_code == 1 else 'NONE')
    return {'status': {0: 'PASS', 1: 'FAIL', 2: 'BLOCKED'}[exit_code], 'reason_code': reason,
            'exit_code': exit_code, 'profile': plan.get('profile'), 'commit': plan.get('commit'),
            'scope': 'worker' if is_worker else plan.get('scope', plan.get('profile')),
            'complete_regression': bool(exit_code == 0 and plan.get('full_regression') and not is_worker),
            'expected_instances': len(expected), 'reported_instances': len(rows) - len(missing),
            'missing_instances': missing, 'issues': issues, 'upstream_failed': gate_failures,
            'counts': {k: sum(r.get('counts', {}).get(k, 0) for r in rows) for k in COUNT_KEYS},
            'status_counts': dict(Counter(r.get('status') for r in rows)), 'results': rows}


def split_machine_events(root, targets, lines, aliases=None):
    """Attribute events by suite.path and test.suiteID, never test-name guessing."""
    root = Path(root).resolve()
    aliases = aliases or {}
    streams = {target: [] for target in targets}
    suites, tests, global_lines = {}, {}, []
    for raw in lines:
        try:
            event = json.loads(raw)
        except (ValueError, TypeError):
            if isinstance(raw, str) and raw.lstrip().startswith('{'):
                global_lines.append(raw)  # Truncated event is incomplete evidence.
            continue  # Flutter banners are not structured evidence.
        if not isinstance(event, dict):
            continue
        kind, target = event.get('type'), None
        if kind == 'suite':
            suite = event.get('suite', {})
            path = str(suite.get('path', ''))
            if path.startswith('file:'):
                path = unquote(urlparse(path).path)
            absolute = (root / path).resolve()
            try:
                path = absolute.relative_to(root).as_posix()
            except ValueError:
                path = str(absolute)
            target = aliases.get(path, path)
            suites[suite.get('id')] = target
        elif kind == 'testStart':
            test = event.get('test', {})
            target = suites.get(test.get('suiteID'))
            tests[test.get('id')] = target
        elif 'testID' in event:
            target = tests.get(event['testID'])
        elif kind == 'group':
            target = suites.get(event.get('group', {}).get('suiteID'))
        if target in streams:
            streams[target].append(raw)
        elif kind in ('start', 'done') or kind == 'error':
            global_lines.append(raw)
        elif kind in ('testStart', 'testDone'):
            # A visible case without a known suite cannot certify any target.
            global_lines.append(json.dumps({'type': 'error', 'message': 'Unattributed machine test event',
                                            'isFailure': False}))
    return {target: stream + global_lines for target, stream in streams.items()}


def _fingerprint(root, plan, instance):
    content = (Path(root) / instance['target']).read_bytes()
    digest = lambda value: hashlib.sha256(value).hexdigest()
    dependencies = set(instance.get('dependencies', []))
    backend = ('UNVERIFIED_SERVICE_VERSION' if dependencies & {'backend', 'isolated-backend'} else
               'UNVERIFIED_SOURCE_VERSION' if 'backend-source' in dependencies else 'NOT_USED')
    return {'app_head': str(plan.get('commit', 'unknown')), 'backend_head': backend,
            'target_sha256': digest(content), 'config_sha256': digest(json.dumps(instance, sort_keys=True).encode()),
            'fixture_fingerprint': str(plan.get('source_fingerprint') or 'synthetic'),
            'device_fingerprint': digest(f"{instance.get('platform')}:{instance.get('role')}".encode())}


def _display_command(command):
    safe_defines = {'SMOKE_INCLUDE_QUARANTINED', 'RUN_DEVICE_INTEGRATION', 'CHANNEL_ENABLED',
                    'TEST_CHANNEL_ENABLED', 'CHANNEL_FEATURE_ENABLED', 'TEST_GOLDEN',
                    'APP_ENV', 'KILL_PHASE', 'KILL_ATTEMPT'}
    display = []
    for argument in command:
        if argument.startswith('--dart-define='):
            key, _, value = argument[len('--dart-define='):].partition('=')
            display.append('--dart-define=' + key + '=' + (value if key in safe_defines else '<redacted>'))
        else:
            display.append(argument)
    return display


def _file_sha256(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def _persist_process_receipt(receipt, evidence_dir):
    """Bind the original process outcome to its saved output before adapting it."""
    payload = {key: receipt.get(key) for key in ('command', 'exit_code', 'log', 'machine', 'error')}
    for key in ('log', 'machine'):
        payload[key + '_sha256'] = _file_sha256(payload[key])
    path = Path(evidence_dir) / 'process.json'
    _write_json(path, payload)
    receipt.update(log_sha256=payload['log_sha256'], machine_sha256=payload['machine_sha256'],
                   process_receipt=str(path), process_receipt_sha256=_file_sha256(path))
    return receipt


def execute_process(command, env, evidence_dir, *, cwd=None, timeout=900, log_path=None,
                    separate_stderr=False, observer=None):
    """Keep live logs, then freeze evidence after stopping a timed-out process group."""
    evidence_dir = Path(evidence_dir)
    evidence_dir.mkdir(parents=True, exist_ok=True)
    log = Path(log_path) if log_path else evidence_dir / 'machine.jsonl'
    log.parent.mkdir(parents=True, exist_ok=True)
    error = None
    interrupted = False
    machine = evidence_dir / 'machine.jsonl' if separate_stderr else log
    if separate_stderr and log == machine:
        log = evidence_dir / 'process.log'
    with contextlib.ExitStack() as stack:
        output = stack.enter_context(machine.open('w', encoding='utf-8'))
        errors = stack.enter_context(log.open('w', encoding='utf-8')) if separate_stderr else subprocess.STDOUT
        try:
            if os.name != 'posix':
                raise OSError('PROCESS_SUPERVISION_UNAVAILABLE: a POSIX host is required for owned process groups')
            with subprocess.Popen(command, cwd=cwd, env=env, stdout=output,
                                  stderr=errors, text=True, start_new_session=True) as process:
                deadline = time.monotonic() + timeout
                while True:
                    try:
                        code = process.wait(timeout=min(0.05, timeout) if observer else timeout)
                        break
                    except subprocess.TimeoutExpired:
                        if time.monotonic() >= deadline:
                            code, error = 124, 'RUNNER_TIMEOUT'
                        elif observer:
                            try:
                                error = observer(machine)
                            except Exception as exc:
                                error = 'RUNNER_OBSERVER_FAILED:' + type(exc).__name__
                            if not error:
                                continue
                            code = 130
                        else:
                            code, error = 124, 'RUNNER_TIMEOUT'
                        # The unreaped leader pins this owned group identity.
                        with contextlib.suppress(ProcessLookupError):
                            os.killpg(process.pid, signal.SIGKILL)
                        process.wait()
                        interrupted = True
                        break
        except OSError as exc:
            code, error = 127, f'{type(exc).__name__}: {exc}'
    if interrupted:
        # A dying descendant may still hold the old stdout/stderr descriptor.
        # Atomically replace each live file with a snapshot so pending writes
        # cannot mutate the paths used by the receipt and its hashes.
        for path in {log, machine}:
            with tempfile.NamedTemporaryFile(dir=path.parent, prefix='.' + path.name + '.', delete=False) as frozen:
                snapshot = Path(frozen.name)
                frozen.write(path.read_bytes())
            try:
                snapshot.replace(path)
            finally:
                snapshot.unlink(missing_ok=True)
    receipt = {'command': _display_command(command), 'exit_code': code, 'log': str(log), 'machine': str(machine), 'error': error,
               'lines': machine.read_text(encoding='utf-8', errors='replace').splitlines()}
    return _persist_process_receipt(receipt, evidence_dir)


def _record_attempt(root, plan, instance, receipt, lines):
    parsed = parse_machine_events(lines, receipt.get('exit_code')).to_dict()
    fingerprint = _fingerprint(root, plan, instance)
    product = receipt.get('product_artifact', {})
    if product.get('fingerprint'):
        fingerprint['fixture_fingerprint'] = hashlib.sha256(
            (fingerprint['fixture_fingerprint'] + product['fingerprint']).encode()).hexdigest()
    # A batch stream cannot be reparsed as one target. Preserve exactly the
    # attributed stream so downloaded artifacts can independently reproduce it.
    evidence = Path(receipt['machine']).parent / (
        'target-' + hashlib.sha256(instance['id'].encode()).hexdigest()[:20] + '.jsonl')
    evidence.write_text('\n'.join(line.rstrip('\r\n') for line in lines) + '\n', encoding='utf-8')
    return {'fingerprint': fingerprint, 'parsed': parsed,
            'log': receipt.get('log'), 'log_sha256': receipt.get('log_sha256'),
            'evidence': str(evidence), 'evidence_sha256': _file_sha256(evidence),
            'process_receipt': receipt.get('process_receipt'),
            'process_receipt_sha256': receipt.get('process_receipt_sha256'),
            'process_exit_code': receipt.get('exit_code'),
            'command': receipt.get('command', []),
            'product_artifact': receipt.get('product_artifact', {}),
            'coverage': receipt.get('coverage'), 'coverage_sha256': receipt.get('coverage_sha256'),
            'native_evidence': receipt.get('native_evidence'),
            'native_evidence_sha256': receipt.get('native_evidence_sha256'),
            'related_evidence': receipt.get('related_evidence', []), 'execution_errors': []}


def _finish(plan, instance, attempts):
    verdict = _verdict(attempts)
    row = _base(plan, instance, verdict['test_status'], verdict['reason_code'])
    row.update(attempts=attempts, counts=_counts(attempts[-1]['parsed']),
               logs=[a['log'] for a in attempts], evidence=[a['evidence'] for a in attempts],
               product_artifact=attempts[-1].get('product_artifact', {}),
               coverage=[a['coverage'] for a in attempts if a.get('coverage')])
    return row


def _runner_name(instance):
    runner = instance.get('runner')
    return runner.get('adapter', runner.get('type')) if isinstance(runner, dict) else runner


def _process_identity_preflight(env):
    """The lock contract requires stable parent and child process start times."""
    try:
        with subprocess.Popen([sys.executable, '-c', 'import sys; sys.stdin.buffer.read(1)'],
                              stdin=subprocess.PIPE, stdout=subprocess.DEVNULL,
                              stderr=subprocess.DEVNULL, env=env) as child:
            try:
                for pid in (os.getpid(), child.pid):
                    starts = []
                    for _ in range(2):
                        query = subprocess.run(['ps', '-o', 'lstart=', '-p', str(pid)],
                                               capture_output=True, text=True, env=env, timeout=5)
                        if query.returncode != 0 or not query.stdout.strip():
                            return ['process-identity: ps cannot verify live parent/child start times; use a host with working process-table access']
                        starts.append(query.stdout.strip())
                    if starts[0] != starts[1]:
                        return ['process-identity: ps returned inconsistent live process start times']
            finally:
                child.stdin.close()
                child.wait(timeout=5)
    except (OSError, subprocess.SubprocessError):
        return ['process-identity: process-table probe unavailable; install ps and permit local child-process identity lookup']
    return []


def _default_preflight(root, instance, env):
    missing, runner = [], str(_runner_name(instance) or '')
    host_platform = {'darwin': 'macos', 'win32': 'windows'}.get(sys.platform, sys.platform)
    if runner not in ('device-pair', 'flutter-device', 'patrol') and instance.get('platform') not in (
            host_platform, 'host', 'any', 'web'):
        missing.append(f"worker-platform: {instance.get('platform')} host required; current host is {host_platform}")
    if runner.startswith('flutter') or runner in ('patrol', 'device-pair'):
        if not shutil.which('flutter', path=env.get('PATH')):
            missing.append('flutter-sdk: install the pinned Flutter SDK and expose flutter on PATH')
        if not (root / '.dart_tool/package_config.json').is_file():
            missing.append('dart-packages: run flutter pub get')
    dependencies = instance.get('dependencies', [])
    if 'backend-source' in dependencies:
        backend = Path(env.get('IMBOY_BACKEND_ROOT', root.parent / 'imboy'))
        for name in ('config/product-feature-manifest.json', 'Makefile'):
            if not (backend / name).is_file():
                missing.append('backend-source: isolated sibling backend checkout missing ' + name)
    if 'process-identity' in dependencies:
        missing.extend(_process_identity_preflight(env))
    if runner == 'flutter-machine' and 'sqlite-ffi' in dependencies and not ctypes.util.find_library('sqlite3'):
        missing.append('sqlite-ffi: host SQLite dynamic library required')
    if runner == 'flutter-machine' and 'crypto-ffi' in dependencies:
        directories = [root / '../spikes/e2ee-group/rust/target/release', root / 'spikes/e2ee-group/rust/target/release']
        if env.get('FRB_DART_LOAD_EXTERNAL_LIBRARY_NATIVE_LIB_DIR'):
            directories.insert(0, Path(env['FRB_DART_LOAD_EXTERNAL_LIBRARY_NATIVE_LIB_DIR']))
        files = {'macos': ['libvodozemac_bindings_dart.dylib'],
                 'linux': ['libvodozemac_bindings_dart.so'],
                 'windows': ['vodozemac_bindings_dart.dll']}.get(instance.get('platform'), [])
        available = any((directory / name).is_file() for directory in directories for name in files)
        config = root / '.dart_tool/package_config.json'
        if not available and instance.get('platform') == 'macos' and config.is_file():
            for package in json.loads(config.read_text()).get('packages', []):
                if package.get('name') == 'flutter_vodozemac':
                    uri = package.get('rootUri', '')
                    base = Path(unquote(urlparse(uri).path)) if uri.startswith('file:') else (config.parent / uri).resolve()
                    available = (base / 'macos/flutter_vodozemac/flutter_vodozemac.xcframework/macos-arm64_x86_64/libflutter_vodozemac.dylib').is_file()
        if not available:
            missing.append('crypto-ffi: matching vodozemac native library required (FRB_DART_LOAD_EXTERNAL_LIBRARY_NATIVE_LIB_DIR)')
    return missing


def _host_command(root, group, env, output, stack, adapters=None):
    first = group[0]
    command = ['flutter', 'test', '--machine', '--no-pub']
    aliases, paths = {}, []
    for instance in group:
        path = instance['target']
        if path.startswith('integration_test/'):
            # IntegrationTest's path convention would select a device. These
            # catalog-owned host contracts need a real host wrapper instead.
            directory = Path(stack.enter_context(tempfile.TemporaryDirectory(prefix='.execution-', dir=root / 'test')))
            wrapper = directory / 'contract_test.dart'
            wrapper.write_text("import '" + (root / path).as_uri() + "' as target;\nvoid main() => target.main();\n")
            (directory / 'flutter_test_config.dart').write_text(
                "import 'dart:async';\nFuture<void> testExecutable(FutureOr<void> Function() main) async { await main(); }\n")
            alias = wrapper.relative_to(root).as_posix()
            aliases[alias] = path
            path = alias
        paths.append(path)
    if adapters is not None:
        prepared = adapters.build_invocation(root, dict(first, target=paths[0]), env, output)
        if prepared.get('errors'):
            raise ValueError('; '.join(prepared['errors']))
        command = prepared['command']
        command[2:3] = paths
        # --name is a regexp contract; the adapter's single-target plain filter
        # is replaced here so route guard variants retain their declared scope.
        if '--plain-name' in command:
            index = command.index('--plain-name')
            del command[index:index + 2]
        process_env = prepared['env']
    else:
        command += paths
        process_env = env
    if '--no-pub' not in command:
        command.append('--no-pub')
    if all(i.get('suite') in {'unit', 'widget', 'component'} for i in group):
        # Use Flutter's existing host concurrency, as the original CI did.
        # Native FFI, backend and route groups retain the adapter's isolation.
        command = [argument for argument in command if argument != '--concurrency=1']
    if first.get('test_name'):
        command += ['--name', first['test_name']]
    for key, value in sorted((first.get('dart_defines', {}) if adapters is None else {}).items()):
        command.append(f'--dart-define={key}={str(value).lower() if isinstance(value, bool) else value}')
    if first.get('suite') == 'route-smoke' and env.get('IMBOY_SMOKE_INCLUDE_QUARANTINED') == 'true':
        command += ['--dart-define=SMOKE_INCLUDE_QUARANTINED=true']
    if first.get('platform') == 'web':
        command += ['--platform', 'chrome']
    if first.get('coverage'):
        output.mkdir(parents=True, exist_ok=True)
        command += ['--coverage', '--coverage-path', str(output / 'lcov.info')]
    return command, aliases, process_env


def _check_snapshot(root, plan):
    if not plan.get('source_fingerprint'):
        return None
    from .execution_catalog import build_plan
    current = build_plan(root, profile=plan['profile'], **plan.get('selectors', {}))
    matches = (current.get('commit') == plan.get('commit') and
               current.get('source_fingerprint') == plan['source_fingerprint'] and
               [(i['id'], i['selected']) for i in current['instances']] ==
               [(i['id'], i['selected']) for i in plan['instances']])
    return None if matches else 'STALE_PLAN'


def _target_hashes(root, instances):
    result = {}
    for target in dict.fromkeys(instance['target'] for instance in instances):
        try:
            result[target] = _file_sha256(root / target)
        except OSError:
            result[target] = None
    return result


def _execution_batches(groups):
    """Bound host process work without changing selected execution identities."""
    for group in groups:
        if not group:
            continue
        size = HOST_BATCH_MAX_TARGETS if _runner_name(group[0]) == 'flutter-machine' else len(group)
        for start in range(0, len(group), size):
            yield group[start:start + size]


def run_plan(root, plan, artifact_dir, *, env=None, worker_platform=None, coverage=False,
             upstream=None, max_infra_attempts=1, worker_suites=None, worker_product_profile=None):
    """Run one immutable plan; use reconcile on all worker results for final CI."""
    root, artifact_dir = Path(root).resolve(), Path(artifact_dir).resolve()
    artifact_dir.mkdir(parents=True, exist_ok=True)
    _write_json(artifact_dir / 'plan.json', plan)
    runtime_env = dict(os.environ if env is None else env)
    runtime_env['PYTHONPATH'] = os.pathsep.join([str(root / 'scripts'), str(root / 'test/tooling/auto_test'),
                                               runtime_env.get('PYTHONPATH', '')])
    selected = _worker_instances(plan, worker_platform, worker_suites, worker_product_profile)
    is_worker = bool(worker_platform or worker_suites or worker_product_profile)
    selected = [dict(i, coverage=bool(coverage and i.get('coverage_eligible', i.get('coverage')))) for i in selected]
    results, groups, pairs = [], defaultdict(list), defaultdict(list)
    stale = _check_snapshot(root, plan)
    initial_targets = _target_hashes(root, selected)
    try:
        from . import execution_adapters as adapters
    except ImportError:
        adapters = None

    def execute_invocation(instance, invocation):
        if invocation.get('errors'):
            row = _base(plan, instance, 'BLOCKED', 'ENV_MISSING')
            row['environment_missing'] = invocation['errors']
            return row
        destination = Path(invocation['log_path']).parent
        receipt = execute_process(invocation['command'], invocation['env'], destination,
                                  cwd=invocation.get('cwd', root), log_path=invocation['log_path'],
                                  separate_stderr=invocation.get('evidence_kind') == 'python-machine')
        receipt['product_artifact'] = invocation.get('product_artifact', {})
        receipt['related_evidence'] = invocation.get('evidence_artifacts', [])
        if invocation.get('evidence_kind') == 'junit':
            receipt['lines'] = _patrol_events(adapters, root, invocation, receipt, instance['target'])
        streams = split_machine_events(root, [instance['target']], receipt['lines'])
        return _finish(plan, instance, [_record_attempt(root, plan, instance, receipt, streams[instance['target']])])

    def adapter_result(instance, receipt):
        receipt = receipt if isinstance(receipt, dict) else {}
        if receipt.get('attempts') or (receipt.get('id') == instance['id'] and receipt.get('status')):
            return receipt
        row = _base(plan, instance, 'BLOCKED', (receipt or {}).get('reason_code', 'MISSING_RESULT'))
        row.update(environment_missing=receipt.get('environment_missing', receipt.get('errors', [])),
                   upstream=(receipt or {}).get('upstream', row['upstream']))
        if receipt.get('companion_evidence'):
            row['companion_evidence'] = receipt['companion_evidence']
        return row

    for instance in selected:
        reason = stale
        failed_upstream = _instance_upstream(plan, instance, upstream, not is_worker)
        if adapters is None:
            reason = 'RUNNER_UNAVAILABLE'
        if failed_upstream:
            reason = 'UPSTREAM_FAILED'
        expected_hash = instance.get('source_sha256')
        if expected_hash and (not (root / instance['target']).is_file() or hashlib.sha256((root / instance['target']).read_bytes()).hexdigest() != expected_hash):
            reason = 'STALE_PLAN'
        missing = [] if reason else _default_preflight(root, instance, runtime_env)
        if not reason and adapters is not None:
            missing += adapters.preflight_instance(root, instance, runtime_env, probe=True)
        if reason or missing:
            row = _base(plan, instance, 'BLOCKED', reason or 'ENV_MISSING')
            row.update(environment_missing=missing, upstream_failed=failed_upstream)
            results.append(row)
            continue
        runner = _runner_name(instance)
        if runner == 'device-pair':
            pairs[(instance.get('pair_group'), instance.get('product_profile'), instance.get('variant'))].append(instance)
        else:
            # Different matrix instances are never collapsed by target path.
            key = (runner, instance['platform'], instance.get('product_profile'),
                   instance.get('variant'), instance.get('role'), instance.get('test_name'),
                   json.dumps(instance.get('dart_defines', {}), sort_keys=True),
                   tuple(sorted(instance.get('dependencies', []))), bool(coverage and instance.get('coverage')))
            if runner != 'flutter-machine' or instance.get('suite') == 'route-smoke':
                key += (instance['id'],)
            groups[key].append(instance)
    batches = list(_execution_batches(groups.values()))
    for batch_index, group in enumerate(batches):
        runner = _runner_name(group[0])
        print(f'Execution batch {batch_index + 1}/{len(batches)}: {runner} '
              f'platform={group[0]["platform"]} targets={len(group)}', file=sys.stderr, flush=True)
        if runner == 'flutter-device' and group[0].get('orchestration') in ('mc-owned-coordinator', 'sqlite-kill-replay'):
            for instance in group:
                output = artifact_dir / 'batches' / f'{batch_index:04d}' / 'coordinated'
                method = 'run_kill_replay' if instance.get('orchestration') == 'sqlite-kill-replay' else 'run_coordinated'
                if adapters is None or not hasattr(adapters, method):
                    receipt = {'reason_code': 'RUNNER_UNAVAILABLE', 'errors': ['MC coordinator adapter unavailable']}
                else:
                    try:
                        kwargs = {'execute_process': execute_process} if method == 'run_kill_replay' else {}
                        receipt = getattr(adapters, method)(root, instance, runtime_env, output, execute_invocation, **kwargs)
                    except Exception as error:
                        receipt = {'reason_code': 'RUNNER_CRASH', 'errors': [type(error).__name__ + ': ' + str(error)]}
                results.append(adapter_result(instance, receipt))
            _write_json(artifact_dir / 'results.json', {'artifact_root': str(artifact_dir), 'results': results})
            continue
        attempt_records = {i['id']: [] for i in group}
        pending = list(group)
        for attempt_index in range(max(1, min(3, max_infra_attempts))):
            output = artifact_dir / 'batches' / f'{batch_index:04d}' / f'attempt-{attempt_index + 1}'
            with contextlib.ExitStack() as stack:
                aliases = {}
                if runner == 'flutter-machine':
                    try:
                        command, aliases, process_env = _host_command(root, pending, runtime_env, output, stack, adapters)
                        invocation = {'command': command, 'env': process_env, 'evidence_kind': 'flutter-machine'}
                    except ValueError as error:
                        invocation = {'errors': [str(error)]}
                elif runner in ('python-unittest', 'python-cases', 'python-recovery'):
                    invocation = {'command': [sys.executable, '-m', 'auto_test_lib.execution_runner',
                                              '--tooling', runner, group[0]['target']], 'env': runtime_env,
                                  'evidence_kind': 'python-machine'}
                elif adapters is not None and runner in ('flutter-device', 'patrol'):
                    invocation = adapters.build_invocation(root, group[0], runtime_env, output)
                else:
                    for instance in pending:
                        row = _base(plan, instance, 'BLOCKED', 'RUNNER_UNAVAILABLE')
                        row['environment_missing'] = [f'No executable adapter for {runner}']
                        results.append(row)
                    pending = []
                    break
                if invocation.get('errors'):
                    for instance in pending:
                        row = _base(plan, instance, 'BLOCKED', 'ENV_MISSING')
                        row['environment_missing'] = invocation['errors']
                        results.append(row)
                    pending = []
                    break
                if (output / 'lcov.info').is_file():
                    (output / 'lcov.info').unlink()
                receipt = execute_process(invocation['command'], invocation.get('env', runtime_env), output,
                                          cwd=invocation.get('cwd', root), log_path=invocation.get('log_path'),
                                          separate_stderr=invocation.get('evidence_kind') == 'python-machine')
                receipt['product_artifact'] = adapters.product_artifact_evidence(root, group[0], runtime_env)
                receipt['related_evidence'] = invocation.get('evidence_artifacts', [])
                if group[0].get('coverage') and (output / 'lcov.info').is_file():
                    receipt['coverage'] = str(output / 'lcov.info')
                    receipt['coverage_sha256'] = _file_sha256(output / 'lcov.info')
                if invocation.get('evidence_kind') == 'junit':
                    receipt['lines'] = _patrol_events(adapters, root, invocation, receipt, group[0]['target'])
                streams = split_machine_events(root, [i['target'] for i in pending], receipt['lines'], aliases)
                retry = []
                for instance in pending:
                    attempt = _record_attempt(root, plan, instance, receipt, streams[instance['target']])
                    if instance.get('coverage') and not receipt.get('coverage') and attempt['parsed'].get('test_status') == 'PASS':
                        attempt['execution_errors'].append('MISSING_COVERAGE_RESULT')
                    attempt_records[instance['id']].append(attempt)
                    if attempt['parsed'].get('failure_class') == 'infra' and attempt['parsed']['test_status'] == 'BLOCKED':
                        retry.append(instance)
                pending = retry
                if not pending:
                    break
        for instance in group:
            attempts = attempt_records[instance['id']]
            if attempts:
                results.append(_finish(plan, instance, attempts))
        _write_json(artifact_dir / 'results.json', {'artifact_root': str(artifact_dir), 'results': results})
    for pair_key, instances in pairs.items():
        if adapters is None or not hasattr(adapters, 'run_pair'):
            results.extend(_base(plan, i, 'BLOCKED', 'ENV_MISSING') for i in instances)
            continue
        all_roles = [i['id'] for i in plan['instances'] if i.get('selected')
                     and (i.get('pair_group'), i.get('product_profile'), i.get('variant')) == pair_key]
        if set(all_roles) != {i['id'] for i in instances}:
            for instance in instances:
                row = _base(plan, instance, 'BLOCKED', 'UPSTREAM_FAILED')
                row['upstream_failed'] = [{'dependency': i, 'status': 'PAIR_ROLE_NOT_IN_WORKER'}
                                          for i in all_roles if i not in {v['id'] for v in instances}]
                results.append(row)
            continue
        output = artifact_dir / 'pairs' / hashlib.sha256(repr(pair_key).encode()).hexdigest()[:12]
        receipts = adapters.run_pair(root, instances, runtime_env, output, execute_invocation)
        for instance in instances:
            results.append(adapter_result(instance, receipts.get(instance['id'])))
        _write_json(artifact_dir / 'results.json', {'artifact_root': str(artifact_dir), 'results': results})
    if coverage:
        merge_coverage_files([path for row in results for path in row.get('coverage', [])],
                             artifact_dir / 'coverage/lcov.info')
    final_targets = _target_hashes(root, selected)
    changed_targets = [path for path in initial_targets if initial_targets[path] != final_targets[path]]
    snapshot_changed = False
    if not stale:
        try:
            snapshot_changed = bool(_check_snapshot(root, plan))
        except (OSError, ValueError):
            snapshot_changed = True  # An invalidated catalog cannot certify the old plan.
    if snapshot_changed or changed_targets:
        for row in results:
            if row.get('status') != 'FAIL':
                row.update(status='BLOCKED', reason_code='SOURCE_CHANGED_DURING_RUN',
                           source_changes={'targets': changed_targets, 'snapshot_changed': snapshot_changed})
    summary = reconcile(plan, results, upstream, worker_platform=worker_platform,
                        worker_suites=worker_suites, worker_product_profile=worker_product_profile,
                        require_gates=not is_worker)
    _write_json(artifact_dir / 'results.json', {'artifact_root': str(artifact_dir), 'results': results})
    _write_json(artifact_dir / 'summary.json', summary)
    return summary


def _patrol_events(adapters, root, invocation, receipt, target):
    original_paths = adapters.fresh_junit_paths(root, invocation.get('junit_before', {}))
    paths, related = [], []
    for index, source in enumerate(original_paths):
        destination = Path(receipt['log']).parent / 'junit' / f'{index:04d}-{Path(source).name}'
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, destination)
        paths.append(str(destination))
        related.append({'path': str(destination), 'sha256': _file_sha256(destination)})
    parsed = adapters.parse_patrol_junit(paths, receipt['exit_code'])
    events = [{'type': 'suite', 'suite': {'id': 0, 'path': target}}]
    counter = 0
    for outcome, count in (('success', parsed['passed']), ('failure', parsed['failed']), ('skipped', parsed['skipped'])):
        for _ in range(count):
            counter += 1
            events += [{'type': 'testStart', 'test': {'id': counter, 'suiteID': 0, 'name': f'native-dart-case-{counter}'}},
                       {'type': 'testDone', 'testID': counter, 'result': outcome, 'skipped': outcome == 'skipped'}]
    hard_errors = [error for error in parsed['errors'] if error not in ('UNEXPECTED_SKIP', 'RUNNER_EXIT_NONZERO')]
    if hard_errors:
        events.append({'type': 'error', 'message': ';'.join(hard_errors), 'isFailure': False})
    events.append({'type': 'done', 'success': parsed['failed'] == 0 and not hard_errors})
    evidence = Path(receipt['log']).parent / 'patrol-result.json'
    _write_json(evidence, {'paths': paths, 'original_paths': original_paths, 'parsed': parsed})
    # Keep the adapted event evidence separate from Patrol's process log, with
    # the original JUnit paths retained alongside it for review.
    lines = [json.dumps(event) for event in events]
    machine = evidence.with_name('patrol-machine.jsonl')
    machine.write_text('\n'.join(lines) + '\n', encoding='utf-8')
    receipt['machine'] = str(machine)
    receipt['native_evidence'] = str(evidence)
    receipt['native_evidence_sha256'] = _file_sha256(evidence)
    receipt['related_evidence'] = receipt.get('related_evidence', []) + related
    return lines


def _tooling_child(runner, target):
    """Adapt existing unittest/CASES exercises to the same machine parser."""
    target_path = Path(target).resolve()
    sys.path.insert(0, str(target_path.parent))
    # Keep our protocol on a private descriptor. Target Python and any nested
    # subprocess stdout must never be mistaken for this runner's own evidence.
    event_stream = os.fdopen(os.dup(sys.stdout.fileno()), 'w', encoding='utf-8')
    sys.stdout.flush()
    os.dup2(sys.stderr.fileno(), sys.stdout.fileno())
    counter, failed = 0, False
    def emit(**event):
        print(json.dumps(event, ensure_ascii=False), file=event_stream, flush=True)
    emit(type='start')
    emit(type='suite', suite={'id': 0, 'path': str(target_path)})
    def start(name):
        nonlocal counter
        counter += 1
        emit(type='testStart', test={'id': counter, 'suiteID': 0, 'name': name})
        return counter
    def finish(test_id, outcome='success', message=None, skipped=False):
        nonlocal failed
        failed = failed or outcome in ('failure', 'error')
        if message:
            emit(type='error', testID=test_id, message=message, isFailure=outcome == 'failure')
        emit(type='testDone', testID=test_id, result=outcome, skipped=skipped, hidden=False)
    class Events(unittest.TestResult):
        def startTest(self, test):
            super().startTest(test)
            self.current = start(test.id())
            self.outcome, self.message, self.skipping = 'success', None, False
        def addFailure(self, test, err):
            super().addFailure(test, err)
            self.outcome, self.message = 'failure', self._exc_info_to_string(err, test)
        def addError(self, test, err):
            super().addError(test, err)
            self.outcome, self.message = 'error', self._exc_info_to_string(err, test)
        def addSkip(self, test, reason):
            super().addSkip(test, reason)
            self.skipping = True
        def addExpectedFailure(self, test, err):
            self.addSkip(test, 'expected failure')
        def addUnexpectedSuccess(self, test):
            self.outcome, self.message = 'failure', 'Unexpected success'
        def addSubTest(self, test, subtest, err):
            super().addSubTest(test, subtest, err)
            if err:
                self.outcome, self.message = 'failure', self._exc_info_to_string(err, test)
        def stopTest(self, test):
            finish(self.current, self.outcome, self.message, self.skipping)
            super().stopTest(test)
    try:
        with contextlib.redirect_stdout(sys.stderr):
            spec = importlib.util.spec_from_file_location('execution_tooling_target', target_path)
            module = importlib.util.module_from_spec(spec)
            sys.modules[spec.name] = module
            spec.loader.exec_module(module)
            if runner == 'python-unittest':
                unittest.defaultTestLoader.loadTestsFromModule(module).run(Events())
            elif runner == 'python-cases':
                for function in module.CASES:
                    test_id = start(function.__name__)
                    try:
                        function()
                    except AssertionError as exc:
                        finish(test_id, 'failure', str(exc))
                    except Exception as exc:
                        finish(test_id, 'error', repr(exc))
                    else:
                        finish(test_id)
            elif runner == 'python-recovery':
                _run_recovery(module, start, finish)
    except Exception as exc:
        finish(start('tooling runner initialization'), 'error', repr(exc))
    emit(type='done', success=not failed)
    return 1 if failed else 0


def _run_recovery(module, start, finish):
    # The legacy drill edits its runtime golden sample and writes a report.
    # Supply a wholly synthetic Git runtime, never the developer's real state.
    with tempfile.TemporaryDirectory(prefix='execution-recovery-') as tmp:
        runtime = Path(tmp) / 'runtime'
        runtime.mkdir()
        commands = [['init', '-q', '-b', 'main'], ['config', 'user.email', 'fixture@example.invalid'],
                    ['config', 'user.name', 'Synthetic Fixture']]
        for command in commands:
            subprocess.run(['git', '-C', str(runtime), *command], check=True, capture_output=True)
        _write_json(runtime / 'registry.json', {'integration': {'path': str(runtime)}, 'intents': [{}]})
        _write_json(runtime / 'state.json', {'tasks': {'fixture': {'work_state': 'TODO'}}})
        (runtime / 'events.jsonl').write_text('')
        for part in ('sealed', 'candidates'):
            sample = runtime / 'golden/P1' / part / 'p1/fixture.png'
            sample.parent.mkdir(parents=True)
            sample.write_bytes(b'synthetic-recovery-copy-fixture')
        subprocess.run(['git', '-C', str(runtime), 'add', '.'], check=True)
        subprocess.run(['git', '-C', str(runtime), 'commit', '-qm', 'synthetic fixture'], check=True)
        module.RUNTIME, module.DRILL_MD = str(runtime), str(Path(tmp) / 'drill.md')
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            code = module.main()
        reports = [json.loads(line) for line in output.getvalue().splitlines() if line.startswith('{')]
        totals = next((r for r in reports if 'total' in r and 'failed' in r), {})
        cases = re.findall(r'^\| (RC\d+[a-z]?) \| (PASS|FAIL) \| (.*?) \|$', Path(module.DRILL_MD).read_text(), re.M)
        if not cases or len(cases) != totals.get('total') or sum(c[1] == 'FAIL' for c in cases) != totals.get('failed'):
            raise ValueError('Recovery drill produced inconsistent per-case evidence')
        for name, status, detail in cases:
            finish(start(name), 'success' if status == 'PASS' else 'failure', None if status == 'PASS' else detail)
        if code != 0 and not totals['failed']:
            raise ValueError(f'Recovery runner exit {code} contradicts case evidence')


def merge_coverage_files(paths, destination):
    """Merge only coverage produced by this invocation, taking maximum hit counts."""
    records, current = {}, None
    for path in dict.fromkeys(paths):
        for line in Path(path).read_text(encoding='utf-8').splitlines():
            if line.startswith('SF:'):
                current = records.setdefault(line[3:], {'DA': {}, 'FN': set(), 'FNDA': {}, 'BRDA': {}})
            elif line == 'end_of_record':
                current = None
            elif current is not None and line.startswith('DA:'):
                location, count, *_ = line[3:].split(',')
                current['DA'][int(location)] = max(int(count), current['DA'].get(int(location), 0))
            elif current is not None and line.startswith('FN:'):
                current['FN'].add(line)
            elif current is not None and line.startswith('FNDA:'):
                count, name = line[5:].split(',', 1)
                current['FNDA'][name] = max(int(count), current['FNDA'].get(name, 0))
            elif current is not None and line.startswith('BRDA:'):
                location, block, branch, count = line[5:].split(',')
                key = (location, block, branch)
                value = -1 if count == '-' else int(count)
                current['BRDA'][key] = max(value, current['BRDA'].get(key, -1))
    if not records:
        return None
    lines = []
    for source, record in sorted(records.items()):
        lines.append('SF:' + source)
        lines.extend(sorted(record['FN']))
        lines.extend(f'FNDA:{count},{name}' for name, count in sorted(record['FNDA'].items()))
        lines.extend(f'DA:{location},{count}' for location, count in sorted(record['DA'].items()))
        lines.extend('BRDA:' + ','.join(key) + ',' + ('-' if count < 0 else str(count))
                     for key, count in sorted(record['BRDA'].items()))
        lines += [f"LF:{len(record['DA'])}", f"LH:{sum(c > 0 for c in record['DA'].values())}", 'end_of_record']
    destination = Path(destination)
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text('\n'.join(lines) + '\n', encoding='utf-8')
    return str(destination)


if __name__ == '__main__':
    if len(sys.argv) == 4 and sys.argv[1] == '--tooling':
        sys.exit(_tooling_child(sys.argv[2], sys.argv[3]))
    raise SystemExit('Use scripts/auto_test.py execution-run for catalog plans')

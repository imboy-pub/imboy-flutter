#!/usr/bin/env python3
"""Replay the Flutter WebSocket handshake experiment on an isolated host."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import signal
import socket
import subprocess
import tarfile
import tempfile
import time

BASE = '946be831b5383141e652d6f30d358749aaed3fea'
SUBMODULE = '62245bd40067d73ddb5bf98d340537cbbe2ae3e7'
TREE = '7ae35918257afcb00d681f9505d573bf7bb1e5d1'
LOCK = '66b49c7ffe4a3fa5d514e32031fe63a4917297afcebde8fffd2302105cc38848'
REFERENCE = {
    'base': BASE,
    'initial': '09273863bdbac3d24395ad4bec869808c5e8dfcf',
    'fixed': 'd73e24c245562e1fa025fa643b5bd80a74340773',
}
MODELS = {'old': 'gpt-6.1-sol', 'new': 'gpt-6.2-sol'}
HERE = Path(__file__).resolve().parent
SUB_PATH = 'plugin/flutter_chat_ui'
JUDGE_FILE = 'test/unit_test/service/ecc027_handshake_contract_test.dart'
PROTOCOL_FILES = (
    'test/unit_test/service/websocket_reinit_test.dart',
    'test/unit_test/service/websocket_send_session_test.dart',
)
IDS = tuple(f'ECC027-{i:02}' for i in range(1, 6))
CONTROL_OUTCOMES = {
    'base': ('fail', 'fail', 'fail', 'pass', 'pass'),
    'initial': ('pass', 'fail', 'fail', 'pass', 'pass'),
    'fixed': ('pass', 'pass', 'pass', 'pass', 'pass'),
}
FROZEN_ENV = {
    'env_dev.g.dart': '9633d4ba6b0355a373e9f8a3dc2e426685ede4e9eb39d44de8cfa9ae5d37e3ee',
    'env_local.g.dart': 'b3a80b43732a646a3764a403c7cccf3e581745d4a33d14937e83dbd571b77aff',
    'env_local_home.g.dart': 'c31178a2548de2cf45f0ab54352fc2f08a2fab97f066655cfbb9348100f004d7',
    'env_local_office.g.dart': 'b56e281b9ab83bd905f7f89496d980b0b0dfec6ac982e283e83c6a8cd49610b0',
    'env_pro.g.dart': '3a749ab22d25a80bb9b113c3cfb9a4713d74bb2b4ff6f7403ee1931f78d2fd41',
}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def git(repo, *args, data=None):
    return subprocess.run(['git', '-C', str(repo), *args], input=data,
                          stdout=subprocess.PIPE, check=True).stdout


def archive(repo, commit, dest):
    with tempfile.TemporaryFile() as stream:
        subprocess.run(['git', '-C', str(repo), 'archive', commit],
                       stdout=stream, check=True)
        stream.seek(0)
        with tarfile.open(fileobj=stream) as source:
            source.extractall(dest, filter='data')


def snapshot(repo, dest):
    dest.mkdir()
    archive(repo, BASE, dest)
    sub_dest = dest / SUB_PATH
    sub_dest.mkdir(parents=True, exist_ok=True)
    sub_repo = repo / SUB_PATH
    if Path(git(sub_repo, 'rev-parse', '--show-toplevel').decode().strip()).resolve() != sub_repo:
        raise RuntimeError(f'Initialize the pinned submodule first: {sub_repo}')
    archive(sub_repo, SUBMODULE, sub_dest)
    if sha(dest / 'pubspec.lock') != LOCK:
        raise RuntimeError('Unexpected lockfile SHA-256')
    git(dest, 'init', '-q')
    git(dest, '-c', 'core.autocrlf=false', 'add', '-A')
    if git(dest, 'write-tree').decode().strip() != TREE:
        raise RuntimeError('Unexpected flattened checkout tree')
    git(dest, '-c', 'user.name=IMBoy Eval', '-c', 'user.email=eval@example.invalid',
        '-c', 'core.hooksPath=/dev/null', 'commit', '-qm', 'snapshot')


def capture(cwd, evidence, name, command, seconds, env=None, stdin=None):
    out = evidence / f'{name}.stdout'
    err = evidence / f'{name}.stderr'
    start = time.monotonic()
    timed_out = False
    with out.open('xb') as stdout, err.open('xb') as stderr:
        try:
            proc = subprocess.Popen(command, cwd=cwd, env=env, stdin=stdin,
                                    stdout=stdout, stderr=stderr, start_new_session=True)
        except OSError as exc:
            stderr.write(str(exc).encode())
            code = 127
        else:
            try:
                code = proc.wait(timeout=seconds)
            except subprocess.TimeoutExpired:
                timed_out = True
                try:
                    os.killpg(proc.pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
                code = proc.wait()
    return {'argv': command, 'exit_code': code, 'timeout': timed_out,
            'seconds': round(time.monotonic() - start, 3),
            'stdout': out.name, 'stdout_sha256': sha(out),
            'stderr': err.name, 'stderr_sha256': sha(err)}


def receipts(evidence, result):
    (evidence / 'receipt.json').write_text(json.dumps(result, indent=2) + '\n')


def setup_flutter(cwd, evidence, flutter, result):
    env = dict(os.environ, CI='true', FLUTTER_SUPPRESS_ANALYTICS='true',
               PATH=f'{Path(flutter).parent}{os.pathsep}{os.environ["PATH"]}')
    config = evidence / 'xdg-config'
    config.mkdir()
    env['XDG_CONFIG_HOME'] = str(config)
    commands = result['commands']
    commands['flutter_version'] = capture(cwd, evidence, 'flutter-version',
                                          [flutter, '--version', '--machine'], 60, env)
    version_path = evidence / commands['flutter_version']['stdout']
    try:
        version = json.loads(version_path.read_text())
    except (ValueError, OSError):
        version = {}
    result['flutter'] = version
    if (commands['flutter_version']['exit_code'] or
            version.get('frameworkRevision') != 'ab2912035e160d9cad6306df307576da6128ebdb' or
            version.get('engineRevision') != '371f77202a73e8dff57a8b3bff75bca55c090aee' or
            version.get('dartSdkVersion') != '3.14.0'):
        return None
    commands['pub_get'] = capture(cwd, evidence, 'pub-get',
                                  [flutter, 'pub', 'get', '--offline', '--enforce-lockfile'], 180, env)
    if commands['pub_get']['exit_code'] or sha(cwd / 'pubspec.lock') != LOCK:
        return None
    for name, digest in FROZEN_ENV.items():
        fixture = HERE / 'synthetic-env' / f'{name}.fixture'
        if sha(fixture) != digest:
            raise RuntimeError(f'Unexpected synthetic environment fixture SHA-256: {name}')
        shutil.copyfile(fixture, cwd / 'lib' / 'config' / name)
    result['synthetic_env_sha256'] = FROZEN_ENV
    if git(cwd, 'status', '--porcelain'):
        return None
    return env


def patch_scope(cwd):
    git(cwd, 'add', '-N', '--', '.')
    paths = git(cwd, 'diff', '--name-only', '-z', 'HEAD').decode().split('\0')[:-1]
    outside = []
    for value in paths:
        path = Path(value)
        is_service = path.parts[:2] == ('lib', 'service')
        is_ws_test = path.parts[0] == 'test' and 'websocket' in path.name and path.name.endswith('_test.dart')
        if not (path.suffix == '.dart' and (is_service or is_ws_test)):
            outside.append(value)
    return paths, outside


def probe_loopback():
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as listener:
            listener.bind(('127.0.0.1', 0))
    except OSError as exc:
        return {'available': False, 'errno': exc.errno, 'error': str(exc)}
    return {'available': True}


def analyze_run(events_file):
    starts = {}
    outcomes = {}
    loader_errors = 0
    finished = None
    for line in events_file.read_text(errors='replace').splitlines():
        if not line.startswith('{'):
            continue
        try:
            event = json.loads(line)
        except json.JSONDecodeError:
            continue
        if event.get('type') == 'testStart':
            test = event['test']
            starts[test['id']] = test
        elif event.get('type') == 'testDone':
            outcomes[event['testID']] = event
        elif event.get('type') == 'done':
            finished = event.get('success')
    gate = {}
    counts = dict(pass_count=0, fail_count=0, skip_count=0, missing_count=0)
    for identifier, test in starts.items():
        done = outcomes.get(identifier)
        if test['name'].startswith('loading '):
            if not done or done['result'] != 'success':
                loader_errors += 1
            continue
        if not done:
            status = 'missing'
        elif test['metadata']['skip'] or done.get('skipped'):
            status = 'skip'
        elif done['result'] == 'success':
            status = 'pass'
        else:
            status = 'fail'
        counts[f'{status}_count'] += 1
        case = test['name'].split(' ', 1)[0]
        if case in IDS:
            gate[case] = status if case not in gate else 'duplicate'
    return {'run_complete': finished is not None, 'reported_success': finished,
            'tests': counts, 'loader_errors': loader_errors,
            'hidden_cases': {case: gate.get(case, 'missing') for case in IDS}}


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--source', required=True, type=Path, help='Local Flutter repository with submodule')
    p.add_argument('--out', required=True, type=Path, help='New, empty result directory')
    p.add_argument('--flutter', required=True, type=Path, help='Writable Flutter 3.50.0 SDK binary')
    commands = p.add_subparsers(dest='action', required=True)
    trial = commands.add_parser('trial')
    trial.add_argument('--model', choices=tuple(MODELS), required=True)
    trial.add_argument('--round', type=int, required=True)
    judge = commands.add_parser('judge')
    choices = judge.add_mutually_exclusive_group(required=True)
    choices.add_argument('--control', choices=tuple(REFERENCE))
    choices.add_argument('--patch', type=Path)
    a = p.parse_args()
    root = a.out.resolve()
    root.mkdir(parents=True)
    work = root / 'checkout'
    evidence = root / 'evidence'
    evidence.mkdir()
    result = {'status': 'BLOCKED', 'action': a.action, 'base': BASE, 'tree': TREE,
              'submodule': SUBMODULE, 'lock_sha256': LOCK, 'host': platform.platform(),
              'prompt_sha256': sha(HERE / 'PROMPT.md'), 'commands': {}}
    try:
        snapshot(a.source.resolve(), work)
        executable = str(a.flutter.resolve())
        env = setup_flutter(work, evidence, executable, result)
        if env is None:
            result['reason'] = 'SDK or locked synthetic fixture preparation failed'
            return 2
        if a.action == 'trial':
            model = MODELS[a.model]
            result.update(model=model, effort='low', round=a.round)
            command = ['codex', '--ask-for-approval', 'never', 'exec', '--ignore-user-config',
                       '--ephemeral', '--sandbox', 'workspace-write', '--model', model,
                       '-c', 'model_reasoning_effort="low"', '--json', '-']
            with (HERE / 'PROMPT.md').open('rb') as prompt:
                run = capture(work, evidence, 'model', command, 720, env, prompt)
            result['commands']['model'] = run
            patch = evidence / 'candidate.patch'
            paths, outside = patch_scope(work)
            patch.write_bytes(git(work, 'diff', '--binary', 'HEAD', '--'))
            result.update(patch_sha256=sha(patch), changed_paths=paths, scope_violations=outside)
            if not run['exit_code'] and paths and not outside:
                result['status'] = 'PATCH_READY'
                return 0
            result['status'] = 'BLOCKED' if not paths and run['exit_code'] else 'INCOMPLETE'
            return 2
        fixture = HERE / 'handshake_contract_test.dart.fixture'
        result['judge_sha256'] = sha(fixture)
        regressions = {name: (work / name).read_bytes() for name in PROTOCOL_FILES}
        if a.control:
            result['control'] = a.control
            data = git(a.source.resolve(), 'diff', '--binary', BASE, REFERENCE[a.control], '--', 'lib/service')
        else:
            result['candidate_patch_sha256'] = sha(a.patch.resolve())
            data = a.patch.resolve().read_bytes()
            if not data:
                raise RuntimeError('Empty candidate patch')
        if data:
            git(work, 'apply', '--check', '-', data=data)
            git(work, 'apply', '-', data=data)
        paths, outside = patch_scope(work)
        result.update(changed_paths=paths, scope_violations=outside)
        if outside or (work / JUDGE_FILE).exists():
            result['status'] = 'FAIL_SCOPE'
            return 1
        for name, contents in regressions.items():
            (work / name).write_bytes(contents)
        shutil.copyfile(fixture, work / JUDGE_FILE)
        result['loopback'] = probe_loopback()
        test_args = [executable, 'test', '--no-pub', '--concurrency=1', '--machine',
                     JUDGE_FILE, *PROTOCOL_FILES]
        run = capture(work, evidence, 'flutter-test', test_args, 360, env)
        result['commands']['flutter_test'] = run
        summary = analyze_run(evidence / run['stdout'])
        result.update(summary)
        skips = summary['tests']['skip_count'] + summary['tests']['missing_count']
        all_cases = set(summary['hidden_cases'].values()) == {'pass'}
        if (not result['loopback']['available'] or run['timeout'] or
                'missing' in summary['hidden_cases'].values()):
            result['status'] = 'BLOCKED'
            return 2
        if a.control:
            expected = CONTROL_OUTCOMES[a.control]
            expected_failures = expected.count('fail')
            result['expected_hidden_cases'] = dict(zip(IDS, expected))
            matches = (tuple(summary['hidden_cases'].values()) == expected and
                       summary['run_complete'] and not summary['loader_errors'] and not skips and
                       summary['tests']['fail_count'] == expected_failures and
                       summary['tests']['pass_count'] + expected_failures > len(IDS) and
                       summary['reported_success'] == (expected_failures == 0) and
                       run['exit_code'] == int(expected_failures > 0))
            result['status'] = 'PASS' if matches else 'FAIL_CALIBRATION'
            return 0 if matches else 1
        if (run['exit_code'] or not summary['reported_success'] or not all_cases or
                skips or summary['loader_errors']):
            result['status'] = 'FAIL'
            return 1
        result['status'] = 'PASS'
        return 0
    except (OSError, RuntimeError, subprocess.CalledProcessError) as exc:
        result['reason'] = str(exc)
        return 2
    finally:
        receipts(evidence, result)
        print(f'{result["status"]} {evidence / "receipt.json"}')


if __name__ == '__main__':
    raise SystemExit(main())

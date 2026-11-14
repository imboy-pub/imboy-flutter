"""Run existing prerequisite gates without counting them as business tests."""
from __future__ import annotations

import hashlib
import shutil
import subprocess
from pathlib import Path


def run_gates(root: Path, plan: dict, output: Path, env: dict) -> dict:
    output.mkdir(parents=True, exist_ok=True)
    error_code_source = env.get('IMBOY_ERROR_CODE_HRL') or str(root.parent / 'imboy/include/error_code.hrl')
    commands = {
        'static-analysis': [['flutter', 'analyze', '--no-fatal-infos', '--no-fatal-warnings'],
                            ['dart', 'analyze', 'lib']],
        'framework': [['bash', 'scripts/check_auto_test_framework.sh', '--checks-only']],
        'sqlite-generator': [['bash', 'scripts/run_sqlite_migration_gate.sh', '--local', '--checks-only']],
        'contracts': [['dart', 'scripts/generate_error_code.dart', '--check',
                       f'--source={error_code_source}'],
                      ['bash', 'scripts/regen_protobuf.sh', '--check']],
    }
    gates = {}
    child_env = dict(env)
    child_env['AUTO_TEST_REPORT_ROOT'] = str((output / 'framework').resolve())
    for name in plan.get('gates', []):
        log = output / (name + '.log')
        row = {'status': 'PASS', 'reason_code': None, 'log': str(log.resolve()),
               'commit': plan['commit'], 'profile': plan['profile'],
               'source_fingerprint': plan['source_fingerprint'], 'artifact_root': str(output.parent.resolve()), 'exit_code': 0,
               'evidence_level': 'static-check', 'commands': []}
        gates[name] = row
        if name == 'ownership':
            log.write_text('Ownership validated while constructing/loading the execution plan.\n', encoding='utf-8')
            continue
        if name not in commands:
            row.update(status='BLOCKED', reason_code='ENV_MISSING', exit_code=2,
                       detail=f'No existing gate is registered for {name}')
            log.write_text(row['detail'] + '\n', encoding='utf-8')
            continue
        with log.open('w', encoding='utf-8') as stream:
            for command in commands[name]:
                row['commands'].append(command)
                # Shell gate scripts have their own honest prerequisite checks;
                # Dart/Flutter absence is an environment condition, not an assertion.
                if not shutil.which(command[0], path=env.get('PATH')):
                    row.update(status='BLOCKED', reason_code='ENV_MISSING', exit_code=2,
                               detail=f'{command[0]} is unavailable')
                    stream.write(row['detail'] + '\n')
                    break
                try:
                    completed = subprocess.run(command, cwd=root, env=child_env,
                                               stdout=stream, stderr=subprocess.STDOUT,
                                               timeout=900, check=False)
                    code = completed.returncode
                except (OSError, subprocess.TimeoutExpired) as error:
                    row.update(status='BLOCKED', reason_code='RUNNER_CRASH', exit_code=2,
                               detail=type(error).__name__)
                    break
                if code:
                    row.update(status='BLOCKED' if code == 2 else 'FAIL',
                               reason_code='ENV_MISSING' if code == 2 else 'CHECK_FAILED',
                               exit_code=code)
                    break
    for row in gates.values():
        log = Path(row['log'])
        if log.is_file():
            row['log_sha256'] = hashlib.sha256(log.read_bytes()).hexdigest()
    return gates


def merge_gate_statuses(gates: dict, upstream: dict) -> dict:
    """A failed receipt or job cannot be erased by another successful attestation."""
    values = dict(upstream)

    def merge(name, status):
        previous = values.get(name)
        if previous is not None and str(previous).lower() not in {'pass', 'passed', 'success'}:
            return
        values[name] = status

    for name, row in gates.items():
        merge(name, row.get('status', 'missing') if isinstance(row, dict) else row)
    mapping = {'execution-plan': ['ownership'],
               'quality-gates': ['static-analysis', 'framework', 'sqlite-generator'],
               'contract-gates': ['contracts']}
    for job, gate_names in mapping.items():
        if job in upstream:
            for name in gate_names:
                if str(upstream[job]).lower() in {'pass', 'passed', 'success'}:
                    merge(name, upstream[job])
                else:
                    # The aggregate job failed, but that does not identify a
                    # failed child. Keep independent receipts; otherwise the
                    # child's evidence is missing. The job still blocks CI.
                    values.setdefault(name, 'missing')
    return values

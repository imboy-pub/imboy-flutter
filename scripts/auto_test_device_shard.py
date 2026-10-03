#!/usr/bin/env python3
"""Step 11/13/14 设备 shard 执行器。

按 target 列表在指定设备上执行 flutter test --machine，写 RUN_ROOT 结构化
结果（events.jsonl + ParsedResult 判定）。不读凭证环境变量；离线 target
不注入 TEST_PHONE/TEST_PASSWORD。重试只针对基础设施失败，最多 2 次。
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / 'scripts'))
from auto_test_lib import acceptance  # noqa: E402
from auto_test_lib.machine_events import parse_machine_events  # noqa: E402
from auto_test_lib.result import classify_attempts  # noqa: E402


def sha256_file(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def append_journal(path: Path, record: dict) -> None:
    """Persist each transition before continuing to another subprocess."""
    with path.open('a', encoding='utf-8') as stream:
        stream.write(json.dumps(record, ensure_ascii=False, allow_nan=False) + '\n')
        stream.flush()
        os.fsync(stream.fileno())


def capture_process(target: str, device: str) -> tuple[str, int]:
    try:
        proc = subprocess.run(
            ['flutter', 'test', target, '-d', device, '--machine', '--no-pub'],
            cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            text=True, timeout=1800,
        )
        return proc.stdout or '', proc.returncode
    except subprocess.TimeoutExpired as error:
        output = error.stdout or ''
        if isinstance(output, bytes):
            output = output.decode('utf-8', errors='replace')
        return output, 124


def attempt_fingerprint(target: str, device: str, platform: str, run_id: str) -> dict:
    def head(root: Path) -> str:
        return subprocess.run(['git', 'rev-parse', 'HEAD'], cwd=root,
                              capture_output=True, text=True).stdout.strip()
    return {
        'app_head': head(ROOT), 'backend_head': head(ROOT / '../imboy'),
        'target_sha256': sha256_file(ROOT / target),
        'config_sha256': hashlib.sha256(f'flutter|test|{target}|{device}'.encode()).hexdigest(),
        'fixture_fingerprint': f'offline:{run_id}',
        'device_fingerprint': f'{platform}:{device[:12]}',
    }


def run_attempt(target: str, device: str, platform: str, out_dir: Path,
                target_dir: Path, run_id: str, number: int) -> dict:
    started = time.time()
    attempt_id = f'{run_id}:{target}:{number}'
    initial_fingerprint = attempt_fingerprint(target, device, platform, run_id)
    append_journal(target_dir / 'starts.jsonl', {'attempt_id': attempt_id,
                   'target': target, 'started_at': started,
                   'fingerprint': initial_fingerprint})
    output, exit_code = capture_process(target, device)
    duration = round(time.time() - started, 1)
    events_path = target_dir / f'attempt{number}.events.jsonl'
    with events_path.open('x', encoding='utf-8') as stream:
        stream.write(output)
        stream.flush()
        os.fsync(stream.fileno())
    parsed = parse_machine_events(output.splitlines(), exit_code, None)
    if exit_code == 124:
        business_failure = (parsed.failed > 0 or parsed.test_status == 'FAIL'
            or parsed.failure_class == 'business'
            or getattr(getattr(parsed, 'first_failure', None), 'is_failure', None) is True)
        parsed.test_status = 'FAIL' if business_failure else 'BLOCKED'
        parsed.reason_code = 'BUSINESS_ASSERTION_FAIL' if business_failure else 'RUNNER_CRASH'
        parsed.failure_class = 'business' if business_failure else 'infra'
    final_fingerprint = attempt_fingerprint(target, device, platform, run_id)
    fingerprint_drift = initial_fingerprint != final_fingerprint
    if fingerprint_drift and parsed.test_status != 'FAIL':
        parsed.test_status = 'BLOCKED'
        parsed.reason_code = 'CANDIDATE_FINGERPRINT_CHANGED'
        parsed.failure_class = 'unknown'
    record = {
        'attempt_id': attempt_id,
        'parsed': {
            'test_status': parsed.test_status, 'executed': parsed.executed,
            'skipped': parsed.skipped, 'failed': parsed.failed,
            'oracle_count': parsed.oracle_count, 'reason_code': parsed.reason_code,
            'failure_class': parsed.failure_class,
        },
        'fingerprint': initial_fingerprint,
        'final_fingerprint': final_fingerprint,
        'fingerprint_drift': fingerprint_drift,
        'events_sha256': sha256_file(events_path),
        'exit_code': exit_code, 'duration_s': duration,
        'events': events_path.relative_to(out_dir).as_posix(),
    }
    append_journal(target_dir / 'attempts.jsonl', record)
    return record


def run_target(target: str, device: str, platform: str, out_dir: Path, run_id: str) -> dict:
    out_dir.mkdir(parents=True, exist_ok=True)
    identity = json.dumps([run_id, target], ensure_ascii=False).encode()
    target_dir = out_dir / hashlib.sha256(identity).hexdigest()
    target_dir.mkdir(exist_ok=False)
    attempts = []
    for number in range(1, 4):
        record = run_attempt(target, device, platform, out_dir, target_dir, run_id, number)
        attempts.append(record)
        if record['parsed']['failure_class'] != 'infra':
            break
    return {
        'target': target, 'platform': platform, 'device': device[:12],
        'attempts': attempts, 'final': classify_attempts(attempts),
        'duration_s': sum(a['duration_s'] for a in attempts),
    }


def load_targets(path: Path) -> list[str]:
    """Validate the whole target manifest before any device or output access."""
    with os.fdopen(acceptance._open_artifact(path.parent, path.name), 'rb') as stream:
        raw = stream.read(1024 * 1024 + 1)
    if len(raw) > 1024 * 1024:
        raise ValueError('target manifest too large')
    payload = json.loads(raw.decode('utf-8'),
                         object_pairs_hook=acceptance._unique_json_object,
                         parse_constant=acceptance._reject_json_constant)
    targets = payload.get('targets') if isinstance(payload, dict) else None
    if (not isinstance(targets, list) or not targets
            or any(not isinstance(t, str) or not t.strip() for t in targets)
            or len(set(targets)) != len(targets)):
        raise ValueError('invalid target list')
    for target in targets:
        parts = acceptance._parts(target)
        if '/'.join(parts) != target or not target.endswith('.dart'):
            raise ValueError('invalid target path')
        fd = acceptance._open_artifact(ROOT, target)
        os.close(fd)
    return targets


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--device', required=True)
    parser.add_argument('--platform', choices=('android', 'macos'), required=True)
    parser.add_argument('--targets', required=True, help='JSON file with {"targets": [...]}')
    parser.add_argument('--out', required=True, help='output dir under RUN_ROOT')
    parser.add_argument('--run-id', default='hardening-20260918T151153Z')
    args = parser.parse_args()
    try:
        targets = load_targets(Path(args.targets))
    except (OSError, ValueError, TypeError, RecursionError):
        print('shard blocked: TARGET_MANIFEST_INVALID', file=sys.stderr)
        return 64
    out_dir = Path(args.out)
    results = []
    for target in targets:
        record = run_target(target, args.device, args.platform, out_dir, args.run_id)
        results.append(record)
        print(f"[{record['final'].get('test_status')}] {target} attempts={len(record['attempts'])} {record['duration_s']}s", flush=True)
    (out_dir / 'results.json').write_text(json.dumps({
        'platform': args.platform, 'device': args.device[:12], 'run_id': args.run_id,
        'targets': targets, 'results': results,
    }, indent=2, ensure_ascii=False))
    statuses = [r['final'].get('test_status') for r in results]
    code = 0 if all(s == 'PASS' for s in statuses) else 1 if 'FAIL' in statuses else 2
    print(f'shard done: {statuses.count("PASS")} PASS / {len(statuses)} total, exit={code}')
    return code


if __name__ == '__main__':
    raise SystemExit(main())

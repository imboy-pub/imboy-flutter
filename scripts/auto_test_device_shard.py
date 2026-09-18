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
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / 'scripts'))
from auto_test_lib.machine_events import parse_machine_events  # noqa: E402
from auto_test_lib.result import classify_attempts  # noqa: E402


def sha256_file(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run_target(target: str, device: str, platform: str, out_dir: Path, run_id: str) -> dict:
    out_dir.mkdir(parents=True, exist_ok=True)
    attempts = []
    command_fingerprint = hashlib.sha256(f'flutter|test|{target}|{device}'.encode()).hexdigest()
    for attempt in range(3):
        started = time.time()
        proc = subprocess.run(
            ['flutter', 'test', target, '-d', device, '--machine', '--no-pub'],
            cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=1800,
        )
        duration = round(time.time() - started, 1)
        events_path = out_dir / f'{Path(target).stem}.attempt{attempt + 1}.events.jsonl'
        events_path.write_text(proc.stdout or '', encoding='utf-8')
        parsed = parse_machine_events((proc.stdout or '').splitlines(), proc.returncode, None)
        attempts.append({
            'parsed': {
                'test_status': parsed.test_status, 'executed': parsed.executed,
                'skipped': parsed.skipped, 'failed': parsed.failed,
                'oracle_count': parsed.oracle_count, 'reason_code': parsed.reason_code,
                'failure_class': parsed.failure_class,
            },
            'fingerprint': {
                'app_head': subprocess.run(['git', 'rev-parse', 'HEAD'], cwd=ROOT,
                                           capture_output=True, text=True).stdout.strip(),
                'backend_head': subprocess.run(['git', 'rev-parse', 'HEAD'], cwd=ROOT / '../imboy',
                                               capture_output=True, text=True).stdout.strip(),
                'target_sha256': sha256_file(ROOT / target),
                'config_sha256': command_fingerprint,
                'fixture_fingerprint': f'offline:{run_id}',
                'device_fingerprint': f'{platform}:{device[:12]}',
            },
            'exit_code': proc.returncode,
            'duration_s': duration,
            'events': events_path.name,
        })
        verdict = attempts[-1]['parsed']
        if verdict['failure_class'] == 'infra' and attempt < 2:
            continue
        break
    final = classify_attempts(attempts)
    return {
        'target': target,
        'platform': platform,
        'device': device[:12],
        'attempts': attempts,
        'final': final,
        'duration_s': sum(a['duration_s'] for a in attempts),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--device', required=True)
    parser.add_argument('--platform', choices=('android', 'macos'), required=True)
    parser.add_argument('--targets', required=True, help='JSON file with {"targets": [...]}')
    parser.add_argument('--out', required=True, help='output dir under RUN_ROOT')
    parser.add_argument('--run-id', default='hardening-20260918T151153Z')
    args = parser.parse_args()
    targets = json.loads(Path(args.targets).read_text())['targets']
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

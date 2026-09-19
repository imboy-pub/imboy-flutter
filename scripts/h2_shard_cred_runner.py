#!/usr/bin/env python3
"""hardening2 P3 · 带凭证 shard runner（auto_test_device_shard 的 dart-define 变体）。

差异（相对 scripts/auto_test_device_shard.py）：
- 注入 A6 测试账号 dart-define（TEST_PHONE/PASSWORD/EXPECTED_UID/PEER_UID）
  + 本地后端 override（API/WS/SOLIDIFIED_KEY），使凭证依赖 target 可执行；
- Android 侧走 patrol --no-uninstall（数据跨 target 保留，避免每 target
  全新安装的 SQLite v0→v21 迁移长链）；
- 每设备串行，target 失败不阻断后续（记录后继续）。

用法:
  python3 scripts/h2_shard_cred_runner.py --device XWE6R19916004085 --platform android \
      --targets /tmp/h2_p3_cred_targets.json --out <RUN_ROOT>/shards/p3_android_cred
"""
import argparse
import hashlib
import json
import subprocess
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RUN_ROOT_DEFAULT = ROOT / "test/auto_test/reports/hardening2-20260918T211458Z"

import json as _json
_CRED = ROOT / "test/auto_test/credentials.local.json"
_C = _json.loads(_CRED.read_text()) if _CRED.exists() else {}
API = "http://127.0.0.1:9800"
WS = "ws://127.0.0.1:9800/api/v1/ws"
KEY = _C.get("solidified_key", "")
KEY_IV = _C.get("solidified_key_iv", "")
A_ACC = _C.get("accounts", {}).get("orgA_owner", {}).get("acc", "")
A_UID = _C.get("accounts", {}).get("orgA_owner", {}).get("uid", "")
B_UID = _C.get("accounts", {}).get("orgA_member", {}).get("uid", "")
PW = _C.get("test_password", "")

COMMON_DEFINES = [
    f"--dart-define=APP_ENV=local",
    f"--dart-define=API_BASE_URL_OVERRIDE={API}",
    f"--dart-define=WS_URL_OVERRIDE={WS}",
    f"--dart-define=SOLIDIFIED_KEY_OVERRIDE={KEY}",
    f"--dart-define=SOLIDIFIED_KEY_IV_OVERRIDE={KEY_IV}",
    f"--dart-define=TEST_PHONE={A_ACC}",
    f"--dart-define=TEST_PASSWORD={PW}",
    f"--dart-define=TEST_EXPECTED_UID={A_UID}",
    f"--dart-define=PEER_UID={B_UID}",
]


def run_machine_events(proc_out: str, returncode: int):
    """从 --machine JSONL 提取判定（与 shard runner 同口径的简化版）。"""
    done, skipped, failed = [], [], []
    for line in proc_out.splitlines():
        line = line.strip()
        if not line.startswith("{"):
            continue
        try:
            ev = json.loads(line)
        except json.JSONDecodeError:
            continue
        if ev.get("type") == "testStart":
            done.append(ev.get("test", {}).get("name", ""))
        elif ev.get("type") == "testDone":
            if ev.get("skipped"):
                skipped.append(ev.get("testID"))
        elif ev.get("type") == "error" or ev.get("type") == "testDone" and ev.get("result") == "failure":
            failed.append(str(ev.get("testID") or ev.get("type")))
    executed = len({t for t in done}) - len(skipped)
    if returncode == 0 and not failed:
        status = "PASS"
    elif failed:
        status = "FAIL"
    else:
        status = "FAIL"
    if executed <= 0 and not failed and returncode == 0:
        status = "PASS"  # 全 skipped 视为通过（非本 target 范围）
    return {
        "test_status": status,
        "tests_seen": len(done),
        "skipped": len(skipped),
        "failed": len(failed),
    }


def run_target(target: str, device: str, platform: str, out_dir: Path):
    out_dir.mkdir(parents=True, exist_ok=True)
    started = time.time()
    log_path = out_dir / f"{Path(target).stem}.log"
    if platform == "android":
        cmd = [
            "patrol", "test", "--target", target, "--device", device,
            "--no-uninstall", *COMMON_DEFINES,
        ]
        env_prefix = dict(ORG_GRADLE_PROJECT_imboyE2eeTestAbi="armeabi-v7a",
                          ORG_GRADLE_PROJECT_imboyE2eeTestNoOrchestrator="true")
    else:
        cmd = ["flutter", "test", target, "-d", device, "--no-pub", *COMMON_DEFINES]
        env_prefix = {}
    import os
    env = {**os.environ, **env_prefix}
    try:
        proc = subprocess.run(cmd, cwd=ROOT, stdout=subprocess.PIPE,
                              stderr=subprocess.STDOUT, text=True, timeout=1800, env=env)
        out, code = proc.stdout or "", proc.returncode
    except subprocess.TimeoutExpired as e:
        out, code = (e.stdout or b"").decode(errors="replace") if isinstance(e.stdout, bytes) else (e.stdout or ""), 124
    log_path.write_text(out, encoding="utf-8")
    parsed = run_machine_events(out, code)
    # patrol 非 --machine：以日志特征兜底判定
    if platform == "android":
        if "All tests passed" in out or "passed!" in out:
            parsed["test_status"] = "PASS"
        elif "Some tests failed" in out or code != 0:
            parsed["test_status"] = parsed["test_status"] if parsed["failed"] else ("FAIL" if code != 0 else "PASS")
    return {
        "target": target,
        "platform": platform,
        "device": device[:12],
        "exit_code": code,
        "duration_s": round(time.time() - started, 1),
        "parsed": parsed,
        "log": log_path.name,
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--device", required=True)
    ap.add_argument("--platform", choices=("android", "macos"), required=True)
    ap.add_argument("--targets", required=True)
    ap.add_argument("--out", required=True)
    args = ap.parse_args()
    targets = json.loads(Path(args.targets).read_text())["targets"]
    out_dir = Path(args.out)
    results = []
    for t in targets:
        rec = run_target(t, args.device, args.platform, out_dir)
        results.append(rec)
        print(f"[{rec['parsed']['test_status']}] {t} {rec['duration_s']}s "
              f"skipped={rec['parsed']['skipped']}", flush=True)
    (out_dir / "results.json").write_text(json.dumps({
        "platform": args.platform, "device": args.device[:12],
        "targets": targets, "results": results,
    }, indent=2, ensure_ascii=False))
    statuses = [r["parsed"]["test_status"] for r in results]
    print(f"shard done: {statuses.count('PASS')} PASS / {len(statuses)} total")
    return 0 if all(s == "PASS" for s in statuses) else 1


if __name__ == "__main__":
    raise SystemExit(main())

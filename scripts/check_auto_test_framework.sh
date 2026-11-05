#!/usr/bin/env bash
# check_auto_test_framework.sh — imboyapp auto-test 框架统一验收 gate（Step 7）。
#
# 计划：docs/plans/2026-09-18-auto-test-framework-hardening-plan.md Step 7。
# 本脚本是本地与 CI（.github/workflows/quality.yml 的 auto-test-framework job）
# 的唯一框架验收入口：CI 与本地必须调用同一命令，不得复制第二套判断。
#
# 串行步骤（任一失败 => gate 退出非 0）：
#   1. Python tooling unit tests（含凭证/脱敏负向测试）
#   2. auto_test.py validate --strict
#   3. auto_test.py catalog --check
#   4. auto_test.py report 仓外连续生成一致（不要求提交报告）
#      + git diff --check
#   5. py_compile 全部控制面脚本
#   6. 框架自检（唯一 target / 假绿 / 凭证字段 / requirement 枚举 / catalog 页覆盖）
#   7. product-feature-manifest 只读校验当前产品生成物；缺源或漂移阻塞，
#      不重生成路由，不再强加历史 full-selected profile。
#
# 测试钩子（供 test/tooling/auto_test/test_gate.py 注入负向用例）：
#   AUTO_TEST_FRAMEWORK_NEGATIVE=<case>  =>  只运行框架自检的第 6 步，
#   case ∈ {missing_catalog_page, unknown_requirement, all_skip_fake_green,
#   target_conflict, credential_field}；注入必须使 gate 非零退出。
#   未设置该变量时行为零差异（完整串行 gate）。
#
# 退出码：0=框架验收通过；1=检查失败；2=环境/产品契约阻塞；64=用法错误。

set -uo pipefail

CHECKS_ONLY=false
case "${1:-}" in
  --checks-only) CHECKS_ONLY=true; shift ;;
  "") ;;
  *) echo "usage: $0 [--checks-only]" >&2; exit 64 ;;
esac
[ "$#" -eq 0 ] || { echo "unexpected arguments" >&2; exit 64; }

APP_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKEND_ROOT="${IMBOY_BACKEND_ROOT:-$APP_ROOT/../imboy}"
NEGATIVE="${AUTO_TEST_FRAMEWORK_NEGATIVE:-}"
AUTO_TEST_REPORT_ROOT="${AUTO_TEST_REPORT_ROOT:-$(mktemp -d "${TMPDIR:-/tmp}/imboyapp-auto-test.XXXXXX")}"
export AUTO_TEST_REPORT_ROOT
mkdir -p "$AUTO_TEST_REPORT_ROOT"
SUMMARY_PATH="${AUTO_TEST_FRAMEWORK_GATE_SUMMARY:-$AUTO_TEST_REPORT_ROOT/gate_summary.json}"
export AUTO_TEST_FRAMEWORK_NEGATIVE  # heredoc python 读取同一注入开关

KNOWN_NEGATIVE_CASES="missing_catalog_page unknown_requirement all_skip_fake_green target_conflict credential_field"

GENERATED_DOCS=(
  "$AUTO_TEST_REPORT_ROOT/AI_TEST_INDEX.md"
  "$AUTO_TEST_REPORT_ROOT/AI_COVERAGE_MATRIX.md"
  "$AUTO_TEST_REPORT_ROOT/AI_SPEC_BACKLOG.md"
)

CHECK_NAMES=()
CHECK_CODES=()
CHECK_DETAILS=()
DRIFT_STATUS="NOT_RUN"
DRIFT_DETAIL=""

record() { # <name> <code> <detail>
  CHECK_NAMES+=("$1"); CHECK_CODES+=("$2"); CHECK_DETAILS+=("$3")
  printf '[gate] %-26s %s %s\n' "$1" "$( [ "$2" -eq 0 ] && echo OK || echo "FAIL($2)" )" "$3"
}

sha_list() { # <files...> -> 每文件 sha256
  local f sum
  for f in "$@"; do
    if [ -f "$f" ]; then sum="$(shasum -a 256 "$f" | awk '{print $1}')"; else sum="MISSING"; fi
    printf '%s\n' "$sum"
  done
}

# ---------------------------------------------------------------------------
# 框架自检（第 6 步 / 负向注入目标）：真实判定函数 + 好坏两套输入
# ---------------------------------------------------------------------------
framework_selfcheck() {
  python3 - "$APP_ROOT" <<'PY'
import copy
import json
import os
import sys
from pathlib import Path

app_root = Path(sys.argv[1])
sys.path.insert(0, str(app_root / 'scripts'))
from auto_test_lib import cache as ca  # noqa: E402
from auto_test_lib import discovery, evidence as ev  # noqa: E402
from auto_test_lib import machine_events as me  # noqa: E402
from auto_test_lib import requirements as req  # noqa: E402
from auto_test_lib import result as rmod  # noqa: E402

case = os.environ.get('AUTO_TEST_FRAMEWORK_NEGATIVE', '')
problems = []

# --- 唯一 target / 冲突安全属性 -------------------------------------------
if case == 'target_conflict':
    specs = [
        {'id': 'A', 'runner': {'target': 'integration_test/x_test.dart', 'type': 'flutter', 'requires': []}, 'risk': 'device-readonly'},
        {'id': 'B', 'runner': {'target': 'integration_test/x_test.dart', 'type': 'flutter', 'requires': []}, 'risk': 'local-write'},
    ]
else:
    specs = discovery.load_specs(app_root)
_, conflicts = rmod.plan_unique_targets(specs)
if conflicts:
    problems.append('TARGET_CONFLICT_DETECTED: %s' % json.dumps(conflicts[0], ensure_ascii=False))

# --- 全 SKIP 假绿：claimed 状态必须与 machine events 重算一致 -------------
fixtures = app_root / 'test' / 'tooling' / 'auto_test' / 'fixtures' / 'machine_events'
if case == 'all_skip_fake_green':
    events_path, claimed = fixtures / 'all_skip.jsonl', 'PASS'  # 模拟旧 exit-code-only 判定
else:
    events_path, claimed = fixtures / 'pass.jsonl', 'PASS'
parsed = me.parse_machine_events(events_path.read_text(encoding='utf-8').splitlines(), process_exit_code=0)
if claimed == 'PASS' and parsed.test_status != 'PASS':
    problems.append('FAKE_GREEN_DETECTED: claimed PASS but events recompute to %s/%s' % (parsed.test_status, parsed.reason_code))

# --- 凭证字段：合法 evidence 不得被拒，含凭证字段名必须被拒 ---------------
environment = {'app_env': 'local', 'api_host': '127.0.0.1', 'ws_host': '127.0.0.1', 'backend_profile': 'fp-local'}
if case == 'credential_field':
    environment['api_key'] = 'SHOULD_BE_REJECTED'
sha = 'c' * 64
manifest = ev.build_evidence(
    run_id='gate-selfcheck', head='a' * 40, backend_head='d' * 40,
    target='integration_test/app_test.dart',
    result_dict={'status': 'PASS', 'executed': 1, 'skipped': 0, 'failed': 0},
    environment=environment,
    device={'id': 'REDACTED', 'platform': 'android', 'state_generation': 'gen-1'},
    fixture={'namespace': 'gate', 'marker': 'REDACTED', 'generation': 'gen-1', 'accounts': 'anon'},
    artifacts=[{'path': 'events.jsonl', 'sha256': sha}],
    dependency_closure={'algorithm': 'catalog-v1', 'manifest_path': 'closure.json',
                        'manifest_sha256': sha, 'content_sha256': sha},
    tested_tree_sha256=sha, catalog_sha256=sha, target_sha256=sha,
    runner_sha256=sha, config_sha256=sha, command_fingerprint=sha,
)
errors = ev.validate_evidence(manifest, requirements=['backend.local'])
if errors:
    problems.append('EVIDENCE_REJECTED: %s' % errors[0])

# --- requirement 有限枚举 --------------------------------------------------
requires = ['device.android', 'legacy_unknown.magic'] if case == 'unknown_requirement' \
    else ['device.android', 'backend.local']
spec = {'runner': {'requires': requires}, 'risk': 'device-readonly'}
req_errors = req.validate_requirements(spec)
if req_errors:
    problems.append('UNKNOWN_REQUIREMENT_LEAK: %s' % req_errors[0])

# --- catalog 页双向覆盖 ----------------------------------------------------
current = {
    'entries': [{'target': 'integration_test/a_test.dart'}],
    'pages': [{'page': 'lib/page/demo/demo_page.dart', 'route_registered': False}],
    'generated_from': {'integration_test_count': 1, 'lib_page_count': 1, 'module_page_count': 0},
}
disk = copy.deepcopy(current)
if case == 'missing_catalog_page':
    disk['pages'] = []  # 磁盘 catalog 缺失该页
issues = discovery.catalog_diff(current, disk)
if issues:
    problems.append('CATALOG_PAGE_DRIFT: %s' % issues[0])

# --- 共享 rebind 判定函数（A/local-write 必须拒绝）-------------------------
if ca.shared_reuse_gate('A', False, 'rebind') is None or ca.shared_reuse_gate('B', True, 'rebind') is None:
    problems.append('SHARED_REUSE_GATE_REFUSED_NOTHING')

if problems:
    for problem in problems:
        print('[selfcheck] %s' % problem, file=sys.stderr)
    sys.exit(1)
print('[selfcheck] ok (case=%r)' % case)
PY
}

# ---------------------------------------------------------------------------
# 负向注入 fast path：只跑第 6 步，注入必须让 gate 非零
# ---------------------------------------------------------------------------
if [ -n "$NEGATIVE" ]; then
  known=0
  for candidate in $KNOWN_NEGATIVE_CASES; do
    [ "$candidate" = "$NEGATIVE" ] && known=1
  done
  if [ "$known" -ne 1 ]; then
    printf '[gate] 未知注入用例: %s（可用: %s）\n' "$NEGATIVE" "$KNOWN_NEGATIVE_CASES" >&2
    exit 64
  fi
  if framework_selfcheck; then
    printf '[gate] 注入 %s 未被框架自检拒绝（INJECTION_NOT_DETECTED）\n' "$NEGATIVE" >&2
    exit 1
  fi
  printf '[gate] 注入 %s 按预期被拒绝\n' "$NEGATIVE"
  exit 1
fi

# ---------------------------------------------------------------------------
# 完整串行 gate（无注入时零差异）
# ---------------------------------------------------------------------------
cd "$APP_ROOT"

# 0. 全仓 Git 跟踪测试归属是硬门禁，不以业务测试已通过表述。
if python3 scripts/auto_test.py execution-check >"$AUTO_TEST_REPORT_ROOT/gate_ownership.log" 2>&1; then
  record "execution_ownership" 0 "$(tail -1 "$AUTO_TEST_REPORT_ROOT/gate_ownership.log")"
else
  record "execution_ownership" "$?" "log: $AUTO_TEST_REPORT_ROOT/gate_ownership.log"
fi

# 1. --checks-only 供统一执行计划使用：tooling 实例由计划执行一次。
# 单独调用 gate 仍执行全部已声明工具测试，避免 unittest 路径规则分叉。
if ! $CHECKS_ONLY; then
  TOOLING_PLATFORM="$(python3 -c 'import sys; print({"darwin": "macos", "win32": "windows"}.get(sys.platform, sys.platform))')"
  if python3 scripts/auto_test.py execution-run --profile tooling --platform "$TOOLING_PLATFORM" \
      --artifact-dir "$AUTO_TEST_REPORT_ROOT/tooling" >"$AUTO_TEST_REPORT_ROOT/gate_unittest.log" 2>&1; then
    record "tooling_unittest" 0 "$(tail -1 "$AUTO_TEST_REPORT_ROOT/gate_unittest.log")"
  else
    record "tooling_unittest" "$?" "log: $AUTO_TEST_REPORT_ROOT/gate_unittest.log"
  fi
fi

# 2. validate --strict
if python3 scripts/auto_test.py validate --strict >"$AUTO_TEST_REPORT_ROOT/gate_validate.log" 2>&1; then
  record "validate_strict" 0 "$(tail -1 "$AUTO_TEST_REPORT_ROOT/gate_validate.log")"
else
  record "validate_strict" "$?" "log: $AUTO_TEST_REPORT_ROOT/gate_validate.log"
fi

# 3. catalog --check
if python3 scripts/auto_test.py catalog --check >"$AUTO_TEST_REPORT_ROOT/gate_catalog.log" 2>&1; then
  record "catalog_check" 0 "$(tail -1 "$AUTO_TEST_REPORT_ROOT/gate_catalog.log")"
else
  record "catalog_check" "$?" "log: $AUTO_TEST_REPORT_ROOT/gate_catalog.log"
fi

# 4. report 生成物一致（regeneration 必须与磁盘字节一致）+ git diff --check
python3 scripts/auto_test.py report >"$AUTO_TEST_REPORT_ROOT/gate_report.log" 2>&1
report_code=$?
before="$(sha_list "${GENERATED_DOCS[@]}")"
if [ "$report_code" -eq 0 ]; then
  python3 scripts/auto_test.py report >>"$AUTO_TEST_REPORT_ROOT/gate_report.log" 2>&1
  report_code=$?
fi
after="$(sha_list "${GENERATED_DOCS[@]}")"
if [ "$report_code" -ne 0 ]; then
  record "generated_docs_check" "$report_code" "report 退出码 $report_code"
elif [ "$before" != "$after" ]; then
  record "generated_docs_check" 1 "仓外报告连续生成不一致"
elif git diff --check >"$AUTO_TEST_REPORT_ROOT/gate_diffcheck.log" 2>&1; then
  record "generated_docs_check" 0 "仓外报告生成一致; git diff --check 干净"
else
  record "generated_docs_check" "$?" "git diff --check 报告问题"
fi

# 5. py_compile
py_files=(scripts/auto_test.py scripts/capture_integration_screenshots.py scripts/auto_test_lib/*.py)
if python3 -m py_compile "${py_files[@]}" >"$AUTO_TEST_REPORT_ROOT/gate_pycompile.log" 2>&1; then
  record "py_compile" 0 "$(printf '%s 个控制面文件' "${#py_files[@]}")"
else
  record "py_compile" "$?" "log: $AUTO_TEST_REPORT_ROOT/gate_pycompile.log"
fi

# 6. 框架自检（无注入 => 全部正向用例）
if framework_selfcheck >"$AUTO_TEST_REPORT_ROOT/gate_selfcheck.log" 2>&1; then
  record "framework_selfcheck" 0 "$(tail -1 "$AUTO_TEST_REPORT_ROOT/gate_selfcheck.log")"
else
  record "framework_selfcheck" "$?" "log: $AUTO_TEST_REPORT_ROOT/gate_selfcheck.log"
fi

# 7. product-feature-manifest 漂移（只读；未验证则阻塞）
if [ ! -f "$BACKEND_ROOT/scripts/generate_product_features.py" ]; then
  DRIFT_STATUS="BLOCKED_PRODUCT_DRIFT"
  DRIFT_DETAIL="backend repo not available at $BACKEND_ROOT（CI 环境无 ../imboy；无法只读核对 profile 漂移）"
  printf 'BLOCKED_PRODUCT_DRIFT: %s\n' "$DRIFT_DETAIL"
  printf '[gate] %-26s ENV(-) %s（必需契约未验证）\n' "product_drift" "$DRIFT_DETAIL"
elif (cd "$BACKEND_ROOT" && python3 scripts/generate_product_features.py --check --app-dir "$APP_ROOT") >"$AUTO_TEST_REPORT_ROOT/gate_drift.log" 2>&1; then
  DRIFT_STATUS="OK"
  DRIFT_DETAIL="product feature manifest 与当前产品生成物一致"
  printf '[gate] %-26s OK %s\n' "product_drift" "$DRIFT_DETAIL"
else
  drift_code=$?
  DRIFT_STATUS="BLOCKED_PRODUCT_DRIFT"
  DRIFT_DETAIL="$(head -1 "$AUTO_TEST_REPORT_ROOT/gate_drift.log" | tr -d '\r')"
  printf 'BLOCKED_PRODUCT_DRIFT: %s\n' "$DRIFT_DETAIL"
  printf '[gate] %-26s ENV(%s) %s（必需契约未验证；不得重生成产品路由）\n' "product_drift" "$drift_code" "$DRIFT_DETAIL"
fi

# ---------------------------------------------------------------------------
# 汇总 + 退出码
# ---------------------------------------------------------------------------
overall=0
[ "$DRIFT_STATUS" = "OK" ] || overall=2
for code in "${CHECK_CODES[@]}"; do
  if [ "$code" -eq 2 ]; then
    [ "$overall" -ne 1 ] && overall=2
  elif [ "$code" -ne 0 ]; then
    overall=1
  fi
done

SUMMARY_PATH_DIR="$(dirname "$SUMMARY_PATH")"
mkdir -p "$SUMMARY_PATH_DIR"
SUMMARY_NAMES="${CHECK_NAMES[*]}" \
SUMMARY_CODES="${CHECK_CODES[*]}" \
SUMMARY_DETAILS="$(printf '%s\n' "${CHECK_DETAILS[@]}")" \
python3 - "$SUMMARY_PATH" "$overall" "$DRIFT_STATUS" "$DRIFT_DETAIL" "$NEGATIVE" <<'PY'
import json
import os
import sys
from pathlib import Path

path, overall, drift_status, drift_detail, negative = (
    sys.argv[1], int(sys.argv[2]), sys.argv[3], sys.argv[4], sys.argv[5],
)
names = os.environ['SUMMARY_NAMES'].split()
codes = [int(c) for c in os.environ['SUMMARY_CODES'].split()]
details = os.environ['SUMMARY_DETAILS'].splitlines()
summary = {
    'schema_version': 1,
    'gate': 'check_auto_test_framework.sh',
    'result': 'PASS' if overall == 0 else ('BLOCKED' if overall == 2 else 'FAIL'),
    'reason_code': 'ENV_MISSING' if overall == 2 else ('CHECK_FAILED' if overall else None),
    'negative_injection': negative or None,
    'checks': [
        {'name': name, 'exit_code': code, 'detail': detail}
        for name, code, detail in zip(names, codes, details)
    ],
    'environment': {
        'product_drift_status': drift_status,
        'product_drift_detail': drift_detail,
        'product_drift_is_gate_fatal': True,
    },
}
target = Path(path)
tmp = target.with_name(target.name + '.tmp.%d' % os.getpid())
tmp.write_text(json.dumps(summary, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
os.replace(tmp, target)
PY

printf '[gate] 总结: %s（明细: %s）\n' "$( [ $overall -eq 0 ] && echo PASS || { [ $overall -eq 2 ] && echo BLOCKED || echo FAIL; } )" "$SUMMARY_PATH"
exit "$overall"

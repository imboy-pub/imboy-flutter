#!/usr/bin/env bash
# IMBoy SQLite 迁移治理统一 Gate（WP6）
#
# 用法：
#   bash scripts/run_sqlite_migration_gate.sh --local   # 本地全量
#   bash scripts/run_sqlite_migration_gate.sh --ci      # CI（evidence 到 build/）
#
# 退出码契约（严格，不得把 BLOCKED 当 PASS）：
#   0   PASS（全部子项通过）
#   1   FAIL（任一子项失败）
#   2   BLOCKED / NOT_RUN（环境缺依赖导致某些子项未运行）
#   64  参数错误
#
# 子项失败不阻断后续子项；每项日志落 evidence 目录；最终汇总含
# PASS/FAIL/BLOCKED/N/A 与日志路径。
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

MODE="${1:-}"
case "$MODE" in
  --local) EVID_ROOT="$(mktemp -d /tmp/imboy-sqlite-gate.XXXXXX)" ;;
  --ci)    EVID_ROOT="$REPO_ROOT/build/sqlite-migration-gate"; mkdir -p "$EVID_ROOT" ;;
  *) echo "usage: $0 --local | --ci"; exit 64 ;;
esac

PASS_COUNT=0
FAIL_COUNT=0
BLOCKED_COUNT=0
FAILED_ITEMS=""
BLOCKED_ITEMS=""

# run_item <名称> <命令...>（不支持 shell 管道；需要时用 bash -c）
run_item() {
  local name="$1"; shift
  local log="$EVID_ROOT/${name// /_}.log"
  if "$@" >"$log" 2>&1; then
    PASS_COUNT=$((PASS_COUNT+1))
    printf '  PASS  %s\n' "$name"
  else
    local rc=$?
    if [ "$rc" -eq 2 ]; then
      BLOCKED_COUNT=$((BLOCKED_COUNT+1)); BLOCKED_ITEMS="$BLOCKED_ITEMS $name"
      printf '  BLOCK %s (exit 2, log: %s)\n' "$name" "$log"
    else
      FAIL_COUNT=$((FAIL_COUNT+1)); FAILED_ITEMS="$FAILED_ITEMS $name"
      printf '  FAIL  %s (exit %s, log: %s)\n' "$name" "$rc" "$log"
    fi
  fi
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "BLOCKED: required command '$1' not found" | tee "$EVID_ROOT/blocked.log"
    exit 2
  }
}

echo "== IMBoy SQLite migration gate ($MODE) =="
echo "evidence: $EVID_ROOT"
date

require_cmd flutter
require_cmd dart

# ---------- 1. 生成器一致性（manifest 单一真源） ----------
run_item "01_generator_check" \
  dart run tool/generate_sqlite_migrations.dart --check

# ---------- 2. 静态分析（仅本治理拥有的文件面；全仓 test/ 有存量
# analyze info 基线（非本任务的既有文件），拉进来只会制造噪音） ----------
run_item "02_dart_analyze" \
  dart analyze lib/service tool/generate_sqlite_migrations.dart test/fixtures/sqlite_migration \
  integration_test/sqlite_migration \
  test/unit_test/service/migration_script_planner_test.dart \
  test/unit_test/service/migration_missing_path_test.dart \
  test/unit_test/service/migration_manifest_test.dart \
  test/unit_test/service/migration_atomic_failure_test.dart \
  test/unit_test/service/migration_baseline_inventory_test.dart \
  test/unit_test/service/migration_service_v25_test.dart \
  test/unit_test/service/migration_downgrade_v19_to_v25_test.dart \
  test/unit_test/service/migration_downgrade_v19_to_v25_exec_test.dart \
  test/unit_test/service/embedded_schema_asset_sync_test.dart \
  test/unit_test/service/db_migration_encryption_test.dart \
  test/unit_test/service/sqlite_uid_isolation_test.dart \
  test/unit_test/service/schema_fingerprint_test.dart \
  test/unit_test/service/schema_contract_test.dart \
  test/unit_test/service/database_snapshot_service_test.dart \
  test/unit_test/service/database_migration_orchestrator_test.dart \
  test/unit_test/integration/sqlite_migration_matrix_test.dart \
  test/unit_test/integration/db_multi_version_upgrade_test.dart \
  test/unit_test/integration/db_multi_version_downgrade_test.dart \
  test/unit_test/integration/db_downgrade_v10_to_v9_test.dart \
  test/unit_test/integration/db_v30_channel_has_purchased_test.dart \
  test/unit_test/integration/db_v25_msg_c2c_sender_did_test.dart

# ---------- 3. 核心单元/契约测试 ----------
run_item "03_planner_fail_fast" \
  flutter test test/unit_test/service/migration_script_planner_test.dart test/unit_test/service/migration_missing_path_test.dart --reporter compact

run_item "04_manifest_contract" \
  flutter test test/unit_test/service/migration_manifest_test.dart --reporter compact

run_item "05_atomic_failure" \
  flutter test test/unit_test/service/migration_atomic_failure_test.dart --reporter compact

run_item "06_baseline_inventory" \
  flutter test test/unit_test/service/migration_baseline_inventory_test.dart --reporter compact

run_item "07_schema_fingerprint" \
  flutter test test/unit_test/service/schema_fingerprint_test.dart --reporter compact

run_item "08_schema_contract_golden" \
  flutter test test/unit_test/service/schema_contract_test.dart --reporter compact

run_item "09_snapshot_service" \
  flutter test test/unit_test/service/database_snapshot_service_test.dart --reporter compact

run_item "10_orchestrator" \
  flutter test test/unit_test/service/database_migration_orchestrator_test.dart --reporter compact

# ---------- 4. 全矩阵与既有迁移回归 ----------
run_item "11_migration_matrix" \
  flutter test test/unit_test/integration/sqlite_migration_matrix_test.dart --reporter compact

run_item "12_legacy_migration_regression" \
  flutter test \
    test/unit_test/service/migration_downgrade_v19_to_v25_test.dart \
    test/unit_test/service/migration_downgrade_v19_to_v25_exec_test.dart \
    test/unit_test/service/migration_service_v25_test.dart \
    test/unit_test/service/embedded_schema_asset_sync_test.dart \
    test/unit_test/service/db_migration_encryption_test.dart \
    test/unit_test/service/sqlite_uid_isolation_test.dart \
    test/unit_test/integration/db_multi_version_upgrade_test.dart \
    test/unit_test/integration/db_multi_version_downgrade_test.dart \
    test/unit_test/integration/db_downgrade_v10_to_v9_test.dart \
    test/unit_test/integration/db_v30_channel_has_purchased_test.dart \
    test/unit_test/integration/db_v25_msg_c2c_sender_did_test.dart \
    --reporter compact

# ---------- 5. 仓库卫生 ----------
run_item "13_git_diff_check" git diff --check

# ---------- 汇总 ----------
echo
echo "== SUMMARY =="
echo "PASS:     $PASS_COUNT"
echo "FAIL:     $FAIL_COUNT"
echo "BLOCKED:  $BLOCKED_COUNT"
[ -n "$FAILED_ITEMS" ]  && echo "failed items:$FAILED_ITEMS"
[ -n "$BLOCKED_ITEMS" ] && echo "blocked items:$BLOCKED_ITEMS"
echo "logs: $EVID_ROOT"

if [ "$FAIL_COUNT" -gt 0 ]; then
  exit 1
elif [ "$BLOCKED_COUNT" -gt 0 ]; then
  exit 2
else
  echo "RESULT: PASS"
  exit 0
fi

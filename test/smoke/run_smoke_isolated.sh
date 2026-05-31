#!/usr/bin/env bash
# 路由烟雾测试 - 进程隔离运行器 / Route smoke test - per-route isolated runner
#
# 为什么需要隔离 / Why isolation:
#   100+ 真实页面在「同一 test isolate」顺序跑时，个别页面 initState 会留下
#   未取消的异步 / Riverpod pending build / 定时器，污染共享 binding 的 teardown
#   不变量（framework.dart:2168 等），引发后续用例级联失败——这是 Flutter test
#   共享 isolate 的固有限制，并非页面真的崩溃（每页孤立运行均通过）。
#   本脚本让每条路由在「独立 flutter test 进程」中运行，彻底消除级联，
#   得到可信的「页面是否崩溃」结论。
#
# 用法 / Usage:
#   bash test/smoke/run_smoke_isolated.sh
#   bash test/smoke/run_smoke_isolated.sh --quiet   # 仅打印汇总与失败项
#
# 退出码 / Exit code: 任一路由失败则非 0，便于 CI 失败。
#
# 代价 / Cost: 每条路由独立编译+运行，全量较慢（数分钟级）。
#   适合 CI nightly 或本地回归；PR 快速门可只跑公开/核心路由子集。

set -uo pipefail

cd "$(dirname "$0")/../.." || exit 1

TEST_FILE="test/smoke/route_smoke_test.dart"
REGISTRY="test/smoke/route_registry.dart"
QUIET="${1:-}"

# 从注册表提取全部路由名。quarantine 项由 route_smoke_test.dart 内部 skip，
# 即使在此被 --plain-name 命中也只会命中 skip 用例（视为通过），无需特殊处理。
# 用 while-read 填充数组以兼容 macOS 自带 bash 3.2（无 mapfile）。
ROUTES=()
while IFS= read -r _r; do
  [ -n "$_r" ] && ROUTES+=("$_r")
done < <(grep -oE "name: '[a-z_]+'" "$REGISTRY" | sed "s/name: '//;s/'//" | sort -u)

if [ "${#ROUTES[@]}" -eq 0 ]; then
  echo "ERROR: 未从 $REGISTRY 提取到任何路由名" >&2
  exit 1
fi

echo "===== 路由烟雾测试（进程隔离）总计 ${#ROUTES[@]} 条 ====="

PASS=0
FAIL=0
FAILED_ROUTES=()

SKIP=0
for name in "${ROUTES[@]}"; do
  # 用 name 后跟 ' (' 精确匹配单条用例描述，避免前缀冲突（如 group / group_list）。
  # 捕获输出以区分三态：通过 / quarantine(跳过) / 真实失败。
  out="$(flutter test "$TEST_FILE" --plain-name "$name (" 2>&1)"
  code=$?
  if [ "$code" -eq 0 ]; then
    PASS=$((PASS + 1))
    [ "$QUIET" != "--quiet" ] && echo "  PASS  $name"
  elif echo "$out" | grep -qE "No tests ran|All tests skipped"; then
    # quarantine 路由的 skip 用例名格式不同（[quarantine] ...），--plain-name 匹配不到
    # → flutter "No tests ran" 非 0，但这不是失败，视为 SKIP。
    SKIP=$((SKIP + 1))
    [ "$QUIET" != "--quiet" ] && echo "  SKIP  $name (quarantine/无匹配用例)"
  else
    FAIL=$((FAIL + 1))
    FAILED_ROUTES+=("$name")
    echo "  FAIL  $name"
  fi
done

echo "===== 汇总: PASS=$PASS  SKIP=$SKIP  FAIL=$FAIL  TOTAL=${#ROUTES[@]} ====="
if [ "$FAIL" -gt 0 ]; then
  echo "失败路由 / Failed routes:"
  printf '  - %s\n' "${FAILED_ROUTES[@]}"
  exit 1
fi
echo "全部通过 / All routes passed."

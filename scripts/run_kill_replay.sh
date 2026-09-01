#!/usr/bin/env bash
# kill_replay 两阶段编排：prepare（种子+等 kill_ready 信号）→ force-stop → verify。
# 实证：KILLED_ROLLED_BACK quick_check=ok rowsPreserved=true（2026-09-01 健康检查）。
#
# 用法：
#   bash scripts/run_kill_replay.sh [device_serial] [attempt]
#   默认 device=XWE6R19916004085 attempt=1
#
# 依赖：flutter、adb 在 PATH；测试文件
#   integration_test/sqlite_migration/sqlite_migration_kill_replay_test.dart
# 独立命名空间：db 位于应用 support 目录 imboy_wp7_kill/ 下，不触碰真实账号数据库。

set -uo pipefail

DEVICE="${1:-XWE6R19916004085}"
ATTEMPT="${2:-1}"
TEST_FILE="integration_test/sqlite_migration/sqlite_migration_kill_replay_test.dart"
LOG_DIR="/tmp/kill_replay"
mkdir -p "$LOG_DIR"

echo "[1/3] prepare 阶段（后台），等待 kill_ready 信号…"
flutter test "$TEST_FILE" \
  --dart-define=APP_ENV=local \
  --dart-define=KILL_PHASE=prepare \
  --dart-define=KILL_ATTEMPT="$ATTEMPT" \
  -d "$DEVICE" > "$LOG_DIR/prepare.log" 2>&1 &
FPID=$!

KILLED=0
for _ in $(seq 1 60); do
  sleep 3
  if grep -q "step=kill_ready" "$LOG_DIR/prepare.log" 2>/dev/null; then
    echo "    收到 kill_ready 信号，force-stop $DEVICE 上的应用…"
    adb -s "$DEVICE" shell am force-stop pub.imboy.app
    KILLED=1
    sleep 3
    kill "$FPID" 2>/dev/null
    break
  fi
  # prepare 阶段自身失败（未出信号就退出）时提前结束，避免空等
  if ! kill -0 "$FPID" 2>/dev/null; then
    echo "    ✗ prepare 进程在 kill_ready 之前退出（未击杀），日志：$LOG_DIR/prepare.log"
    exit 1
  fi
done

if [ "$KILLED" != "1" ]; then
  echo "    ✗ 180 秒内未出现 kill_ready 信号，放弃。日志：$LOG_DIR/prepare.log"
  kill "$FPID" 2>/dev/null
  exit 1
fi

echo "[2/3] prepare 已击杀，等待设备与应用状态稳定…"
sleep 5

echo "[3/3] verify 阶段：回读校验回滚完整性与行数保全…"
flutter test "$TEST_FILE" \
  --dart-define=APP_ENV=local \
  --dart-define=KILL_PHASE=verify \
  --dart-define=KILL_ATTEMPT="$ATTEMPT" \
  -d "$DEVICE" > "$LOG_DIR/verify.log" 2>&1
VERIFY_EXIT=$?

grep -a "WP7-EVIDENCE" "$LOG_DIR/verify.log" | sed 's/\x1b\[[0-9;]*m//g' | tail -2
if [ $VERIFY_EXIT -eq 0 ]; then
  echo "✓ kill_replay attempt=$ATTEMPT 通过（KILLED_ROLLED_BACK，行数保全）"
else
  echo "✗ verify 失败（exit=$VERIFY_EXIT），日志：$LOG_DIR/verify.log"
fi
exit $VERIFY_EXIT

#!/usr/bin/env bash
# run_all_integration_tests.sh — 已退役的旧入口，收编为统一 runner 兼容壳。
#
# Step 7（docs/plans/2026-09-18-auto-test-framework-hardening-plan.md）：
# 本脚本曾自带第二套 runner 逻辑（固定设备 ID、远程生产 API 地址、内置账号
# 默认值、按日志关键词判定 PASS），全部删除。真机集成测试统一由
# scripts/run_test_suite.sh 编排，结果判定由 machine events 完成，框架验收由
# scripts/check_auto_test_framework.sh 完成。
#
# 兼容行为：把参数原样转发给统一 runner 并透传退出码。
# 设备/凭证/目标一律来自显式环境变量或 --device 参数，本脚本不提供任何默认值。

set -uo pipefail

APP_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "run_all_integration_tests.sh 已退役：转发到统一 runner scripts/run_test_suite.sh" >&2
echo "（旧固定设备/远程生产地址/账号默认值与日志关键词 PASS 判定已删除）" >&2

exec bash "$APP_ROOT/scripts/run_test_suite.sh" --mode full "$@"

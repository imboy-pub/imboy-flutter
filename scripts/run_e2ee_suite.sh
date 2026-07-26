#!/usr/bin/env bash
# E2EE 客户端安全验证套件（一键可审计）
# 用法: bash scripts/run_e2ee_suite.sh
# 前置: flutter pub get && dart pub global activate protoc_plugin (可选)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

echo "=== IMBoy E2EE 客户端安全验证套件 ==="
echo ""

# 1. 静态分析
echo "--- [1/3] dart analyze (E2EE 相关) ---"
dart analyze lib/service/e2ee/ lib/service/protocol/ --fatal-infos
echo "[OK] 静态分析零警告"
echo ""

# 2. E2EE 单元测试套件
echo "--- [2/3] flutter test test/service/e2ee/ ---"
flutter test test/service/e2ee/ --reporter compact
echo ""

# 3. 协议集成测试
echo "--- [3/3] flutter test test/service/protocol/ ---"
if ls test/service/protocol/*_test.dart 1>/dev/null 2>&1; then
    flutter test test/service/protocol/ --reporter compact
else
    echo "[SKIP] 无 protocol 测试文件"
fi
echo ""

echo "=== E2EE 客户端验证全部通过 ==="

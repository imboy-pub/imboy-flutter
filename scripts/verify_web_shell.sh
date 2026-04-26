#!/usr/bin/env bash
# Web Shell 模块健康度一键验证脚本
#
# 用法 / Usage:
#   ./scripts/verify_web_shell.sh           # 完整验证（推荐 reviewer 使用）
#   ./scripts/verify_web_shell.sh --quick   # 快速模式（跳过 build web）
#   ./scripts/verify_web_shell.sh --no-server  # 不启动 http server
#
# 验证项 / Checks:
#   1. flutter analyze lib/page/web_shell/ test/page/web_shell/    (静态分析零警告)
#   2. flutter test test/page/web_shell/                           (12 个 _test.dart 文件)
#   3. flutter build web --release --no-tree-shake-icons           (完整构建)
#   4. python3 -m http.server 9820 (build/web)                     (烟雾测试 server)
#
# 退出码 / Exit codes:
#   0  全部通过
#   1  analyze 报错
#   2  测试失败
#   3  build web 失败
#   4  环境检查失败（flutter / dart 不可用）

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

QUICK=false
START_SERVER=true
for arg in "$@"; do
  case "$arg" in
    --quick) QUICK=true ;;
    --no-server) START_SERVER=false ;;
    --help|-h)
      grep '^#' "$0" | sed 's/^# \?//'
      exit 0
      ;;
  esac
done

cd "$PROJECT_DIR"

# ─── 环境检查 / Environment check ──────────────────────────
echo "==> [1/4] 环境检查 / Environment check"
if ! command -v flutter >/dev/null 2>&1; then
  echo "❌ flutter 命令不可用 / flutter command not found" >&2
  exit 4
fi
flutter --version | head -1
echo ""

# ─── flutter analyze ─────────────────────────────────────
echo "==> [2/4] flutter analyze (web_shell 模块)"
if flutter analyze lib/page/web_shell/ test/page/web_shell/ --no-fatal-infos; then
  echo "✅ analyze 零警告 / clean"
else
  echo "❌ analyze 失败 / failed" >&2
  exit 1
fi
echo ""

# ─── flutter test (web_shell only) ────────────────────────
echo "==> [3/4] flutter test (web_shell 模块, 应有 226 测全绿)"
if flutter test test/page/web_shell/ --reporter compact; then
  echo "✅ web_shell 测试全绿 / tests pass"
else
  echo "❌ 测试失败 / tests failed" >&2
  exit 2
fi
echo ""

# ─── flutter build web (跳过 quick 模式) ────────────────────
if [ "$QUICK" = "true" ]; then
  echo "==> [4/4] flutter build web — 已跳过 (--quick 模式)"
else
  echo "==> [4/4] flutter build web --release（首次约 60-75s, 增量更快）"
  if flutter build web --release --no-tree-shake-icons; then
    BUILD_SIZE=$(du -sh build/web 2>/dev/null | cut -f1)
    JS_SIZE=$(stat -f "%z" build/web/main.dart.js 2>/dev/null || stat -c "%s" build/web/main.dart.js 2>/dev/null)
    echo "✅ build web 成功 / built: build/web ($BUILD_SIZE, main.dart.js=$JS_SIZE bytes)"
  else
    echo "❌ build web 失败 / failed" >&2
    exit 3
  fi
fi
echo ""

# ─── HTTP server (烟雾测试 / smoke server) ─────────────────
if [ "$START_SERVER" = "true" ] && [ "$QUICK" != "true" ]; then
  echo "==> 启动 HTTP server 在 :9820 (Ctrl+C 停止)"
  echo "    浏览器访问: http://localhost:9820/"
  echo "    验证项: 1) 不白屏 2) 看到 WebLoginPage 3) F12 控制台无致命错误"
  echo ""
  cd build/web
  python3 -m http.server 9820 || python -m http.server 9820
fi

echo "✅ 全部验证通过 / all checks passed"

#!/usr/bin/env bash
# 全仓 Git 跟踪测试归属硬门禁。旧 workflow 路径参数仅作存在性兼容检查。
set -euo pipefail
APP_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$APP_ROOT"
if [[ "$#" -gt 1 ]]; then
  echo "usage: $0 [workflow-path]" >&2; exit 64
fi
if [[ "$#" -eq 1 && ! -f "$1" ]]; then
  echo "workflow not found: $1" >&2; exit 1
fi
exec python3 scripts/auto_test.py execution-check

#!/usr/bin/env bash
# IMBoy 文件行数 ratchet 门（APP-02，2026-08-29）
#
# 编码规范（AGENTS.md / CLAUDE.md）：Dart 源文件 < 800 行。存量 117 个文件
# 已超限（最大 5057 行，test/unit_test/store/attachment_upload_task_recovery_test.dart）——本门不做
# 存量拆分，只防新增债务：
#   1) 新文件超过 800 行 → FAIL（不在基线）；
#   2) 基线内文件行数**增长** → FAIL（只许减不许增）；
#   3) 行数减少 / 跌破 800 → 不失败，打印可收紧提示。
#
# 范围：git 跟踪的 *.dart；排除 codegen 产物（.g/.freezed/.gr/.pb*）、
# plugin/**（保留区）、build/、.dart_tool/。
#
# 用法：
#   bash scripts/quality/check_file_size_ratchet.sh                     # 检查
#   bash scripts/quality/check_file_size_ratchet.sh --update-baseline   # 重采基线
#
# 退出码契约（对齐 check_analyzer_ratchet.sh）：
#   0 PASS / 1 FAIL / 2 BLOCKED（git 不可用 / 基线缺失）/ 64 参数错误
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

SCRIPT_REL="scripts/quality/check_file_size_ratchet.sh"
BASELINE="$REPO_ROOT/scripts/quality/file_size_baseline.txt"
MAX_LINES=800

MODE="check"
case "${1:-}" in
  "")                 MODE="check"  ;;
  --update-baseline)  MODE="update" ;;
  *)  echo "usage: bash $SCRIPT_REL [--update-baseline]"; exit 64 ;;
esac

command -v git >/dev/null 2>&1 || { echo "BLOCKED: command 'git' not found"; exit 2; }

# git 跟踪 + 未跟踪未忽略的 Dart 文件（新文件在 commit 前也能被本地检查拦住），
# 排除生成物与保留区；输出 count<TAB>file（仅超限文件）
collect_oversized() {
  local files
  files="$(git ls-files --cached --others --exclude-standard --deduplicate '*.dart' \
    | grep -vE '(\.g\.dart|\.freezed\.dart|\.gr\.dart|\.pb\.dart|\.pbenum\.dart|\.pbjson\.dart|\.pbserver\.dart|^plugin/|^build/|^\.dart_tool/)' \
    | grep -v '^$' || true)"
  [ -z "$files" ] && return 0
  printf '%s\n' "$files" | tr '\n' '\0' | xargs -0 wc -l \
    | awk -v max="$MAX_LINES" '$1 > max && $2 != "total" { print $1 "\t" $2 }' \
    | sort -t$'\t' -k2,2
}

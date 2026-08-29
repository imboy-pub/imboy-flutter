#!/usr/bin/env bash
# IMBoy 文件行数 ratchet 门（APP-02，2026-08-29）
#
# 编码规范（AGENTS.md / CLAUDE.md）：Dart 源文件 < 800 行。存量 47 个文件
# 已超限（最大 2726 行，lib/page/chat/chat/chat_page.dart）——本门不做
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

CURRENT="$(collect_oversized)"
CUR_COUNT=$(printf '%s\n' "$CURRENT" | awk 'NF' | wc -l | tr -d ' ')

# ---------- --update-baseline：重采基线 ----------
if [ "$MODE" = "update" ]; then
  {
    echo "# IMBoy 文件行数 ratchet 基线（门脚本生成，勿手改）"
    echo "# 再生成：bash $SCRIPT_REL --update-baseline"
    echo "# 日期：$(date +%F)"
    echo "# 格式：count<TAB>file ｜ 上限 ${MAX_LINES} 行 ｜ 只许减不许增"
    [ -n "$CURRENT" ] && printf '%s\n' "$CURRENT"
  } > "$BASELINE"
  echo "基线已更新：${BASELINE}（超限文件 ${CUR_COUNT} 个）"
  exit 0
fi

# ---------- check ----------
[ -f "$BASELINE" ] || {
  echo "BLOCKED: 基线缺失 ${BASELINE}，先跑: bash $SCRIPT_REL --update-baseline"
  exit 2
}

baseline_count_of() {
  awk -F'\t' -v f="$1" 'NF >= 2 && $1 !~ /^#/ && $2 == f { n = $1 } END { print (n + 0) }' \
    "$BASELINE"
}
current_count_of() {
  printf '%s\n' "$CURRENT" | awk -F'\t' -v f="$1" '$2 == f { n = $1 } END { print (n + 0) }'
}

BASE_COUNT=$(awk 'NF >= 2 && $1 !~ /^#/' "$BASELINE" | wc -l | tr -d ' ')
echo "上限 ${MAX_LINES} 行 ｜ 当前超限文件 $CUR_COUNT 个 ｜ 基线 $BASE_COUNT 个"

# 1) FAIL：新超限文件（基线=0）或基线内文件行数增长
FAIL_TOTAL=0
REGRESS=""
while IFS=$'\t' read -r cnt file; do
  [ -z "${file:-}" ] && continue
  base=$(baseline_count_of "$file")
  if [ "$base" -eq 0 ]; then
    REGRESS="${REGRESS}NEW"$'\t'"${file}"$'\t'"${cnt}"$'\t'"${base}"$'\n'
    FAIL_TOTAL=$((FAIL_TOTAL + 1))
  elif [ "$cnt" -gt "$base" ]; then
    REGRESS="${REGRESS}GROW"$'\t'"${file}"$'\t'"${cnt}"$'\t'"${base}"$'\n'
    FAIL_TOTAL=$((FAIL_TOTAL + 1))
  fi
done <<EOF
$CURRENT
EOF

if [ "$FAIL_TOTAL" -gt 0 ]; then
  echo
  echo "RESULT: FAIL —— $FAIL_TOTAL 个文件违反行数 ratchet："
  while IFS=$'\t' read -r tag file cnt base; do
    [ -z "${file:-}" ] && continue
    if [ "$tag" = "NEW" ]; then
      echo "  +NEW  ${file}（${cnt} 行 > ${MAX_LINES}，不在基线）"
    else
      echo "  +GROW ${file}（基线 ${base:-0} → ${cnt} 行，只许减不许增）"
    fi
  done <<EOF
$REGRESS
EOF
  echo
  echo "请拆分文件 / 下沉逻辑；确属有意接受时重采基线并随代码同一提交 review："
  echo "  bash $SCRIPT_REL --update-baseline"
  exit 1
fi

# 2) 收紧提示：基线内文件行数下降或跌破上限被移除
SHRUNK=""
while IFS=$'\t' read -r bcnt bfile; do
  case "$bfile" in ""|\#*) continue ;; esac
  cur=$(current_count_of "$bfile")
  if [ "$cur" -eq 0 ]; then
    SHRUNK="${SHRUNK}  $bfile: 已降至 ${MAX_LINES} 行以内（基线 ${bcnt}）→ 可从基线移除"$'\n'
  elif [ "$cur" -lt "$bcnt" ]; then
    SHRUNK="${SHRUNK}  $bfile: 基线 $bcnt → 当前 $cur 行"$'\n'
  fi
done < "$BASELINE"
[ -n "$SHRUNK" ] && {
  echo "提示：以下文件行数较基线减少，可用 --update-baseline 收紧："
  printf '%s' "$SHRUNK"
}

echo "RESULT: PASS（无新增超限、无超限文件增长）"
exit 0

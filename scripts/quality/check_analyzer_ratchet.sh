#!/usr/bin/env bash
# IMBoy 全仓 analyzer ratchet 门（APP-02，2026-08-29）
#
# 背景：全仓 flutter analyze 已于 APP-02 清零（159 → 0，基线含 1 error /
# 63 warning / 95 info）。本门锁定零基线：基线外**新增 1 条即 FAIL**；
# 基线内条数减少不报错（打印可收紧提示）。与既有
# check_analyze_increment.sh（仅双体验功能目录）互补：本门覆盖全仓。
#
# 数据源：dart analyze --format=machine（flutter analyze 无 --format 参数；
# dart analyze 与 flutter analyze 共用同一 analysis_options.yaml 与 analyzer）。
# 机器格式行：SEVERITY|TYPE|CODE|FILE|LINE|COL|LENGTH|MESSAGE
# 问题指纹 = (severity, 规则代码, 文件) + 条数；**不记行号**（行号随编辑漂移）。
#
# 用法：
#   bash scripts/quality/check_analyzer_ratchet.sh                     # 检查
#   bash scripts/quality/check_analyzer_ratchet.sh --update-baseline   # 重采基线
#
# 退出码契约（对齐 run_sqlite_migration_gate.sh / check_analyze_increment.sh）：
#   0   PASS（无基线外新增；条数减少仅提示收紧，不失败）
#   1   FAIL（出现基线外 / 超量的 (severity, code, file) 组合）
#   2   BLOCKED（dart 不可用 / 依赖未装 / analyze 未正常完成 / 基线缺失）
#   64  参数错误
#
# CI 接入：.github/workflows/quality.yml 的 flutter-analyze job
# （Get dependencies 之后追加一步调用本脚本）。
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

SCRIPT_REL="scripts/quality/check_analyzer_ratchet.sh"
BASELINE="$REPO_ROOT/scripts/quality/analyzer_ratchet_baseline.txt"

MODE="check"
case "${1:-}" in
  "")                 MODE="check"  ;;
  --update-baseline)  MODE="update" ;;
  *)  echo "usage: bash $SCRIPT_REL [--update-baseline]"; exit 64 ;;
esac

command -v dart >/dev/null 2>&1 || { echo "BLOCKED: command 'dart' not found"; exit 2; }
[ -f ".dart_tool/package_config.json" ] || {
  echo "BLOCKED: .dart_tool/package_config.json 缺失（需先 flutter pub get）"
  exit 2
}

TMP_RAW="$(mktemp /tmp/imboy-analyzer-ratchet.XXXXXX)"
trap 'rm -f "$TMP_RAW"' EXIT

echo "== dart analyze --format=machine（全仓） =="
# dart analyze 退出码：0=无问题，2=发现 warning 级，3=发现 error 级
# （均为正常完成）；其余值（1=用法/致命错误等）视为 BLOCKED。
set +e
dart analyze --format=machine >"$TMP_RAW" 2>&1
ANALYZE_EXIT=$?
set -e
if [ "$ANALYZE_EXIT" -ne 0 ] && [ "$ANALYZE_EXIT" -ne 2 ] && [ "$ANALYZE_EXIT" -ne 3 ]; then
  echo "BLOCKED: dart analyze 异常退出（exit=${ANALYZE_EXIT}），输出尾部："
  tail -5 "$TMP_RAW"
  exit 2
fi

# 聚合当前问题 → stdout：count<TAB>severity|code|file（排序）。
# 机器行 severity 取值 ERROR/WARNING/INFO；FILE 归一为仓库相对路径
# （dart analyze 可能输出绝对路径或 ./ 前缀路径，跨机器/CI 需统一）。
aggregate_current() {
  awk -F'|' -v root="$REPO_ROOT/" '
    $1 == "ERROR" || $1 == "WARNING" || $1 == "INFO" {
      file = $4
      sub("^" root, "", file)
      sub(/^\.\//, "", file)
      print $1 "|" $3 "|" file
    }' "$TMP_RAW" | sort | uniq -c | awk '{print $1 "\t" $2}' | sort -t$'\t' -k2,2
}

# 基线中指纹的条数；缺省 0
baseline_count_of() {
  awk -F'\t' -v k="$1" 'NF >= 2 && $1 !~ /^#/ && $2 == k { n = $1 } END { print (n + 0) }' \
    "$BASELINE" 2>/dev/null
}

# 当前结果中指纹的条数；缺省 0
current_count_of() {
  printf '%s\n' "$CURRENT" | awk -F'\t' -v k="$1" '$2 == k { n = $1 } END { print (n + 0) }'
}

CURRENT="$(aggregate_current)"
CUR_GROUPS=$(printf '%s\n' "$CURRENT" | awk 'NF' | wc -l | tr -d ' ')

# ---------- --update-baseline：重采基线 ----------
if [ "$MODE" = "update" ]; then
  {
    echo "# IMBoy 全仓 analyzer ratchet 基线（门脚本生成，勿手改）"
    echo "# 再生成：bash $SCRIPT_REL --update-baseline"
    echo "# 日期：$(date +%F) ｜ $(dart --version 2>&1 | head -1)"
    echo "# 格式：count<TAB>severity|code|file（指纹=(severity,规则代码,文件)；不记行号）"
    [ -n "$CURRENT" ] && printf '%s\n' "$CURRENT"
  } > "$BASELINE"
  echo "基线已更新：${BASELINE}（${CUR_GROUPS} 组，共 $(printf '%s\n' "$CURRENT" | awk 'NF{s+=$1} END{print s+0}') 条）"
  exit 0
fi

# ---------- check：与基线比对 ----------
[ -f "$BASELINE" ] || {
  echo "BLOCKED: 基线缺失 ${BASELINE}，先跑: bash $SCRIPT_REL --update-baseline"
  exit 2
}
BASE_GROUPS=$(awk 'NF >= 2 && $1 !~ /^#/' "$BASELINE" | wc -l | tr -d ' ')
BASE_TOTAL=$(awk -F'\t' 'NF >= 2 && $1 !~ /^#/ {s += $1} END {print s + 0}' "$BASELINE")
CUR_TOTAL=$(printf '%s\n' "$CURRENT" | awk -F'\t' 'NF >= 2 {s += $1} END {print s + 0}')
echo "当前问题组合 $CUR_GROUPS 组 / 共 $CUR_TOTAL 条 ｜ 基线 $BASE_GROUPS 组 / 共 $BASE_TOTAL 条"

# 1) 超限检测：当前任一指纹条数 > 基线 → FAIL（基线外组合基线数为 0，天然 FAIL）
FAIL_COUNT=0
REGRESS=""
while IFS=$'\t' read -r cnt key; do
  [ -z "${key:-}" ] && continue
  base=$(baseline_count_of "$key")
  if [ "$cnt" -gt "$base" ]; then
    REGRESS="${REGRESS}${key}"$'\t'"${cnt}"$'\t'"${base}"$'\n'
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
done <<EOF
$CURRENT
EOF

if [ "$FAIL_COUNT" -gt 0 ]; then
  echo
  echo "RESULT: FAIL —— $FAIL_COUNT 个 (severity, 规则, 文件) 指纹超出基线："
  while IFS=$'\t' read -r key cnt base; do
    [ -z "${key:-}" ] && continue
    echo "  +$((cnt - base))  ${key}（基线 ${base} → 当前 ${cnt}）"
  done <<EOF
$REGRESS
EOF
  echo
  echo "请修复新增问题后重试；确属有意变更时重采基线并随代码同一提交 review："
  echo "  bash $SCRIPT_REL --update-baseline"
  exit 1
fi

# 2) 收紧提示：条数较基线减少不失败，仅提示可重采
SHRUNK=""
while IFS=$'\t' read -r bcnt bkey; do
  case "$bkey" in ""|\#*) continue ;; esac
  cur=$(current_count_of "$bkey")
  if [ "$cur" -lt "$bcnt" ]; then
    SHRUNK="${SHRUNK}  $bkey: 基线 $bcnt → 当前 $cur"$'\n'
  fi
done < "$BASELINE"
[ -n "$SHRUNK" ] && {
  echo "提示：以下指纹条数较基线减少，可用 --update-baseline 收紧："
  printf '%s' "$SHRUNK"
}

if [ "$CUR_TOTAL" -eq 0 ]; then
  echo "RESULT: PASS（全仓 0 issue，零基线保持中）"
else
  echo "RESULT: PASS（无基线外新增分析问题）"
fi
exit 0

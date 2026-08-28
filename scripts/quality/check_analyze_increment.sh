#!/usr/bin/env bash
# IMBoy 双体验功能目录 · 增量静态分析质量门（P1）
#
# 方针：不清存量债——全仓 flutter analyze 的历史问题（~165 项）维持现状，
# 只拦"新增"：双体验功能目录内任一 (文件路径, 规则代码) 组合的分析条数
# 超过基线 scripts/quality/analyze_baseline.txt 即 FAIL。
#
# 功能目录清单 = 双体验合并范围（f60a9338..c72ab6b5）触碰的 lib/ 路径归纳：
# workspace / project / chat shell / workspace shell 及其关联 pages、
# models、api、service。采用目录级前缀，新增文件自动入门；
# lib/i18n/ 为 slang 生成物，不入门。
#
# 用法：
#   bash scripts/quality/check_analyze_increment.sh                    # 增量检查
#   bash scripts/quality/check_analyze_increment.sh --update-baseline  # 有意变更后重采基线
#
# 退出码契约（对齐 scripts/run_sqlite_migration_gate.sh）：
#   0   PASS（功能目录无新增分析问题；条数减少仅提示收紧，不失败）
#   1   FAIL（出现基线外 / 超量的 (文件, 规则) 组合）
#   2   BLOCKED（flutter 不可用 / analyze 未正常完成 / 基线缺失）
#   64  参数错误
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

SCRIPT_REL="scripts/quality/check_analyze_increment.sh"
BASELINE="$REPO_ROOT/scripts/quality/analyze_baseline.txt"

# ---------- 功能目录清单（双体验合并范围归纳；目录级前缀） ----------
FEATURE_PATHS=(
  "lib/config/"                # 路由 / 常量 / 初始化（workspace_routes、app_router…）
  "lib/page/channel/"          # 频道合成页
  "lib/page/chat/"             # 聊天输入 / 快捷回复 / 附件 / 发送
  "lib/page/chat_shell/"       # 双体验 · 移动端壳
  "lib/page/group/"            # 群相册 / 文件 / 日程
  "lib/page/passport/"         # 登录注册流
  "lib/page/personal_info/"
  "lib/page/scanner/"          # 扫码登录确认
  "lib/page/search/"           # 网页搜索
  "lib/page/settings/"         # E2EE 备份导入
  "lib/page/wallet/"           # 钱包 / 提现
  "lib/page/workspace/"        # 工作台 + 项目（双体验核心）
  "lib/page/workspace_shell/"  # 双体验 · 桌面端壳
  "lib/service/"               # SQLite 迁移 / 快照 / 契约 / olm / storage_secure
  "lib/store/api/"             # workspace_api / project_api 等
  "lib/store/model/"           # workspace_model / project_model 等
)

MODE="check"
case "${1:-}" in
  "")                 MODE="check"  ;;
  --update-baseline)  MODE="update" ;;
  *)  echo "usage: bash $SCRIPT_REL [--update-baseline]"; exit 64 ;;
esac

command -v flutter >/dev/null 2>&1 || { echo "BLOCKED: command 'flutter' not found"; exit 2; }
[ -f ".dart_tool/package_config.json" ] || {
  echo "BLOCKED: .dart_tool/package_config.json 缺失（需先 flutter pub get；"
  echo "        本门不代跑 pub get，避免重写 pubspec.lock）"
  exit 2
}

TMP_RAW="$(mktemp /tmp/imboy-analyze-gate.XXXXXX)"
trap 'rm -f "$TMP_RAW"' EXIT

echo "== flutter analyze（全仓，门内过滤到功能目录） =="
# --no-pub：绝不在门内隐式执行 flutter pub get（会重写 pubspec.lock）。
# 存在 error 级问题时 analyze 退出码非 0 属正常输出，以末尾汇总行为准。
flutter analyze --no-pub --no-fatal-infos --no-fatal-warnings >"$TMP_RAW" 2>&1
grep -qE '[0-9]+ issues? found|No issues found' "$TMP_RAW" || {
  echo "BLOCKED: flutter analyze 未正常完成，输出尾部："
  tail -5 "$TMP_RAW"
  exit 2
}

# 条目格式（解析约定同 .github/workflows/quality.yml）：
#   severity • message • file:line:col • code
# 问题身份 = (文件路径, 规则代码)，按组合计数；不记行号（行号会漂移）。
PATHS_STR="${FEATURE_PATHS[*]}"

# 聚合功能目录内当前问题 → stdout：count \t file \t code（排序）
aggregate_current() {
  sed $'s/\x1b\[[0-9;]*m//g' "$TMP_RAW" | awk -F' • ' -v paths="$PATHS_STR" '
    $1 ~ /^[[:space:]]*(info|warning|error)[[:space:]]*$/ {
      loc = $(NF-1); code = $NF
      if (code == "" || loc == "") next
      sub(/:[0-9]+:[0-9]+$/, "", loc)          # 去掉 :line:col
      n = split(paths, p, / +/)
      for (i = 1; i <= n; i++)
        if (p[i] != "" && index(loc, p[i]) == 1) { print loc "\t" code; break }
    }' \
    | sort | uniq -c | awk '{print $1 "\t" $2 "\t" $3}' | sort -t$'\t' -k2,2 -k3,3
}

# 基线中 (file, code) 的计数；缺省 0
baseline_count_of() {
  awk -F'\t' -v f="$1" -v c="$2" \
    'NF >= 3 && $1 !~ /^#/ && $2 == f && $3 == c { n = $1 } END { print (n + 0) }' \
    "$BASELINE" 2>/dev/null
}

# 当前结果中 (file, code) 的计数；缺省 0
current_count_of() {
  printf '%s\n' "$CURRENT" | awk -F'\t' -v f="$1" -v c="$2" \
    '$2 == f && $3 == c { n = $1 } END { print (n + 0) }'
}

# 打印某 (file, code) 组合的原始条目（含消息与精确位置）
print_entries() {
  sed $'s/\x1b\[[0-9;]*m//g' "$TMP_RAW" | awk -F' • ' -v f="$1" -v c="$2" '
    $1 ~ /^[[:space:]]*(info|warning|error)[[:space:]]*$/ {
      loc = $(NF-1); code = $NF
      file = loc; sub(/:[0-9]+:[0-9]+$/, "", file)
      if (file == f && code == c) print "      " $0
    }'
}

CURRENT="$(aggregate_current)"
CUR_GROUPS=$(printf '%s\n' "$CURRENT" | awk 'NF' | wc -l | tr -d ' ')

# ---------- --update-baseline：重采基线 ----------
if [ "$MODE" = "update" ]; then
  {
    echo "# IMBoy 双体验功能目录 flutter analyze 基线（门脚本生成，勿手改）"
    echo "# 再生成：bash $SCRIPT_REL --update-baseline"
    echo "# 日期：$(date +%F) ｜ $(flutter --version 2>/dev/null | head -1)"
    echo "# 格式：count<TAB>file<TAB>code（问题身份=(文件,规则代码)；不记行号）"
    [ -n "$CURRENT" ] && printf '%s\n' "$CURRENT"
  } > "$BASELINE"
  echo "基线已更新：${BASELINE}（${CUR_GROUPS} 组）"
  exit 0
fi

# ---------- check：与基线比对 ----------
[ -f "$BASELINE" ] || {
  echo "BLOCKED: 基线缺失 ${BASELINE}，先跑: bash $SCRIPT_REL --update-baseline"
  exit 2
}
BASE_GROUPS=$(awk 'NF >= 3 && $1 !~ /^#/' "$BASELINE" | wc -l | tr -d ' ')
echo "功能目录前缀 ${#FEATURE_PATHS[@]} 个 ｜ 当前问题组合 $CUR_GROUPS 组 ｜ 基线 $BASE_GROUPS 组"

# 1) 超限检测：当前任一组合条数 > 基线 → FAIL
FAIL_COUNT=0
REGRESS=""
while IFS=$'\t' read -r cnt file code; do
  [ -z "${file:-}" ] && continue
  base=$(baseline_count_of "$file" "$code")
  if [ "$cnt" -gt "$base" ]; then
    REGRESS="${REGRESS}${file}"$'\t'"${code}"$'\t'"${cnt}"$'\t'"${base}"$'\n'
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
done <<EOF
$CURRENT
EOF

if [ "$FAIL_COUNT" -gt 0 ]; then
  echo
  echo "RESULT: FAIL —— $FAIL_COUNT 个 (文件, 规则) 组合超出基线："
  while IFS=$'\t' read -r file code cnt base; do
    [ -z "${file:-}" ] && continue
    echo "  +$((cnt - base))  $file  [$code]（基线 $base → 当前 ${cnt}）"
    print_entries "$file" "$code"
  done <<EOF
$REGRESS
EOF
  echo
  echo "请修复以上新增问题；确属有意变更时重采基线并随代码一起提交："
  echo "  bash $SCRIPT_REL --update-baseline"
  exit 1
fi

# 2) 收紧提示：条数较基线减少不失败，仅提示可重采
SHRUNK=""
while IFS=$'\t' read -r bcnt bfile bcode; do
  case "$bfile" in ""|\#*) continue ;; esac
  cur=$(current_count_of "$bfile" "$bcode")
  if [ "$cur" -lt "$bcnt" ]; then
    SHRUNK="${SHRUNK}  $bfile [$bcode]: 基线 $bcnt → 当前 $cur"$'\n'
  fi
done < "$BASELINE"
[ -n "$SHRUNK" ] && {
  echo "提示：以下组合条数较基线减少，可用 --update-baseline 收紧："
  printf '%s' "$SHRUNK"
}

echo "RESULT: PASS（功能目录无新增分析问题）"
exit 0

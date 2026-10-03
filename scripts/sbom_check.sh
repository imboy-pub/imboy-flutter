#!/usr/bin/env bash
# C17b — SBOM 生成 + CVE 扫描（AC-35 / privacy-profile.md §5 缺口 G1+G2）
#
# 用法:
#   bash scripts/sbom_check.sh              # 默认输出到系统临时目录（仓外，不入仓）
#   SBOM_OUT_DIR=/tmp/sbom bash scripts/sbom_check.sh
#   STRICT=1 bash scripts/sbom_check.sh     # 发现 CVE 时以非零退出（CI 门语义）
#
# 依赖:
#   - osv-scanner（Google OSV 官方 CLI）。本脚本只做 PATH 探测 fail-fast，
#     **不擅自安装**——缺失时打印安装指引后退出 127：
#       brew install osv-scanner
#     或（需要 Go ≥1.22）:
#       go install github.com/google/osv-scanner/v2/cmd/osv-scanner@latest
#     （二进制须在 PATH，通常为 $(go env GOPATH)/bin）
#
# 产物（均写入输出目录，不写进仓库 / build/）:
#   - sbom.cdx.json    CycloneDX 1.5 SBOM（全量包清单，--all-packages）
#   - osv-report.json  CVE 扫描结果（JSON，机器可读）
#   - osv-report.txt   CVE 扫描结果（表格，人类可读）
#
# osv-scanner 退出码约定: 0=无发现 1=有漏洞/发现 127=一般错误 128=未扫到包。
# 本脚本默认把「有发现」当警告（exit 0，摘要打到 stdout）；STRICT=1 时
# 有发现即 exit 1。
#
# ── 接入建议（由用户决策，本脚本不自行改 gate）──────────────────────────────
# 是否进 scripts/pre_push_gate.sh 由用户拍板。若决定接入，建议形态：
#   bash scripts/sbom_check.sh && [ 无 CRITICAL/HIGH 新增 ]
# 两点注意：
#   1. osv-scanner 需网络访问 api.osv.dev——放进 pre_push_gate 会让离线
#      提交全部失败，建议作为「有网时的周期任务 / release 流程」而非
#      每次 push 硬门；
#   2. STRICT 语义建议只对 E2EE 关键依赖（flutter_vodozemac / crypto /
#      pointycastle，见 privacy-profile.md §5 G3）收严，全量严格门在
#      当前 67 包可升级的现状下会常红。
# ────────────────────────────────────────────────────────────────────────────
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

LOCKFILE="pubspec.lock"
if [ ! -f "$LOCKFILE" ]; then
  echo "[sbom_check] 缺少 $LOCKFILE——先在仓库根执行 flutter pub get" >&2
  exit 127
fi

# ── 1. osv-scanner PATH 探测（fail-fast，不安装） ───────────────────────────
if ! command -v osv-scanner >/dev/null 2>&1; then
  cat >&2 <<'EOF'
[sbom_check] 未在 PATH 找到 osv-scanner。安装方式（任选其一）：

  brew install osv-scanner
  # 或（需要 Go >= 1.22）：
  go install github.com/google/osv-scanner/v2/cmd/osv-scanner@latest
  # go 安装的二进制在 $(go env GOPATH)/bin，确认其在 PATH 内

安装后重跑: bash scripts/sbom_check.sh
EOF
  exit 127
fi

OSV_VERSION="$(osv-scanner --version 2>/dev/null || echo unknown)"
echo "[sbom_check] osv-scanner: $OSV_VERSION"

# v2 用 `osv-scanner scan ...` 子命令；v1 顶层直接接参数。
if osv-scanner scan --help >/dev/null 2>&1; then
  OSV_SCAN=(osv-scanner scan)
else
  OSV_SCAN=(osv-scanner)
fi

# ── 2. 输出目录：默认仓外临时目录（不入仓、不占 build/） ─────────────────────
if [ -n "${SBOM_OUT_DIR:-}" ]; then
  OUT_DIR="$SBOM_OUT_DIR"
  mkdir -p "$OUT_DIR"
else
  OUT_DIR="$(mktemp -d "${TMPDIR:-/tmp}/imboyapp-sbom.XXXXXX")"
fi
echo "[sbom_check] 输出目录: $OUT_DIR"

# ── 3. CycloneDX SBOM（stdout 重定向落盘） ─────────────────────────────────
SBOM_FILE="$OUT_DIR/sbom.cdx.json"
# cyclonedx-1-5 为当前 osv-scanner 支持的 CycloneDX 版本；若该格式名不被
# 支持（更老版本），回退 cyclonedx-1.4。
if ! "${OSV_SCAN[@]}" --format cyclonedx-1-5 --all-packages . > "$SBOM_FILE" 2> "$OUT_DIR/sbom.stderr"; then
  echo "[sbom_check] cyclonedx-1-5 失败，回退 cyclonedx-1.4（详见 $OUT_DIR/sbom.stderr）" >&2
  "${OSV_SCAN[@]}" --format cyclonedx-1-4 --all-packages . > "$SBOM_FILE"
fi
SBOM_COUNT="$(python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(len(d.get("components", [])))' "$SBOM_FILE" 2>/dev/null || echo '?')"
echo "[sbom_check] SBOM: $SBOM_FILE（components: $SBOM_COUNT）"

# ── 4. CVE 扫描（pubspec.lock） ────────────────────────────────────────────
JSON_REPORT="$OUT_DIR/osv-report.json"
TXT_REPORT="$OUT_DIR/osv-report.txt"
set +e
"${OSV_SCAN[@]}" --format json -L "$LOCKFILE" > "$JSON_REPORT" 2> "$OUT_DIR/osv.stderr"
OSV_RC=$?
set -e

# 人类可读表格版（table 是默认格式，另行跑一次到文件；stderr 保留）
if [ "$OSV_RC" -ne 127 ] && [ "$OSV_RC" -ne 128 ]; then
  set +e
  "${OSV_SCAN[@]}" -L "$LOCKFILE" > "$TXT_REPORT" 2>/dev/null
  set -e
fi

case "$OSV_RC" in
  0)
    echo "[sbom_check] CVE 扫描：未发现已知漏洞（报告: $JSON_REPORT）"
    ;;
  1)
    echo "[sbom_check] CVE 扫描：发现漏洞/finding——详见："
    echo "    $JSON_REPORT"
    echo "    $TXT_REPORT"
    if [ -n "${STRICT:-}" ]; then
      echo "[sbom_check] STRICT=1：有发现即失败" >&2
      exit 1
    fi
    ;;
  128)
    echo "[sbom_check] 警告：osv-scanner 未从 $LOCKFILE 解析到任何包（exit 128）" >&2
    ;;
  *)
    echo "[sbom_check] osv-scanner 异常退出（exit $OSV_RC，stderr: $OUT_DIR/osv.stderr）" >&2
    exit "$OSV_RC"
    ;;
esac

echo "[sbom_check] 完成。产物目录不入仓；如需保留请自行归档 $OUT_DIR"

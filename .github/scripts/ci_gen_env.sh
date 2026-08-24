#!/usr/bin/env bash
# CI 专用：生成被 .gitignore 排除的 env 配置文件。
# 仓库约定：env_dev.dart/env_pro.dart 源文件与全部 env_*.g.dart 生成物不入库
# （envied 从本地 .env.<环境> 生成，solidified_key 为敏感字段）。
# CI 无本地文件，必须：①从模板恢复源文件 ②写 dummy .env.* ③build_runner 生成。
# ⚠️ 严禁 --build-filter（会误删其余 64 个 .g.dart，事故记录在案）。
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

# ① 源文件（模板内容仅注解，无密钥）
cp .github/templates/env_dev.dart lib/config/env_dev.dart
cp .github/templates/env_pro.dart lib/config/env_pro.dart

# ② dummy .env.*（全部占位值，无真实密钥；SOLIDIFIED_KEY 32 位/IV 16 位对齐格式约定）
write_env() {
  # 已存在（本地开发的真实配置）则跳过，防误覆盖；CI 检出不存在才写入
  if [ -f "$1" ]; then
    echo "[ci_gen_env] $1 已存在，跳过"
    return 0
  fi
  cat > "$1" <<'EOF'
ENV=ci
IOS_APP_ID=
API_BASE_URL=http://127.0.0.1:9800
WS_URL=ws://127.0.0.1:9800/api/v1/ws
SOLIDIFIED_KEY=ci01ci01ci01ci01ci01ci01ci01ci01
SOLIDIFIED_KEY_IV=civ01civ01civ01c
A_MAP_WEBS_KEY=
A_MAP_IOS_KEY=
A_MAP_ANDROID_KEY=
JPUSH_APPKEY=
UPLOAD_BASE_URL=http://127.0.0.1:9800
UPLOAD_SENCE=ci
UP_AUTH_KEY=
AI_TEST_ENABLED=false
ANTHROPIC_API_KEY=
OPENAI_API_KEY=
TEST_PHONE=
TEST_PASSWORD=
TEST_SEARCH_KEYWORD=
EOF
}
write_env .env.dev
write_env .env.pro
write_env .env.local
write_env .env.local_home
write_env .env.local_office

# ③ 生成 .g.dart（全量 build，禁用 --build-filter）
flutter pub run build_runner build --delete-conflicting-outputs

# build_runner 还会重写已入库的 provider 等生成物；这些文件不是本脚本
# 的职责，且不同 Dart 版本的纯格式变化会让后续格式门禁产生假失败。CI
# cleanroom 仅保留被忽略的 env_*.g.dart，恢复其余已跟踪 Dart 生成物。
# 本地开发不能恢复，以免覆盖开发者未提交的改动。
if [[ -n "${CI:-}" ]]; then
  generated_tracked_dart="$(git diff --name-only -- '*.dart')"
  if [[ -n "$generated_tracked_dart" ]]; then
    while IFS= read -r generated_file; do
      git restore -- "$generated_file"
    done <<< "$generated_tracked_dart"
    generated_count="$(printf '%s\n' "$generated_tracked_dart" | wc -l | tr -d ' ')"
    echo "[ci_gen_env] 已恢复 ${generated_count} 个非 env 已跟踪 Dart 生成物"
  fi
fi

echo "[ci_gen_env] 生成的 env .g.dart："
ls lib/config/*.g.dart

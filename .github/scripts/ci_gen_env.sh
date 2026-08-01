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
dart run build_runner build --delete-conflicting-outputs

echo "[ci_gen_env] 生成的 env .g.dart："
ls lib/config/*.g.dart

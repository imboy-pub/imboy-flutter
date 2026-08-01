#!/usr/bin/env bash
# CI 专用：jverify 是 .gitignore 的本地插件（plugin/jverify），CI 检出无此目录，
# pub get 必败（"depends on jverify from path which doesn't exist"）。
# 本地 plugin/jverify 即官方 3.1.7（与 hosted 版本一致），故 CI 检出缺目录时
# 把 dependency_overrides 的 path 覆写改回 hosted。本地开发目录存在则跳过。
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

if [ -f plugin/jverify/pubspec.yaml ]; then
  echo "[ci_patch_path_deps] plugin/jverify 存在，无需 patch"
  exit 0
fi

perl -0777 -pi -e 's/  jverify:\n    path: plugin\/jverify/  jverify: ^3.1.7/' pubspec.yaml
echo "[ci_patch_path_deps] 已将 jverify path 覆写改回 hosted ^3.1.7："
grep -n "jverify" pubspec.yaml | head -3

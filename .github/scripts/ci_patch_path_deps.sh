#!/usr/bin/env bash
# CI 专用：本地插件或私有 Git 依赖在 GitHub-hosted runner 不可用时，切换到
# 与本地插件一致的公开 jverify 3.1.7，确保 cleanroom 能解析依赖。
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

if [ -f plugin/jverify/pubspec.yaml ]; then
  echo "[ci_patch_path_deps] plugin/jverify 存在，无需 patch"
  exit 0
fi

perl -0777 -pi -e 's{  jverify:(?:\h*#.*)?\n(?:    path: plugin/jverify|    git:\n      url: git\@gitee\.com:imboy-tripartite-deps/jverify-flutter-plugin\.git\n      ref: dev-3\.x)}{  jverify: ^3.1.7}' pubspec.yaml

if ! grep -q '^  jverify: \^3\.1\.7$' pubspec.yaml; then
  echo "[ci_patch_path_deps] 未找到可替换的 jverify 本地或私有 Git 依赖" >&2
  exit 1
fi

echo "[ci_patch_path_deps] 已将 jverify 切换为公开 hosted ^3.1.7："
grep -n '^  jverify:' pubspec.yaml

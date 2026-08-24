#!/usr/bin/env bash
# CI 专用：本地插件或 SSH Git 依赖在 GitHub-hosted runner 不可用时，切换到
# 可匿名读取的同一公开 HTTPS Git 来源，确保 cleanroom 能解析依赖。
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

if [ -f plugin/jverify/pubspec.yaml ]; then
  echo "[ci_patch_path_deps] plugin/jverify 存在，无需 patch"
  exit 0
fi

perl -0777 -pi -e 's{  jverify:(?:\h*#.*)?\n(?:    path: plugin/jverify|    git:\n      url: git\@gitee\.com:imboy-tripartite-deps/jverify-flutter-plugin\.git\n      ref: dev-3\.x)}{  jverify:\n    git:\n      url: https://gitee.com/imboy-tripartite-deps/jverify-flutter-plugin.git\n      ref: dev-3.x}' pubspec.yaml

if ! grep -A3 '^  jverify:' pubspec.yaml | grep -q '^      url: https://gitee.com/imboy-tripartite-deps/jverify-flutter-plugin.git$'; then
  echo "[ci_patch_path_deps] 未找到可替换的 jverify 本地或 SSH Git 依赖" >&2
  exit 1
fi

echo "[ci_patch_path_deps] 已将 jverify 切换为公开 HTTPS 来源："
grep -A3 '^  jverify:' pubspec.yaml

perl -0777 -pi -e 's{  r_upgrade:(?:\h*#.*)?\n(?:    path: plugin/r_upgrade|    git:\n      url: git\@gitee\.com:imboy-tripartite-deps/r_upgrade\.git\n      ref: leeyi)}{  r_upgrade:\n    git:\n      url: https://gitee.com/imboy-tripartite-deps/r_upgrade.git\n      ref: leeyi}' pubspec.yaml

if ! grep -A3 '^  r_upgrade:' pubspec.yaml | grep -q '^      url: https://gitee.com/imboy-tripartite-deps/r_upgrade.git$'; then
  echo "[ci_patch_path_deps] 未找到可替换的 r_upgrade 本地或 SSH Git 依赖" >&2
  exit 1
fi

echo "[ci_patch_path_deps] 已将 r_upgrade 切换为公开 HTTPS 来源："
grep -A3 '^  r_upgrade:' pubspec.yaml

perl -pi -e 's{git\@gitee\.com:imboy-tripartite-deps/}{https://gitee.com/imboy-tripartite-deps/}' pubspec.yaml

if grep -q 'git@gitee.com:' pubspec.yaml; then
  echo "[ci_patch_path_deps] pubspec.yaml 仍含 SSH Git 来源" >&2
  exit 1
fi

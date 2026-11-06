#!/usr/bin/env bash
# CI 专用：本地插件或 SSH Git 依赖在 GitHub-hosted runner 不可用时，切换到
# 可匿名读取的同一公开 HTTPS Git 来源，确保 cleanroom 能解析依赖。
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

if [[ "${1:-}" == "--check" ]]; then
  # A frozen execution plan binds the tracked pubspec/lockfile. CI must report
  # transport drift before dependency resolution, not rewrite those inputs.
  python3 - <<'PY'
from pathlib import Path
import re
import sys

text = Path('pubspec.yaml').read_text(encoding='utf-8')
errors = []
for package, repository in [('jverify', 'jverify-flutter-plugin'), ('r_upgrade', 'r_upgrade')]:
    match = re.search(r'^  ' + package + r':[^\n]*\n((?:[ \t]+[^\n]*\n|\n)*)', text, re.M)
    # Keep exactly this dependency's block, stopping at its next peer key.
    block = re.split(r'^  \S', match[1], maxsplit=1, flags=re.M)[0] if match else ''
    expected = 'https://gitee.com/imboy-tripartite-deps/' + repository + '.git'
    if not re.search(r'^      url: ' + re.escape(expected) + r'\s*$', block, re.M):
        errors.append(package + ': expected the committed public HTTPS dependency; update the source explicitly before planning')
if re.search(r'^[^#\n]*git@gitee\.com:', text, re.M):
    errors.append('SSH-only Git dependency remains in the frozen pubspec')
if errors:
    print('\n'.join('[ci_patch_path_deps] ' + error for error in errors), file=sys.stderr)
    sys.exit(2)
print('[ci_patch_path_deps] Public dependency sources verified; tracked inputs unchanged')
PY
  exit $?
elif [[ "$#" -gt 0 ]]; then
  echo 'Usage: ci_patch_path_deps.sh [--check]' >&2
  exit 64
fi

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

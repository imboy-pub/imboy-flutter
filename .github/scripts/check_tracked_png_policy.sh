#!/usr/bin/env bash
# zero-tracked-PNG 惯例守卫（瘦身 V1 治理，2026-11-18）
#
# 惯例：test/ 下的 golden 渲染 PNG 一律不入库（本地交付边界，
# .gitignore 已声明；历史两次泄漏 = test/uiux 624 张 + 五目录 94 张）。
# 本门防的是「git add -f / 新目录忘加规则」式回归。
# docs/design 的文档内嵌插图不在此门范围（合法插图，非运行证据）。
set -euo pipefail
cd "$(dirname "$0")/../.."

leaks=$(git ls-files | grep -E '^test/.*\.png$' || true)
if [ -n "$leaks" ]; then
  echo "::error::zero-tracked-PNG 违例：test/ 下发现 tracked PNG（golden 渲染基线属本地交付）"
  echo "$leaks"
  echo "::error::请对对应 goldens 目录执行 git rm --cached 并确认 .gitignore 规则覆盖"
  exit 1
fi
echo "PNG policy OK: test/ 下零 tracked PNG"

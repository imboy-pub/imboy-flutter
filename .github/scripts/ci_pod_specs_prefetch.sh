#!/usr/bin/env bash
# CocoaPods Specs 镜像预取（带界重试）。
#
# 背景：Podfile 以 URL 直连 tuna 镜像；runner 上该 source 未配置时，
# pod install 会现场 git clone 整个 Specs 仓库。tuna 排队（Position 45+）
# 加 curl 56 连接重置竞态下，2026-11-21 run 44938305238 的 Build iOS
# 实测 pod install 挂 188s 后失败，且该失败形态落在
# ci_retry_build_downloads.sh 的 pods 重试窗之外（Attempt 1/3 即终止）。
#
# 这里在 pod install 之前显式 add 同名镜像源并 update：
# - 后续 pod install 只做本地增量比对，不再现场 clone；
# - pod repo update 一并重试（Agora 等依赖要求最新 specs，原步骤语义保留）；
# - 失败时清掉半克隆目录再重试，避免残留目录让后续 attempt 假命中。
set -euo pipefail

mirror_name='tsinghua-git-cocoapods'
mirror_url='https://mirrors.tuna.tsinghua.edu.cn/git/CocoaPods/Specs.git'
mirror_dir="$HOME/.cocoapods/repos/$mirror_name"

prefetch_once() {
  if [[ ! -d "$mirror_dir" ]]; then
    pod repo add "$mirror_name" "$mirror_url"
  fi
  pod repo update
}

for attempt in 1 2 3; do
  echo "[ci_pod_specs_prefetch] Attempt $attempt/3"
  if prefetch_once; then
    echo "[ci_pod_specs_prefetch] specs mirror ready: $mirror_dir"
    exit 0
  fi
  rm -rf "$mirror_dir"
  sleep $((attempt * 20))
done

echo "::error::CocoaPods specs 镜像预取 3 次均失败（$mirror_url）" >&2
exit 1

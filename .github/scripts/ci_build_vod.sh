#!/usr/bin/env bash
# CI 专用：构建 vodozemac FFI 动态库并摆到测试硬编码的 spike 路径。
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

# 只在 Linux 需要：移动端由 flutter_vodozemac 插件自身构建。
if [ "$(uname -s)" != "Linux" ]; then
  echo "[ci_build_vod] 非 Linux（$(uname -s)），跳过"
  exit 0
fi

if ! command -v cargo >/dev/null 2>&1; then
  if [ -f "$HOME/.cargo/env" ]; then
    . "$HOME/.cargo/env"
  else
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal
    . "$HOME/.cargo/env"
  fi
fi

CRATE=$(echo "$HOME"/.pub-cache/hosted/pub.dev/flutter_vodozemac-*/rust)
if [ ! -d "$CRATE" ]; then
  echo "[ci_build_vod] 未找到 flutter_vodozemac rust 源（pub get 先跑）" >&2
  exit 1
fi

BUILD_DIR=/tmp/vodozemac-build
echo "[ci_build_vod] cargo build --release ($CRATE)"
cargo build --release --manifest-path "$CRATE/Cargo.toml" --target-dir "$BUILD_DIR"

DEST=../spikes/e2ee-group/rust/target/release
mkdir -p "$DEST"
cp "$BUILD_DIR/release/libvodozemac_bindings_dart.so" "$DEST/"
echo "[ci_build_vod] 已就位："
ls -la "$DEST"

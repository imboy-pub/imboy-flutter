#!/usr/bin/env bash
# CI 专用：构建 vodozemac FFI 动态库并摆到测试硬编码的 spike 路径。
# 背景：test/service/e2ee 多个测试 vod.init(libraryPath: '../spikes/e2ee-group/rust/target/release/')，
# 本地 macOS 找不到该文件时回退到 flutter_vodozemac 包内 macos 预编译 dylib 故可通过；
# pub 包 linux/ 只有 CMakeLists.txt 无预编译 .so → Linux CI 必崩 setUpAll。
# 这里用 pub 包自带 rust 源码 cargo build 出 cdylib，摆到测试查找路径。
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

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

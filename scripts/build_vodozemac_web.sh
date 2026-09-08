#!/usr/bin/env bash
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

PUB_CACHE_DIR="${PUB_CACHE:-$HOME/.pub-cache}/hosted/pub.dev"
DART_SOURCE="$PUB_CACHE_DIR/vodozemac-0.8.0"
RUST_SOURCE="$PUB_CACHE_DIR/flutter_vodozemac-0.8.1/rust"
OUTPUT_DIR="$PWD/web/pkg"

for command in flutter_rust_bridge_codegen wasm-pack wasm-bindgen; do
  command -v "$command" >/dev/null || {
    echo "缺少 Web E2EE 构建工具：$command" >&2
    exit 1
  }
done
for source in "$DART_SOURCE" "$RUST_SOURCE"; do
  [ -d "$source" ] || {
    echo "缺少依赖源码：$source；请先运行 flutter pub get" >&2
    exit 1
  }
done

BUILD_DIR=$(mktemp -d /tmp/imboy-vodozemac-web.XXXXXX)
trap 'rm -rf "$BUILD_DIR"' EXIT
mkdir -p "$BUILD_DIR/dart" "$BUILD_DIR/rust"
cp -R "$DART_SOURCE/." "$BUILD_DIR/dart/"
cp -R "$RUST_SOURCE/." "$BUILD_DIR/rust/"

flutter_rust_bridge_codegen build-web \
  --dart-root "$BUILD_DIR/dart" \
  --rust-root "$BUILD_DIR/rust" \
  --release

mkdir -p "$OUTPUT_DIR"
cp "$BUILD_DIR/dart/web/pkg/vodozemac_bindings_dart.js" "$OUTPUT_DIR/"
cp "$BUILD_DIR/dart/web/pkg/vodozemac_bindings_dart_bg.wasm" "$OUTPUT_DIR/"
echo "Web E2EE 产物已生成：$OUTPUT_DIR"

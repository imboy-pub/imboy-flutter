#!/usr/bin/env bash
# regenerate_protobuf.sh — Re-generate Dart protobuf files from imboy.proto
# Usage: ./scripts/regen_protobuf.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="$(dirname "$SCRIPT_DIR")"
PROTO_SRC="${APP_DIR}/../imboy/src/imboy.proto"
OUT_DIR="${APP_DIR}/lib/service/protocol"

if [ ! -f "$PROTO_SRC" ]; then
  echo "ERROR: proto source not found at $PROTO_SRC" >&2
  exit 1
fi

# Ensure protoc-gen-dart is on PATH
export PATH="$PATH:$HOME/.pub-cache/bin"

if ! command -v protoc-gen-dart &>/dev/null; then
  echo "ERROR: protoc-gen-dart not found. Run: dart pub global activate protoc_plugin" >&2
  exit 1
fi

mkdir -p "$OUT_DIR"
protoc --dart_out="$OUT_DIR" -I"$(dirname "$PROTO_SRC")" "$PROTO_SRC"

echo "Protobuf Dart files regenerated in $OUT_DIR"

#!/usr/bin/env bash
# regenerate_protobuf.sh — Re-generate Dart protobuf files from imboy.proto
# Usage: ./scripts/regen_protobuf.sh
set -euo pipefail
MODE="${1:-generate}"
case "$MODE" in generate|--check) ;; *) echo "usage: $0 [--check]" >&2; exit 64 ;; esac
[ "$#" -le 1 ] || { echo "usage: $0 [--check]" >&2; exit 64; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="$(dirname "$SCRIPT_DIR")"
PROTO_SRC="${APP_DIR}/../imboy/src/imboy.proto"
OUT_DIR="${APP_DIR}/lib/service/protocol"

if [ ! -f "$PROTO_SRC" ]; then
  echo "ENV_MISSING: proto source not found at $PROTO_SRC" >&2
  exit 2
fi

# Ensure protoc-gen-dart is on PATH
export PATH="$PATH:${PUB_CACHE:-$HOME/.pub-cache}/bin"

if ! command -v protoc-gen-dart &>/dev/null; then
  echo "ENV_MISSING: protoc-gen-dart not found. Run: dart pub global activate protoc_plugin 25.1.0" >&2
  exit 2
fi

command -v protoc >/dev/null 2>&1 || { echo "ENV_MISSING: protoc not found" >&2; exit 2; }

if [[ "$MODE" == "--check" ]]; then
  CHECK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/imboy-proto-check.XXXXXX")"
  trap 'rm -rf "$CHECK_DIR"' EXIT
  protoc --dart_out="$CHECK_DIR" -I"$(dirname "$PROTO_SRC")" "$PROTO_SRC"
  count=0
  for generated in "$CHECK_DIR"/*.dart; do
    [[ -f "$generated" ]] || continue
    count=$((count + 1))
    diff -u "$OUT_DIR/$(basename "$generated")" "$generated"
  done
  [[ "$count" -gt 0 ]] || { echo 'No protobuf output generated' >&2; exit 1; }
  echo "Protobuf generated contract matches; working tree was not modified."
else
  mkdir -p "$OUT_DIR"
  protoc --dart_out="$OUT_DIR" -I"$(dirname "$PROTO_SRC")" "$PROTO_SRC"
  echo "Protobuf Dart files regenerated in $OUT_DIR"
fi

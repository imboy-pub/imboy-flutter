#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ $# -lt 1 ]]; then
  cat <<'USAGE'
Usage:
  ./scripts/build_play_aab.sh <build_number> [build_name]

Examples:
  ./scripts/build_play_aab.sh 70101
  ./scripts/build_play_aab.sh 70102 0.7.2
USAGE
  exit 1
fi

BUILD_NUMBER="$1"
BUILD_NAME="${2:-$(awk -F': ' '/^version:/{print $2}' pubspec.yaml | head -n1)}"

if [[ -z "$BUILD_NAME" ]]; then
  echo "Unable to resolve build name from pubspec.yaml, please pass [build_name]."
  exit 1
fi

echo "Building AAB with build_name=$BUILD_NAME, build_number=$BUILD_NUMBER"
flutter build appbundle --build-name="$BUILD_NAME" --build-number="$BUILD_NUMBER"

echo "AAB output:"
echo "  $ROOT_DIR/build/app/outputs/bundle/release/app-release.aab"

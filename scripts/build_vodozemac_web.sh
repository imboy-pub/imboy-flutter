#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "IMBOY_VODOZEMAC_BUILD_ROOT=/persistent/git-external/path $0 [--stage-only]" >&2
}

if [[ $# -gt 1 || ($# -eq 1 && $1 != --stage-only) ]]; then
  usage
  exit 64
fi

repo=$(git rev-parse --show-toplevel)
cd "$repo"
root=${IMBOY_VODOZEMAC_BUILD_ROOT:-}
if [[ "$root" != /* ]]; then
  usage
  exit 64
fi

for command in cargo node python3 wasm-bindgen; do
  command -v "$command" >/dev/null || {
    echo "Missing Web E2EE build tool: $command" >&2
    exit 1
  }
done

root=$(python3 -B -c 'import sys; from pathlib import Path; print(Path(sys.argv[1]).resolve())' "$root")
case "$root/" in
  "$repo/"*|/tmp/*|/private/tmp/*|/private/var/folders/*|/var/folders/*)
    echo "Use a persistent build directory outside the repository" >&2
    exit 64
    ;;
esac
mkdir -p "$root"
build=$(mktemp -d "$root/vodozemac-web.XXXXXXXX")
mkdir -p "$build/tmp" "$build/pkg"
echo "Web E2EE build state: $build"
export TMPDIR="$build/tmp"
export CARGO_HOME=${IMBOY_VODOZEMAC_CARGO_HOME:-"$root/cargo-home"}
export CARGO_TARGET_DIR="$root/cargo-target"

# Resolve the exact installed Dart packages selected by pubspec.lock. Use the
# pub package's generated Rust and Cargo.lock without regenerating bindings.
python3 -B - "$build" <<'PY'
import json
import hashlib
import re
import shutil
import sys
from pathlib import Path
from urllib.parse import unquote, urlparse

build = Path(sys.argv[1])
lock = Path("pubspec.lock").read_text()
config = Path(".dart_tool/package_config.json").resolve()
packages = {row["name"]: row for row in json.loads(config.read_text())["packages"]}

def package_root(name):
    section = re.search(rf"^  {re.escape(name)}:\n((?:^    .*\n)+)", lock, re.M)
    locked = None if section is None else re.search(r'^    version: "?([^"\n]+)"?$', section[1], re.M)
    if locked is None:
        raise SystemExit(f"{name} missing from pubspec.lock")
    uri = urlparse(packages[name]["rootUri"])
    path = Path(unquote(uri.path))
    root = path if uri.scheme == "file" else (config.parent / path).resolve()
    if not re.search(rf'^version: "?{re.escape(locked[1])}"?$', (root / "pubspec.yaml").read_text(), re.M):
        raise SystemExit(f"{name} package does not match pubspec.lock")
    return root, locked[1]

dart, dart_version = package_root("vodozemac")
plugin, plugin_version = package_root("flutter_vodozemac")
_, bridge_version = package_root("flutter_rust_bridge")
rust = plugin / "rust"
generated_dart = (dart / "lib/src/generated/frb_generated.dart").read_text()
generated_rust = (rust / "src/frb_generated.rs").read_text()
dart_hash = re.search(r"get rustContentHash => (-?\d+);", generated_dart)
rust_hash = re.search(r"FLUTTER_RUST_BRIDGE_CODEGEN_CONTENT_HASH: i32 = (-?\d+);", generated_rust)
dart_bridge = re.search(r"get codegenVersion => '([^']+)';", generated_dart)
cargo_lock = (rust / "Cargo.lock").read_text()
cargo_bridge = re.search(r'\[\[package\]\]\nname = "flutter_rust_bridge"\nversion = "([^"]+)"', cargo_lock)
wasm_bindgen = re.search(r'\[\[package\]\]\nname = "wasm-bindgen"\nversion = "([^"]+)"', cargo_lock)
if not (dart_hash and rust_hash and dart_bridge and cargo_bridge and wasm_bindgen):
    raise SystemExit("Incomplete Vodozemac lock or generated ABI metadata")
if dart_hash[1] != rust_hash[1] or dart_bridge[1] != bridge_version or cargo_bridge[1] != bridge_version:
    raise SystemExit("Vodozemac Rust and Dart bindings are incompatible")
shutil.copytree(rust, build / "rust", ignore=shutil.ignore_patterns(".git", "target"))
info = {
    "vodozemac": dart_version, "flutter_vodozemac": plugin_version,
    "flutter_rust_bridge": bridge_version, "wasm_bindgen": wasm_bindgen[1],
    "rust_content_hash": int(dart_hash[1]),
    "cargo_lock_sha256": hashlib.sha256((rust / "Cargo.lock").read_bytes()).hexdigest(),
    "generated_dart_sha256": hashlib.sha256(
        (dart / "lib/src/generated/frb_generated.dart").read_bytes()
    ).hexdigest(),
    "generated_rust_sha256": hashlib.sha256(
        (rust / "src/frb_generated.rs").read_bytes()
    ).hexdigest(),
}
(build / "bindings.json").write_text(json.dumps(info, indent=2) + "\n")
(build / "versions").write_text(f"{wasm_bindgen[1]} {dart_hash[1]}\n")
PY

read -r bindgen_version expected_hash < "$build/versions"
if [[ "$(wasm-bindgen --version)" != "wasm-bindgen $bindgen_version" ]]; then
  echo "Expected wasm-bindgen $bindgen_version from the Vodozemac Cargo.lock" >&2
  exit 1
fi

env -u CARGO_ENCODED_RUSTFLAGS RUSTFLAGS='--cfg=getrandom_backend="wasm_js"' \
  cargo build --manifest-path "$build/rust/Cargo.toml" --target wasm32-unknown-unknown \
  --release --locked --offline 2>&1 | tee "$build/cargo.log"
wasm-bindgen "$CARGO_TARGET_DIR/wasm32-unknown-unknown/release/vodozemac_bindings_dart.wasm" \
  --target no-modules --no-typescript --out-dir "$build/pkg" \
  --out-name vodozemac_bindings_dart

# Instantiate the exact output pair and check what the Web FRB loader will
# read, rather than trusting the version string embedded in the source.
node --input-type=module - "$build/pkg" "$expected_hash" <<'JS' | tee "$build/abi.log"
import fs from 'node:fs';
import vm from 'node:vm';
import { webcrypto } from 'node:crypto';
const [dir, expected] = process.argv.slice(2);
const name = `${dir}/vodozemac_bindings_dart`;
const localModule = new WebAssembly.Module(fs.readFileSync(`${name}_bg.wasm`));
const context = vm.createContext({ TextDecoder, TextEncoder, WebAssembly, console, localModule, crypto: webcrypto, setTimeout });
vm.runInContext(fs.readFileSync(`${name}.js`, 'utf8'), context);
const actual = vm.runInContext('wasm_bindgen.initSync({module: localModule}).frb_get_rust_content_hash()', context);
if (actual !== Number(expected)) throw new Error(`Vodozemac ABI mismatch: expected ${expected}, got ${actual}`);
console.log(`Vodozemac ABI verified: ${actual}`);
JS

echo "Verified Web E2EE assets: $build/pkg"

#!/usr/bin/env bash
# CI: retry submodule updates without changing sources or pinned gitlinks.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

depth="${1:-1}"
if [[ $# -gt 1 || ( "$depth" != 0 && "$depth" != 1 ) ]]; then
  echo 'Usage: ci_checkout_submodules.sh [0|1] (0 omits the depth limit)' >&2
  exit 64
fi
update_args=(--init --force --checkout --recursive)
if [[ "$depth" == 1 ]]; then update_args+=(--depth=1); fi

# Match checkout's non-interactive, lfs:false behavior for this public HTTPS source.
export GIT_TERMINAL_PROMPT=0 GCM_INTERACTIVE=Never GIT_LFS_SKIP_SMUDGE=1
git submodule sync --recursive
git config --file .gitmodules --get-regexp '^submodule\..*\.url$'
git submodule status --recursive

for attempt in 1 2 3; do
  echo "[ci_submodules] Update attempt $attempt/3 (depth=$depth)"
  if git -c protocol.version=2 \
      -c http.lowSpeedLimit=1024 -c http.lowSpeedTime=60 \
      -c fetch.fsckObjects=true \
      submodule update "${update_args[@]}"; then
    break
  else
    status=$?
  fi
  if [[ "$attempt" == 3 ]]; then
    echo "::error::Submodule checkout failed after 3 attempts (git exit $status). Sources and required commits are listed above; no alternate revision was used." >&2
    exit "$status"
  fi
  delay=$((attempt * 10))
  echo "::warning::Submodule update failed (git exit $status); retrying in ${delay}s."
  sleep "$delay"
done

# foreach skips uninitialized modules, so reject missing/conflicting gitlinks first.
submodule_status="$(git submodule status --recursive)"
printf '%s\n' "$submodule_status"
if grep -Eq '^[-+U]' <<< "$submodule_status"; then
  echo '::error::Submodule missing, conflicted, or at a different commit.' >&2
  exit 1
fi
git submodule foreach --quiet --recursive '
  expected=$(git -C "$toplevel" rev-parse "HEAD:$sm_path") || exit 1
  actual=$(git rev-parse --verify HEAD) || exit 1
  if [ "$actual" != "$expected" ]; then
    echo "::error::$displaypath: expected $expected, got $actual" >&2
    exit 1
  fi
  if ! git diff --quiet HEAD --; then
    echo "::error::$displaypath: tracked source differs from $expected" >&2
    exit 1
  fi
  git config --local gc.auto 0 || exit 1
  echo "[ci_submodules] Verified $displaypath at $actual"
'

#!/usr/bin/env bash
# Verify the runner's system SQLite; install only when its development package is missing.
# CI callers bound this whole step to five minutes, including package-manager waits.
set -euo pipefail

if package_status=$(dpkg-query -W -f='${Status}' libsqlite3-dev 2>/dev/null) &&
    [[ "$package_status" == 'install ok installed' ]]; then
  echo '[ci_sqlite] Using installed libsqlite3-dev.'
else
  apt_options=(
    -o Acquire::Retries=2
    -o Acquire::http::Timeout=30
    -o Acquire::https::Timeout=30
    -o DPkg::Lock::Timeout=60
  )
  sudo env DEBIAN_FRONTEND=noninteractive apt-get "${apt_options[@]}" update -qq
  sudo env DEBIAN_FRONTEND=noninteractive apt-get "${apt_options[@]}" \
    install -y --no-install-recommends libsqlite3-dev
fi

test "$(dpkg-query -W -f='${Status}' libsqlite3-dev)" = 'install ok installed'
dpkg-query -W -f='${Package} ${Version}\n' libsqlite3-dev

# The Dart system-library hook loads this unversioned name, which the dev
# package supplies. Finding only libsqlite3.so.0 would not verify that contract.
python3 - <<'PY'
import ctypes

library = ctypes.CDLL('libsqlite3.so')
library.sqlite3_libversion.restype = ctypes.c_char_p
print('[ci_sqlite] Loaded libsqlite3.so: SQLite ' +
      library.sqlite3_libversion().decode('ascii'))
PY

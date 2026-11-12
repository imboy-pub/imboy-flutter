#!/usr/bin/env bash
# Prepare a real product variant only inside the isolated CI checkout.
set -euo pipefail
profile=${1:?product profile required}
app=$(git rev-parse --show-toplevel)
backend="$(dirname "$app")/imboy"
admin="$(dirname "$app")/imboyadmin"
manifest="$app/.github/scripts/uiux_full_product_manifest.json"
expected=5d6547fbf4c172e2ef98835284926d190b2c1557c5c15cbb3802f6df997eaa6b
[[ "$(shasum -a 256 "$manifest" | awk '{print $1}')" == "$expected" ]]
case "$profile" in
  phase1_delivery)
    python3 "$backend/scripts/generate_product_features.py" --check --require-profile "$profile" --app-dir "$app" --admin-dir "$admin"
    ;;
  full-selected)
    cp "$manifest" "$backend/config/product-feature-manifest.json"
    python3 "$backend/scripts/generate_product_features.py" --require-profile "$profile" --app-dir "$app" --admin-dir "$admin"
    python3 "$backend/scripts/generate_product_features.py" --check --require-profile "$profile" --app-dir "$app" --admin-dir "$admin"
    ;;
  *) echo "Unsupported product profile: $profile" >&2; exit 2 ;;
esac

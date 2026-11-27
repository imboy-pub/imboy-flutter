#!/usr/bin/env python3
"""Parse buildapp receipts, and exercise the actual shell receipt writer.

Run without arguments for regression tests, or pass receipt paths to validate
receipts produced by the end-to-end suite. PyYAML is a test-only dependency.
"""
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

import yaml


def validate_receipt(path):
    with Path(path).open(encoding="utf-8") as stream:
        receipt = yaml.safe_load(stream)
    assert isinstance(receipt, dict), "receipt must be a mapping"
    for key in ("identity_used", "url_scheme", "artifact_checks"):
        assert isinstance(receipt.get(key), dict), f"{key} must be a mapping"
    for key in ("disclosures", "artifacts"):
        values = receipt.get(key)
        assert isinstance(values, list), f"{key} must be a list"
        assert all(isinstance(value, str) for value in values), f"{key} must contain strings"
    identity = receipt["identity_used"]
    assert isinstance(receipt.get("customer_id"), str), "customer ID must be a string"
    assert isinstance(receipt["url_scheme"].get("configured_url_scheme"), str), "configured scheme must be a string"
    assert isinstance(identity.get("url_scheme"), str), "identity URL scheme note must be a string"
    status = receipt.get("ios_app_group_validation_status")
    if status == "verified":
        assert identity["ios_app_group_id"] == f"group.{identity['ios_bundle_id']}"
        assert identity["ios_share_url_scheme"] == f"ShareMedia-{identity['ios_bundle_id']}"
        assert receipt["ios_app_group_evidence_source"] != "not-applicable"
    else:
        assert status == "not-applicable", "unknown App Group validation status"
        assert identity["ios_app_group_id"] == "not-injected"
        assert identity["ios_share_url_scheme"] == "not-injected"
        assert receipt["ios_app_group_evidence_source"] == "not-applicable"
    artifact = receipt["artifact_checks"]
    if artifact["ios_app_group_validation_status"] == "verified-unsigned-plists":
        assert receipt["build_status"] == "PASS"
        assert artifact["ios_app_group_id"] == identity["ios_app_group_id"]
        assert artifact["ios_share_url_scheme"] == identity["ios_share_url_scheme"]
        assert artifact["ios_share_extension_bundle_id"] == f"{identity['ios_bundle_id']}.ShareExtension"
        assert artifact["ios_signed_entitlements_status"] == "NOT_VERIFIED_UNSIGNED_BUILD"
        assert "ShareExtension.appex/Info.plist" in artifact["ios_app_group_evidence_source"]
    else:
        for key in ("ios_app_group_validation_status", "ios_app_group_id", "ios_share_url_scheme",
                    "ios_share_extension_bundle_id", "ios_signed_entitlements_status", "ios_app_group_evidence_source"):
            assert artifact[key] == "not-built", f"{key} claims unchecked artifact evidence"
    if receipt["build_status"] == "DRY_RUN":
        assert artifact["ios_app_group_validation_status"] == "not-built"
        assert receipt["artifacts"] == []
    return receipt


class ReceiptWriterTests(unittest.TestCase):
    def render(self, **overrides):
        # Execute the production writer itself without running Flutter or
        # creating a worktree. This catches YAML structure and escaping errors
        # in buildapp.sh rather than testing a duplicate serializer.
        source = Path(__file__).with_name("buildapp.sh").read_text(encoding="utf-8")
        start = source.index('MANIFEST="$STAGING_DIR/build-manifest.yaml"')
        end = source.index("# SHA256SUMS covers exactly:", start)
        values = {
            "RUN_ID": "20261127000100-123-456", "CUSTOMER_ID": "customer-alpha",
            "PROJECT_PURPOSE": "buildapp-selftest",
            "AUTH_STATUS": "selftest-fixture", "DRY_RUN": "1",
            "ENV_NAME": "development", "APP_ENV": "dev", "BUILD_STATUS": "DRY_RUN",
            "SRC_COMMIT": "a" * 40, "BUILD_NAME": "1.0.0-alpha.19", "BUILD_NUMBER": "11270001",
            "ASSET_PKG_NAME": "fixture-assets-v1", "ASSET_VERSION": "1",
            "REPLACEMENT_MAP": "manifest/replacement-map.yaml", "APP_NAME": "TestApp",
            "APP_ID": "com.example.alpha", "BUNDLE_ID": "com.example.alpha",
            "IOS_APP_GROUP_ID": "group.com.example.alpha", "IOS_APP_GROUP_STATUS": "verified",
            "IOS_SHARE_SCHEME": "ShareMedia-com.example.alpha",
            "IOS_APP_GROUP_EVIDENCE": "ShareExtension-Info.plist + Runner/ShareExtension-entitlements",
            "URL_SCHEME_NOTE": "customer scheme: alphaapp", "RESOLVED_SCHEME": "alphaapp",
            "SCHEME_RESOLUTION": "identity.url_scheme", "SCHEME_INHERITED": "0",
            "ANDROID_REGISTERED_SCHEMES": "not-injected", "IOS_REGISTERED_SCHEMES": "alphaapp",
            "IOS_ALL_URL_SCHEMES": "alphaapp, alipay, weixin", "URL_SCHEME_VALIDATION": "verified",
            "API_SOURCE": "inherited-vendor-demo", "ANDROID_APK_SCHEMES": "not-built",
            "ANDROID_APK_TOOL": "none", "IOS_APP_SCHEMES": "not-built", "PUSH_DEMO": "false",
            "IOS_APP_GROUP_ARTIFACT_ID": "not-built", "IOS_SHARE_ARTIFACT_SCHEME": "not-built",
            "IOS_SHARE_ARTIFACT_BUNDLE_ID": "not-built", "IOS_APP_GROUP_ARTIFACT_STATUS": "not-built",
            "FEATURES_GATE": "enforce", "GATE_DISCLOSURE": "", "CODEGEN_DISCLOSURE": "",
            "DEMO_SIGNING_DISCLOSURE": "", "VENDOR_URL_SCHEME": "imboy",
        }
        values.update(overrides)
        with tempfile.TemporaryDirectory(prefix="buildapp-receipt-") as directory:
            values["STAGING_DIR"] = directory
            values["CONFIG_DIR"] = directory
            prelude = """set -eu
PLATFORMS=(ios)
INVENTORY=()
yaml_get() {
  case "$2" in
    customer_type) printf '%s\\n' prospect ;;
    project_purpose) printf '%s\\n' "$PROJECT_PURPOSE" ;;
    store_submission.allowed) printf '%s\\n' false ;;
  esac
}
"""
            subprocess.run(["bash", "-c", prelude + source[start:end]],
                           env={**os.environ, **values}, check=True, capture_output=True, text=True)
            return validate_receipt(Path(directory) / "build-manifest.yaml")

    def test_ios_receipt_keeps_identity_and_top_level_evidence(self):
        receipt = self.render()
        self.assertEqual(receipt["identity_used"]["url_scheme"], "customer scheme: alphaapp")
        self.assertEqual(receipt["identity_used"]["ios_app_group_id"], "group.com.example.alpha")

    def test_uninjected_platform_does_not_claim_app_group_evidence(self):
        receipt = self.render(IOS_APP_GROUP_ID="not-injected", IOS_APP_GROUP_STATUS="not-applicable",
                              IOS_APP_GROUP_EVIDENCE="not-applicable", IOS_SHARE_SCHEME="not-injected")
        self.assertEqual(receipt["ios_app_group_validation_status"], "not-applicable")

    def test_free_text_round_trips_quotes_colons_and_newlines(self):
        text = '客户😀: "Alpha" # note\\path\nsecond\tline'
        receipt = self.render(APP_NAME=text, CODEGEN_DISCLOSURE=text,
                              PROJECT_PURPOSE="buildapp-selftest: receipt")
        self.assertEqual(receipt["identity_used"]["display_name"], text)
        self.assertIn(text, receipt["disclosures"])
        self.assertEqual(receipt["project_purpose"], "buildapp-selftest: receipt")

    def test_yaml_keyword_identity_values_stay_strings(self):
        for value in ("null", "yes", "on", "true"):
            with self.subTest(value=value):
                receipt = self.render(RESOLVED_SCHEME=value, CUSTOMER_ID=value)
                self.assertEqual(receipt["url_scheme"]["configured_url_scheme"], value)
                self.assertEqual(receipt["customer_id"], value)

    def test_inherited_scheme_disclosure_is_a_string(self):
        receipt = self.render(SCHEME_INHERITED="1", URL_SCHEME_NOTE="vendor scheme: imboy")
        self.assertTrue(any("INHERITS the vendor imboy://" in item for item in receipt["disclosures"]))

    def test_unsigned_artifact_does_not_claim_signed_entitlements(self):
        receipt = self.render(DRY_RUN="0", BUILD_STATUS="PASS",
                              IOS_APP_GROUP_ARTIFACT_STATUS="verified-unsigned-plists",
                              IOS_APP_GROUP_ARTIFACT_ID="group.com.example.alpha",
                              IOS_SHARE_ARTIFACT_SCHEME="ShareMedia-com.example.alpha",
                              IOS_SHARE_ARTIFACT_BUNDLE_ID="com.example.alpha.ShareExtension")
        self.assertEqual(receipt["artifact_checks"]["ios_signed_entitlements_status"],
                         "NOT_VERIFIED_UNSIGNED_BUILD")


if __name__ == "__main__":
    if len(sys.argv) > 1:
        for filename in sys.argv[1:]:
            validate_receipt(filename)
            print(f"Receipt YAML verified: {filename}")
    else:
        unittest.main()

#!/usr/bin/env python3
"""Regression tests using copies of the real iOS target configuration."""
import copy
import json
import plistlib
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

import buildapp_ios_app_group_tools as share

REPO = Path(__file__).resolve().parents[1]
TOOL = Path(share.__file__).resolve()
ALPHA = "com.example.customer-alpha"
BETA = "com.example.customer-beta"
SOURCE_FILES = ("Runner/Info.plist", "ShareExtension/Info.plist", *share.REQUIRED_ENTITLEMENTS)
PROJECT_FILE = "Runner.xcodeproj/project.pbxproj"
ALL_SOURCE_FILES = (*SOURCE_FILES, PROJECT_FILE)


def write_plist(path, value, binary=False):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(plistlib.dumps(value, fmt=plistlib.FMT_BINARY if binary else plistlib.FMT_XML))


class ShareIdentityTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="buildapp-share-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.ios = self.source("ios")

    def source(self, name):
        root = self.root / name
        for relative in ALL_SOURCE_FILES:
            target = root / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(REPO / "ios" / relative, target)
        return root

    def snapshot(self, root=None):
        root = root or self.ios
        return {p.relative_to(root).as_posix(): p.read_bytes() for p in root.rglob("*") if p.is_file()}

    def alter(self, relative, update):
        path = self.ios / relative
        data = share.load(path)
        update(data)
        write_plist(path, data)

    def reject_without_writes(self, bundle=ALPHA):
        before = self.snapshot()
        with self.assertRaises(ValueError):
            share.inject(self.ios, bundle)
        self.assertEqual(before, self.snapshot())

    def built_app(self, binary=False):
        share.inject(self.ios, ALPHA)
        app = self.root / "Runner.app"
        for source, relative, bundle in (
            ("Runner/Info.plist", "Info.plist", ALPHA),
            ("ShareExtension/Info.plist", "PlugIns/ShareExtension.appex/Info.plist", f"{ALPHA}.ShareExtension"),
        ):
            data = share.load(self.ios / source)
            data["CFBundleIdentifier"] = bundle
            write_plist(app / relative, data, binary=binary)
        return app

    def test_two_customers_use_distinct_groups_and_matching_callbacks(self):
        original = {p: (REPO / "ios" / p).read_bytes() for p in ALL_SOURCE_FILES}
        beta = self.source("beta")
        for root, bundle, other in ((self.ios, ALPHA, BETA), (beta, BETA, ALPHA)):
            with self.subTest(bundle=bundle):
                evidence = share.inject(root, bundle)
                self.assertEqual(f"group.{bundle}", evidence["app_group_id"])
                self.assertEqual(f"ShareMedia-{bundle}", evidence["share_url_scheme"])
                self.assertEqual(sorted(share.REQUIRED_ENTITLEMENTS), evidence["entitlement_files"])
                self.assertEqual("PlugIns", evidence["extension_embed_destination"])
                self.assertEqual(evidence, share.verify_source(root, bundle))
                for relative in SOURCE_FILES:
                    self.assertNotIn(f"group.{other}".encode(), (root / relative).read_bytes())
                    self.assertNotIn(b"group.pub.imboy.app", (root / relative).read_bytes())
                runner = share.load(root / "Runner/Info.plist")
                schemes = [s for t in runner["CFBundleURLTypes"] for s in t["CFBundleURLSchemes"]]
                self.assertIn(f"ShareMedia-{bundle}", schemes)
                self.assertNotIn("ShareMedia-pub.imboy.app", schemes)
        self.assertEqual(original, {p: (REPO / "ios" / p).read_bytes() for p in ALL_SOURCE_FILES})

    def test_only_group_and_share_callback_fields_change(self):
        self.alter("Runner/RunnerRelease.entitlements", lambda d: d.update({"aps-environment": "production"}))
        expected = {relative: share.load(self.ios / relative) for relative in SOURCE_FILES}
        for relative, data in expected.items():
            if relative.endswith(".entitlements"):
                data[share.ENTITLEMENT_KEY] = [f"group.{ALPHA}"]
            else:
                data["AppGroupId"] = f"group.{ALPHA}"
        runner = expected["Runner/Info.plist"]
        for entry in runner["CFBundleURLTypes"]:
            if entry["CFBundleURLName"] == "pub.imboy.app":
                entry["CFBundleURLSchemes"] = [f"ShareMedia-{ALPHA}"]
        share.inject(self.ios, ALPHA)
        self.assertEqual(expected, {p: share.load(self.ios / p) for p in SOURCE_FILES})

    def test_repeated_injection_is_idempotent(self):
        first = share.inject(self.ios, ALPHA)
        before = self.snapshot()
        self.assertEqual(first, share.inject(self.ios, ALPHA))
        self.assertEqual(before, self.snapshot())

    def test_embed_destination_is_the_only_project_edit(self):
        path = self.ios / PROJECT_FILE
        baseline = path.read_bytes()
        self.assertEqual(1, baseline.count(b"dstSubfolderSpec = 10;"))
        share.inject(self.ios, ALPHA)
        self.assertEqual(baseline.replace(b"dstSubfolderSpec = 10;", b"dstSubfolderSpec = 13;"), path.read_bytes())
        changed = path.read_bytes()
        share.inject(self.ios, ALPHA)
        self.assertEqual(changed, path.read_bytes())

    def test_other_copy_phase_destinations_remain_unchanged(self):
        path = self.ios / PROJECT_FILE
        other = """\t\tOTHERFRAMEWORKSPHASE /* Embed Frameworks */ = {
\t\t\tisa = PBXCopyFilesBuildPhase;
\t\t\tdstPath = "";
\t\t\tdstSubfolderSpec = 10;
\t\t\tfiles = ();
\t\t\tname = "Embed Frameworks";
\t\t};
"""
        text = path.read_text()
        text = text.replace("/* End PBXCopyFilesBuildPhase section */", other + "/* End PBXCopyFilesBuildPhase section */")
        path.write_text(text)
        share.inject(self.ios, ALPHA)
        self.assertEqual(text.replace("dstSubfolderSpec = 10;", "dstSubfolderSpec = 13;", 1), path.read_text())
        self.assertIn(other, path.read_text())

    def test_missing_or_duplicate_embed_phase_is_rejected_before_writes(self):
        path = self.ios / PROJECT_FILE
        baseline = path.read_text()
        phase = re.search(
            r"(?ms)^\t\t[A-Za-z0-9]+ /\* Embed App Extensions \*/ = \{.*?^\t\t\};\n", baseline
        ).group(0)
        for text in (baseline.replace(phase, ""), baseline.replace(phase, phase * 2)):
            with self.subTest(text=text[:40]):
                path.write_text(text)
                self.reject_without_writes()
        path.unlink()
        before = self.snapshot()
        with self.assertRaises(OSError):
            share.inject(self.ios, ALPHA)
        self.assertEqual(before, self.snapshot())

    def test_unknown_embed_structure_destination_or_target_is_rejected(self):
        path = self.ios / PROJECT_FILE
        baseline = path.read_text()
        replacements = (
            ('dstPath = "";', 'dstPath = "Other";'),
            ("dstSubfolderSpec = 10;", "dstSubfolderSpec = 16;"),
            ("dstSubfolderSpec = 10;", "dstSubfolderSpec = 10; unknown = YES;"),
            ("BB2D3E4F5A60718293A4B6 /* ShareExtension.appex in Embed App Extensions */,",
             "OTHERFILE /* ShareExtension.appex in Embed App Extensions */,"),
            ("fileRef = AA4B5C6D7E8F90120203A4B8 /* ShareExtension.appex */;",
             "fileRef = OTHERPRODUCT /* ShareExtension.appex */;"),
            ("path = ShareExtension.appex;", "path = ForeignExtension.appex;"),
            ("II1A2B3C4D5E60718293A4B5 /* Embed App Extensions */,", ""),
        )
        for old, new in replacements:
            with self.subTest(new=new):
                self.assertIn(old, baseline)
                path.write_text(baseline.replace(old, new))
                self.reject_without_writes()

    def test_source_verification_rejects_frameworks_destination(self):
        share.inject(self.ios, ALPHA)
        path = self.ios / PROJECT_FILE
        path.write_text(path.read_text().replace("dstSubfolderSpec = 13;", "dstSubfolderSpec = 10;"))
        with self.assertRaises(ValueError):
            share.verify_source(self.ios, ALPHA)

    def test_cannot_repurpose_another_customer_tree(self):
        share.inject(self.ios, BETA)
        self.reject_without_writes()

    def test_invalid_or_vendor_bundle_fails_before_writes(self):
        for bundle in ("pub.imboy.app", "PUB.ImBoy.app", "plain", "com.example_bad.app", "com..app",
                       ".com.app", "com.app.", "com.app/name", "com.app *", "com.客户.app", "com.app\n"):
            with self.subTest(bundle=bundle):
                self.reject_without_writes(bundle)

    def test_every_required_entitlement_must_exist(self):
        for relative in share.REQUIRED_ENTITLEMENTS:
            with self.subTest(relative=relative):
                path = self.ios / relative
                original = path.read_bytes()
                path.unlink()
                self.reject_without_writes()
                path.write_bytes(original)

    def test_additional_entitlements_are_injected_and_verified(self):
        extra = self.ios / "Runner/RunnerStaging.entitlements"
        shutil.copyfile(self.ios / "Runner/Runner.entitlements", extra)
        result = share.inject(self.ios, ALPHA)
        self.assertIn("Runner/RunnerStaging.entitlements", result["entitlement_files"])
        data = share.load(extra)
        data[share.ENTITLEMENT_KEY] = [f"group.{BETA}"]
        write_plist(extra, data)
        with self.assertRaises(ValueError):
            share.verify_source(self.ios, ALPHA)

    def test_invalid_entitlements_fail_before_any_plist_is_rewritten(self):
        path = self.ios / "ShareExtension/ShareExtension.entitlements"
        baseline = share.load(path)
        for groups in ([], "group.pub.imboy.app", [True], [f"group.{BETA}"],
                       [share.VENDOR_GROUP, f"group.{ALPHA}"], [share.VENDOR_GROUP] * 2):
            with self.subTest(groups=groups):
                data = copy.deepcopy(baseline)
                data[share.ENTITLEMENT_KEY] = groups
                write_plist(path, data)
                self.reject_without_writes()
        write_plist(path, {})
        self.reject_without_writes()

    def test_foreign_or_wrongly_typed_app_group_overrides_fail(self):
        for relative in ("Runner/Info.plist", "ShareExtension/Info.plist"):
            baseline = share.load(self.ios / relative)
            for group in (f"group.{BETA}", [share.VENDOR_GROUP], 42, ""):
                with self.subTest(relative=relative, group=group):
                    data = copy.deepcopy(baseline)
                    data["AppGroupId"] = group
                    write_plist(self.ios / relative, data)
                    self.reject_without_writes()
            write_plist(self.ios / relative, baseline)

    def test_stale_group_in_each_source_is_detected_after_injection(self):
        share.inject(self.ios, ALPHA)
        for relative in SOURCE_FILES:
            path = self.ios / relative
            original = path.read_bytes()
            data = share.load(path)
            if relative.endswith(".entitlements"):
                data[share.ENTITLEMENT_KEY] = [share.VENDOR_GROUP]
            else:
                data["AppGroupId"] = share.VENDOR_GROUP
            write_plist(path, data)
            with self.subTest(relative=relative), self.assertRaises(ValueError):
                share.verify_source(self.ios, ALPHA)
            path.write_bytes(original)

    def test_missing_or_malformed_plists_fail_without_writes(self):
        path = self.ios / "ShareExtension/Info.plist"
        for payload in (b"not a plist", b"<?xml version='1.0'?><plist><dict>", plistlib.dumps([])):
            with self.subTest(payload=payload):
                path.write_bytes(payload)
                self.reject_without_writes()
        path.unlink()
        self.reject_without_writes()

    def test_share_callback_cannot_be_missing_duplicate_or_foreign(self):
        path = self.ios / "Runner/Info.plist"
        baseline = share.load(path)
        share_type = next(t for t in baseline["CFBundleURLTypes"] if t["CFBundleURLName"] == "pub.imboy.app")
        variants = []
        missing = copy.deepcopy(baseline)
        missing["CFBundleURLTypes"].remove(share_type)
        variants.append(missing)
        duplicate = copy.deepcopy(baseline)
        duplicate["CFBundleURLTypes"].append(copy.deepcopy(share_type))
        variants.append(duplicate)
        for value in (f"ShareMedia-{BETA}", "ShareMedia-pub.imboy.app"):
            alias = copy.deepcopy(baseline)
            alias["CFBundleURLTypes"].append({"CFBundleURLName": "alias", "CFBundleURLSchemes": [value.lower()]})
            variants.append(alias)
        for schemes in ([f"ShareMedia-{BETA}"], ["ShareMedia-pub.imboy.app"] * 2, "ShareMedia-pub.imboy.app", [42]):
            malformed = copy.deepcopy(baseline)
            next(t for t in malformed["CFBundleURLTypes"] if t["CFBundleURLName"] == "pub.imboy.app")["CFBundleURLSchemes"] = schemes
            variants.append(malformed)
        for index, data in enumerate(variants):
            with self.subTest(index=index):
                write_plist(path, data)
                self.reject_without_writes()

    def test_extension_cannot_register_a_callback(self):
        self.alter("ShareExtension/Info.plist", lambda d: d.update({"CFBundleURLTypes": []}))
        self.reject_without_writes()

    def test_literal_foreign_source_bundle_is_rejected(self):
        self.alter("Runner/Info.plist", lambda d: d.update({"CFBundleIdentifier": BETA}))
        self.reject_without_writes()

    def test_built_binary_plists_report_actual_customer_identity(self):
        result = share.verify_app(self.built_app(binary=True), ALPHA)
        self.assertEqual(f"group.{ALPHA}", result["app_group_id"])
        self.assertEqual(f"ShareMedia-{ALPHA}", result["share_url_scheme"])
        self.assertEqual(ALPHA, result["runner_bundle_id"])
        self.assertEqual(f"{ALPHA}.ShareExtension", result["extension_bundle_id"])
        self.assertEqual([], result["entitlement_files"])

    def test_built_runner_default_group_is_valid_but_stale_override_is_not(self):
        app = self.built_app()
        path = app / "Info.plist"
        data = share.load(path)
        del data["AppGroupId"]
        write_plist(path, data)
        self.assertEqual(f"group.{ALPHA}", share.verify_app(app, ALPHA)["app_group_id"])
        data["AppGroupId"] = share.VENDOR_GROUP
        write_plist(path, data)
        with self.assertRaises(ValueError):
            share.verify_app(app, ALPHA)

    def test_built_extension_is_required(self):
        app = self.built_app()
        shutil.rmtree(app / "PlugIns")
        with self.assertRaises(ValueError):
            share.verify_app(app, ALPHA)

    def test_built_bundle_group_and_callback_mismatches_are_rejected(self):
        app = self.built_app()
        for relative, key, value in (
            ("Info.plist", "CFBundleIdentifier", BETA),
            ("PlugIns/ShareExtension.appex/Info.plist", "CFBundleIdentifier", f"{BETA}.ShareExtension"),
            ("PlugIns/ShareExtension.appex/Info.plist", "AppGroupId", share.VENDOR_GROUP),
        ):
            path = app / relative
            original = path.read_bytes()
            data = share.load(path)
            data[key] = value
            write_plist(path, data)
            with self.subTest(relative=relative, key=key), self.assertRaises(ValueError):
                share.verify_app(app, ALPHA)
            path.write_bytes(original)
        path = app / "Info.plist"
        data = share.load(path)
        next(t for t in data["CFBundleURLTypes"] if t["CFBundleURLName"] == "pub.imboy.app")["CFBundleURLSchemes"] = ["ShareMedia-pub.imboy.app"]
        write_plist(path, data)
        with self.assertRaises(ValueError):
            share.verify_app(app, ALPHA)

    def test_cli_emits_json_and_returns_nonzero_for_invalid_artifact(self):
        result = subprocess.run([sys.executable, str(TOOL), "inject", str(self.ios), ALPHA], capture_output=True, text=True)
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertEqual(f"group.{ALPHA}", json.loads(result.stdout)["app_group_id"])
        result = subprocess.run([sys.executable, str(TOOL), "verify-app", str(self.root / "missing.app"), ALPHA], capture_output=True, text=True)
        self.assertNotEqual(0, result.returncode)
        self.assertEqual("", result.stdout)
        self.assertIn("validation failed", result.stderr)
        self.assertNotIn("Traceback", result.stderr)


if __name__ == "__main__":
    unittest.main()

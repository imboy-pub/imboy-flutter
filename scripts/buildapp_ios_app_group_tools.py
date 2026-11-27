#!/usr/bin/env python3
"""Inject and verify the customer identity used by share_handler_ios 0.0.15.

Source verification covers both plists and every target entitlement file.
verify-app checks the built, unsigned app/extension plists; it does not claim
to verify code-signing entitlements or device-level container access.
"""
import argparse
import json
import plistlib
import re
import sys
from pathlib import Path

VENDOR_BUNDLE = "pub.imboy.app"
VENDOR_GROUP = f"group.{VENDOR_BUNDLE}"
SHARE_URL_NAME = VENDOR_BUNDLE  # Stable URL type key, not the callback identity.
ENTITLEMENT_KEY = "com.apple.security.application-groups"
PROJECT_FILE = "Runner.xcodeproj/project.pbxproj"
REQUIRED_ENTITLEMENTS = (
    "Runner/Runner.entitlements",
    "Runner/RunnerProfile.entitlements",
    "Runner/RunnerRelease.entitlements",
    "ShareExtension/ShareExtension.entitlements",
)


def load(path):
    try:
        with Path(path).open("rb") as stream:
            value = plistlib.load(stream)
    except Exception as exc:
        # plistlib rejects XML entity declarations. Normalize its XML/binary
        # parser failures at this input boundary without importing a raw parser.
        raise ValueError(f"{path}: invalid or missing plist: {exc}") from exc
    if not isinstance(value, dict):
        raise ValueError(f"{path}: plist root must be a dictionary")
    return value


def validate_bundle(bundle_id):
    if not re.fullmatch(r"[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+", bundle_id):
        raise ValueError(f"invalid iOS bundle identifier: {bundle_id!r}")
    if bundle_id.casefold() == VENDOR_BUNDLE.casefold():
        raise ValueError("customer builds may not reuse the vendor bundle/App Group")


def share_url_type(info, allowed_schemes, path):
    types = info.get("CFBundleURLTypes")
    if not isinstance(types, list) or any(not isinstance(t, dict) for t in types):
        raise ValueError(f"{path}: missing or invalid CFBundleURLTypes")
    matches = [t for t in types if t.get("CFBundleURLName") == SHARE_URL_NAME]
    if len(matches) != 1:
        raise ValueError(f"{path}: expected exactly one ShareMedia URL type")
    target = matches[0]
    schemes = target.get("CFBundleURLSchemes")
    if not isinstance(schemes, list) or len(schemes) != 1 or schemes[0] not in allowed_schemes:
        raise ValueError(f"{path}: unexpected ShareMedia callback: {schemes!r}")
    for entry in types:
        values = entry.get("CFBundleURLSchemes")
        if not isinstance(values, list) or any(not isinstance(v, str) for v in values):
            raise ValueError(f"{path}: invalid CFBundleURLSchemes")
        if entry is not target and any(v.casefold().startswith("sharemedia-") for v in values):
            raise ValueError(f"{path}: duplicate or cross-customer ShareMedia callback")
    return target


def source_files(ios_dir):
    root = Path(ios_dir)
    for relative in REQUIRED_ENTITLEMENTS:
        if not (root / relative).is_file():
            raise ValueError(f"missing required entitlement file: {relative}")
    entitlements = sorted({
        path for target in ("Runner", "ShareExtension")
        for path in (root / target).glob("*.entitlements")
    })
    paths = [root / "Runner/Info.plist", root / "ShareExtension/Info.plist", *entitlements]
    return root, paths, {path: load(path) for path in paths}


def extension_embed_project(ios_dir, injecting=False):
    """Validate this repo's single embed phase; change only its destination ID."""
    path = Path(ios_dir) / PROJECT_FILE
    project = path.read_bytes().decode("utf-8")

    def one(pattern, text, label):
        matches = list(re.finditer(pattern, text, re.MULTILINE | re.DOTALL))
        if len(matches) != 1:
            raise ValueError(f"{path}: expected one {label}")
        return matches[0]

    section = one(
        r"/\* Begin PBXCopyFilesBuildPhase section \*/(.*?)/\* End PBXCopyFilesBuildPhase section \*/",
        project, "PBXCopyFilesBuildPhase section",
    )
    phase = one(
        r"^[ \t]*([A-Za-z0-9]+) /\* Embed App Extensions \*/ = \{(.*?)^[ \t]*\};[ \t]*$",
        section.group(1), "Embed App Extensions phase",
    )
    # A second phase with a different object comment but the same name is also
    # ambiguous. Unknown fields/order or destinations fail for human review.
    one(r'\bname\s*=\s*"Embed App Extensions"\s*;', section.group(1), "embed phase name")
    fields = re.fullmatch(
        r'\s*isa\s*=\s*PBXCopyFilesBuildPhase;'
        r'\s*buildActionMask\s*=\s*2147483647;'
        r'\s*dstPath\s*=\s*"";'
        r'\s*dstSubfolderSpec\s*=\s*(?P<destination>[0-9]+);'
        r'\s*files\s*=\s*\(\s*(?P<file>[A-Za-z0-9]+)'
        r'\s*/\* ShareExtension.appex in Embed App Extensions \*/,\s*\);'
        r'\s*name\s*=\s*"Embed App Extensions";'
        r'\s*runOnlyForDeploymentPostprocessing\s*=\s*0;\s*',
        phase.group(2),
    )
    if fields is None:
        raise ValueError(f"{path}: unrecognized ShareExtension embed phase structure")
    if fields.group("destination") not in (("10", "13") if injecting else ("13",)):
        raise ValueError(f"{path}: ShareExtension must embed in PlugIns (dstSubfolderSpec=13)")

    # Resolve the sole copied build-file to its actual .appex product, so a
    # misleading comment cannot cause us to rewrite a different copy phase.
    build_file = one(
        rf"^[ \t]*{re.escape(fields.group('file'))}\s*/\*[^\n]*?\*/\s*=\s*\{{([^\n]*)\}};[ \t]*$",
        project, "ShareExtension embed build-file reference",
    )
    build_fields = re.fullmatch(
        r'\s*isa\s*=\s*PBXBuildFile;\s*fileRef\s*=\s*([A-Za-z0-9]+)'
        r'\s*/\* ShareExtension.appex \*/;\s*settings\s*=\s*\{\s*ATTRIBUTES\s*=\s*\('
        r'(?:\s*(?:RemoveHeadersOnCopy|CodeSignOnCopy),)*\s*\);\s*\};\s*',
        build_file.group(1),
    )
    if build_fields is None:
        raise ValueError(f"{path}: unrecognized ShareExtension build-file target")
    file_ref = one(
        rf"^[ \t]*{re.escape(build_fields.group(1))}\s*/\*[^\n]*?\*/\s*=\s*\{{([^\n]*)\}};[ \t]*$",
        project, "ShareExtension product reference",
    )
    if not re.fullmatch(
        r'\s*isa\s*=\s*PBXFileReference;\s*explicitFileType\s*=\s*"wrapper.app-extension";'
        r'\s*includeInIndex\s*=\s*0;\s*path\s*=\s*ShareExtension.appex;'
        r'\s*sourceTree\s*=\s*BUILT_PRODUCTS_DIR;\s*', file_ref.group(1),
    ):
        raise ValueError(f"{path}: embed reference is not the ShareExtension.appex product")
    runner = one(
        r"^[ \t]*[A-Za-z0-9]+ /\* Runner \*/ = \{\s*isa = PBXNativeTarget;(.*?)^[ \t]*\};[ \t]*$",
        project, "Runner native target",
    )
    phases = one(r"\bbuildPhases\s*=\s*\((.*?)\);", runner.group(1), "Runner buildPhases")
    phase_id = re.escape(phase.group(1))
    one(rf"\b{phase_id}\s*/\* Embed App Extensions \*/\s*,", phases.group(1), "Runner embed phase reference")
    if len(re.findall(rf"\b{phase_id}\b", project)) != 2:
        raise ValueError(f"{path}: embed phase must belong only to Runner")

    start = section.start(1) + phase.start(2) + fields.start("destination")
    end = section.start(1) + phase.start(2) + fields.end("destination")
    return path, (project[:start] + "13" + project[end:]).encode("utf-8")


def check_source_identity(data, paths, bundle_id, injecting=False):
    group = f"group.{bundle_id}"
    scheme = f"ShareMedia-{bundle_id}"
    allowed_groups = (VENDOR_GROUP, group) if injecting else (group,)
    allowed_schemes = (f"ShareMedia-{VENDOR_BUNDLE}", scheme) if injecting else (scheme,)
    for path, expected_bundle in zip(paths[:2], (bundle_id, f"{bundle_id}.ShareExtension")):
        info = data[path]
        if info.get("CFBundleIdentifier") not in (
            "$(PRODUCT_BUNDLE_IDENTIFIER)", "${PRODUCT_BUNDLE_IDENTIFIER}", expected_bundle
        ):
            raise ValueError(f"{path}: unexpected source CFBundleIdentifier")
        if injecting and "AppGroupId" not in info:
            continue  # The plugin supports a default; injection makes it explicit.
        if info.get("AppGroupId") not in allowed_groups:
            raise ValueError(f"{path}: unexpected AppGroupId={info.get('AppGroupId')!r}")
    if "CFBundleURLTypes" in data[paths[1]]:
        raise ValueError(f"{paths[1]}: ShareExtension must not register URL types")
    share_url_type(data[paths[0]], allowed_schemes, paths[0])
    for path in paths[2:]:
        groups = data[path].get(ENTITLEMENT_KEY)
        if not isinstance(groups, list) or len(groups) != 1 or groups[0] not in allowed_groups:
            raise ValueError(f"{path}: unexpected {ENTITLEMENT_KEY}={groups!r}")


def verify_source(ios_dir, bundle_id):
    validate_bundle(bundle_id)
    root, paths, data = source_files(ios_dir)
    check_source_identity(data, paths, bundle_id)
    extension_embed_project(ios_dir)
    return {
        "app_group_id": data[paths[0]]["AppGroupId"],
        "share_url_scheme": share_url_type(
            data[paths[0]], (f"ShareMedia-{bundle_id}",), paths[0]
        )["CFBundleURLSchemes"][0],
        "entitlement_files": [path.relative_to(root).as_posix() for path in paths[2:]],
        "extension_embed_destination": "PlugIns",
    }


def inject(ios_dir, bundle_id):
    validate_bundle(bundle_id)
    _, paths, data = source_files(ios_dir)
    # Validate the entire input before the first write. A foreign customer group
    # or malformed/missing target must not leave a partly rewritten source tree.
    check_source_identity(data, paths, bundle_id, injecting=True)
    project_path, project_payload = extension_embed_project(ios_dir, injecting=True)
    for path in paths[:2]:
        data[path]["AppGroupId"] = f"group.{bundle_id}"
    share_url_type(
        data[paths[0]], (f"ShareMedia-{VENDOR_BUNDLE}", f"ShareMedia-{bundle_id}"), paths[0]
    )["CFBundleURLSchemes"] = [f"ShareMedia-{bundle_id}"]
    for path in paths[2:]:
        data[path][ENTITLEMENT_KEY] = [f"group.{bundle_id}"]
    payloads = {path: plistlib.dumps(value, sort_keys=False) for path, value in data.items()}
    payloads[project_path] = project_payload
    for path, payload in payloads.items():
        path.write_bytes(payload)
    return verify_source(ios_dir, bundle_id)


def verify_app(app_dir, bundle_id):
    validate_bundle(bundle_id)
    app = Path(app_dir)
    runner_path = app / "Info.plist"
    extension_path = app / "PlugIns/ShareExtension.appex/Info.plist"
    runner, extension = load(runner_path), load(extension_path)
    group = f"group.{bundle_id}"
    if runner.get("CFBundleIdentifier") != bundle_id:
        raise ValueError(f"{runner_path}: unexpected built Runner bundle identifier")
    if extension.get("CFBundleIdentifier") != f"{bundle_id}.ShareExtension":
        raise ValueError(f"{extension_path}: unexpected built ShareExtension bundle identifier")
    # Runner's default is group.<its bundle ID>; the extension must carry the
    # explicitly injected value. An existing wrong Runner override is rejected.
    if runner.get("AppGroupId", group) != group or extension.get("AppGroupId") != group:
        raise ValueError("built Runner and ShareExtension AppGroupId do not match the customer")
    if "CFBundleURLTypes" in extension:
        raise ValueError(f"{extension_path}: ShareExtension must not register URL types")
    target = share_url_type(runner, (f"ShareMedia-{bundle_id}",), runner_path)
    return {
        "app_group_id": extension["AppGroupId"],
        "share_url_scheme": target["CFBundleURLSchemes"][0],
        "entitlement_files": [],  # Unsigned plist checks are not signing evidence.
        "runner_bundle_id": runner["CFBundleIdentifier"],
        "extension_bundle_id": extension["CFBundleIdentifier"],
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("inject", "verify", "verify-app"))
    parser.add_argument("path", help="ios source directory, or built Runner.app for verify-app")
    parser.add_argument("bundle_id", help="customer Runner bundle identifier")
    args = parser.parse_args()
    try:
        action = {"inject": inject, "verify": verify_source, "verify-app": verify_app}[args.command]
        result = action(args.path, args.bundle_id)
    except (OSError, ValueError) as exc:
        print(f"iOS share identity validation failed: {exc}", file=sys.stderr)
        return 1
    print(json.dumps(result, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

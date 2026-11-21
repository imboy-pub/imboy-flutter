#!/usr/bin/env python3
"""Customer-scoped App Group injection and verification for iOS share builds."""
import argparse
import plistlib
import sys
from pathlib import Path

VENDOR_GROUP = "group.pub.imboy.app"
ENTITLEMENT_KEY = "com.apple.security.application-groups"


def load(path):
    try:
        with Path(path).open("rb") as stream:
            value = plistlib.load(stream)
    except Exception as exc:
        raise ValueError(f"{path}: invalid plist: {exc}") from exc
    if not isinstance(value, dict):
        raise ValueError(f"{path}: plist root must be a dictionary")
    return value


def save(path, value):
    with Path(path).open("wb") as stream:
        plistlib.dump(value, stream, fmt=plistlib.FMT_XML, sort_keys=False)


def validate(group):
    if not group.startswith("group.") or len(group) <= 6 or any(c.isspace() for c in group):
        raise ValueError(f"invalid App Group identifier: {group!r}")
    if group == VENDOR_GROUP:
        raise ValueError("customer builds may not reuse the vendor App Group")


def verify(info_path, expected, entitlements):
    validate(expected)
    info = load(info_path)
    actual = info.get("AppGroupId")
    if actual != expected:
        raise ValueError(f"{info_path}: AppGroupId={actual!r}, expected {expected!r}")
    for path in entitlements:
        data = load(path)
        groups = data.get(ENTITLEMENT_KEY)
        if groups != [expected]:
            raise ValueError(f"{path}: {ENTITLEMENT_KEY}={groups!r}, expected [{expected!r}]")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=("inject", "verify"))
    parser.add_argument("share_extension_info")
    parser.add_argument("expected_group")
    parser.add_argument("entitlements", nargs="+")
    args = parser.parse_args()
    try:
        validate(args.expected_group)
        files = [Path(p) for p in args.entitlements]
        if not files or any(not p.is_file() for p in files):
            raise ValueError("all Runner and ShareExtension entitlement files must exist")
        if args.command == "inject":
            info = load(args.share_extension_info)
            info["AppGroupId"] = args.expected_group
            save(args.share_extension_info, info)
            for path in files:
                data = load(path)
                groups = data.get(ENTITLEMENT_KEY)
                if not isinstance(groups, list) or not groups:
                    raise ValueError(f"{path}: missing {ENTITLEMENT_KEY}")
                if any(value not in (VENDOR_GROUP, args.expected_group) for value in groups):
                    raise ValueError(f"{path}: unexpected pre-existing App Groups: {groups!r}")
                data[ENTITLEMENT_KEY] = [args.expected_group]
                save(path, data)
        verify(args.share_extension_info, args.expected_group, files)
    except (OSError, ValueError) as exc:
        print(f"App Group validation failed: {exc}", file=sys.stderr)
        return 1
    print(f"App Group verified: {args.expected_group} ({len(files)} entitlement files)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

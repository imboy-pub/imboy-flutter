#!/usr/bin/env python3
"""Check repository SDK pins and the installed SDK before dependency resolution.

Uses only Python's standard library; ci.yml is the canonical Flutter pin.
pubspec.lock supplies the resolved dependencies' Flutter minimum.
--config-only requires no SDK. --dart-only supports standalone contract jobs.
Dependency constraints are still validated by flutter pub get.
"""

import argparse
import json
import os
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def version(value):
    if not re.fullmatch(r"\d+\.\d+\.\d+", value):
        raise ValueError(f"Expected a stable SDK version, got {value!r}")
    return tuple(map(int, value.split(".")))


def capture(pattern, text):
    match = re.search(pattern, text, re.MULTILINE)
    if not match:
        raise ValueError(f"Unsupported SDK configuration: {pattern}")
    return match.group(1)


def scalar_values(key, text):
    """Read the single-line SDK fields used by these workflows, quoted or bare."""
    for value in re.findall(rf"^\s*{key}:\s*(.+)$", text, re.MULTILINE):
        yield value.split(" #", 1)[0].strip().strip("'\"")


def check_configuration():
    pubspec = (ROOT / "pubspec.yaml").read_text()
    # Fail closed if these constraint forms change; do not approximate pub semver.
    dart_min = version(capture(r"^  sdk: \^(\d+\.\d+\.\d+)\s*$", pubspec))
    lock_sdks = capture(r"^sdks:\n([\s\S]*)", (ROOT / "pubspec.lock").read_text())
    flutter_min = version(capture(
        r'^  flutter: [\'"]>=(\d+\.\d+\.\d+)[\'"]\s*$', lock_sdks,
    ))
    workflows = ROOT / ".github/workflows"
    pin = capture(
        r"^  FLUTTER_VERSION: '(\d+\.\d+\.\d+)'$",
        (workflows / "ci.yml").read_text(),
    )
    if version(pin) < flutter_min:
        raise ValueError(f"CI Flutter {pin} is below project minimum {flutter_min}")
    paths = [*workflows.glob("*.yml"), *workflows.glob("*.yaml")]
    for path in sorted(paths):
        text = path.read_text()
        for declared in scalar_values("(?:FLUTTER_VERSION|flutter-version)", text):
            if declared == "${{ env.FLUTTER_VERSION }}":
                declared = capture(r"^  FLUTTER_VERSION: '(\d+\.\d+\.\d+)'$", text)
            version(declared)
            if declared != pin:
                raise ValueError(f"{path.name}: Flutter {declared} differs from {pin}")
        for declared in scalar_values("sdk-version", text):
            require_dart(version(declared), dart_min)
    return pin, dart_min, flutter_min


def require_dart(installed, minimum):
    if not minimum <= installed < (minimum[0] + 1, 0, 0):
        constraint = "^" + ".".join(map(str, minimum))
        raise ValueError(f"Dart {installed} does not satisfy {constraint}")


def installed_dart():
    output = subprocess.check_output(
        ["dart", "--version"], text=True, stderr=subprocess.STDOUT,
    )
    return capture(r"Dart SDK version: (\d+\.\d+\.\d+)", output)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--config-only", action="store_true")
    mode.add_argument("--dart-only", action="store_true")
    args = parser.parse_args()
    pin, dart_min, flutter_min = check_configuration()
    if args.config_only:
        print(f"PASS: workflow SDK pins consistent (Flutter {pin})")
        return
    if args.dart_only:
        dart = installed_dart()
    else:
        sdk = json.loads(subprocess.check_output(
            ["flutter", "--version", "--machine"], text=True,
        ))
        flutter = sdk["frameworkVersion"]
        if version(flutter) < flutter_min:
            raise ValueError(f"Flutter {flutter} is below project minimum {flutter_min}")
        if os.environ.get("CI") == "true" and flutter != pin:
            raise ValueError(f"CI installed Flutter {flutter}, expected {pin}")
        dart = sdk["dartSdkVersion"]
        path_dart = installed_dart()
        if path_dart != dart:
            raise ValueError(f"PATH Dart {path_dart} differs from Flutter's Dart {dart}")
    require_dart(version(dart), dart_min)
    print(f"PASS: Dart {dart} satisfies project SDK constraint; CI Flutter pin {pin}")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, subprocess.SubprocessError, KeyError) as error:
        print(f"SDK compatibility FAIL: {error}", file=sys.stderr)
        sys.exit(1)

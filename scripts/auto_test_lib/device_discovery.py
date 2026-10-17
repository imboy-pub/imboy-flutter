#!/usr/bin/env python3
"""真机设备发现与执行前资格判定（单一实现，供 CLI 与采集脚本共用）。

放在 auto_test_lib 包内以避免与 test/tooling/auto_test 测试包同名遮蔽：
capture_integration_screenshots 在 unittest 上下文中被 spec_from_file_location
加载时，顶层名 auto_test 已被测试包占用，无法从 scripts/auto_test.py 导入。
"""
from __future__ import annotations

import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def platform_for_device(device: str) -> str:
    """离线 dry-run 的平台推断（非资格）：macos/darwin 记为 macos，其余显示为 android。

    仅用于 dry-run 输出与指纹草稿；--execute 的真实资格一律走
    qualify_device(flutter devices --machine)，未发现/不支持/模拟器会被拒绝。
    """
    if device in ('macos', 'darwin') or device.startswith('darwin-'):
        return 'macos'
    return 'android'


def discover_devices() -> tuple[list[dict], str | None]:
    """flutter devices --machine 的结构化设备发现；失败返回 (devices, error_code)。"""
    try:
        completed = subprocess.run(
            ['flutter', 'devices', '--machine'],
            cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
            text=True, check=False, timeout=60,
        )
    except (OSError, subprocess.TimeoutExpired):
        return [], 'DEVICE_DISCOVERY_FAILED'
    if completed.returncode != 0:
        return [], 'DEVICE_DISCOVERY_FAILED'
    try:
        devices = json.loads(completed.stdout or '[]')
    except json.JSONDecodeError:
        return [], 'DEVICE_DISCOVERY_MALFORMED'
    if not isinstance(devices, list):
        return [], 'DEVICE_DISCOVERY_MALFORMED'
    return [d for d in devices if isinstance(d, dict)], None


def qualify_device(device: str, devices: list[dict]) -> tuple[str, list[str]]:
    """执行前真实设备资格：按 flutter devices 的 targetPlatform 判定平台。

    返回 (platform, errors)。未知设备、iOS、web/Chrome、Android 模拟器与
    其他不支持 target 一律拒绝，不默认为 android；仅 android-* 真机
    (emulator=false) 与 darwin (macOS 桌面) 通过。
    """
    if not device:
        return '', ['DEVICE_ID_MISSING']
    for dev in devices:
        if dev.get('id') != device:
            continue
        target = str(dev.get('targetPlatform') or '')
        emulator = bool(dev.get('emulator'))
        if target == 'darwin':
            return 'macos', []
        if target.startswith('android-'):
            if 'emulator' not in dev or dev.get('emulator') is None:
                # fail-closed：模拟器标志缺失时按资格不明拒绝，不默认真机。
                return '', ['ANDROID_EMULATOR_FLAG_UNKNOWN']
            if emulator:
                return '', ['ANDROID_EMULATOR_FORBIDDEN']
            return 'android', []
        if target.startswith('ios'):
            return '', ['IOS_DEVICE_NOT_IN_PLATFORM_SET']
        return '', [f'UNSUPPORTED_TARGET_PLATFORM:{target or "unknown"}']
    return '', ['DEVICE_NOT_FOUND']

#!/usr/bin/env python3
"""在 Android 真机 integration_test 的截图检查点采集 ADB 截图。

测试工具会在 AI_SCREENSHOT_HOLD_MS > 0 时输出 [AI_SCREENSHOT] 标记并暂停；
本脚本监听标记、通过 adb exec-out screencap 保存 PNG。默认不读取仓内凭证。

命令构造与 preflight 复用 scripts/auto_test_lib/target_config.py，
保证 run 与 capture 校验的是同一份最终生效 APP/API/WS/凭证配置。
"""
from __future__ import annotations

import argparse
import json
import os
import re
import shlex
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / 'scripts'))
from auto_test_lib.target_config import build_flutter_test_command, effective_target_config  # noqa: E402
from auto_test_lib.machine_events import parse_machine_events  # noqa: E402
from auto_test_lib.acceptance import valid_event_protocol  # noqa: E402
# 经包路径导入：unittest 上下文中顶层名 auto_test 被 test/tooling/auto_test 包遮蔽。
from auto_test_lib.device_discovery import discover_devices, qualify_device  # noqa: E402

MARKER = re.compile(r'\[AI_SCREENSHOT\]\s+(.+)$')


def capture_exit_code(lines: list[str], process_code: int, captured: int) -> int:
    """A zero exit alone cannot prove a finished, non-skipped capture journey."""
    parsed = parse_machine_events(lines, process_code, None)
    if parsed.test_status == 'FAIL':
        return 1
    if not valid_event_protocol(lines):
        return 2
    if process_code != 0 or parsed.test_status != 'PASS' or captured == 0:
        return 2
    return 0


def screenshot_marker(line: str) -> re.Match[str] | None:
    """Read screenshot names from machine print events, excluding JSON syntax."""
    try:
        event = json.loads(line)
    except (ValueError, TypeError):
        return None
    if not isinstance(event, dict) or event.get('type') != 'print':
        return None
    message = event.get('message')
    return MARKER.search(message) if isinstance(message, str) else None


def capture_device_errors(device: str, platform: str) -> list[str]:
    """The direct capture CLI must enforce the same physical-device gate."""
    devices, error = discover_devices()
    if error:
        return [error]
    qualified_platform, errors = qualify_device(device, devices)
    if not errors and platform != qualified_platform:
        errors = ['CAPTURE_PLATFORM_MISMATCH']
    return errors


def capture_android(device: str, destination: Path) -> bool:
    shot = subprocess.run(
        ['adb', '-s', device, 'exec-out', 'screencap', '-p'],
        capture_output=True,
        check=False,
    )
    if shot.returncode or not shot.stdout.startswith(b'\x89PNG'):
        return False
    destination.write_bytes(shot.stdout)
    return True


def capture_ios(device: str, destination: Path) -> bool:
    """通过用户配置的私有 iOS 真机采集器抓屏，避免绑定不稳定的 Xcode 私有接口。"""
    command_text = os.environ.get('IMBOY_IOS_SCREENSHOT_COMMAND', '')
    if not command_text:
        raise ValueError(
            'iOS 真机截图需要 IMBOY_IOS_SCREENSHOT_COMMAND；命令必须含 {device} 与 {output} 占位符。'
        )
    command = [
        token.replace('{device}', device).replace('{output}', str(destination.resolve()))
        for token in shlex.split(command_text)
    ]
    if not any('{device}' in token for token in shlex.split(command_text)) or not any(
        '{output}' in token for token in shlex.split(command_text)
    ):
        raise ValueError('IMBOY_IOS_SCREENSHOT_COMMAND 必须同时含 {device} 与 {output} 占位符。')
    completed = subprocess.run(command, check=False)
    return completed.returncode == 0 and destination.is_file() and destination.stat().st_size > 0


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--target', required=True, help='integration_test 下的测试文件')
    parser.add_argument('--device', required=True, help='真实 Android adb device ID')
    parser.add_argument('--output', required=True, help='截图输出目录')
    parser.add_argument('--platform', choices=('android', 'ios'), default='android')
    parser.add_argument('--hold-ms', type=int, default=2500)
    parser.add_argument('--app-env', default=os.environ.get('IMBOY_APP_ENV', 'local_office'))
    args = parser.parse_args()
    target = ROOT / args.target
    if not target.is_file() or not args.target.startswith('integration_test/'):
        parser.error('--target 必须是存在的 integration_test 文件')
    if args.hold_ms < 1000:
        parser.error('--hold-ms 至少 1000，保证 ADB 有抓屏窗口')
    return args


def main() -> int:
    args = parse_args()
    # preflight：在启动任何子进程前校验最终生效配置（远程/缺凭证/不一致一律 BLOCKED）
    env = dict(os.environ)
    env['IMBOY_APP_ENV'] = args.app_env
    cfg = effective_target_config(
        env=env,
        device_id=args.device,
        platform=args.platform,
        target=args.target,
        hold_ms=args.hold_ms,
    )
    blocked = list(cfg.blocked_codes)
    if not cfg.consistent:
        blocked.append(cfg.inconsistency_code)
    if args.platform == 'ios' and not os.environ.get('IMBOY_IOS_SCREENSHOT_COMMAND'):
        blocked.append('IOS_CAPTURE_COMMAND_MISSING')
    if blocked:
        print(f'BLOCKED: {"; ".join(sorted(set(blocked)))}；不启动测试子进程。', file=sys.stderr)
        return 2
    device_errors = capture_device_errors(args.device, args.platform)
    if device_errors:
        print(f'BLOCKED: {"; ".join(device_errors)}；不启动采集子进程。', file=sys.stderr)
        return 2
    output = Path(args.output)
    output.mkdir(parents=True, exist_ok=True)
    if any(output.iterdir()):
        print('BLOCKED: 截图输出目录必须为空，禁止复用历史采集证据。', file=sys.stderr)
        return 2
    return run_capture(cfg, args.device, args.platform, output)


def run_capture(cfg, device: str, platform: str, output: Path) -> int:
    command = build_flutter_test_command(cfg) + ['--machine']
    process = subprocess.Popen(command, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, bufsize=1)
    captured = 0
    lines: list[str] = []
    assert process.stdout is not None
    for line in process.stdout:
        lines.append(line)
        print(line, end='')
        match = screenshot_marker(line)
        if not match:
            continue
        name = re.sub(r'[^A-Za-z0-9_.-]+', '_', match.group(1)).strip('_')
        destination = output / f'{captured + 1:02d}_{name}.png'
        try:
            saved = capture_android(device, destination) if platform == 'android' else capture_ios(device, destination)
        except ValueError as exc:
            print(f'\nBLOCKED: {exc}', file=sys.stderr)
            process.terminate()
            return 2
        if not saved:
            print(f'\nWARN: {platform} 截图失败: {name}', file=sys.stderr)
            continue
        captured += 1
        print(f'AI_SCREENSHOT_SAVED: {destination}')
    code = process.wait()
    print(f'截图数: {captured}')
    return capture_exit_code(lines, code, captured)


if __name__ == '__main__':
    raise SystemExit(main())

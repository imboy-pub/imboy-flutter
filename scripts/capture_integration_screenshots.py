#!/usr/bin/env python3
"""在 Android 真机 integration_test 的截图检查点采集 ADB 截图。

测试工具会在 AI_SCREENSHOT_HOLD_MS > 0 时输出 [AI_SCREENSHOT] 标记并暂停；
本脚本监听标记、通过 adb exec-out screencap 保存 PNG。默认不读取仓内凭证。
"""
from __future__ import annotations

import argparse
import os
import re
import shlex
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
MARKER = re.compile(r'\[AI_SCREENSHOT\]\s+(.+)$')


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


def main() -> int:
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
    if args.platform == 'ios' and not os.environ.get('IMBOY_IOS_SCREENSHOT_COMMAND'):
        print('BLOCKED: iOS 真机截图需要 IMBOY_IOS_SCREENSHOT_COMMAND；不启动测试。', file=sys.stderr)
        return 2
    for name in ('IMBOY_TEST_PHONE', 'IMBOY_TEST_PASSWORD'):
        if not os.environ.get(name):
            print(f'BLOCKED: 缺少 {name}；不启动真机测试。', file=sys.stderr)
            return 2
    output = Path(args.output)
    output.mkdir(parents=True, exist_ok=True)
    command = [
        'flutter', 'test', args.target, '-d', args.device,
        f'--dart-define=APP_ENV={args.app_env}',
        f'--dart-define=TEST_PHONE={os.environ["IMBOY_TEST_PHONE"]}',
        f'--dart-define=TEST_PASSWORD={os.environ["IMBOY_TEST_PASSWORD"]}',
        f'--dart-define=AI_SCREENSHOT_HOLD_MS={args.hold_ms}',
    ]
    process = subprocess.Popen(command, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, bufsize=1)
    captured = 0
    assert process.stdout is not None
    for line in process.stdout:
        print(line, end='')
        match = MARKER.search(line)
        if not match:
            continue
        name = re.sub(r'[^A-Za-z0-9_.-]+', '_', match.group(1)).strip('_')
        destination = output / f'{captured + 1:02d}_{name}.png'
        try:
            saved = capture_android(args.device, destination) if args.platform == 'android' else capture_ios(args.device, destination)
        except ValueError as exc:
            print(f'\nBLOCKED: {exc}', file=sys.stderr)
            process.terminate()
            return 2
        if not saved:
            print(f'\nWARN: {args.platform} 截图失败: {name}', file=sys.stderr)
            continue
        destination.write_bytes(shot.stdout)
        captured += 1
        print(f'AI_SCREENSHOT_SAVED: {destination}')
    code = process.wait()
    print(f'截图数: {captured}')
    return code


if __name__ == '__main__':
    raise SystemExit(main())

"""共享的最终生效目标配置（effective target config）。

run 与 capture 必须经由同一份函数解析 APP/API/WS/凭证覆盖链并构造
flutter 命令；preflight 校验的是即将传给子进程的最终配置，而不是
父进程环境变量。指纹与命令中绝不出现凭证明文。
"""
from __future__ import annotations

import hashlib
import os
from dataclasses import dataclass, field
from urllib.parse import urlsplit

PRO_APP_ENVS = {'pro', 'prod', 'production'}
LOOPBACK_HOSTS = {'127.0.0.1'}  # 127.0.0.0/8 的字面前缀在 is_loopback_host 处理


def is_loopback_host(hostname: str | None) -> bool:
    if not hostname:
        return False
    host = hostname.strip('[]').lower()
    if host == '::1':
        return True
    if host == 'localhost' or host == '0.0.0.0':
        # 'localhost' 依赖解析结果，不能作为 loopback 证明；0.0.0.0 是全接口绑定。
        return False
    parts = host.split('.')
    return len(parts) == 4 and parts[0] == '127' and all(
        part.isdigit() and 0 <= int(part) <= 255 for part in parts[1:]
    )


def resolve_host(url: str | None) -> str | None:
    if not url:
        return None
    return urlsplit(url if '://' in url else f'//{url}').hostname


@dataclass
class EffectiveTargetConfig:
    app_env: str | None
    api_url: str | None
    ws_url: str | None
    device_id: str | None
    platform: str
    has_phone: bool
    has_password: bool
    dart_defines: list[str] = field(default_factory=list)
    api_host_resolved: str | None = None
    ws_host_resolved: str | None = None
    fingerprint: str = ''
    consistent: bool = True
    inconsistency_code: str = 'NONE'
    blocked_codes: list[str] = field(default_factory=list)

    def to_public_dict(self) -> dict:
        """不含凭证的指纹视图；可安全进入日志与 manifest。"""
        return {
            'app_env': self.app_env,
            'api_url_host': self.api_host_resolved,
            'ws_url_host': self.ws_host_resolved,
            'device_present': bool(self.device_id),
            'platform': self.platform,
            'credentials_present': self.has_phone and self.has_password,
            'fingerprint': self.fingerprint,
            'consistent': self.consistent,
            'inconsistency_code': self.inconsistency_code,
            'blocked_codes': self.blocked_codes,
        }


def resolve_api_url(env: dict) -> str | None:
    return (
        env.get('IMBOY_API_BASE_URL_OVERRIDE')
        or env.get('IMBOY_API_BASE_URL')
        or env.get('API_BASE_URL')
        or None
    )


def effective_target_config(
    env: dict,
    device_id: str | None,
    platform: str = 'android',
    target: str | None = None,
    hold_ms: int | None = None,
) -> EffectiveTargetConfig:
    """从显式 env 快照构造最终生效配置；env 必须是调用方捕获的副本。"""
    app_env = env.get('IMBOY_APP_ENV')
    api_url = resolve_api_url(env)
    ws_url = env.get('IMBOY_WS_URL_OVERRIDE') or None
    phone = env.get('IMBOY_TEST_PHONE')
    password = env.get('IMBOY_TEST_PASSWORD')
    cfg = EffectiveTargetConfig(
        app_env=app_env,
        api_url=api_url,
        ws_url=ws_url,
        device_id=device_id,
        platform=platform,
        has_phone=bool(phone),
        has_password=bool(password),
    )
    cfg.api_host_resolved = resolve_host(api_url)
    cfg.ws_host_resolved = resolve_host(ws_url)

    defines: list[str] = []
    if app_env:
        defines.append(f'--dart-define=APP_ENV={app_env}')
    if phone and password:
        defines.append(f'--dart-define=TEST_PHONE={phone}')
        defines.append(f'--dart-define=TEST_PASSWORD={password}')
    elif phone or password:
        cfg.consistent = False
        cfg.inconsistency_code = 'CREDENTIALS_HALF_PRESENT'
    if env.get('IMBOY_API_BASE_URL_OVERRIDE'):
        defines.append(f'--dart-define=API_BASE_URL_OVERRIDE={api_url}')
    elif api_url:
        defines.append(f'--dart-define=API_BASE_URL={api_url}')
    if ws_url:
        defines.append(f'--dart-define=WS_URL_OVERRIDE={ws_url}')
    for var, define in (
        ('IMBOY_SOLIDIFIED_KEY_OVERRIDE', 'SOLIDIFIED_KEY_OVERRIDE'),
        ('IMBOY_SOLIDIFIED_KEY_IV_OVERRIDE', 'SOLIDIFIED_KEY_IV_OVERRIDE'),
    ):
        value = env.get(var)
        if value:
            defines.append(f'--dart-define={define}={value}')
    if target:
        defines.append(target)
    if device_id:
        defines.extend(['-d', device_id])
    if hold_ms is not None:
        defines.append(f'--dart-define=AI_SCREENSHOT_HOLD_MS={hold_ms}')
    cfg.dart_defines = defines

    # preflight：校验最终生效组合，远程/不一致在 spawn 前挡下
    hosts = [cfg.api_host_resolved, cfg.ws_host_resolved]
    if app_env in PRO_APP_ENVS and any(is_loopback_host(h) for h in hosts):
        cfg.consistent = False
        cfg.inconsistency_code = 'APP_ENV_PRO_WITH_LOCAL_URL'
    if cfg.api_host_resolved and cfg.ws_host_resolved and cfg.api_host_resolved != cfg.ws_host_resolved:
        cfg.consistent = False
        cfg.inconsistency_code = 'API_WS_ORIGIN_MISMATCH'
    for host in hosts:
        if host is not None and not is_loopback_host(host):
            cfg.consistent = False
            if 'REMOTE_TARGET_FORBIDDEN' not in cfg.blocked_codes:
                cfg.blocked_codes.append('REMOTE_TARGET_FORBIDDEN')
    if not cfg.device_id:
        cfg.blocked_codes.append('DEVICE_MISSING')
    if not (cfg.has_phone and cfg.has_password):
        cfg.blocked_codes.append('CREDENTIALS_MISSING')

    payload = '|'.join(
        str(part)
        for part in (
            app_env or '-',
            cfg.api_host_resolved or '-',
            cfg.ws_host_resolved or '-',
            platform,
            bool(device_id),
            bool(phone and password),
            target or '-',
        )
    )
    cfg.fingerprint = hashlib.sha256(payload.encode('utf-8')).hexdigest()
    return cfg


def build_flutter_test_command(cfg: EffectiveTargetConfig, runner: str = 'flutter') -> list[str]:
    """run 与 capture 共用的最终命令构造；含 secrets 的 defines 只进子进程 argv，不进指纹。"""
    return [runner, 'test', *cfg.dart_defines]

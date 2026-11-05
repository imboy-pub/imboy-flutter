"""Execution contracts for the existing Flutter, Patrol and paired targets.

Adapters prepare commands and collect evidence; they never declare business PASS.
The execution runner must classify Flutter machine events (including exit status),
or the fresh Patrol JUnit cases, and reconcile every planned instance afterwards.
"""
from __future__ import annotations

import base64
import hashlib
import importlib.util
import json
import math
import os
import re
import shutil
import socket
import subprocess
import sys
import time
import xml.etree.ElementTree as ET
from concurrent.futures import ThreadPoolExecutor
from functools import lru_cache
from pathlib import Path
from typing import Callable
from urllib.parse import urlsplit

from .devices import discover_devices, qualify_device
from .target_config import is_loopback_host
from . import acceptance, acceptance_preflight, state

PAIR_TARGETS = {
    'integration_test/e2ee_cross_platform_interop_test.dart': 'e2ee-vector',
    'integration_test/e2ee_cross_platform_group_interop_test.dart': 'e2ee-vector',
    'integration_test/rtc/c2c_call_matrix_a_side_test.dart': 'rtc-concurrent',
    'integration_test/rtc/c2c_call_matrix_b_side_test.dart': 'rtc-concurrent',
    'integration_test/rtc/rtc_group_regression_test.dart': 'rtc-group-concurrent',
    'integration_test/demo_flow/dual_account_message_flow_test.dart': 'dual-concurrent',
    'integration_test/demo_flow/group_dual_account_message_flow_test.dart': 'dual-concurrent',
    'integration_test/demo_flow/local_dual_account_message_flow_test.dart': 'dual-sequential',
    'integration_test/demo_flow/group_collaboration_flow_test.dart': 'collaboration-sequential',
    'integration_test/two_client/h2_c2c_android_a_side_test.dart': 'h2-c2c',
    'integration_test/two_client/h2_c2c_mac_b_side_test.dart': 'h2-c2c',
    'integration_test/two_client/h2_c2c_history_test.dart': 'h2-c2c',
    'integration_test/two_client/h2_c2g_android_a_side_test.dart': 'h2-c2g',
    'integration_test/two_client/h2_c2g_mac_b_side_test.dart': 'h2-c2g',
    'integration_test/two_client/h2_c2g_new_member_test.dart': 'h2-c2g',
    'integration_test/chat/j16c_dnd_two_device_a_test.dart': 'dnd-fixture',
    'integration_test/chat/j16c_dnd_two_device_b_test.dart': 'dnd-fixture',
    'integration_test/chat/j28b_two_client_new_end_test.dart': 'legacy-fixture',
}
DEVICE_RUNNERS = {'flutter-device', 'device-pair', 'patrol'}
BACKEND_DEPENDENCIES = {'backend', 'isolated-backend', 'backend-api', 'backend-ws',
                        'backend-contract', 'isolated-accounts', 'livekit'}
ENV_ALIASES = {
    'API_BASE_URL': ('IMBOY_API_BASE_URL_OVERRIDE', 'IMBOY_API_BASE_URL', 'API_BASE_URL'),
    'WS_URL_OVERRIDE': ('IMBOY_WS_URL_OVERRIDE', 'WS_URL_OVERRIDE'),
    'APP_ENV': ('IMBOY_APP_ENV', 'APP_ENV'),
    'TEST_PHONE': ('IMBOY_TEST_PHONE', 'TEST_PHONE'),
    'TEST_PASSWORD': ('IMBOY_TEST_PASSWORD', 'TEST_PASSWORD'),
    'TEST_CODE': ('IMBOY_TEST_CODE', 'TEST_CODE'),
    'TEST_PHONE2': ('IMBOY_TEST_PHONE2', 'TEST_PHONE2'),
    'TEST_PASSWORD2': ('IMBOY_TEST_PASSWORD2', 'TEST_PASSWORD2'),
    'SOLIDIFIED_KEY_OVERRIDE': ('IMBOY_SOLIDIFIED_KEY_OVERRIDE', 'IMBOY_SOLIDIFIED_KEY'),
    'SOLIDIFIED_KEY_IV_OVERRIDE': ('IMBOY_SOLIDIFIED_KEY_IV_OVERRIDE',),
}


def _value(env: dict, name: str, role: str = '') -> str:
    """Role credentials override common values; no credential defaults exist."""
    candidates = ENV_ALIASES.get(name, ('IMBOY_' + name, name))
    if role:
        suffix = role.upper().replace('-', '_')
        for key in (f'IMBOY_{suffix}_{name}', f'{name}_{suffix}'):
            if env.get(key):
                return str(env[key])
    return next((str(env[k]) for k in candidates if env.get(k)), '')


def device_id_for(instance: dict, env: dict) -> str:
    role = str(instance.get('device_role') or instance.get('account_role') or instance.get('role') or '').upper().replace('-', '_')
    platform = str(instance.get('platform') or '').upper()
    keys = ([f'IMBOY_EXECUTION_DEVICE_{role}'] if role else []) + [
        f'IMBOY_EXECUTION_DEVICE_{platform}', f'{platform}_DEVICE_ID',
        'IMBOY_EXECUTION_DEVICE', 'IMBOY_TEST_DEVICE',
    ]
    return str(instance.get('device_id') or next((env[k] for k in keys if env.get(k)), ''))


def needs_backend(instance: dict) -> bool:
    dependencies = set(instance.get('dependencies') or [])
    if instance.get('offline') is True:
        return False
    return (instance.get('suite') == 'backend-contract'
            or bool(dependencies & BACKEND_DEPENDENCIES)
            or (instance.get('runner') in DEVICE_RUNNERS
                and instance.get('target') not in {
                    'integration_test/patrol/handshake_test.dart',
                    'integration_test/e2ee_cross_platform_interop_test.dart',
                    'integration_test/e2ee_cross_platform_group_interop_test.dart',
                }
                and not instance.get('offline', False)))


def backend_environment_errors(instance: dict, env: dict, *, probe: bool = False) -> list[str]:
    """A local opt-in and explicit literal loopback URLs precede any network I/O."""
    if not needs_backend(instance):
        return []
    errors: list[str] = []
    if env.get('IMBOY_TEST_ISOLATED') != 'true':
        errors.append('ISOLATED_FIXTURE_OPT_IN_MISSING:IMBOY_TEST_ISOLATED=true')
    if _value(env, 'APP_ENV') != 'local':
        errors.append('APP_ENV_LOCAL_REQUIRED')
    urls = {'API_BASE_URL': _value(env, 'API_BASE_URL')}
    if instance.get('runner') in DEVICE_RUNNERS or 'backend-ws' in instance.get('dependencies', []):
        urls['WS_URL_OVERRIDE'] = _value(env, 'WS_URL_OVERRIDE')
    if 'livekit' in instance.get('dependencies', []):
        urls['LK_RTC_WS_OVERRIDE'] = _value(env, 'LK_RTC_WS_OVERRIDE')
    endpoints = []
    for name, value in urls.items():
        try:
            parsed = urlsplit(value)
            allowed = ('http', 'https') if name == 'API_BASE_URL' else ('ws', 'wss')
            if (not value or parsed.scheme not in allowed or parsed.username or parsed.password
                    or not is_loopback_host(parsed.hostname)):
                errors.append(f'ISOLATED_LOOPBACK_URL_REQUIRED:{name}')
                continue
            port = parsed.port or (443 if parsed.scheme in {'https', 'wss'} else 80)
            endpoints.append((name, parsed.hostname, port))
        except ValueError:
            errors.append(f'ISOLATED_LOOPBACK_URL_REQUIRED:{name}')
    role = str(instance.get('account_role') or instance.get('role') or '')
    if instance.get('session_mode') != 'mc-owned' and (not _value(env, 'TEST_PHONE', role) or not (
        _value(env, 'TEST_PASSWORD', role) or _value(env, 'TEST_CODE', role)
    )):
        errors.append('ISOLATED_TEST_ACCOUNT_MISSING')
    if not _value(env, 'SOLIDIFIED_KEY_OVERRIDE'):
        errors.append('ISOLATED_SIGNING_KEY_MISSING')
    if instance.get('runner') in DEVICE_RUNNERS and not _value(env, 'SOLIDIFIED_KEY_IV_OVERRIDE'):
        errors.append('ISOLATED_SIGNING_IV_MISSING')
    if 'business-writes' in instance.get('dependencies', []):
        if _value(env, 'TEST_ALLOW_BUSINESS_WRITES') != 'true':
            errors.append('ISOLATED_BUSINESS_WRITES_OPT_IN_MISSING')
    if probe and not errors:
        for name, hostname, port in endpoints:
            try:
                with socket.create_connection((hostname, port), timeout=1):
                    pass
            except OSError:
                errors.append(f'SERVICE_UNAVAILABLE:{name}')
    return errors


PRODUCT_ARTIFACTS = (
    'lib/app_core/feature_flags/generated_product_features.dart',
    'lib/config/router/generated_product_feature_routes.dart',
    'lib/app_core/feature_flags/generated_channel_order_widget.dart',
    'android/app/product-features.properties',
    'android/app/src/debug/AndroidManifest.xml',
    'android/app/src/profile/AndroidManifest.xml',
    'android/app/src/release/AndroidManifest.xml',
)
PRODUCT_VALIDATION_INPUTS = (
    'scripts/generate_product_features.py',
    'config/product-feature-manifest.json',
    'src/lib/imboy_feature.erl',
    'src/lib/imboy_plugin_registry.erl',
    'src/lib/imboy_policy_catalog.erl',
)


@lru_cache(maxsize=16)
def _validated_product_artifacts(root: str, backend: str, signature: tuple) -> dict:
    """Use the existing generator's render contract without invoking its writes.

    Its CLI --check rewrites already-equal outputs. Here only source_catalog,
    validate and render are called; missing backend/admin generated files cannot
    prevent verification of the app's seven generated artifacts.
    """
    root_path, backend_path = Path(root), Path(backend)
    try:
        script = backend_path / 'scripts/generate_product_features.py'
        spec = importlib.util.spec_from_file_location('imboy_execution_product_generator', script)
        generator = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(generator)
        manifest = generator.read_manifest(backend_path / 'config/product-feature-manifest.json')
        contract = generator.validate(manifest, generator.source_catalog(backend_path))
        expected = generator.render(contract, app_dir=root_path)
        artifacts = {}
        errors = []
        rendered = {str(path.relative_to(root_path)): content
                    for path, content in expected.items() if path.is_relative_to(root_path)}
        if set(rendered) != set(PRODUCT_ARTIFACTS):
            errors.append('PRODUCT_GENERATOR_ARTIFACT_SET_CHANGED')
        for name in PRODUCT_ARTIFACTS:
            path = root_path / name
            if not path.is_file():
                errors.append('PRODUCT_ARTIFACT_MISSING:' + name)
            else:
                content = path.read_bytes()
                artifacts[name] = hashlib.sha256(content).hexdigest()
                if name not in rendered or content != rendered[name].encode():
                    errors.append('PRODUCT_GENERATED_ARTIFACT_DRIFT:' + name)
        identity = {'manifest_profile': manifest.get('profile'),
                    'manifest_hash': contract['manifest_hash'],
                    'compiled_features': contract['compiled_features'],
                    'artifacts': artifacts, 'validation_inputs': dict(signature)}
        return {**identity, 'fingerprint': hashlib.sha256(
                    json.dumps(identity, sort_keys=True).encode()).hexdigest(),
                'validation': 'existing-generator-read-only-render', 'errors': errors}
    except (OSError, ValueError, KeyError, AttributeError, TypeError, RuntimeError) as exc:
        return {'errors': ['PRODUCT_MANIFEST_VALIDATION_FAILED:' + type(exc).__name__]}


def product_artifact_evidence(root: Path, instance: dict, env: dict) -> dict:
    product = instance.get('product_contract') or {}
    requested = product.get('manifest_profile') or instance.get('product_profile')
    features = set(instance.get('required_features') or []) | set(product.get('required_features') or [])
    if requested in (None, '', 'current', 'any', 'all', 'host', 'default') and not features:
        return {'errors': []}
    root = Path(root).resolve()
    backend = Path(env.get('IMBOY_BACKEND_ROOT', root.parent / 'imboy')).resolve()
    signature = []
    for scope, base, names in (('backend', backend, PRODUCT_VALIDATION_INPUTS),
                                ('app', root, PRODUCT_ARTIFACTS)):
        for name in names:
            path = base / name
            signature.append((scope + ':' + name,
                hashlib.sha256(path.read_bytes()).hexdigest() if path.is_file() else 'missing'))
    evidence = dict(_validated_product_artifacts(str(root), str(backend), tuple(signature)))
    errors = list(evidence.get('errors', []))
    if not errors:
        if requested not in (None, '', 'current', 'any', 'all', 'host', 'default', evidence['manifest_profile']):
            errors.append(f'PRODUCT_PROFILE_BUILD_REQUIRED:{requested}')
        for feature in sorted(features - set(evidence['compiled_features'])):
            errors.append(f'COMPILED_FEATURE_MISSING:{feature}')
    evidence['requested_manifest_profile'] = requested
    evidence['required_features'] = sorted(features)
    evidence['errors'] = errors
    return evidence


def product_environment_errors(root: Path, instance: dict, env: dict) -> list[str]:
    return product_artifact_evidence(root, instance, env)['errors']


REGISTERED_GOLDEN_FONT_SOURCE = 'test/uiux/support/golden_font_loader.dart'


def registered_golden_font_asset(root: Path) -> dict:
    """Read the existing single literal asset; never evaluate Dart or copy its pins.

    This deliberately accepts only the current declaration shape. A registry
    migration requires adapter review rather than guessing a new font contract.
    Parsing is independent of local font availability, so plans work on Linux.
    """
    try:
        source = (root / REGISTERED_GOLDEN_FONT_SOURCE).read_text(encoding='utf-8')
    except (OSError, UnicodeError) as error:
        raise ValueError('REGISTERED_GOLDEN_FONT_REGISTRY_UNREADABLE:' +
                         REGISTERED_GOLDEN_FONT_SOURCE) from error
    # Preserve quoted text while removing the declaration's explanatory comments.
    source = re.sub(r"'(?:\\.|[^'\\])*'|\"(?:\\.|[^\"\\])*\"|//[^\n]*|/\*[\s\S]*?\*/",
                    lambda match: ' ' if match[0].startswith(('//', '/*')) else match[0], source)
    declarations = re.findall(
        r'\bconst\s+List<GoldenFontAsset>\s+kGoldenFontAssets\s*=\s*\[([\s\S]*?)\]\s*;', source)
    literal = r"'[^'\\$\r\n]*'"
    shape = (rf'\s*GoldenFontAsset\(\s*path:\s*(?P<path>{literal})\s*,'
             rf'\s*sha256Hex:\s*(?P<sha256>{literal})\s*,'
             rf'\s*licenseNote:\s*(?P<license>(?:{literal}\s*)+)\s*,\s*\),\s*')
    asset = re.fullmatch(shape, declarations[0]) if len(declarations) == 1 else None
    if asset is None:
        raise ValueError('REGISTERED_GOLDEN_FONT_REGISTRY_INVALID:' + REGISTERED_GOLDEN_FONT_SOURCE)
    registration = {'path': asset['path'][1:-1], 'sha256': asset['sha256'][1:-1],
                    'license': ''.join(value[1:-1] for value in re.findall(literal, asset['license']))}
    if (not Path(registration['path']).is_absolute()
            or not re.fullmatch(r'[0-9a-f]{64}', registration['sha256'])
            or not registration['license'].strip()):
        raise ValueError('REGISTERED_GOLDEN_FONT_REGISTRY_INVALID:' + REGISTERED_GOLDEN_FONT_SOURCE)
    return registration


def registered_golden_font_errors(root: Path, instance: dict) -> list[str]:
    """Check the licensed local asset without requiring or generating pixels.

    This is only an environment prerequisite. The unchanged Dart cases still
    verify glyph coverage, FontLoader and negative/synthetic contract behavior.
    """
    if 'registered-golden-font' not in instance.get('dependencies', []):
        return []
    try:
        asset = registered_golden_font_asset(root)
    except ValueError as error:
        return [str(error)]
    path = Path(asset['path'])
    try:
        if not path.is_file():
            return ['REGISTERED_GOLDEN_FONT_MISSING:' + asset['path']]
        if hashlib.sha256(path.read_bytes()).hexdigest() != asset['sha256']:
            return ['REGISTERED_GOLDEN_FONT_HASH_MISMATCH:' + asset['path']]
    except OSError:
        return ['REGISTERED_GOLDEN_FONT_UNREADABLE:' + asset['path']]
    return []


def golden_environment_errors(root: Path, instance: dict, env: dict) -> list[str]:
    """Pinned engine, fonts and pre-existing baseline hashes form the golden contract.

    The manifest is deliberately supplied by the baseline owner. No baseline is
    synthesized here. Missing cases that evade the manifest still fail the guarded
    Dart registration and cannot become a passing skipped comparison.
    """
    if instance.get('suite') != 'golden':
        return []
    path = env.get('IMBOY_GOLDEN_ENVIRONMENT')
    if not path:
        return ['GOLDEN_ENVIRONMENT_MANIFEST_MISSING:IMBOY_GOLDEN_ENVIRONMENT']
    try:
        data = json.loads(Path(path).read_text())
    except (OSError, ValueError):
        return ['GOLDEN_ENVIRONMENT_MANIFEST_INVALID']
    errors = []
    host = {'darwin': 'macos', 'win32': 'windows'}.get(sys.platform, sys.platform)
    if data.get('platform') != host:
        errors.append('GOLDEN_PLATFORM_MISMATCH')
    baseline_map = data.get('baselines', {}).get(instance.get('target'))
    fonts = data.get('fonts')
    if not isinstance(baseline_map, dict) or not baseline_map:
        errors.append('GOLDEN_TARGET_BASELINES_MISSING')
    if not isinstance(fonts, dict) or not fonts:
        errors.append('GOLDEN_FONT_CONTRACT_MISSING')
    for kind, files in (('BASELINE', baseline_map), ('FONT', fonts)):
        for name, expected in (files.items() if isinstance(files, dict) else []):
            candidate = (root / name).resolve()
            if not candidate.is_relative_to(root.resolve()):
                errors.append(f'GOLDEN_{kind}_PATH_OUTSIDE_REPO')
                continue
            if not candidate.is_file():
                errors.append(f'GOLDEN_{kind}_MISSING:{name}')
            elif not isinstance(expected, str) or hashlib.sha256(candidate.read_bytes()).hexdigest() != expected:
                errors.append(f'GOLDEN_{kind}_HASH_MISMATCH:{name}')
    try:
        completed = subprocess.run(['flutter', '--version', '--machine'], cwd=root,
                                   capture_output=True, text=True, timeout=30, check=False)
        version = json.loads(completed.stdout)
        if (completed.returncode != 0 or not data.get('frameworkRevision')
                or not data.get('engineRevision')
                or any(data.get(k) != version.get(k) for k in ('frameworkRevision', 'engineRevision'))):
            errors.append('GOLDEN_FLUTTER_VERSION_MISMATCH')
    except (OSError, ValueError, subprocess.TimeoutExpired):
        errors.append('GOLDEN_FLUTTER_VERSION_UNAVAILABLE')
    return errors


def acceptance_environment_evidence(root: Path, instance: dict, env: dict) -> dict:
    """Reuse frozen-input/lease gates; a caller boolean grants no verification."""
    if not (instance.get('acceptance_preflight') or str(instance.get('target', '')).startswith('integration_test/full_acceptance/')):
        return {'errors': [], 'defines': {}}
    keys = ('IMBOY_ACCEPTANCE_EVIDENCE_ROOT', 'IMBOY_ACCEPTANCE_CONTEXT',
            'IMBOY_ACCEPTANCE_CONTEXT_SHA256', 'IMBOY_ACCEPTANCE_LEASES_DIR')
    errors = ['ACCEPTANCE_INPUT_MISSING:' + key for key in keys if not env.get(key)]
    output = {'scope': 'DEVICE_PREPARATION_INPUTS_ONLY', 'product_pass': False,
              'errors': errors, 'defines': {}}
    if errors:
        return output
    evidence_root = Path(env[keys[0]])
    descriptor = {'path': env[keys[1]], 'sha256': env[keys[2]]}
    context, problems = acceptance.load_frozen_json(evidence_root, descriptor)
    errors.extend(problems)
    output['context'] = descriptor
    if errors:
        return output
    try:
        if not isinstance(context, dict) or context.get('schema_version') != 1:
            raise ValueError('ACCEPTANCE_CONTEXT_SCHEMA_INVALID')
        matches = [row for row in context['instances'] if all(
            row.get(key, 'primary' if key == 'role' else None) == instance.get(key, 'primary' if key == 'role' else None)
            for key in ('target', 'platform', 'product_profile', 'role'))]
        if len(matches) != 1:
            raise ValueError('ACCEPTANCE_INSTANCE_MISSING_OR_DUPLICATE')
        row = matches[0]
        repositories = {'imboyapp': Path(root),
            'imboy': Path(env.get('IMBOY_BACKEND_ROOT', Path(root).parent / 'imboy')),
            'imboyadmin': Path(env.get('IMBOY_ADMIN_ROOT', Path(root).parent / 'imboyadmin'))}
        errors.extend(acceptance_preflight.audit_preparation_inputs(
            evidence_root, context['frozen'], context['report'], repositories,
            allow_initial_empty_history=True)['errors'])
        records = {}
        for name in ('frozen', 'authorization', 'runtime', 'fixture', 'device'):
            source = context['frozen'] if name == 'frozen' else row[name]
            records[name], problems = acceptance.load_frozen_json(evidence_root, source)
            errors.extend(problems)
        if errors:
            return output
        frozen = records['frozen']
        for name, kind in (('authorization', 'config'), ('runtime', 'config'), ('fixture', 'fixture'), ('device', 'device')):
            if not any(binding['kind'] == kind and binding['artifact'] == row[name]
                       for binding in frozen['runtime_bindings']):
                errors.append('ACCEPTANCE_UNBOUND_ARTIFACT:' + name)
        expected_profile = (instance.get('dart_defines') or {}).get('ACCEPTANCE_NAV_CHANNEL_PROFILE', instance['product_profile'])
        case = row['case']
        if (case.get('platform') != instance['platform'] or case.get('profile') != expected_profile
                or case.get('role_variant') != instance.get('role', 'primary')
                or not any(all(required.get(key) == case.get(key) for key in
                    ('case_id', 'platform', 'profile', 'role_variant')) for required in frozen['required_cases'])):
            errors.append('ACCEPTANCE_CASE_BINDING_MISMATCH')
        defines, problems = _acceptance_bound_inputs(instance, env, row, records)
        errors.extend(problems)
        if not errors:
            output.update(defines=defines, verified=True, artifacts={name: row[name]
                for name in ('authorization', 'runtime', 'fixture', 'device')}, lease=records['device']['lease'])
    except (KeyError, TypeError, ValueError, AttributeError, OSError) as exc:
        errors.append(str(exc) if isinstance(exc, ValueError) and str(exc).startswith('ACCEPTANCE_')
                      else 'ACCEPTANCE_CONTEXT_INVALID')
    return output


def _acceptance_bound_inputs(instance: dict, env: dict, row: dict, records: dict) -> tuple[dict, list[str]]:
    frozen, authorization, runtime, fixture, device = (records[name] for name in
        ('frozen', 'authorization', 'runtime', 'fixture', 'device'))
    errors = []
    values = fixture['values']
    uid = str(values.get('TEST_EXPECTED_UID', ''))
    if (fixture.get('synthetic') is not True or not fixture.get('fixture_id')
            or not re.fullmatch(r'[1-9][0-9]{0,18}', uid) or int(uid) > 9223372036854775807):
        errors.append('ACCEPTANCE_SYNTHETIC_FIXTURE_INVALID')
    fields = instance.get('acceptance_fixture_fields', ['TEST_EXPECTED_UID'])
    for name in fields:
        if not isinstance(values.get(name), (str, int)) or not str(values[name]).strip():
            errors.append('ACCEPTANCE_FIXTURE_VALUE_MISSING:' + name)
        elif _value(env, name) and _value(env, name) != str(values[name]):
            errors.append('ACCEPTANCE_FIXTURE_ENV_MISMATCH:' + name)
    if 'ACCEPTANCE_PLAN_PRICE' in values and not re.fullmatch(r'[0-9]+', str(values['ACCEPTANCE_PLAN_PRICE'])):
        errors.append('ACCEPTANCE_PLAN_PRICE_INVALID')
    for name in ('ACCEPTANCE_ORG_ID', 'ACCEPTANCE_DIRECTORY_MEMBER_ID'):
        if name in values and (not re.fullmatch(r'[1-9][0-9]{0,18}', str(values[name]))
                              or int(values[name]) > 9223372036854775807):
            errors.append('ACCEPTANCE_FIXTURE_ID_INVALID:' + name)
    selected_device = device_id_for(instance, env)
    if device.get('device_id') != selected_device or device.get('platform') != instance['platform']:
        errors.append('ACCEPTANCE_DEVICE_BINDING_MISMATCH')
    lease = device['lease']
    resource = instance['platform'].upper() + '_DEVICE:' + selected_device
    if lease.get('resource') != resource:
        errors.append('ACCEPTANCE_LEASE_RESOURCE_MISMATCH')
    try:
        leases = env['IMBOY_ACCEPTANCE_LEASES_DIR']
        owner = state.read_lease(leases, resource)
        if any(owner.get(key) != lease.get(key) for key in state.LEASE_OWNER_REQUIRED_FIELDS):
            errors.append('ACCEPTANCE_LEASE_OWNER_MISMATCH')
        heartbeat = owner.get('heartbeat')
        if (type(heartbeat) not in (int, float) or not math.isfinite(heartbeat)
                or heartbeat > time.time() + 5 or state.lease_stale(leases, resource)):
            errors.append('ACCEPTANCE_LEASE_NOT_ACTIVE')
    except (state.StateError, OSError, ValueError):
        errors.append('ACCEPTANCE_LEASE_MISSING_OR_INVALID')
    for name, env_name, schemes in (('api_url', 'API_BASE_URL', {'http', 'https'}),
                                    ('ws_url', 'WS_URL_OVERRIDE', {'ws', 'wss'})):
        url = runtime.get(name, '')
        parsed = urlsplit(url)
        if (parsed.scheme not in schemes or not is_loopback_host(parsed.hostname)
                or parsed.port is None or parsed.username or parsed.password or parsed.query or parsed.fragment
                or url != _value(env, env_name)):
            errors.append('ACCEPTANCE_RUNTIME_ENDPOINT_MISMATCH:' + name)
    heads = {repo: candidate['head'] for repo, candidate in frozen['candidates'].items()}
    if (runtime.get('app_env') != 'local' or runtime.get('external_services_disabled') is not True
            or runtime.get('heads') != heads):
        errors.append('ACCEPTANCE_RUNTIME_IDENTITY_INVALID')
    nav_profile = (instance.get('dart_defines') or {}).get('ACCEPTANCE_NAV_CHANNEL_PROFILE')
    if nav_profile in ('enabled', 'disabled') and (
            runtime.get('channel_enabled') is not (nav_profile == 'enabled') or runtime.get('experience') != 'chat'
            or type(device.get('logical_width')) not in (int, float) or not 0 < device['logical_width'] < 600):
        errors.append('ACCEPTANCE_NAVIGATION_RUNTIME_MISMATCH')
    approved = {key: instance.get(key, 'primary' if key == 'role' else None)
                for key in ('target', 'platform', 'product_profile', 'role')}
    approved.update(device_id=selected_device, expected_uid=uid,
                    runtime_sha256=row['runtime']['sha256'], fixture_sha256=row['fixture']['sha256'])
    expires = authorization.get('expires_at')
    if (authorization.get('approved') is not True
            or not authorization.get('approval_ref') or not authorization.get('approved_by')
            or authorization.get('scope') != 'isolated-device-preparation'
            or type(expires) not in (int, float) or not math.isfinite(expires) or expires <= time.time()
            or any(authorization.get(key) != value for key, value in approved.items())
            or authorization.get('lease') != lease):
        errors.append('ACCEPTANCE_AUTHORIZATION_SCOPE_INVALID')
    if errors:
        return {}, errors
    defines = {name: str(values[name]) for name in fields}
    defines.update(ACCEPTANCE_RUNNER_VERIFIED='true', ACCEPTANCE_DEVICE_ID=selected_device,
        ACCEPTANCE_PLATFORM=instance['platform'], ACCEPTANCE_LEASE_ID=lease['run'] + ':' + resource,
        ACCEPTANCE_FIXTURE_ID=fixture['fixture_id'], ACCEPTANCE_AUTH_SHA256=row['authorization']['sha256'],
        ACCEPTANCE_RUNTIME_SHA256=row['runtime']['sha256'], ACCEPTANCE_FIXTURE_SHA256=row['fixture']['sha256'],
        ACCEPTANCE_BACKEND_HEAD=heads['imboy'], ACCEPTANCE_APP_HEAD=heads['imboyapp'], ACCEPTANCE_ADMIN_HEAD=heads['imboyadmin'])
    return defines, []


def mc_owned_environment(instance: dict, env: dict) -> tuple[dict, dict]:
    """Bind the existing MC owned fixture to one physical device and variant."""
    effective = dict(env)
    if instance.get('session_mode') != 'mc-owned':
        return effective, {'errors': []}
    mode = ((instance.get('dart_defines') or {}).get('MC_OWNED_NEGATIVE_MODE')
            if instance.get('orchestration') == 'mc-owned-coordinator' else 'positive')
    key = 'IMBOY_MC_OWNED_CONTEXT_' + str(mode).upper()
    value = env.get(key) or env.get('IMBOY_MC_OWNED_CONTEXT')
    digest = env.get(key + '_SHA256') or env.get('IMBOY_MC_OWNED_CONTEXT_SHA256')
    result = {'errors': [], 'mode': mode}
    if not value or not digest:
        result['errors'] = ['MC_OWNED_CONTEXT_MISSING:' + key + '[_SHA256]']
        return effective, result
    try:
        path = Path(value)
        info = path.stat()
        if (not path.is_absolute() or path.is_symlink() or not path.is_file()
                or info.st_uid != os.getuid() or info.st_mode & 0o077 or info.st_size > 1048576
                or hashlib.sha256(path.read_bytes()).hexdigest() != digest):
            raise ValueError('private owned context invalid')
        if mode in ('live', 'reconnect'):
            from mc22_owned_coordinator import validate_context
            context = validate_context(path)
            if context['negative_mode'] != mode:
                raise ValueError('variant mismatch')
        else:
            context = json.loads(path.read_text())
        if (context['package'] != 'pub.imboy.app.gzcustomer'
                or any(type(context[k]) is not int or not 1024 <= context[k] <= 65535
                       for k in ('api_port', 'bootstrap_port'))
                or context['api_port'] == context['bootstrap_port']
                or any(not re.fullmatch(r'[1-9][0-9]{0,18}', str(context[k]))
                       for k in ('uid', 'channel_id', 'group_id'))
                or not isinstance(context['channel_name'], str) or not context['channel_name'].strip()
                or not isinstance(context['bootstrap_key'], str) or len(context['bootstrap_key']) < 32):
            raise ValueError('owned identity invalid')
        device_id = device_id_for(instance, env)
        resource = 'ANDROID_DEVICE:' + device_id
        lease = context['lease']
        leases = env.get('IMBOY_MC_OWNED_LEASES_DIR', '')
        if not leases or lease['resource'] != resource or context['device_id'] != device_id:
            raise ValueError('owned lease mismatch')
        owner = state.read_lease(leases, resource)
        if (any(owner.get(k) != lease.get(k) for k in state.LEASE_OWNER_REQUIRED_FIELDS)
                or state.lease_stale(leases, resource)
                or type(owner.get('heartbeat')) not in (int, float)
                or not math.isfinite(owner['heartbeat']) or owner['heartbeat'] > time.time() + 5):
            raise ValueError('owned lease not current')
        api, bootstrap = context['api_port'], context['bootstrap_port']
        effective.update(IMBOY_API_BASE_URL_OVERRIDE=f'http://127.0.0.1:{api}',
            IMBOY_WS_URL_OVERRIDE=f'ws://127.0.0.1:{api}/api/v1/ws',
            MC_OWNED_SESSION_URL=f'http://127.0.0.1:{bootstrap}/mc-owned/android/session',
            MC_OWNED_BOOTSTRAP_KEY=context['bootstrap_key'], MC_OWNED_UID=str(context['uid']),
            MC_CHANNEL_ID=str(context['channel_id']), MC_DISCUSSION_GROUP_ID=str(context['group_id']),
            MC_CHANNEL_NAME=context['channel_name'])
        if mode in ('live', 'reconnect'):
            effective.update(MC_OWNED_PHASE_URL=f'http://127.0.0.1:{bootstrap}/mc-owned/android/phase',
                             MC_OWNED_PHASE_KEY=context['phase_key'])
        else:
            for field in ('MC_POST_TAG', 'MC_POST_QUERY', 'MC_EXPECTED_BODY'):
                if not isinstance(context.get(field), str) or not context[field].strip():
                    raise ValueError('owned positive fixture missing')
                effective[field] = context[field]
        names = ['MC_OWNED_SESSION_URL', 'MC_OWNED_BOOTSTRAP_KEY', 'MC_OWNED_UID',
                 'MC_CHANNEL_ID', 'MC_DISCUSSION_GROUP_ID', 'MC_CHANNEL_NAME']
        names += (['MC_OWNED_PHASE_URL', 'MC_OWNED_PHASE_KEY'] if mode in ('live', 'reconnect')
                  else ['MC_POST_TAG', 'MC_POST_QUERY', 'MC_EXPECTED_BODY'])
        # Actual Dart defines must come from this checked private context, not
        # from similarly named caller variables that would escape its binding.
        result['defines'] = {name: effective[name] for name in names}
        for name in names:
            effective['IMBOY_' + name] = effective[name]
        result.update(context_path=str(path), context_sha256=digest, lease=lease,
                      api_port=api, bootstrap_port=bootstrap)
    except (OSError, ValueError, KeyError, TypeError, state.StateError):
        result['errors'] = ['MC_OWNED_CONTEXT_INVALID_OR_LEASE_MISSING:' + key]
    return effective, result


def preflight_instance(root: Path, instance: dict, env: dict | None = None,
                       devices: list[dict] | None = None, *, probe: bool = False) -> list[str]:
    env = dict(os.environ if env is None else env)
    env, owned = mc_owned_environment(instance, env)
    errors = list(owned['errors'])
    errors.extend(backend_environment_errors(instance, env))
    errors.extend(product_environment_errors(root, instance, env))
    errors.extend(registered_golden_font_errors(root, instance))
    errors.extend(golden_environment_errors(root, instance, env))
    errors.extend(acceptance_environment_evidence(root, instance, env)['errors'])
    runner = instance.get('runner')
    if instance.get('target') in PAIR_TARGETS and runner != 'device-pair':
        errors.append('PAIR_TARGET_REQUIRES_PAIR_RUNNER')
    if runner in DEVICE_RUNNERS:
        if devices is None:
            devices, discovery_error = discover_devices()
            if discovery_error:
                errors.append(discovery_error)
        platform, qualification = qualify_device(device_id_for(instance, env), devices or [],
                                                   allowed_platforms={str(instance.get('platform'))})
        errors.extend(qualification)
        if platform and platform != instance.get('platform'):
            errors.append('DEVICE_PLATFORM_MISMATCH')
    executable = 'patrol' if runner == 'patrol' else 'flutter'
    if runner in DEVICE_RUNNERS | {'flutter-machine'} and not shutil.which(executable):
        errors.append(f'RUNNER_MISSING:{executable}')
    if runner == 'patrol' and instance.get('platform') != 'android':
        errors.append('PATROL_ANDROID_INSTRUMENTATION_REQUIRED')
    for name in instance.get('required_env', []):
        if not _value(env, name, str(instance.get('account_role') or instance.get('role') or '')):
            errors.append(f'FIXTURE_VALUE_MISSING:{name}')
    for name in instance.get('required_true_env', []):
        if _value(env, name, str(instance.get('account_role') or instance.get('role') or '')) != 'true':
            errors.append(f'FIXTURE_OPT_IN_MISSING:{name}=true')
    if instance.get('orchestration') in {'dnd-fixture', 'legacy-fixture'}:
        errors.extend(companion_environment_errors(instance, env))
    if instance.get('orchestration') == 'rtc-concurrent':
        for name in ('TEST_EXPECTED_UID', 'PEER_UID'):
            if not _value(env, name, str(instance.get('account_role') or instance.get('role') or '')):
                errors.append(f'PAIR_FIXTURE_VALUE_MISSING:{name}')
    if instance.get('orchestration') == 'mc-owned-coordinator' and not shutil.which('adb'):
        errors.append('RUNNER_MISSING:adb')
    # Missing scoped approval/lease/fixture must not initiate backend probes.
    if probe and not errors:
        errors.extend(backend_environment_errors(instance, env, probe=True))
    return list(dict.fromkeys(errors))


def build_invocation(root: Path, instance: dict, env: dict, output_dir: Path,
                     devices: list[dict] | None = None, *, paired: bool = False,
                     extra_defines: dict | None = None) -> dict:
    """Prepare one process. preflight errors are retained, not silently waived."""
    runner = instance.get('runner')
    if (runner == 'device-pair' or instance.get('target') in PAIR_TARGETS) and not paired:
        raise ValueError('PAIR_TARGET_REQUIRES_PAIR_ORCHESTRATION')
    role = str(instance.get('account_role') or instance.get('role') or '')
    target = str(instance['target'])
    env, owned = mc_owned_environment(instance, env)
    process_env = dict(env)
    defines = dict(instance.get('dart_defines') or {})
    for name in ENV_ALIASES:
        value = _value(env, name, role)
        if value:
            defines[name] = value
            process_env[name] = value
    if needs_backend(instance):
        # Both app Env and FlowConfig must see the explicit local URL.
        defines['API_BASE_URL_OVERRIDE'] = defines.get('API_BASE_URL', '')
        process_env['IMBOY_SOLIDIFIED_KEY'] = defines.get('SOLIDIFIED_KEY_OVERRIDE', '')
    fixture_env = set(instance.get('required_env', [])) | set(instance.get('required_true_env', []))
    for name in fixture_env:
        if _value(env, name, role):
            defines[name] = _value(env, name, role)
            process_env[name] = defines[name]
    if instance.get('session_mode') == 'mc-owned' and not owned['errors']:
        defines.update(owned['defines'])
    for name in ('TEST_ALLOW_BUSINESS_WRITES', 'TEST_ALLOW_CHANNEL_WRITES', 'TEST_EXPECTED_UID',
                 'PEER_UID', 'TEST_PEER_UID', 'TEST_GROUP_ID', 'TEST_REQUIRED_MEMBER_UIDS',
                 'TEST_DUAL_RUN_ID', 'LK_RTC_WS_OVERRIDE', 'TEST_ALLOW_API_WRITES'):
        value = _value(env, name, role)
        if value:
            defines[name] = value
            process_env[name] = value
    orchestration = instance.get('orchestration') or PAIR_TARGETS.get(target)
    if orchestration == 'e2ee-vector':
        defines.update(TEST_INTEROP_ROLE=role, PATROL_INTEROP='false')
    elif orchestration in {'rtc-concurrent', 'rtc-group-concurrent'} or 'livekit' in instance.get('dependencies', []):
        defines.update(LK_RTC_RUN='true', LK_RTC_STRICT='true')
    elif orchestration in {'h2-c2c', 'h2-c2g'}:
        defines['H2_C2C_REAL_RUN' if orchestration == 'h2-c2c' else 'H2_C2G_REAL_RUN'] = 'true'
    elif orchestration == 'collaboration-sequential':
        defines.update(TEST_COLLAB_ROLE=str(instance['role']), TEST_ALLOW_BUSINESS_WRITES='true',
                       IMBOY_TEST_ISOLATED='true')
    elif orchestration in {'dual-concurrent', 'dual-sequential'}:
        defines['TEST_DUAL_ROLE'] = role
        # Legacy define names remain, while backend_environment_errors enforces loopback.
        flag = ('TEST_ALLOW_DUAL_GROUP_PROD_WRITES' if 'group_dual_' in target
                else 'TEST_ALLOW_DUAL_ACCOUNT_PROD_WRITES')
        defines[flag] = _value(env, 'TEST_ALLOW_BUSINESS_WRITES')
        if orchestration == 'dual-sequential':
            defines['TEST_STOP_AFTER_OUTGOING_ACK'] = 'true' if role == 'sender' else 'false'
            defines['TEST_FORCE_LOGOUT_BEFORE_LOGIN'] = 'true'
    defines.update(extra_defines or {})
    acceptance_evidence = acceptance_environment_evidence(root, instance, env)
    defines.pop('ACCEPTANCE_RUNNER_VERIFIED', None)
    defines.update(acceptance_evidence.get('defines', {}))
    output_dir.mkdir(parents=True, exist_ok=True)
    if runner == 'patrol':
        command = ['patrol', 'test', '--target', target, '--device', device_id_for(instance, env),
                   '--no-uninstall', '--show-flutter-logs']
        kind = 'junit'
    else:
        if runner == 'flutter-machine' and target.startswith('integration_test/'):
            raise ValueError('HOST_INTEGRATION_WRAPPER_REQUIRED: execution_runner creates an in-project test wrapper')
        command = ['flutter', 'test', target, '--machine', '--concurrency=1', '--no-pub']
        if runner in DEVICE_RUNNERS:
            command.extend(['-d', device_id_for(instance, env), '--no-test-assets'])
        if instance.get('flavor'):
            command.extend(['--flavor', str(instance['flavor'])])
        if instance.get('test_name'):
            command.extend(['--plain-name', str(instance['test_name'])])
        kind = 'flutter-machine'
    if instance.get('suite') == 'golden':
        process_env['IMBOY_GOLDEN_REQUIRED'] = 'true'
    command.extend(f'--dart-define={name}={str(value).lower() if isinstance(value, bool) else value}'
                   for name, value in sorted(defines.items()))
    product_evidence = product_artifact_evidence(root, instance, env)
    if product_evidence.get('fingerprint'):
        (output_dir / 'product-artifact.json').write_text(
            json.dumps(product_evidence, sort_keys=True, indent=2) + '\n')
    evidence_artifacts = []
    if acceptance_evidence.get('context'):
        path = output_dir / 'acceptance-environment.json'
        path.write_text(json.dumps(acceptance_evidence, sort_keys=True, indent=2) + '\n')
        evidence_artifacts.append({'path': str(path), 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()})
    return {'command': command, 'env': process_env, 'cwd': str(root), 'evidence_kind': kind,
            'product_artifact': product_evidence,
            'evidence_artifacts': evidence_artifacts,
            'log_path': str(output_dir / 'process.log'),
            'junit_before': junit_snapshot(root) if kind == 'junit' else {},
            'errors': preflight_instance(root, instance, env, devices)}


def junit_snapshot(root: Path) -> dict[str, tuple[int, int]]:
    results = {}
    for base in (root / 'build/app/outputs/androidTest-results', root / 'android/app/build/outputs/androidTest-results'):
        for path in base.rglob('*.xml') if base.exists() else []:
            stat = path.stat()
            results[str(path)] = (stat.st_mtime_ns, stat.st_size)
    return results


def fresh_junit_paths(root: Path, before: dict) -> list[str]:
    return [path for path, fingerprint in junit_snapshot(root).items()
            if tuple(before.get(path, ())) != fingerprint]


def parse_patrol_junit(paths: list[str | Path], exit_code: int | None) -> dict:
    """Patrol's parameterized native cases delegate to each Dart patrolTest.

    Native bootstrap-only cases, stale files, empty suites and inconsistent suite
    counts cannot prove execution. The caller supplies only fresh_junit_paths.
    """
    passed = failed = skipped = 0
    errors = []
    if not paths:
        errors.append('PATROL_RESULT_MISSING')
    for path in paths:
        try:
            tree = ET.parse(path).getroot()
            for suite in tree.iter('testsuite'):
                cases = list(suite.findall('testcase'))
                if suite.get('tests') is not None and int(suite.get('tests', '0')) != len(cases):
                    errors.append('PATROL_RESULT_COUNTS_MISMATCH')
                for key, actual in (('failures', sum(c.find('failure') is not None for c in cases)),
                                    ('errors', sum(c.find('error') is not None for c in cases)),
                                    ('skipped', sum(c.find('skipped') is not None for c in cases))):
                    if suite.get(key) is not None and int(suite.get(key, '0')) != actual:
                        errors.append('PATROL_RESULT_COUNTS_MISMATCH')
                for case in cases:
                    if ('MainActivityTest' not in case.get('classname', '')
                            or not case.get('name', '').startswith('runDartTest[')):
                        errors.append('PATROL_DART_CASE_IDENTITY_MISSING')
                    if case.find('failure') is not None or case.find('error') is not None:
                        failed += 1
                    elif case.find('skipped') is not None:
                        skipped += 1
                    else:
                        passed += 1
        except (OSError, ET.ParseError, ValueError):
            errors.append('PATROL_RESULT_INVALID')
    if exit_code is None or exit_code != 0:
        errors.append('RUNNER_EXIT_NONZERO' if exit_code is not None else 'RUNNER_EXIT_MISSING')
    if not passed + failed + skipped:
        errors.append('ZERO_EXECUTION')
    if skipped:
        errors.append('UNEXPECTED_SKIP')
    return {'passed': passed, 'failed': failed, 'skipped': skipped,
            'executed': passed + failed + skipped, 'actual_run': passed + failed,
            'errors': list(dict.fromkeys(errors)),
            'test_status': 'PASS' if passed > 0 and not failed and not errors else 'FAIL'}


def reassemble_vector(text: str) -> str:
    chunks: dict[int, str] = {}
    totals = set()
    for index, total, chunk in re.findall(r'E2EE_INTEROP_VECTOR_B64_CHUNK:(\d+)/(\d+):([A-Za-z0-9_=-]+)', text):
        idx, count = int(index), int(total)
        if idx < 1 or count < 1 or idx > count or (idx in chunks and chunks[idx] != chunk):
            raise ValueError('PAIR_VECTOR_INVALID')
        chunks[idx] = chunk
        totals.add(count)
    if len(totals) != 1 or set(chunks) != set(range(1, next(iter(totals), 0) + 1)):
        raise ValueError('PAIR_VECTOR_INCOMPLETE')
    vector = ''.join(chunks[i] for i in sorted(chunks))
    try:
        decoded = base64.b64decode(vector + '=' * (-len(vector) % 4), altchars=b'-_', validate=True)
        json.loads(decoded)
    except (ValueError, UnicodeDecodeError):
        raise ValueError('PAIR_VECTOR_INVALID') from None
    return vector


def pair_environment_errors(instances: list[dict], env: dict) -> list[str]:
    if not instances:
        return ['PAIR_PLAN_EMPTY']
    methods = {i.get('orchestration') or PAIR_TARGETS.get(i.get('target')) for i in instances}
    if len(methods) != 1 or None in methods:
        return ['PAIR_ORCHESTRATION_UNKNOWN_OR_MIXED']
    method = next(iter(methods))
    if method not in set(PAIR_TARGETS.values()):
        return ['PAIR_ORCHESTRATION_UNKNOWN_OR_MIXED']
    required = {
        'e2ee-vector': {'sender', 'receiver', 'final'},
        'rtc-concurrent': {'caller', 'callee'},
        'h2-c2c': {'sender', 'receiver', 'history-sender', 'history-receiver'},
        'h2-c2g': {'sender', 'receiver', 'new-member'},
        'collaboration-sequential': {'owner', 'member'},
        'legacy-fixture': {'new-client'},
    }.get(method, {'sender', 'receiver'})
    if method == 'dual-sequential' and len({i.get('platform') for i in instances}) > 1:
        # This audited wrapper supports independent same-platform topologies.
        # Preserve Android and macOS obligations, with separate role evidence.
        return [f'{platform}:{error}' for platform in sorted({i['platform'] for i in instances})
                for error in pair_environment_errors([i for i in instances if i['platform'] == platform], env)]
    roles = [i.get('role') for i in instances]
    if len(roles) != len(set(roles)) or set(roles) != required:
        return ['PAIR_ROLE_SET_INCOMPLETE']
    if len({i.get('product_profile') for i in instances}) != 1:
        return ['PAIR_PRODUCT_PROFILE_MISMATCH']
    mapping = {i['role']: device_id_for(i, env) for i in instances}
    if not all(mapping.values()):
        return ['PAIR_DEVICE_MISSING']
    if method in {'h2-c2c', 'h2-c2g'}:
        if mapping['sender'] == mapping['receiver']:
            return ['PAIR_DEVICES_MUST_BE_DISTINCT']
        if method == 'h2-c2c' and (mapping['history-sender'] != mapping['sender']
                or mapping['history-receiver'] != mapping['receiver']):
            return ['PAIR_HISTORY_DEVICE_MUST_REUSE_PERSISTED_STORAGE']
        if method == 'h2-c2g' and mapping['new-member'] != mapping['receiver']:
            return ['PAIR_NEW_MEMBER_MUST_USE_RELEASED_MAC_SLOT']
    elif method not in {'e2ee-vector', 'dual-sequential'} and len(set(mapping.values())) != len(mapping):
        return ['PAIR_DEVICES_MUST_BE_DISTINCT']
    if method == 'e2ee-vector':
        platforms = {i['role']: i['platform'] for i in instances}
        if platforms != {'sender': 'android', 'receiver': 'macos', 'final': 'android'}:
            return ['PAIR_INTEROP_PLATFORM_TOPOLOGY_INVALID']
    return []


def run_pair(root: Path, instances: list[dict], env: dict, output_dir: Path,
             execute: Callable[[dict, dict], dict], devices: list[dict] | None = None) -> dict[str, dict]:
    """Call the existing runner for each role, preserving per-instance evidence.

    execute(instance, invocation) must write invocation.log_path while running and
    return a classified result (status or test_status). Vector text only transports
    synthetic state; it is never used as a PASS predicate.
    """
    methods = {i.get('orchestration') or PAIR_TARGETS.get(i.get('target')) for i in instances}
    if methods == {'dual-sequential'} and len({i.get('platform') for i in instances}) > 1:
        results = {}
        for platform in sorted({i['platform'] for i in instances}):
            topology = [i for i in instances if i['platform'] == platform]
            results.update(run_pair(root, topology, env, output_dir / platform, execute, devices))
        return results
    errors = pair_environment_errors(instances, env)
    for instance in instances:
        errors.extend(preflight_instance(root, instance, env, devices))
    if methods == {'rtc-group-concurrent'}:
        groups = {_value(env, 'TEST_GROUP_ID', str(i.get('account_role') or i.get('role') or '')) for i in instances}
        uids = [_value(env, 'TEST_EXPECTED_UID', str(i.get('account_role') or i.get('role') or '')) for i in instances]
        if len(groups) != 1 or not all(groups):
            errors.append('PAIR_GROUP_FIXTURE_MUST_MATCH')
        if len(uids) != len(set(uids)) or not all(uids):
            errors.append('PAIR_ACCOUNTS_MUST_BE_DISTINCT')
    if errors:
        return {i['id']: {'status': 'BLOCKED', 'reason_code': 'ENV_MISSING',
                          'errors': list(dict.fromkeys(errors))} for i in instances}
    by_role = {i['role']: i for i in instances}
    method = instances[0].get('orchestration') or PAIR_TARGETS[instances[0]['target']]
    results = {}

    def run(role: str, extra: dict | None = None) -> dict:
        item = by_role[role]
        try:
            invocation = build_invocation(root, item, env, output_dir / role, devices,
                                          paired=True, extra_defines=extra)
            return execute(item, invocation)
        except Exception as exc:
            return {'status': 'BLOCKED', 'reason_code': 'RUNNER_CRASH',
                    'errors': [type(exc).__name__ + ':' + str(exc)]}

    def passed(result: dict) -> bool:
        return result.get('status', result.get('test_status')) == 'PASS'

    if method in {'e2ee-vector', 'dual-sequential', 'collaboration-sequential'}:
        vector = ''
        upstream = None
        roles = (('sender', 'receiver', 'final') if method == 'e2ee-vector' else
                 ('owner', 'member') if method == 'collaboration-sequential' else ('sender', 'receiver'))
        for role in roles:
            item = by_role[role]
            if upstream:
                results[item['id']] = {'status': 'BLOCKED', 'reason_code': 'UPSTREAM_FAILED',
                                      'upstream': [upstream]}
                continue
            result = run(role, {'TEST_INTEROP_VECTOR_B64': vector} if vector else None)
            results[item['id']] = result
            if not passed(result):
                upstream = item['id']
            elif method == 'e2ee-vector' and role != 'final':
                try:
                    vector = reassemble_vector((output_dir / role / 'process.log').read_text())
                except (OSError, ValueError) as exc:
                    result.update(status='FAIL', reason_code='EVIDENCE_INVALID', errors=[str(exc)])
                    upstream = item['id']
        return results
    if method in {'h2-c2c', 'h2-c2g'}:
        with ThreadPoolExecutor(max_workers=2) as pool:
            receiver = pool.submit(run, 'receiver')
            sender = pool.submit(run, 'sender')
            results[by_role['receiver']['id']] = receiver.result()
            if method == 'h2-c2g':
                # B must exit before the new account takes over the same macOS slot;
                # A remains alive while the new device key arrives and rotates Megolm.
                item = by_role['new-member']
                if passed(results[by_role['receiver']['id']]):
                    results[item['id']] = run('new-member')
                else:
                    results[item['id']] = {'status': 'BLOCKED', 'reason_code': 'UPSTREAM_FAILED',
                                          'upstream': [by_role['receiver']['id']]}
            results[by_role['sender']['id']] = sender.result()
        if method == 'h2-c2c':
            failed = [i['id'] for role, i in by_role.items()
                      if role in {'sender', 'receiver'} and not passed(results[i['id']])]
            for role in ('history-sender', 'history-receiver'):
                item = by_role[role]
                results[item['id']] = ({'status': 'BLOCKED', 'reason_code': 'UPSTREAM_FAILED',
                                       'upstream': failed} if failed else run(role))
        return results
    if method in {'dnd-fixture', 'legacy-fixture'}:
        primary = 'receiver' if method == 'dnd-fixture' else 'new-client'
        if method == 'dnd-fixture':
            result = run('sender')
            results[by_role['sender']['id']] = result
            if not passed(result):
                results[by_role[primary]['id']] = {'status': 'BLOCKED', 'reason_code': 'UPSTREAM_FAILED',
                                                  'upstream': [by_role['sender']['id']]}
                return results
        item = by_role[primary]
        companion = {**item, 'id': item['id'] + ':external-fixture', 'role': 'external-fixture'}
        invocation = companion_invocation(root, item, env, output_dir / primary)
        with ThreadPoolExecutor(max_workers=2) as pool:
            future = pool.submit(execute, companion, invocation)
            primary_result = run(primary)
            fixture_result = future.result()
        fixture_result['driver_sha256'] = hashlib.sha256(Path(invocation['command'][1]).read_bytes()).hexdigest()
        primary_result['companion_evidence'] = fixture_result
        if not passed(fixture_result):
            primary_result.update(status='BLOCKED', reason_code='UPSTREAM_FAILED',
                                  upstream=[companion['id']])
        results[item['id']] = primary_result
        return results
    first, second = ('callee', 'caller') if method == 'rtc-concurrent' else ('receiver', 'sender')
    # The receiver process starts first. Waiting for its live readiness log only
    # orders signaling; the machine-event result remains the sole PASS evidence.
    with ThreadPoolExecutor(max_workers=2) as pool:
        future = pool.submit(run, first)
        if method == 'rtc-concurrent':
            deadline = time.monotonic() + int(env.get('IMBOY_PAIR_READY_TIMEOUT', '180'))
            path = output_dir / first / 'process.log'
            ready = False
            while time.monotonic() < deadline and not future.done():
                if path.exists() and '[B] 等待来电' in path.read_text(errors='replace'):
                    ready = True
                    break
                time.sleep(0.1)
            if not ready:
                results[by_role[second]['id']] = {'status': 'BLOCKED', 'reason_code': 'UPSTREAM_FAILED',
                    'upstream': [by_role[first]['id']], 'errors': ['PAIR_RECEIVER_NOT_READY']}
            else:
                results[by_role[second]['id']] = run(second)
        else:
            results[by_role[second]['id']] = run(second)
        results[by_role[first]['id']] = future.result()
    return results


def verify_coordinator_evidence(receipt: dict, resolve_path: Callable[[str], Path]) -> list[str]:
    """Replay MC coordinator gate evidence after execution or artifact relocation.

    These are fixture phases, not Flutter cases. Only the existing coordinator's
    complete structured action sequence plus a zero process exit satisfies it.
    """
    sequences = {
        'live': ['view_sent', 'handled:joined', 'handled:warm', 'handled:before_received',
                 'view_sent', 'handled:chat_denied', 'handled:cache_denied', 'coordinator_verified'],
        'reconnect': ['view_sent', 'handled:joined', 'handled:warm', 'link_removed',
                      'handled:before_received', 'handled:disconnected', 'link_restored',
                      'handled:offline_queued', 'view_sent', 'handled:reconnected',
                      'handled:queued_denied', 'coordinator_verified'],
    }
    try:
        if (receipt.get('kind') != 'coordinator-gate' or receipt.get('mode') not in sequences
                or type(receipt.get('exit_code')) is not int or receipt['exit_code'] != 0
                or not re.fullmatch(r'[a-f0-9]{64}', receipt.get('context_sha256', ''))
                or not receipt.get('instance_id')
                or receipt.get('target') != 'integration_test/micro_community_owned_android_negative_test.dart'):
            return ['COORDINATOR_RECEIPT_INVALID']
        command = receipt['command']
        if (not isinstance(command, list) or not all(isinstance(part, str) and part for part in command)
                or len(command) != 8 or Path(command[1]).name != 'mc22_owned_coordinator.py'
                or command[2::2] != ['--context', '--device', '--events']
                or command[-1] != receipt['evidence']):
            return ['COORDINATOR_COMMAND_INVALID']
        paths = {}
        for name in ('log', 'evidence', 'process_receipt'):
            path = Path(resolve_path(receipt[name]))
            if hashlib.sha256(path.read_bytes()).hexdigest() != receipt['hashes'][name]:
                return ['COORDINATOR_ARTIFACT_HASH_MISMATCH:' + name]
            paths[name] = path
        process = json.loads(paths['process_receipt'].read_text())
        if any(process.get(key) != receipt.get(key) for key in
               ('kind', 'mode', 'exit_code', 'command', 'log', 'evidence', 'context_sha256', 'instance_id', 'target')):
            return ['COORDINATOR_PROCESS_RECEIPT_MISMATCH']
        rows = [json.loads(line) for line in paths['evidence'].read_text().splitlines()]
        if ([row.get('event') for row in rows] != sequences[receipt['mode']]
                or any(set(row) != {'event', 'monotonic'} or type(row['monotonic']) not in (int, float)
                       or not math.isfinite(row['monotonic']) or row['monotonic'] < 0 for row in rows)
                or any(rows[index]['monotonic'] < rows[index - 1]['monotonic'] for index in range(1, len(rows)))):
            return ['COORDINATOR_PHASE_EVIDENCE_INCOMPLETE']
        return []
    except (OSError, ValueError, KeyError, TypeError, AttributeError):
        return ['COORDINATOR_EVIDENCE_MISSING_OR_INVALID']


def run_coordinated(root: Path, instance: dict, env: dict, output_dir: Path,
                    execute: Callable[[dict, dict], dict], devices: list[dict] | None = None) -> dict:
    """Run the existing MC host coordinator beside one actual Flutter target."""
    errors = preflight_instance(root, instance, env, devices)
    effective, owned = mc_owned_environment(instance, env)
    errors.extend(owned['errors'])
    if errors:
        return {'status': 'BLOCKED', 'reason_code': 'ENV_MISSING', 'errors': list(dict.fromkeys(errors))}
    invocation = build_invocation(root, instance, effective, output_dir / 'flutter', devices)
    if invocation['errors']:
        return {'status': 'BLOCKED', 'reason_code': 'ENV_MISSING', 'errors': invocation['errors']}
    destination = output_dir / 'coordinator'
    destination.mkdir(parents=True, exist_ok=True)
    log, events, process_receipt = (destination / name for name in ('process.log', 'phases.jsonl', 'process.json'))
    command = [sys.executable, str(Path(root) / 'scripts/mc22_owned_coordinator.py'),
               '--context', owned['context_path'], '--device', device_id_for(instance, env), '--events', str(events)]
    code = None
    primary = None
    with log.open('xb') as handle:
        process = subprocess.Popen(command, cwd=root, env=effective, stdout=handle, stderr=subprocess.STDOUT)
        try:
            primary = execute(instance, invocation)
        except Exception as exc:
            primary = {'status': 'BLOCKED', 'reason_code': 'RUNNER_CRASH', 'errors': [type(exc).__name__]}
        finally:
            try:
                code = process.wait(timeout=15)
            except subprocess.TimeoutExpired:
                # Existing SIGTERM handler unwinds the coordinator's finally and
                # restores only its own reverse mapping. Do not touch other leases.
                process.terminate()
                try:
                    code = process.wait(timeout=25)
                except subprocess.TimeoutExpired:
                    process.kill()
                    code = process.wait(timeout=5)
    gate = {'kind': 'coordinator-gate', 'mode': owned['mode'], 'exit_code': code,
            'instance_id': instance['id'], 'target': instance['target'], 'command': command,
            'log': str(log), 'evidence': str(events), 'context_sha256': owned['context_sha256']}
    process_receipt.write_text(json.dumps(gate, sort_keys=True, indent=2) + '\n')
    gate['process_receipt'] = str(process_receipt)
    gate['hashes'] = {key: hashlib.sha256(Path(gate[key]).read_bytes()).hexdigest()
                      if Path(gate[key]).is_file() else '' for key in ('log', 'evidence', 'process_receipt')}
    problems = verify_coordinator_evidence(gate, Path)
    gate.update(status='BLOCKED' if problems else 'PASS',
                reason_code='COORDINATOR_EVIDENCE_INVALID' if problems else 'NONE', errors=problems)
    primary['companion_evidence'] = gate
    if problems and primary.get('status') != 'FAIL':
        primary.update(status='BLOCKED', reason_code='UPSTREAM_FAILED', upstream=[instance['id'] + ':coordinator'])
    return primary


def companion_environment_errors(instance: dict, env: dict) -> list[str]:
    """Historical host/old-client fixtures are explicit, hashed local inputs.

    A driver emits the existing Flutter machine protocol under the target path.
    It prepares the synthetic legacy state and observes the live primary log to
    trigger the specified peer action. Both streams must be classified PASS.
    """
    method = instance.get('orchestration')
    key = 'IMBOY_LEGACY_PAIR_DRIVER' if method == 'legacy-fixture' else 'IMBOY_DND_PAIR_DRIVER'
    value = env.get(key, '')
    if not value:
        return ['EXTERNAL_COMPANION_MISSING:' + key]
    path = Path(value)
    if not path.is_absolute() or not path.is_file() or path.suffix != '.py':
        return ['EXTERNAL_COMPANION_INVALID:' + key]
    expected = env.get(key + '_SHA256', '')
    if not expected or hashlib.sha256(path.read_bytes()).hexdigest() != expected:
        return ['EXTERNAL_COMPANION_HASH_MISMATCH:' + key]
    return []


def companion_invocation(root: Path, instance: dict, env: dict, output_dir: Path) -> dict:
    key = ('IMBOY_LEGACY_PAIR_DRIVER' if instance['orchestration'] == 'legacy-fixture'
           else 'IMBOY_DND_PAIR_DRIVER')
    output_dir.mkdir(parents=True, exist_ok=True)
    return {'command': [sys.executable, env[key], '--target', instance['target'],
                        '--primary-log', str(output_dir / 'process.log'),
                        '--orchestration', instance['orchestration']],
            'env': dict(env), 'cwd': str(root), 'evidence_kind': 'flutter-machine',
            'log_path': str(output_dir / 'companion' / 'process.log'),
            'errors': companion_environment_errors(instance, env)}

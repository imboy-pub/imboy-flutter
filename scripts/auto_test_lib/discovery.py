"""双向资产发现与 catalog 生成。

扫描 integration tests、lib/page 页面、模块化 presentation 页面与 GoRoute
注册目标，生成稳定排序的 test/auto_test/catalog.json；catalog --check 只
比较不改文件。impact 基于 catalog 输出变更直接命中的唯一 targets。
"""
from __future__ import annotations

import hashlib
import json
import re
import subprocess
from pathlib import Path

EXCLUSION_CODES = {'PLATFORM_NA', 'FEATURE_DISABLED', 'UNREACHABLE_DEAD_CODE', 'DUPLICATE_EQUIVALENCE'}
CATALOG_SCHEMA_VERSION = 1


def git_head(repo: Path) -> str:
    try:
        return subprocess.run(
            ['git', '-C', str(repo), 'rev-parse', 'HEAD'], capture_output=True, text=True, check=True
        ).stdout.strip()
    except subprocess.CalledProcessError:
        return 'NOT_A_GIT_REPO'


def scan_integration_tests(root: Path) -> list[str]:
    return sorted(p.relative_to(root).as_posix() for p in (root / 'integration_test').rglob('*_test.dart'))


def scan_lib_pages(root: Path) -> list[str]:
    return sorted(p.relative_to(root).as_posix() for p in (root / 'lib' / 'page').rglob('*_page.dart'))


def scan_module_pages(root: Path) -> list[str]:
    base = root / 'lib' / 'modules'
    if not base.is_dir():
        return []
    return sorted(
        p.relative_to(root).as_posix() for p in base.rglob('*_page.dart') if '/presentation/' in p.relative_to(root).as_posix()
    )


_ROUTE_RE = re.compile(r'GoRoute\s*\(')
_PAGE_ARG_RE = re.compile(r"(?:page|builder)[^;{}]*?([A-Za-z0-9_]+Page)\s*\(")


def scan_route_pages(root: Path) -> list[str]:
    """静态识别 GoRoute 注册引用的 Page 构件名（保守正则，不构建 import 图）。"""
    dirs = [root / 'lib' / 'config' / 'router']
    for module in ('organization', 'enterprise', 'customer_service'):
        candidate = root / 'lib' / 'modules' / module / 'presentation'
        if candidate.is_dir():
            dirs.append(candidate)
    pages: set[str] = set()
    for base in dirs:
        for path in sorted(base.rglob('*.dart')):
            try:
                text = path.read_text(encoding='utf-8', errors='replace')
            except OSError:
                continue
            if not _ROUTE_RE.search(text):
                continue
            for match in _PAGE_ARG_RE.finditer(text):
                pages.add(f'{match.group(1)}')
    return sorted(pages)


def _page_component(path: str) -> str:
    return Path(path).stem


def sha256_file(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load_specs(root: Path) -> list[dict]:
    specs_dir = root / 'test' / 'auto_test' / 'specs'
    specs = []
    for path in sorted(specs_dir.glob('*.json')):
        spec = json.loads(path.read_text(encoding='utf-8'))
        spec['_spec_file'] = path.relative_to(root).as_posix()
        specs.append(spec)
    return specs


_LEDGER_ROW_RE = re.compile(r'^\|[^|]*\|[^|]*\|[^|]*`([^`]+)`')


_PATH_LIKE_RE = re.compile(r'^(?:lib/)?[A-Za-z0-9_/.-]+\.dart$')


def scan_ledger_issues(root: Path) -> list[dict]:
    """页面台账健康检查：首个页面源码路径必须存在；非页面路径仅提示不阻断。"""
    issues = []
    base = root / 'test' / 'auto_test'
    for path in sorted(base.glob('*/*_page.md')):
        first_source = ''
        for line in path.read_text(encoding='utf-8', errors='replace').splitlines():
            match = _LEDGER_ROW_RE.match(line)
            if not match:
                continue
            candidate = match.group(1).strip()
            if candidate.startswith('page/'):
                candidate = f'lib/{candidate}'
            if _PATH_LIKE_RE.match(candidate):
                first_source = candidate
                break
        rel = path.relative_to(root).as_posix()
        if not first_source:
            issues.append({'ledger': rel, 'issue': 'NO_PAGE_SOURCE_FOUND'})
        elif not (root / first_source).is_file():
            issues.append({'ledger': rel, 'issue': 'PAGE_SOURCE_MISSING', 'source': first_source})
    return issues


def generate_catalog(root: Path) -> dict:
    """确定性生成 catalog：每个 integration test 文件恰一条 entry 或一条 exclusion。"""
    itests = scan_integration_tests(root)
    lib_pages = scan_lib_pages(root)
    module_pages = scan_module_pages(root)
    route_pages = scan_route_pages(root)
    specs = load_specs(root)
    spec_by_target: dict[str, dict] = {}
    for spec in specs:
        spec_by_target.setdefault(spec['runner']['target'], spec)
    spec_sources = {source for spec in specs for source in spec.get('sources', [])}
    spec_dependencies = {dep for spec in specs for dep in spec.get('dependencies', [])}

    entries = []
    for target in itests:
        spec = spec_by_target.get(target)
        entry = {
            'id': f'test:{target}',
            'target': target,
            'target_sha256': sha256_file(root / target),
            'sources': sorted(spec['sources']) if spec else [],
            'dependencies': sorted(spec.get('dependencies', [])) if spec else [],
            'risk': spec.get('risk_mode') or spec.get('risk') if spec else None,
            'requirements': sorted(spec['runner'].get('requires', [])) if spec else [],
            'tags': sorted({target.split('/')[1]} if '/' in target else {'root'}),
            'enabled': bool(spec and spec.get('safe_to_execute')),
            'oracle_hint': bool(_target_has_oracle(root / target)),
        }
        if entry['risk'] is None:
            entry['risk'] = 'device-readonly'  # 无 spec 的存量测试默认只读规划
        entries.append(entry)

    page_map = []
    all_pages = sorted(set(lib_pages + module_pages))
    component_to_paths = {_page_component(p): p for p in all_pages}
    for page in all_pages:
        related = [e for e in entries if page in e['sources'] or page in e['dependencies']]
        mapped_targets = sorted({e['target'] for e in related if page in e['sources']})
        dep_targets = sorted({e['target'] for e in related if page not in e['sources']})
        page_map.append({
            'page': page,
            'mapped_targets': mapped_targets,
            'dependency_targets': dep_targets,
            'route_registered': _page_component(page) in route_pages,
            'in_spec_sources': page in spec_sources or page in spec_dependencies,
            'excluded': False,
            'exclusion_code': None,
            'details': '',
        })

    catalog = {
        'schema_version': CATALOG_SCHEMA_VERSION,
        'generated_from': {
            'app_head': git_head(root),
            'backend_head': git_head(root.parent / 'imboy'),
            'integration_test_count': len(itests),
            'lib_page_count': len(lib_pages),
            'module_page_count': len(module_pages),
            'route_page_component_count': len(route_pages),
            'spec_count': len(specs),
        },
        'entries': entries,
        'pages': page_map,
        'exclusions': [],
        'ledger_issues': scan_ledger_issues(root),
    }
    return catalog


_ORACLE_RE = re.compile(r'\b(expect|expectLater)\s*\(')
_ORACLE_HELPER_WHITELIST = re.compile(r'\b(verifyAppState|assertPersisted|expectPageVisible|oracle)\b')


def _target_has_oracle(target_path: Path) -> bool:
    try:
        text = target_path.read_text(encoding='utf-8', errors='replace')
    except OSError:
        return False
    return bool(_ORACLE_RE.search(text) or _ORACLE_HELPER_WHITELIST.search(text))


def catalog_diff(current: dict, disk: dict) -> list[str]:
    """集合差：数量漂移、缺失、悬空、风险冲突。"""
    issues: list[str] = []
    cur_targets = {e['target'] for e in current['entries']}
    disk_targets = {e['target'] for e in disk['entries']}
    for missing in sorted(cur_targets - disk_targets):
        issues.append(f'catalog 缺失 integration test: {missing}')
    for stale in sorted(disk_targets - cur_targets):
        issues.append(f'catalog 收录了不存在/未发现的 target: {stale}')
    cur_pages = {p['page'] for p in current['pages']}
    disk_pages = {p['page'] for p in disk['pages']}
    for missing in sorted(cur_pages - disk_pages):
        issues.append(f'catalog 缺失页面: {missing}')
    for stale in sorted(disk_pages - cur_pages):
        issues.append(f'catalog 含已消失页面: {stale}')
    for key in ('integration_test_count', 'lib_page_count', 'module_page_count'):
        if current['generated_from'][key] != disk['generated_from'][key]:
            issues.append(f'{key} 漂移: disk={disk["generated_from"][key]} now={current["generated_from"][key]}')
    for entry in disk['entries']:
        if entry.get('exclusion_code') and entry['exclusion_code'] not in EXCLUSION_CODES:
            issues.append(f'非法 exclusion_code: {entry["target"]}: {entry["exclusion_code"]}')
    return issues


def impact_targets(catalog: dict, changed_paths: list[str], smoke: list[str] | None = None) -> list[str]:
    """变更直接命中的唯一 targets + 固定 smoke 集。未映射源码显式失败。"""
    changed = set(changed_paths)
    hits: set[str] = set()
    unmapped: list[str] = []
    for path in sorted(changed):
        matched = False
        for entry in catalog['entries']:
            if path in entry['sources'] or path in entry['dependencies']:
                hits.add(entry['target'])
                matched = True
        for page in catalog['pages']:
            if page['page'] == path:
                hits.update(page['mapped_targets'])
                matched = True
        if not matched and path.startswith(('lib/', 'integration_test/', 'test/')):
            unmapped.append(path)
    if unmapped:
        raise ValueError('IMPACT_UNMAPPED_SOURCES: ' + ', '.join(unmapped))
    hits.update(smoke or [])
    return sorted(hits)

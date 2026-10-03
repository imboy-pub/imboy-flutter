"""Step 9: 全页面功能清单（functional inventory）生成器。

数据源（机器优先，AI 只做后续语义审核）：
  (a) test/auto_test/*/*_page.md 页面台账：每行表格的功能列生成一条 function 记录。
  (b) lib/modules/{organization,enterprise,customer_service}/presentation/*_page.dart
      台账缺失的 9 个企业模块页面：静态提取可交互控件（宁多勿漏），并可为它们
      生成带 `generated ... by step9` 标记的台账 md（--write-ledgers）。
  (b2) 其余无台账的 lib/page/**/*_page.dart：同样静态提取，source 标
      'generated:lib_page'，不新增台账文件（台账新增仅限授权的 9 个模块页）。
  (c) 路由注册：discovery.scan_route_pages 的组件集 -> route_registered 标注。

生成 test/auto_test/functional_inventory.json；--check 只比较不改文件。
校验 validate_inventory 覆盖 DOM-001：可达页未登记、页面 0 功能、功能无 oracle、
无 platforms、test_target 悬空均报错。
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

if __package__ in (None, ''):  # 允许 python3 scripts/auto_test_lib/inventory.py 直跑
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from auto_test_lib import discovery  # noqa: E402

INVENTORY_SCHEMA_VERSION = 1
INVENTORY_PATH = ('test', 'auto_test', 'functional_inventory.json')
STEP9_GENERATED_MARK = 'generated 2026-09-18 by step9'
GENERATED_ORACLE = 'expect(<控件可观察状态>)'
GENERATED_ORACLE_FLAG = 'GENERATED_ORACLE_PLACEHOLDER'
LEDGER_ORACLE = '见台账断言'
MODULE_LEDGER_MODULES = ('organization', 'enterprise', 'customer_service')
ACTION_MAX_CHARS = 200

# ---------------------------------------------------------------- 台账解析

_HEADER_CELL_RE = re.compile(r'^\|?\s*([^|]*?)\s*\|')
_ROW_SPLIT_MIN = 11  # 与 scripts/auto_test.py page_inventory 一致


def _split_row(line: str) -> list[str]:
    return [cell.strip() for cell in line.split('|')]


def _is_data_row(line: str) -> bool:
    if not line.startswith('| ') or line.startswith('| 计划变化'):
        return False
    return not set(line.replace('|', '').strip()) <= {'-', ' ', ':'}


def _ledger_header_indexes(header_line: str) -> dict[str, int]:
    """按表头文字定位列，找不到时回退固定列（3=页面path 4=功能介绍 5=测试状态）。"""
    cells = _split_row(header_line)
    idx: dict[str, int] = {}
    for name, want in (('page_path', '页面path'), ('action', '功能介绍'), ('status', '测试状态'), ('note', '备注')):
        for i, cell in enumerate(cells):
            if cell == want:
                idx[name] = i
                break
    idx.setdefault('page_path', 3)
    idx.setdefault('action', 4)
    idx.setdefault('status', 5)
    idx.setdefault('note', 10)
    return idx


def _normalize_source(raw: str) -> str:
    src = raw.strip().strip('`').strip()
    if src.startswith('page/'):
        src = f'lib/{src}'
    return src


def _sanitize_action(text: str) -> str:
    """台账/JSON 双安全：去表格分隔符与换行、压缩空白、截断 200 字符。"""
    cleaned = text.replace('|', '/').replace('`', "'").replace('\n', ' ')
    cleaned = re.sub(r'\s+', ' ', cleaned).strip()
    return cleaned[:ACTION_MAX_CHARS]


def parse_ledger(path: Path) -> dict:
    """解析一份台账：返回 first_source/rows（含生成标记行）。"""
    text = path.read_text(encoding='utf-8', errors='replace')
    lines = text.splitlines()
    generated = any(STEP9_GENERATED_MARK in ln for ln in lines[:6])
    header_idx: dict[str, int] | None = None
    first_source = ''
    rows: list[dict] = []
    for line in lines:
        if not _is_data_row(line):
            if line.startswith('| 计划变化') and header_idx is None:
                header_idx = _ledger_header_indexes(line)
            continue
        cells = _split_row(line)
        if len(cells) < _ROW_SPLIT_MIN:
            continue
        idx = header_idx or _ledger_header_indexes('')
        row_source_raw = cells[idx['page_path']]
        row_source = _normalize_source(row_source_raw)
        if not first_source and row_source:
            first_source = row_source
        action = _sanitize_action(cells[idx['action']])
        if not action:
            continue
        rows.append({
            'row_source': row_source,
            'action': action,
            'status': cells[idx['status']],
            'note': cells[idx['note']] if idx['note'] < len(cells) else '',
        })
    return {'path': path, 'generated': generated, 'first_source': first_source, 'rows': rows}


def _row_page(row: dict, first_source: str, root: Path) -> str:
    """行级源码优先（仅当它确是 *_page.dart 且存在），否则回退台账首行源码。"""
    row_source = row['row_source']
    if row_source.endswith('_page.dart') and (root / row_source).is_file():
        return row_source
    return first_source


# ------------------------------------------------- 模块页面控件静态提取

_CONTROL_SPECS: list[tuple[str, re.Pattern[str]]] = [
    ('button', re.compile(r'\bonPressed\s*:')),
    ('button', re.compile(r'\bonTap(?:Down|Up)?\s*:')),
    ('button', re.compile(r'\bonPressedFallback\s*:')),
    ('text_field', re.compile(r'\bonChanged\s*:')),
    ('text_field', re.compile(r'\bonSubmitted\s*:')),
    ('gesture', re.compile(r'\bonLongPress(?:Start|End|Down|Up)?\s*:')),
    ('gesture', re.compile(r'\bonDoubleTap\s*:')),
    ('menu_item', re.compile(r'\bListTile\s*\(')),
    ('menu_item', re.compile(r'\b(?:PopupMenuItem|DropdownMenuItem|BottomSheet)\s*[\(<]')),
]
_TEXT_LITERAL_RE = re.compile(r"Text\s*\(\s*(?:'([^']*)'|\"([^\"]*)\")")


def extract_page_controls(source_text: str) -> list[dict]:
    """逐行扫描控件回调；就近取 Text 字面量做入口名。宁多勿漏。"""
    lines = source_text.splitlines()
    found: list[dict] = []
    used_labels: set[int] = set()

    def _label_near(line_no: int) -> str:
        for probe in range(max(0, line_no - 3), min(len(lines), line_no + 2)):
            if probe in used_labels:
                continue
            match = _TEXT_LITERAL_RE.search(lines[probe])
            if match:
                label = (match.group(1) or match.group(2) or '').strip()
                if label and '$' not in label:  # 含插值的文案不稳定，跳过
                    used_labels.add(probe)
                    return _sanitize_action(label)
        return ''

    for i, line in enumerate(lines):
        for control, pattern in _CONTROL_SPECS:
            if not pattern.search(line):
                continue
            label = _label_near(i)
            if label:
                action = f'触发「{label}」{control} 交互'
            else:
                action = f'触发第 {len(found) + 1} 处 {control} 交互入口'
            found.append({'control': control, 'action': action})
    return found


def _stem_component(stem: str) -> str:
    return ''.join(part[:1].upper() + part[1:] for part in stem.split('_') if part)


def _module_of_page(page: str, root: Path) -> str:
    """function_id 的 module 段：台账目录名 / 模块名 / lib/page 二级目录名。"""
    parts = page.split('/')
    if parts[1] == 'modules' and len(parts) > 2:
        return parts[2]
    if parts[1] == 'page' and len(parts) > 2:
        return parts[2]
    return 'app'


# ------------------------------------------------------------- 台账生成

_LEDGER_TEMPLATE_HEADER = (
    '# `{page}`\n'
    '\n'
    '> {mark}，待人工细化\n'
    '> 功能点 {count} 个 | bug 发现 0 / 解决 0 / 待处理 0\n'
    '> 索引：[../README.md](../README.md)\n'
    '\n'
    '| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |\n'
    '|---|---|---|---|---|---|---|---|---|---|\n'
)


def render_module_ledger(page: str, controls: list[dict]) -> str:
    rows = [
        '| 无待办 | - | `{page}` | {action} | 未测 | 待生成 | 0 | 0 | 0 | GENERATED_BY_STEP9 control={control} |'.format(
            page=page, action=ctrl['action'], control=ctrl['control']
        )
        for ctrl in controls
    ]
    return _LEDGER_TEMPLATE_HEADER.format(
        page=page, mark=STEP9_GENERATED_MARK, count=len(controls)
    ) + '\n'.join(rows) + '\n'


# ------------------------------------------------------------- 记录构建

def _make_record(
    *,
    page: str,
    module: str,
    stem: str,
    seq_source: tuple[str, int],
    source: str,
    control: str,
    action: str,
    oracle: str,
    details: str,
    route_components: set[str],
    catalog_page: dict | None,
) -> dict:
    component = _stem_component(stem)
    registered = component in route_components
    test_target = None
    requirements = ['device.android']
    if catalog_page:
        mapped = catalog_page.get('mapped_targets') or []
        if mapped:
            test_target = mapped[0]
    record = {
        'function_id': '',  # 稍后统一编号
        'page': page,
        'route_or_entry': component if registered else 'in_page_control',
        'route_registered': registered,
        'source': source,
        'control': control,
        'action': action,
        'expected_oracle': oracle,
        'details': details,
        'platforms': ['android', 'macos'],
        'requirements': requirements,
        'fixture': 'shared:readonly',
        'test_target': test_target,
        'disposition': 'required',
        'exclusion_code': None,
    }
    record['_seq_source'] = seq_source  # 排序键，输出前删除
    record['_module'] = module
    record['_stem'] = stem
    return record


def _ledger_generated_fields(row: dict) -> tuple[str, str, str]:
    """step9 生成台账行：占位 oracle；备注内携带 control 类型。"""
    control = 'unknown'
    note = row.get('note', '')
    match = re.search(r'control=([a-z_]+)', note)
    if match:
        control = match.group(1)
    details = GENERATED_ORACLE_FLAG + '; step9-generated ledger row'
    return control, GENERATED_ORACLE, details


def generate_inventory(root: Path, *, write_missing_ledgers: bool = False) -> tuple[dict, list[str]]:
    """确定性生成 functional inventory。返回 (inventory, 新写台账路径列表)。"""
    root = Path(root)
    auto_dir = root / 'test' / 'auto_test'

    route_components = set(discovery.scan_route_pages(root))
    lib_pages = discovery.scan_lib_pages(root)
    module_pages = discovery.scan_module_pages(root)
    all_pages = sorted(set(lib_pages + module_pages))
    page_exists = {p for p in all_pages if (root / p).is_file()}

    catalog = discovery.generate_catalog(root)
    catalog_by_page = {p['page']: p for p in catalog['pages']}

    records: list[dict] = []
    ledger_pages: set[str] = set()
    written: list[str] = []

    # (a) 全部台账行
    for ledger_path in sorted(auto_dir.glob('*/*_page.md')):
        ledger = parse_ledger(ledger_path)
        rel = ledger_path.relative_to(root).as_posix()
        if not ledger['rows'] or not ledger['first_source']:
            continue
        ledger_pages.add(ledger['first_source'])
        for i, row in enumerate(ledger['rows']):
            page = _row_page(row, ledger['first_source'], root)
            if ledger['generated']:
                control, oracle, details = _ledger_generated_fields(row)
            else:
                control, oracle, details = 'unknown', LEDGER_ORACLE, ''
            records.append(_make_record(
                page=page,
                module=ledger_path.parent.name,
                stem=Path(page).stem,
                seq_source=(rel, i),
                source=rel,
                control=control,
                action=row['action'],
                oracle=oracle,
                details=details,
                route_components=route_components,
                catalog_page=catalog_by_page.get(page),
            ))

    # (b)/(b2) 无台账页面：静态提取；模块页（授权 9 页）可选写台账
    pages_with_records = {r['page'] for r in records}
    pages_with_records |= ledger_pages
    for page in all_pages:
        if page in pages_with_records:
            continue
        source_path = root / page
        if not source_path.is_file():
            continue
        controls = extract_page_controls(source_path.read_text(encoding='utf-8', errors='replace'))
        if not controls:
            controls = [{'control': 'unknown', 'action': '页面可进入（无静态可识别控件，待人工细化）'}]
        module = _module_of_page(page, root)
        is_module_page = page.startswith('lib/modules/') and module in MODULE_LEDGER_MODULES
        ledger_rel = ''
        if is_module_page and write_missing_ledgers:
            ledger_dir = auto_dir / module
            ledger_dir.mkdir(parents=True, exist_ok=True)
            ledger_path = ledger_dir / f'{Path(page).stem}.md'
            ledger_path.write_text(render_module_ledger(page, controls), encoding='utf-8')
            ledger_rel = ledger_path.relative_to(root).as_posix()
            written.append(ledger_rel)
        for i, ctrl in enumerate(controls):
            source = ledger_rel if ledger_rel else (
                'generated:module_page' if is_module_page else 'generated:lib_page'
            )
            records.append(_make_record(
                page=page,
                module=module,
                stem=Path(page).stem,
                seq_source=(f'gen:{page}', i),
                source=source,
                control=ctrl['control'],
                action=ctrl['action'],
                oracle=GENERATED_ORACLE,
                details=GENERATED_ORACLE_FLAG + ('; module page static extraction' if is_module_page else '; lib page static extraction'),
                route_components=route_components,
                catalog_page=catalog_by_page.get(page),
            ))

    # 稳定编号：按 (module, stem) 分组，组内按 seq_source 排序
    groups: dict[tuple[str, str], list[dict]] = {}
    for record in records:
        groups.setdefault((record['_module'], record['_stem']), []).append(record)
    functions: list[dict] = []
    for (module, stem) in sorted(groups):
        group = sorted(groups[(module, stem)], key=lambda r: r['_seq_source'])
        for seq, record in enumerate(group, start=1):
            record['function_id'] = f'fn:{module}:{stem}:{seq:03d}'
            del record['_seq_source'], record['_module'], record['_stem']
            functions.append(record)
    functions.sort(key=lambda r: r['function_id'])

    page_summary = []
    for page in all_pages:
        func_ids = [f['function_id'] for f in functions if f['page'] == page]
        page_summary.append({
            'page': page,
            'module': _module_of_page(page, root),
            'function_count': len(func_ids),
            'route_registered': _stem_component(Path(page).stem) in route_components,
            'has_ledger': any(f['source'].endswith('_page.md') and f['page'] == page for f in functions),
            'ledger_generated': any(
                f['page'] == page and 'step9' in (f['details'] or '') for f in functions
            ),
        })

    inventory = {
        'schema_version': INVENTORY_SCHEMA_VERSION,
        'generated_from': {
            'app_head': 'see-catalog',
            'ledger_count': len(sorted(auto_dir.glob('*/*_page.md'))),
            'ledger_row_count': sum(1 for r in records if not r['source'].startswith('generated:')),
            'lib_page_count': len(lib_pages),
            'module_page_count': len(module_pages),
            'route_page_component_count': len(route_components),
            'function_count': len(functions),
            'generated_ledger_pages': sorted(written),
            'note': 'disposition 仅静态 required/excluded；运行结果只写 ignored RUN_ROOT/results/**',
        },
        'functions': functions,
        'pages': page_summary,
    }
    return inventory, written


# ----------------------------------------------------------------- 校验

def validate_inventory(root: Path, inventory: dict) -> list[str]:
    """DOM-001 面：缺页 / 0 功能 / 无 oracle / 无 platforms / 悬空 target。"""
    root = Path(root)
    errors: list[str] = []
    functions = inventory.get('functions', [])
    registered_pages = {f['page'] for f in functions}

    reachable = set(discovery.scan_lib_pages(root)) | set(discovery.scan_module_pages(root))
    auto_dir = root / 'test' / 'auto_test'
    for ledger_path in sorted(auto_dir.glob('*/*_page.md')):
        ledger = parse_ledger(ledger_path)
        if ledger['first_source']:
            reachable.add(ledger['first_source'])
    for page in sorted(reachable - registered_pages):
        errors.append(f'可达页面未登记任何功能: {page}')

    counts: dict[str, int] = {}
    for func in functions:
        counts[func['page']] = counts.get(func['page'], 0) + 1
        fid = func.get('function_id', '?')
        if not func.get('expected_oracle'):
            errors.append(f'功能无 oracle: {fid}')
        if not func.get('platforms'):
            errors.append(f'功能无平台归属: {fid}')
        target = func.get('test_target')
        if target and not (root / target).is_file():
            errors.append(f'test_target 悬空: {fid} -> {target}')
        disposition = func.get('disposition')
        if disposition not in ('required', 'excluded'):
            errors.append(f'非法 disposition: {fid}: {disposition}')
        if disposition == 'excluded':
            code = func.get('exclusion_code')
            if code not in discovery.EXCLUSION_CODES:
                errors.append(f'非法 exclusion_code: {fid}: {code}')
        elif func.get('exclusion_code'):
            errors.append(f'required 项不得携带 exclusion_code: {fid}')
    for page in sorted(p for p in registered_pages if p in reachable and counts.get(p, 0) == 0):
        errors.append(f'页面存在但 0 功能项: {page}')
    return errors


# ----------------------------------------------------------------- IO

def acceptance_readiness_errors(inventory: object) -> list[str]:
    """Reject unresolved inventory obligations before business acceptance.

    This static gate proves neither executable oracle quality nor execution.
    Exclusions require an independently approved applicability contract; an
    unverified disposition cannot remove an obligation here.
    """
    if not isinstance(inventory, dict):
        return ['ACCEPTANCE_INVENTORY_SCHEMA_INVALID']
    functions = inventory.get('functions')
    if not isinstance(functions, list) or not functions:
        return ['ACCEPTANCE_INVENTORY_EMPTY_OR_INVALID']
    errors = []
    for index, function in enumerate(functions):
        if not isinstance(function, dict):
            errors.append(f'ACCEPTANCE_FUNCTION_SCHEMA_INVALID:{index}')
            continue
        if function.get('disposition') != 'required':
            errors.append(f'ACCEPTANCE_APPLICABILITY_UNVERIFIED:{index}')
        oracle, details = function.get('expected_oracle'), function.get('details', '')
        if not isinstance(oracle, str) or not oracle.strip() or not isinstance(details, str):
            errors.append(f'ACCEPTANCE_ORACLE_INVALID:{index}')
        elif ('GENERATED_ORACLE_PLACEHOLDER' in details
              or '<控件可观察状态>' in oracle):
            errors.append(f'ACCEPTANCE_ORACLE_PLACEHOLDER:{index}')
        target = function.get('test_target')
        if not isinstance(target, str) or not target.strip():
            errors.append(f'ACCEPTANCE_TARGET_MISSING:{index}')
    return errors

def render_json(payload: dict) -> str:
    return json.dumps(payload, ensure_ascii=False, indent=2) + '\n'


def write_inventory(root: Path, inventory: dict) -> Path:
    path = root.joinpath(*INVENTORY_PATH)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(render_json(inventory), encoding='utf-8')
    return path


def check_inventory(root: Path) -> list[str]:
    """重新生成并与磁盘字节比较；返回差异列表（空 = 通过）。"""
    root = Path(root)
    inventory, _ = generate_inventory(root)
    errors = validate_inventory(root, inventory)
    if errors:
        return errors
    path = root.joinpath(*INVENTORY_PATH)
    if not path.is_file():
        return ['functional_inventory.json 缺失']
    disk = path.read_text(encoding='utf-8')
    if disk != render_json(inventory):
        return ['functional_inventory.json 与再生结果不一致（stale）']
    return []


def main(argv: list[str] | None = None) -> int:
    argv = list(sys.argv[1:] if argv is None else argv)
    root = Path(__file__).resolve().parents[2]
    acceptance_check = '--acceptance-check' in argv
    check = '--check' in argv or acceptance_check
    write_ledgers = '--write-ledgers' in argv
    if acceptance_check and write_ledgers:
        print('ERROR: ACCEPTANCE_CHECK_CANNOT_WRITE_LEDGERS', file=sys.stderr)
        return 64
    inventory, written = generate_inventory(root, write_missing_ledgers=write_ledgers)
    errors = validate_inventory(root, inventory)
    if acceptance_check:
        errors.extend(acceptance_readiness_errors(inventory))
    if errors:
        for err in errors:
            print(f'ERROR: {err}', file=sys.stderr)
        return 64
    if check:
        path = root.joinpath(*INVENTORY_PATH)
        if not path.is_file():
            print('ERROR: functional_inventory.json 缺失', file=sys.stderr)
            return 2
        if path.read_text(encoding='utf-8') != render_json(inventory):
            print('ERROR: functional_inventory.json 与再生结果不一致', file=sys.stderr)
            return 2
        print('inventory --check OK: '
              f"pages={len(inventory['pages'])} functions={len(inventory['functions'])}")
        return 0
    path = write_inventory(root, inventory)
    for rel in written:
        print(f'wrote ledger: {rel}')
    print(f'wrote {path.relative_to(root)}: pages={len(inventory["pages"])} '
          f'functions={len(inventory["functions"])} generated_ledgers={len(written)}')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())

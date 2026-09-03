#!/usr/bin/env python3
"""AI 真机回归规格的校验、影响分析与受控编排。

规格是可提交的 JSON；截图、日志及真实运行报告只写入 test/auto_test/reports/。
本工具默认只读/dry-run。--execute 仍不会越过 case 的本地环境和风险门禁。
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shlex
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import urlsplit


ROOT = Path(__file__).resolve().parent.parent
AUTO = ROOT / 'test' / 'auto_test'
SPECS = AUTO / 'specs'
REPORTS = AUTO / 'reports'
BASELINES = AUTO / 'baselines'
VALID_RISKS = {'P0', 'P1', 'P2'}
VALID_RUNNERS = {'flutter', 'patrol'}
VALID_VISUAL_RESULTS = {'PASS', 'FAIL', 'REVIEW', 'BLOCKED'}
CORE_MODULE_PRIORITY = {
    'passport': 0,
    'conversation': 1,
    'chat': 2,
    'contact': 3,
    'group': 4,
    'mine': 5,
    'wallet': 6,
}


def load_specs() -> list[tuple[Path, dict]]:
    specs = []
    for path in sorted(SPECS.glob('*.json')):
        try:
            specs.append((path, json.loads(path.read_text(encoding='utf-8'))))
        except json.JSONDecodeError as exc:
            raise ValueError(f'{path.relative_to(ROOT)} 不是合法 JSON: {exc}') from exc
    return specs


def validate(specs: list[tuple[Path, dict]]) -> list[str]:
    errors: list[str] = []
    ids: set[str] = set()
    required = {'schema_version', 'id', 'title', 'risk', 'phase', 'sources', 'assertions', 'visual', 'runner'}
    for path, spec in specs:
        name = path.relative_to(ROOT)
        missing = required - set(spec)
        if missing:
            errors.append(f'{name}: 缺字段 {sorted(missing)}')
            continue
        if spec['schema_version'] != 1:
            errors.append(f'{name}: schema_version 必须为 1')
        case_id = spec['id']
        if not isinstance(case_id, str) or not case_id:
            errors.append(f'{name}: id 必须是非空字符串')
        elif case_id in ids:
            errors.append(f'{name}: 重复 id {case_id}')
        else:
            ids.add(case_id)
        if spec['risk'] not in VALID_RISKS:
            errors.append(f'{name}: risk 必须是 {sorted(VALID_RISKS)}')
        if spec['phase'] not in {'p0', 'p1'}:
            errors.append(f'{name}: phase 必须为 p0 或 p1')
        if not isinstance(spec['sources'], list) or not spec['sources']:
            errors.append(f'{name}: sources 必须至少包含一个源码路径')
        else:
            for source in spec['sources']:
                if not isinstance(source, str) or not (ROOT / source).is_file():
                    errors.append(f'{name}: source 不存在: {source}')
        if not isinstance(spec['assertions'], dict) or not spec['assertions'].get('functional'):
            errors.append(f'{name}: assertions.functional 不能为空')
        visual = spec['visual']
        if not isinstance(visual, dict) or not visual.get('rubric'):
            errors.append(f'{name}: visual.rubric 不能为空')
        runner = spec['runner']
        if not isinstance(runner, dict) or runner.get('type') not in VALID_RUNNERS:
            errors.append(f'{name}: runner.type 必须为 {sorted(VALID_RUNNERS)}')
            continue
        target = runner.get('target')
        if not isinstance(target, str) or not (ROOT / target).is_file():
            errors.append(f'{name}: runner.target 不存在: {target}')
        if not isinstance(runner.get('requires'), list):
            errors.append(f'{name}: runner.requires 必须是列表')
        checkpoints = spec.get('checkpoints')
        if checkpoints is not None and (
            not isinstance(checkpoints, list)
            or not checkpoints
            or any(not isinstance(checkpoint, str) or not checkpoint for checkpoint in checkpoints)
        ):
            errors.append(f'{name}: checkpoints 必须是非空字符串列表')
        elif checkpoints and isinstance(target, str) and (ROOT / target).is_file():
            runner_source = (ROOT / target).read_text(encoding='utf-8')
            for checkpoint in checkpoints:
                if checkpoint not in runner_source or 'takeScreenshot' not in runner_source:
                    errors.append(f'{name}: runner.target 未声明截图检查点: {checkpoint}')
        if not isinstance(spec.get('safe_to_execute'), bool):
            errors.append(f'{name}: safe_to_execute 必须是布尔值')
    return errors


def select(specs: list[tuple[Path, dict]], phase: str) -> list[tuple[Path, dict]]:
    return [(path, spec) for path, spec in specs if phase == 'all' or spec['phase'] == phase]


def print_plan(specs: list[tuple[Path, dict]]) -> None:
    for _, spec in specs:
        runner = spec['runner']
        safety = '可执行' if spec['safe_to_execute'] else '仅规划（高风险）'
        print(f"{spec['id']} [{spec['risk']}] {spec['title']} — {runner['type']}:{runner['target']} — {safety}")


def is_local_url(value: str) -> bool:
    parsed = urlsplit(value)
    return parsed.scheme in {'http', 'https', 'ws', 'wss'} and parsed.hostname in {
        '127.0.0.1', 'localhost', '0.0.0.0',
    }


def _target_urls() -> tuple[str, str]:
    api_url = (
        os.environ.get('IMBOY_API_BASE_URL_OVERRIDE')
        or os.environ.get('IMBOY_API_BASE_URL')
        or os.environ.get('API_BASE_URL')
        or ''
    )
    return api_url, os.environ.get('IMBOY_WS_URL_OVERRIDE', '')


def _flutter_env_defines() -> list[str]:
    """与 capture_integration_screenshots.py 同一套受控注入：
    仅当 IMBOY_TEST_PHONE/IMBOY_TEST_PASSWORD 显式提供时才拼 dart-define，
    同时透传 IMBOY_APP_ENV 与 *_OVERRIDE 地址（本地后端 + adb reverse 联调配方）。"""
    defines = []
    app_env = os.environ.get('IMBOY_APP_ENV')
    if app_env:
        defines.append(f'--dart-define=APP_ENV={app_env}')
    phone = os.environ.get('IMBOY_TEST_PHONE')
    password = os.environ.get('IMBOY_TEST_PASSWORD')
    if phone and password:
        defines.append(f'--dart-define=TEST_PHONE={phone}')
        defines.append(f'--dart-define=TEST_PASSWORD={password}')
    api_url, ws_url = _target_urls()
    if os.environ.get('IMBOY_API_BASE_URL_OVERRIDE'):
        defines.append(f'--dart-define=API_BASE_URL_OVERRIDE={api_url}')
    elif api_url:
        defines.append(f'--dart-define=API_BASE_URL={api_url}')
    if ws_url:
        defines.append(f'--dart-define=WS_URL_OVERRIDE={ws_url}')
    for var, define in (
        ('IMBOY_SOLIDIFIED_KEY_OVERRIDE', 'SOLIDIFIED_KEY_OVERRIDE'),
        ('IMBOY_SOLIDIFIED_KEY_IV_OVERRIDE', 'SOLIDIFIED_KEY_IV_OVERRIDE'),
    ):
        value = os.environ.get(var)
        if value:
            defines.append(f'--dart-define={define}={value}')
    return defines


def run(specs: list[tuple[Path, dict]], device: str, execute: bool, artifact_dir: Path) -> int:
    api_url, ws_url = _target_urls()
    remote_allowed = os.environ.get('IMBOY_ALLOW_REMOTE_TEST') == '1'
    env_defines = _flutter_env_defines()
    results = []
    for _, spec in specs:
        runner = spec['runner']
        status, reason, code = 'PLANNED', 'dry-run；未触发设备或网络操作', 0
        command = [runner['type']]
        if runner['type'] == 'flutter':
            command += ['test', runner['target'], '-d', device, *env_defines]
        else:
            command += ['test', '--target', runner['target'], '--device', device]
        if not spec['safe_to_execute']:
            status, reason, code = 'BLOCKED', 'case 标记为高风险，必须由专用受控测试替代', 2
        elif not device:
            status, reason, code = 'BLOCKED', '缺少 --device 真机 ID', 2
        elif (not is_local_url(api_url) or (ws_url and not is_local_url(ws_url))) and not remote_allowed:
            status, reason, code = 'BLOCKED', '远程地址需 IMBOY_ALLOW_REMOTE_TEST=1', 2
        elif execute:
            completed = subprocess.run(command, cwd=ROOT, check=False)
            code = completed.returncode
            status = 'PASS' if code == 0 else 'FAIL'
            reason = '执行完成' if code == 0 else f'退出码 {code}'
        results.append({'id': spec['id'], 'status': status, 'reason': reason, 'command': command, 'exit_code': code})
        print(f"[{status}] {spec['id']}: {reason}")

    artifact_dir.mkdir(parents=True, exist_ok=True)
    (artifact_dir / 'summary.json').write_text(json.dumps({
        'generated_at': datetime.now(timezone.utc).isoformat(),
        'api_url': api_url,
        'results': results,
    }, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    render_report(artifact_dir / 'summary.json', [], artifact_dir / 'report.md')
    return 1 if any(item['status'] == 'FAIL' for item in results) else 2 if any(item['status'] == 'BLOCKED' for item in results) else 0


def capture_case(spec: dict, device: str, output: Path, hold_ms: int, app_env: str, platform: str, execute: bool) -> int:
    """以规格为入口采集一个低风险 case 的截图；默认仅输出计划。"""
    api_url, ws_url = _target_urls()
    command = [
        sys.executable,
        'scripts/capture_integration_screenshots.py',
        '--target', spec['runner']['target'],
        '--device', device,
        '--output', str(output),
        '--platform', platform,
        '--hold-ms', str(hold_ms),
        '--app-env', app_env,
    ]
    if spec['runner']['type'] != 'flutter':
        print('BLOCKED: 当前仅支持 Flutter integration_test 截图采集。')
        return 2
    if not spec['safe_to_execute']:
        print('BLOCKED: case 标记为高风险；请先提供专用受控测试，不能采集该流程。')
        return 2
    if not device:
        print('BLOCKED: 缺少 --device 真机 ID。')
        return 2
    if (
        not is_local_url(api_url) or (ws_url and not is_local_url(ws_url))
    ) and os.environ.get('IMBOY_ALLOW_REMOTE_TEST') != '1':
        print('BLOCKED: 远程地址需 IMBOY_ALLOW_REMOTE_TEST=1。')
        return 2
    if not execute:
        print('PLANNED: dry-run；未启动真机或读取测试账号。')
        print(shlex.join(command))
        return 0
    completed = subprocess.run(command, cwd=ROOT, check=False)
    expected = spec.get('checkpoints', [])
    captured = sorted(path.name for path in output.glob('*.png'))
    missing = [checkpoint for checkpoint in expected if not any(name.endswith(f'_{checkpoint}.png') for name in captured)]
    status = 'PASS' if completed.returncode == 0 and not missing else 'FAIL' if completed.returncode else 'BLOCKED'
    manifest = {
        'case_id': spec['id'],
        'status': status,
        'runner_target': spec['runner']['target'],
        'platform': platform,
        'expected_checkpoints': expected,
        'captured_files': captured,
        'missing_checkpoints': missing,
        'test_exit_code': completed.returncode,
    }
    output.parent.mkdir(parents=True, exist_ok=True)
    (output.parent / 'capture.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    if missing:
        print(f'BLOCKED: 缺少规格声明的截图检查点: {", ".join(missing)}')
        return 2
    return completed.returncode


def write_index(specs: list[tuple[Path, dict]]) -> None:
    output = [
        '# AI 真机回归规格索引',
        '',
        '`specs/` 是 AI 真机回归的权威输入；本文件由 `python3 scripts/auto_test.py report` 生成。',
        '真实通过必须以 `reports/<run-id>/summary.json` 为证据；本索引不记录假绿。',
        '完整页面迁移队列见 [AI_COVERAGE_MATRIX.md](./AI_COVERAGE_MATRIX.md)：样板页不等于全页功能已覆盖。',
        '建议的下一批规格见 [AI_SPEC_BACKLOG.md](./AI_SPEC_BACKLOG.md)：必须先完成风险与数据前置分级。',
        '',
        '## 三期落地状态',
        '',
        '| 期次 | 交付 | 状态 |', '|---|---|---|',
        '| 一期 | JSON 规格、静态校验、视觉准则与报告生成 | 已落地 |',
        '| 二期 | 6 个 P0 页面样板、源码/测试映射、关键入口语义标识样例 | 已落地；视觉基线待真机采集 |',
        '| 三期 | 改动影响分析、dry-run/显式执行编排、可归档报告 | 已落地 |',
        '', '## 样板 case', '',
        '| Case | 风险 | 页面 | 执行器 | 截图检查点 | 视觉基线 | 高风险门禁 |', '|---|---|---|---|---|---|---|',
    ]
    for _, spec in specs:
        runner = spec['runner']
        baseline = spec['visual'].get('baseline', '待采集')
        checkpoints = '<br>'.join(f'`{item}`' for item in spec.get('checkpoints', ['待补充']))
        output.append('| `%s` | %s | %s | `%s` | %s | %s | %s |' % (
            spec['id'], spec['risk'], spec['title'], runner['target'], checkpoints, baseline,
            '是' if not spec['safe_to_execute'] else '否'))
    output += ['', '## 使用', '', '```bash', 'python3 scripts/auto_test.py validate', 'python3 scripts/auto_test.py plan --phase p0', 'python3 scripts/auto_test.py impact lib/page/wallet/transfer_send_page.dart', 'python3 scripts/auto_test.py run --phase p0 --device <真实设备ID> --dry-run', 'python3 scripts/auto_test.py capture --case CONVERSATION-LIST-001 --device <Android真实设备ID>', '```', '']
    (AUTO / 'AI_TEST_INDEX.md').write_text('\n'.join(output), encoding='utf-8')


def page_inventory() -> list[dict]:
    """读取既有页面台账，复用其源码路径而不引入第二份页面名单。"""
    pages: list[dict] = []
    for path in sorted(AUTO.glob('*/*.md')):
        if path.parent.name in {'specs', 'reports', 'baselines'}:
            continue
        rows = 0
        attention = 0
        source = ''
        for line in path.read_text(encoding='utf-8').splitlines():
            if not line.startswith('| ') or line.startswith('| 计划变化'):
                continue
            columns = [item.strip() for item in line.split('|')]
            if len(columns) < 11:
                continue
            rows += 1
            if columns[1] != '无待办':
                attention += 1
            if not source:
                source = columns[3].strip('`')
                if source.startswith('page/'):
                    source = f'lib/{source}'
        if rows:
            pages.append({'path': path, 'source': source, 'rows': rows, 'attention': attention})
    return pages


def write_coverage_matrix(specs: list[tuple[Path, dict]]) -> None:
    """生成页面级规格迁移队列；样板存在不等于页面所有功能点都已验证。"""
    by_source: dict[str, list[str]] = {}
    for _, spec in specs:
        for source in spec['sources']:
            by_source.setdefault(source, []).append(spec['id'])
    pages = page_inventory()
    covered = [page for page in pages if page['source'] in by_source]
    unmapped = [page for page in pages if not page['source'] or not (ROOT / page['source']).is_file()]
    lines = [
        '# AI 真机规格覆盖矩阵',
        '',
        '> 本矩阵从既有 `test/auto_test/<模块>/<页面>.md` 自动生成。',
        '> “已有样板”仅表示至少一个可执行规格关联到该页；**不等于该页全部功能点或全部 UI 状态已覆盖**。',
        '',
        '## 汇总',
        '',
        '| 指标 | 数量 |',
        '|---|---:|',
        f'| 页面台账总数 | {len(pages)} |',
        f'| 已有关联规格的样板页 | {len(covered)} |',
        f'| 待分级并补规格的页面 | {len(pages) - len(covered) - len(unmapped)} |',
        f'| 源码映射缺失 | {len(unmapped)} |',
        '',
        '## 页面队列',
        '',
        '| 模块 | 页面台账 | 源码 | 功能点 | AI 规格状态 | 关联 case |',
        '|---|---|---|---:|---|---|',
    ]
    for page in pages:
        source = page['source']
        cases = by_source.get(source, [])
        if cases:
            status = '已有样板（需继续细化）'
        elif not source or not (ROOT / source).is_file():
            status = '源码映射缺失'
        else:
            status = '待分级并补规格'
        relative = page['path'].relative_to(AUTO).as_posix()
        case_text = '<br>'.join(f'`{case}`' for case in cases) if cases else '—'
        lines.append('| %s | [%s](%s) | `%s` | %d | %s | %s |' % (
            page['path'].parent.name, page['path'].stem, relative, source or '—',
            page['rows'], status, case_text))
    (AUTO / 'AI_COVERAGE_MATRIX.md').write_text('\n'.join(lines) + '\n', encoding='utf-8')


def spec_backlog(specs: list[tuple[Path, dict]]) -> list[dict]:
    covered_sources = {source for _, spec in specs for source in spec['sources']}
    candidates = [
        page for page in page_inventory()
        if page['source'] not in covered_sources and page['source'] and (ROOT / page['source']).is_file()
    ]
    return sorted(candidates, key=lambda page: (
        CORE_MODULE_PRIORITY.get(page['path'].parent.name, 99),
        -page['attention'],
        -page['rows'],
        page['path'].as_posix(),
    ))


def write_spec_backlog(specs: list[tuple[Path, dict]]) -> None:
    candidates = spec_backlog(specs)
    lines = [
        '# AI 真机规格补齐队列',
        '',
        '> 本文件由 `python3 scripts/auto_test.py coverage-report` 生成。',
        '> 这是规格补齐优先级，不是风险结论、可执行许可或测试通过证据。每项仍须先定义非破坏性流程、数据前置与截图检查点。',
        '',
        '排序规则：核心用户旅程（登录→会话→聊天→联系人→群→我的→钱包）优先；同一模块内，台账有待办项和功能点更多的页面优先。',
        '',
        '| 顺序 | 建议层级 | 模块 | 页面 | 源码 | 功能点 | 台账待办 | 下一步 |',
        '|---:|---|---|---|---|---:|---:|---|',
    ]
    for index, page in enumerate(candidates, 1):
        module = page['path'].parent.name
        suggested = 'P0 候选' if module in CORE_MODULE_PRIORITY else 'P1 候选'
        relative = page['path'].relative_to(AUTO).as_posix()
        next_step = '定义只读/夹具流程、风险门禁和截图检查点'
        lines.append('| %d | %s | %s | [%s](%s) | `%s` | %d | %d | %s |' % (
            index, suggested, module, page['path'].stem, relative, page['source'],
            page['rows'], page['attention'], next_step))
    (AUTO / 'AI_SPEC_BACKLOG.md').write_text('\n'.join(lines) + '\n', encoding='utf-8')


def print_next_batch(specs: list[tuple[Path, dict]], limit: int) -> None:
    candidates = spec_backlog(specs)
    for index, page in enumerate(candidates[:limit], 1):
        module = page['path'].parent.name
        suggested = 'P0 候选' if module in CORE_MODULE_PRIORITY else 'P1 候选'
        print(f'{index}. [{suggested}] {page["source"]} — {page["rows"]} 功能点 / 台账待办 {page["attention"]}')
    if not candidates:
        print('没有待补规格页面。')


def find_case(specs: list[tuple[Path, dict]], case_id: str) -> dict:
    for _, spec in specs:
        if spec['id'] == case_id:
            return spec
    raise ValueError(f'未找到 case: {case_id}')


def visual_request(spec: dict, screenshot: Path, baseline: Path | None, device: str, theme: str, locale: str, output: Path) -> None:
    if not screenshot.is_file():
        raise ValueError(f'当前截图不存在: {screenshot}')
    if baseline is not None and not baseline.is_file():
        raise ValueError(f'视觉基线不存在: {baseline}')
    job = {
        'schema_version': 1,
        'case_id': spec['id'],
        'title': spec['title'],
        'screenshot': str(screenshot.resolve()),
        'baseline': str(baseline.resolve()) if baseline else None,
        'context': {'device': device, 'theme': theme, 'locale': locale},
        'rubric': spec['visual']['rubric'],
        'required_response_schema': {
            'result': 'PASS|FAIL|REVIEW|BLOCKED',
            'confidence': '0.0..1.0',
            'findings': '[{rule,severity,bounds:[x,y,w,h],reason}]',
        },
        'decision_rule': 'confidence < 0.85、P0/P1 finding 或基线差异未解释时必须返回 REVIEW。',
    }
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(job, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(f'✅ 已生成供应商无关的视觉评审任务: {output}')


def image_size(path: Path) -> tuple[int, int]:
    completed = subprocess.run(['magick', 'identify', '-format', '%w %h', str(path)], capture_output=True, text=True, check=True)
    match = re.fullmatch(r'(\d+)\s+(\d+)', completed.stdout.strip())
    if not match:
        raise ValueError(f'无法读取截图尺寸: {path}')
    return int(match.group(1)), int(match.group(2))


def visual_diff(baseline: Path, current: Path, diff: Path, threshold: float) -> int:
    if not baseline.is_file() or not current.is_file():
        raise ValueError('baseline 与 current 必须都是存在的图片')
    width, height = image_size(baseline)
    if image_size(current) != (width, height):
        print('BLOCKED: 截图尺寸不同，必须按同一设备/方向/缩放重新采集。')
        return 2
    diff.parent.mkdir(parents=True, exist_ok=True)
    completed = subprocess.run(['magick', 'compare', '-metric', 'AE', str(baseline), str(current), str(diff)], capture_output=True, text=True, check=False)
    metric = completed.stderr.strip()
    match = re.match(r'^(\d+)', metric)
    if match is None:
        raise ValueError(f'ImageMagick 未返回像素差异: {metric}')
    changed = int(match.group(1))
    ratio = changed / (width * height)
    status = 'PASS' if ratio <= threshold else 'REVIEW'
    print(json.dumps({'status': status, 'changed_pixels': changed, 'ratio': ratio, 'threshold': threshold, 'diff': str(diff)}, ensure_ascii=False))
    return 0 if status == 'PASS' else 2


def validate_visual_response(response: object) -> dict:
    if not isinstance(response, dict):
        raise ValueError('视觉模型响应必须是 JSON object')
    if response.get('result') not in VALID_VISUAL_RESULTS:
        raise ValueError(f"result 必须为 {sorted(VALID_VISUAL_RESULTS)}")
    confidence = response.get('confidence')
    if not isinstance(confidence, (int, float)) or not 0 <= confidence <= 1:
        raise ValueError('confidence 必须在 0..1 之间')
    findings = response.get('findings')
    if not isinstance(findings, list):
        raise ValueError('findings 必须是列表')
    for index, finding in enumerate(findings):
        if not isinstance(finding, dict) or not isinstance(finding.get('rule'), str) or not isinstance(finding.get('reason'), str):
            raise ValueError(f'findings[{index}] 必须含 rule 与 reason')
    return response


def visual_review(request: Path, output: Path, execute: bool) -> int:
    if not request.is_file():
        raise ValueError(f'视觉任务不存在: {request}')
    try:
        job = json.loads(request.read_text(encoding='utf-8'))
    except json.JSONDecodeError as exc:
        raise ValueError(f'视觉任务不是合法 JSON: {exc}') from exc
    screenshot = Path(str(job.get('screenshot', '')))
    if not screenshot.is_file():
        raise ValueError('视觉任务引用的截图不存在')
    command_text = os.environ.get('IMBOY_VISION_REVIEW_COMMAND', '')
    allowed = os.environ.get('IMBOY_ALLOW_VISION_UPLOAD') == '1'
    if not execute:
        print('PLANNED: dry-run；未调用模型。使用 --execute 且设置 IMBOY_ALLOW_VISION_UPLOAD=1 才会上传截图。')
        return 0
    if not allowed:
        print('BLOCKED: 缺少 IMBOY_ALLOW_VISION_UPLOAD=1；截图不得上传。')
        return 2
    if not command_text:
        print('BLOCKED: 缺少 IMBOY_VISION_REVIEW_COMMAND 私有模型适配命令。')
        return 2
    command = shlex.split(command_text) + [str(request.resolve())]
    completed = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, check=False)
    if completed.returncode != 0:
        raise ValueError(f'视觉模型适配命令失败（退出码 {completed.returncode}）: {completed.stderr.strip()[:500]}')
    try:
        response = validate_visual_response(json.loads(completed.stdout))
    except json.JSONDecodeError as exc:
        raise ValueError(f'视觉模型输出不是合法 JSON: {exc}') from exc
    if not job.get('baseline') and response['result'] == 'PASS':
        response = dict(response)
        response['result'] = 'REVIEW'
        response['findings'] = list(response['findings']) + [{
            'rule': 'approved_baseline',
            'severity': 'P1',
            'bounds': [0, 0, 0, 0],
            'reason': '尚未登记批准基线；单次视觉判断不能形成 PASS 证据。',
        }]
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps({'request': str(request), 'response': response}, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(f"[{response['result']}] 已保存视觉评审结果: {output}")
    return 0 if response['result'] == 'PASS' else 1 if response['result'] == 'FAIL' else 2


def baseline_register(case_id: str, screenshot: Path, device: str, theme: str, locale: str, replace: bool, destination: Path | None) -> None:
    if not screenshot.is_file():
        raise ValueError(f'截图不存在: {screenshot}')
    suffix = screenshot.suffix.lower()
    if suffix not in {'.png', '.jpg', '.jpeg', '.webp'}:
        raise ValueError('基线截图必须是 PNG/JPEG/WebP')
    safe_device = re.sub(r'[^A-Za-z0-9_.-]+', '_', device)
    safe_locale = re.sub(r'[^A-Za-z0-9_.-]+', '_', locale)
    target = destination or BASELINES / case_id / f'{safe_device}-{theme}-{safe_locale}{suffix}'
    if target.exists() and not replace:
        raise ValueError(f'基线已存在: {target}；确认视觉变更后才可加 --replace 覆盖。')
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(screenshot, target)
    metadata = target.with_suffix(target.suffix + '.json')
    metadata.write_text(json.dumps({
        'case_id': case_id,
        'device': device,
        'theme': theme,
        'locale': locale,
        'source_sha256': hashlib.sha256(screenshot.read_bytes()).hexdigest(),
    }, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(f'✅ 已登记视觉基线: {target}')


def render_report(summary: Path, visual_reports: list[Path], output: Path) -> None:
    """把机器产物渲染为人工可读报告；不把 dry-run 或视觉候选误写成通过。"""
    if not summary.is_file():
        raise ValueError(f'执行摘要不存在: {summary}')
    try:
        run_data = json.loads(summary.read_text(encoding='utf-8'))
    except json.JSONDecodeError as exc:
        raise ValueError(f'执行摘要不是合法 JSON: {exc}') from exc
    results = run_data.get('results')
    if not isinstance(results, list):
        raise ValueError('执行摘要缺少 results 列表')
    visuals: list[dict] = []
    for path in visual_reports:
        if not path.is_file():
            raise ValueError(f'视觉报告不存在: {path}')
        try:
            data = json.loads(path.read_text(encoding='utf-8'))
        except json.JSONDecodeError as exc:
            raise ValueError(f'视觉报告不是合法 JSON: {path}: {exc}') from exc
        response = validate_visual_response(data.get('response', data))
        approved_baseline = False
        request_path = data.get('request')
        if isinstance(request_path, str) and Path(request_path).is_file():
            try:
                request_data = json.loads(Path(request_path).read_text(encoding='utf-8'))
                approved_baseline = bool(request_data.get('baseline'))
            except json.JSONDecodeError:
                approved_baseline = False
        if response['result'] == 'PASS' and not approved_baseline:
            response = dict(response)
            response['result'] = 'REVIEW'
            response['findings'] = list(response['findings']) + [{
                'rule': 'approved_baseline',
                'severity': 'P1',
                'bounds': [0, 0, 0, 0],
                'reason': '报告无法确认已批准基线；视觉 PASS 已降级为 REVIEW。',
            }]
        visuals.append({'path': path, 'response': response, 'approved_baseline': approved_baseline})
    run_statuses = {str(item.get('status', 'UNKNOWN')) for item in results if isinstance(item, dict)}
    visual_statuses = {item['response']['result'] for item in visuals}
    if 'FAIL' in run_statuses or 'FAIL' in visual_statuses:
        verdict = 'FAIL'
    elif 'BLOCKED' in run_statuses or 'BLOCKED' in visual_statuses:
        verdict = 'BLOCKED'
    elif 'PLANNED' in run_statuses or not visuals or 'REVIEW' in visual_statuses:
        verdict = 'PARTIAL'
    elif run_statuses == {'PASS'} and visual_statuses == {'PASS'}:
        verdict = 'PASS'
    else:
        verdict = 'PARTIAL'
    lines = [
        '# AI 真机回归报告',
        '',
        f'- 总结论：`{verdict}`',
        f'- 执行摘要：`{summary}`',
        f'- 生成时间：`{datetime.now(timezone.utc).isoformat()}`',
        '',
        '> 证据边界：仅当功能执行与已批准基线的视觉审查均为 PASS 时，本文才会给出 PASS。PLANNED、BLOCKED、缺少视觉报告或 REVIEW 都不是通过。',
        '',
        '## 功能执行',
        '',
        '| Case | 状态 | 原因 |',
        '|---|---|---|',
    ]
    for item in results:
        if not isinstance(item, dict):
            continue
        lines.append('| `%s` | `%s` | %s |' % (
            item.get('id', 'UNKNOWN'), item.get('status', 'UNKNOWN'), str(item.get('reason', '')).replace('|', '\\|')))
    lines += ['', '## 视觉审查', '']
    if not visuals:
        lines.append('未提供视觉审查结果，因此不能形成真机 UI/UX 通过结论。')
    else:
        lines += ['| 文件 | 批准基线 | 结论 | 置信度 | 问题数 |', '|---|---|---|---:|---:|']
        for item in visuals:
            response = item['response']
            lines.append('| `%s` | %s | `%s` | %.2f | %d |' % (
                item['path'], '是' if item['approved_baseline'] else '否',
                response['result'], response['confidence'], len(response['findings'])))
        for item in visuals:
            response = item['response']
            if not response['findings']:
                continue
            lines += ['', f"### {item['path'].name} 发现", '']
            for finding in response['findings']:
                lines.append('- `%s` / `%s`：%s' % (
                    finding.get('severity', 'UNKNOWN'), finding['rule'], finding['reason']))
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text('\n'.join(lines) + '\n', encoding='utf-8')
    print(f'✅ 已生成可读回归报告: {output}（{verdict}）')


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    for command in ('plan', 'report', 'run'):
        p = sub.add_parser(command)
        p.add_argument('--phase', choices=('p0', 'p1', 'all'), default='all')
        if command == 'run':
            p.add_argument('--device', default='')
            p.add_argument('--dry-run', action='store_true')
            p.add_argument('--execute', action='store_true')
            p.add_argument('--artifact-dir', default='')
    capture = sub.add_parser('capture')
    capture.add_argument('--case', required=True)
    capture.add_argument('--device', default='')
    capture.add_argument('--output', default='')
    capture.add_argument('--hold-ms', type=int, default=2500)
    capture.add_argument('--app-env', default=os.environ.get('IMBOY_APP_ENV', 'local_office'))
    capture.add_argument('--platform', choices=('android', 'ios'), default='android')
    capture.add_argument('--execute', action='store_true')
    impact = sub.add_parser('impact')
    impact.add_argument('changed', nargs='+')
    visual_request_parser = sub.add_parser('visual-request')
    visual_request_parser.add_argument('--case', required=True)
    visual_request_parser.add_argument('--screenshot', required=True)
    visual_request_parser.add_argument('--baseline')
    visual_request_parser.add_argument('--device', required=True)
    visual_request_parser.add_argument('--theme', choices=('light', 'dark'), required=True)
    visual_request_parser.add_argument('--locale', default='zh-CN')
    visual_request_parser.add_argument('--output', required=True)
    visual_diff_parser = sub.add_parser('visual-diff')
    visual_diff_parser.add_argument('--baseline', required=True)
    visual_diff_parser.add_argument('--current', required=True)
    visual_diff_parser.add_argument('--diff', required=True)
    visual_diff_parser.add_argument('--threshold', type=float, default=0.002)
    visual_review_parser = sub.add_parser('visual-review')
    visual_review_parser.add_argument('--request', required=True)
    visual_review_parser.add_argument('--output', required=True)
    visual_review_parser.add_argument('--execute', action='store_true')
    baseline_register_parser = sub.add_parser('baseline-register')
    baseline_register_parser.add_argument('--case', required=True)
    baseline_register_parser.add_argument('--screenshot', required=True)
    baseline_register_parser.add_argument('--device', required=True)
    baseline_register_parser.add_argument('--theme', choices=('light', 'dark'), required=True)
    baseline_register_parser.add_argument('--locale', default='zh-CN')
    baseline_register_parser.add_argument('--replace', action='store_true')
    baseline_register_parser.add_argument('--destination')
    render_report_parser = sub.add_parser('render-report')
    render_report_parser.add_argument('--summary', required=True)
    render_report_parser.add_argument('--visual', action='append', default=[])
    render_report_parser.add_argument('--output', required=True)
    next_batch_parser = sub.add_parser('next-batch')
    next_batch_parser.add_argument('--limit', type=int, default=12)
    sub.add_parser('coverage-report')
    sub.add_parser('validate')
    args = parser.parse_args()
    try:
        specs = load_specs()
    except ValueError as exc:
        print(f'❌ {exc}', file=sys.stderr)
        return 1
    errors = validate(specs)
    if errors:
        print('\n'.join(f'❌ {error}' for error in errors), file=sys.stderr)
        return 1
    if args.command == 'validate':
        print(f'✅ {len(specs)} 个 AI 真机规格校验通过')
    elif args.command == 'plan':
        print_plan(select(specs, args.phase))
    elif args.command == 'impact':
        changed = {Path(path).as_posix() for path in args.changed}
        affected = [(path, spec) for path, spec in specs if changed.intersection(spec['sources'] + spec.get('dependencies', []))]
        print_plan(affected)
        if not affected:
            print('未命中样板规格；该改动仍可能需要人工判断。')
    elif args.command == 'capture':
        if args.hold_ms < 1000:
            parser.error('--hold-ms 至少 1000，保证 ADB 有抓屏窗口')
        output = Path(args.output) if args.output else REPORTS / datetime.now().strftime('%Y%m%d-%H%M%S') / 'screenshots'
        try:
            return capture_case(find_case(specs, args.case), args.device, output, args.hold_ms, args.app_env, args.platform, args.execute)
        except ValueError as exc:
            print(f'❌ {exc}', file=sys.stderr)
            return 1
    elif args.command == 'report':
        write_index(select(specs, args.phase))
        write_coverage_matrix(specs)
        write_spec_backlog(specs)
        print('✅ 已生成 test/auto_test/AI_TEST_INDEX.md')
        print('✅ 已生成 test/auto_test/AI_COVERAGE_MATRIX.md')
        print('✅ 已生成 test/auto_test/AI_SPEC_BACKLOG.md')
    elif args.command == 'coverage-report':
        write_coverage_matrix(specs)
        write_spec_backlog(specs)
        print('✅ 已生成 test/auto_test/AI_COVERAGE_MATRIX.md')
        print('✅ 已生成 test/auto_test/AI_SPEC_BACKLOG.md')
    elif args.command == 'next-batch':
        if args.limit < 1:
            parser.error('--limit 必须大于 0')
        print_next_batch(specs, args.limit)
    elif args.command == 'visual-request':
        try:
            visual_request(
                find_case(specs, args.case),
                Path(args.screenshot),
                Path(args.baseline) if args.baseline else None,
                args.device,
                args.theme,
                args.locale,
                Path(args.output),
            )
        except ValueError as exc:
            print(f'❌ {exc}', file=sys.stderr)
            return 1
    elif args.command == 'visual-diff':
        if not 0 <= args.threshold <= 1:
            parser.error('--threshold 必须在 0..1 之间')
        try:
            return visual_diff(Path(args.baseline), Path(args.current), Path(args.diff), args.threshold)
        except (ValueError, subprocess.CalledProcessError) as exc:
            print(f'❌ {exc}', file=sys.stderr)
            return 1
    elif args.command == 'visual-review':
        try:
            return visual_review(Path(args.request), Path(args.output), args.execute)
        except ValueError as exc:
            print(f'❌ {exc}', file=sys.stderr)
            return 1
    elif args.command == 'baseline-register':
        try:
            find_case(specs, args.case)
            baseline_register(
                args.case, Path(args.screenshot), args.device, args.theme,
                args.locale, args.replace,
                Path(args.destination) if args.destination else None,
            )
        except ValueError as exc:
            print(f'❌ {exc}', file=sys.stderr)
            return 1
    elif args.command == 'render-report':
        try:
            render_report(Path(args.summary), [Path(path) for path in args.visual], Path(args.output))
        except ValueError as exc:
            print(f'❌ {exc}', file=sys.stderr)
            return 1
    else:
        if args.execute and args.dry_run:
            parser.error('--execute 与 --dry-run 不能同时使用')
        artifact_dir = Path(args.artifact_dir) if args.artifact_dir else REPORTS / datetime.now().strftime('%Y%m%d-%H%M%S')
        return run(select(specs, args.phase), args.device, args.execute, artifact_dir)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())

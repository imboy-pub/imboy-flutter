"""Read-only E2EE ledger binding gate; synthetic records never certify safety."""
import csv
import io
import re
from pathlib import Path
from typing import Any, List

from auto_test_lib import acceptance, acceptance_contract, acceptance_versions

_IDS = {'AC-%02d' % number for number in range(36)}
_CARD_GROUPS = ((0, 1, 2), (3, 4), (5, 6), (7, 8), (9, 10), (11, 12),
                (13, 14), (15, 16), (17, 18), (19, 20), (21,), (22, 23),
                (24, 25, 26), (27, 28), (29,), (30, 31), (32, 33), (34, 35))
_CARDS = {'AC-%02d' % number: 'C%02d' % card
          for card, numbers in enumerate(_CARD_GROUPS) for number in numbers}
_FIELDS = ('id', 'card', 'status', 'plan_sha', 'backend_sha', 'app_sha',
           'other_repo_sha', 'config_hash', 'command_id', 'command', 'exit_code',
           'test_count', 'oracle', 'evidence_path', 'evidence_sha256', 'reviewer',
           'completed_at')


def _load_rows(root: Path, descriptor: Any):
    if not isinstance(descriptor, dict):
        return None, ['UPSTREAM_LEDGER_DESCRIPTOR_INVALID']
    errors = acceptance.validate_artifact_files(root, [descriptor])
    if errors:
        return None, errors
    try:
        raw = acceptance._read_verified_artifact(root, descriptor).decode('utf-8')
        reader = csv.DictReader(io.StringIO(raw), delimiter='\t', strict=True)
        if reader.fieldnames != list(_FIELDS):
            return None, ['UPSTREAM_LEDGER_HEADER_INVALID']
        rows = list(reader)
        if any(None in row or any(value is None for value in row.values()) for row in rows):
            return None, ['UPSTREAM_LEDGER_ROW_INVALID']
        ids = [row['id'] for row in rows]
        if len(ids) != 36 or set(ids) != _IDS:
            return None, ['UPSTREAM_ACCEPTANCE_SET_MISMATCH']
        return rows, []
    except (OSError, ValueError, UnicodeError, csv.Error):
        return None, ['UPSTREAM_LEDGER_UNREADABLE']


def _bindings(frozen: Any):
    try:
        if not isinstance(frozen, dict):
            return None
        expected = {'plan_sha': frozen['version_inputs']['e2ee_plan']['sha256'],
                    'backend_sha': frozen['candidates']['imboy']['head'],
                    'app_sha': frozen['candidates']['imboyapp']['head']}
        for field, value in expected.items():
            size = 64 if field == 'plan_sha' else 40
            if (not isinstance(value, str) or not re.fullmatch('[0-9a-f]{%d}' % size, value)
                    or value == '0' * size):
                return None
        return expected
    except (KeyError, TypeError):
        return None


def _pass_errors(root: Path, row: dict, expected: dict) -> List[str]:
    errors = []
    if row['card'] != _CARDS[row['id']]:
        errors.append('UPSTREAM_ACCEPTANCE_CARD_MISMATCH:' + row['id'])
    if row['status'] != 'PASS':
        return errors + ['UPSTREAM_REQUIRED_NOT_PASS:' + row['id']]
    if any(row[field] != value for field, value in expected.items()):
        errors.append('UPSTREAM_PASS_BINDING_MISMATCH:' + row['id'])
    if row['exit_code'] != '0' or not re.fullmatch('[1-9][0-9]{0,11}', row['test_count']):
        errors.append('UPSTREAM_PASS_EXECUTION_INVALID:' + row['id'])
    if not re.fullmatch('[0-9a-f]{64}', row['config_hash']):
        errors.append('UPSTREAM_PASS_CONFIG_INVALID:' + row['id'])
    if any(not row[field].strip() or row[field] == '-' for field in
           ('card', 'command_id', 'command', 'oracle', 'reviewer', 'completed_at')):
        errors.append('UPSTREAM_PASS_PROVENANCE_MISSING:' + row['id'])
    errors.extend(acceptance.validate_artifact_files(root, [
        {'path': row['evidence_path'], 'sha256': row['evidence_sha256']}]))
    return errors


def audit_upstream_ledger(root: Path, frozen: Any, observed: Any) -> List[str]:
    """Check the full 36-ID E2EE qualification, not a limited product profile.

    Descriptor comes from the independent frozen index. This proves recorded
    bindings only; authentic commands/oracles and independent review remain
    required. Never upgrade partial upstream status or issue product PASS.
    """
    expected = _bindings(frozen)
    if expected is None:
        return ['UPSTREAM_BINDINGS_INVALID']
    descriptor = frozen.get('upstream_acceptance_artifact')
    if descriptor != observed or not isinstance(descriptor, dict):
        return ['UPSTREAM_LEDGER_BINDING_CHANGED']
    rows, errors = _load_rows(root, descriptor)
    if errors:
        return errors
    for row in rows:
        errors.extend(_pass_errors(root, row, expected))
    return errors


def register_cli(subparsers: Any) -> None:
    parser = subparsers.add_parser('acceptance-upstream-preflight',
        help='只读核对完整E2EE上游账本；不替代真实安全验收')
    for option in ('evidence-root', 'frozen-input', 'frozen-sha256',
                   'acceptance-report', 'report-sha256'):
        parser.add_argument('--' + option, required=True)


def run_cli(args: Any, workspace: Path) -> int:
    import json
    root = Path(args.evidence_root)
    result = {'scope': 'UPSTREAM_FULL_LEDGER_INPUTS_ONLY', 'product_pass': False,
              'errors': [], 'remaining_gates': ['authentic business/security oracles',
                  'independent reviews, devices, final qualification']}
    frozen, errors = acceptance.load_frozen_json(root,
        {'path': args.frozen_input, 'sha256': args.frozen_sha256})
    result['errors'].extend(errors)
    report, errors = acceptance.load_frozen_json(root,
        {'path': args.acceptance_report, 'sha256': args.report_sha256})
    result['errors'].extend(errors)
    if not result['errors'] and isinstance(frozen, dict) and isinstance(report, dict):
        result['errors'].extend(acceptance_contract.audit_candidate_repositories(
            {name: workspace / name for name in ('imboy', 'imboyapp', 'imboyadmin')},
            frozen.get('candidates'), report.get('candidates')))
        result['errors'].extend(acceptance_versions.audit_version_inputs(
            root, frozen.get('version_inputs'), report.get('version_inputs')))
        result['errors'].extend(audit_upstream_ledger(
            root, frozen, report.get('upstream_acceptance_artifact')))
        from auto_test_lib import acceptance_upstream_commands
        result['errors'].extend(acceptance_upstream_commands.audit_upstream_command_links(
            root, frozen, report.get('upstream_commands_artifact')))
    elif not result['errors']:
        result['errors'].append('UPSTREAM_INPUT_SCHEMA_INVALID')
    print(json.dumps(result, ensure_ascii=False, sort_keys=True))
    return 2 if result['errors'] else 0

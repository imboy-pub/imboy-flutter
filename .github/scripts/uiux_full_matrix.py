"""Partition a frozen full/offline plan without changing execution identity."""
from __future__ import annotations

import copy
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'scripts'))
from auto_test_lib.execution_runner import host_worker_matrix  # noqa: E402


def matrix(full, offline):
    for field in ('commit', 'source_fingerprint', 'gates'):
        if full.get(field) != offline.get(field):
            raise ValueError(f'PLAN_BINDING_MISMATCH:{field}')
    if full.get('full_regression') is not True or offline.get('scope') != 'scoped':
        raise ValueError('PLAN_SCOPE_INVALID')
    full_selected = [row for row in full['instances'] if row.get('selected')]
    full_rows = {row['id']: row for row in full_selected}
    if len(full_rows) != len(full_selected):
        raise ValueError('DUPLICATE_FULL_PLAN')
    selected = [row for row in offline['instances'] if row.get('selected')]
    if not selected or len(selected) != len({row['id'] for row in selected}):
        raise ValueError('EMPTY_OR_DUPLICATE_OFFLINE_PLAN')
    if any(full_rows.get(row['id']) != row for row in selected):
        raise ValueError('OFFLINE_NOT_IDENTICAL_TO_FULL')
    platforms = {'linux', 'macos', 'web'}
    suites = {'unit', 'widget', 'component', 'sqlite-ffi', 'crypto-ffi', 'tooling', 'route-smoke'}
    expected = {row['id'] for row in full_selected
                if row['platform'] in platforms and row['suite'] in suites}
    if {row['id'] for row in selected} != expected:
        raise ValueError('OFFLINE_SELECTION_INCOMPLETE')
    workers = []
    for product in sorted({row['product_profile'] for row in selected}):
        product_plan = copy.deepcopy(offline)
        for row in product_plan['instances']:
            row['selected'] = bool(row.get('selected') and row['product_profile'] == product)
        for worker in host_worker_matrix(product_plan)['include']:
            workers.append({key: value for key, value in worker.items() if key != 'os'} | {'product': product})
    keys = [(w['platform'], w['suite'], w['product']) for w in workers]
    if len(keys) != len(set(keys)):
        raise ValueError('DUPLICATE_WORKER')
    for row in selected:
        if keys.count((row['platform'], row['suite'], row['product_profile'])) != 1:
            raise ValueError('INSTANCE_PARTITION_INCOMPLETE')
    return {'include': workers}


def main():
    if len(sys.argv) != 3:
        raise SystemExit('usage: uiux_full_matrix.py FULL_PLAN OFFLINE_PLAN')
    full, offline = (json.loads(Path(path).read_text()) for path in sys.argv[1:])
    print(json.dumps(matrix(full, offline), separators=(',', ':')))


if __name__ == '__main__':
    main()

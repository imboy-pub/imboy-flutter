#!/usr/bin/env python3
"""Step 15 finalizer: build structured report data and render the single
user-facing test-report.html via the accepted Step 3 renderer."""
from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / 'scripts'))
from auto_test_lib.report import render_test_report_html  # noqa: E402

RR = ROOT / 'test/auto_test/reports/hardening-20260918T151153Z'


def jload(rel: str, default=None):
    p = RR / rel
    if not p.is_file():
        return default if default is not None else {}
    return json.loads(p.read_text(encoding='utf-8'))


def main() -> int:
    summary = jload('results/summary.json')
    step15_head = '3efd68768a9a9a70371c05c4192a72fb776d3fcf'
    commits = {
        1: '5319294c', 2: '98ce2b73', 3: 'a58cc163', 4: '9ff1e6d1', 5: 'efbffb3b',
        6: 'd49e8476', 7: 'f8cc55fd', 8: 'NO_COMMIT_READ_ONLY', 9: '5c54f71d',
        10: 'NO_COMMIT_READ_ONLY', 11: 'NO_COMMIT_READ_ONLY', 12: 'NO_COMMIT_READ_ONLY',
        13: 'NO_COMMIT_READ_ONLY', 14: '84d7d592', 15: step15_head[:8],
    }
    steps_table = [
        {'step': '1 基线+夹具', 'verdict': 'PASS', 'commit': commits[1], 'evidence': 'steps/step1.json'},
        {'step': '2 capture/target config', 'verdict': 'PASS', 'commit': commits[2], 'evidence': 'steps/step2.json'},
        {'step': '3 parser/renderer', 'verdict': 'PASS', 'commit': commits[3], 'evidence': 'steps/step3.json'},
        {'step': '4 requirements/preflight', 'verdict': 'PASS', 'commit': commits[4], 'evidence': 'steps/step4.json'},
        {'step': '5 catalog/impact/CLI', 'verdict': 'PASS', 'commit': commits[5], 'evidence': 'steps/step5.json'},
        {'step': '6 state/evidence/cache', 'verdict': 'PASS', 'commit': commits[6], 'evidence': 'steps/step6.json'},
        {'step': '7 unified gate/CI', 'verdict': 'PASS', 'commit': commits[7], 'evidence': 'steps/step7.json'},
        {'step': '8 framework closeout', 'verdict': 'PASS', 'commit': commits[8], 'evidence': 'steps/step8.json'},
        {'step': '9 inventory/domain/fixture', 'verdict': 'PASS', 'commit': commits[9], 'evidence': 'steps/step9.json'},
        {'step': '10 E2EE gates', 'verdict': 'PARTIAL', 'commit': commits[10], 'evidence': 'steps/step10_app.json + steps/step10_backend_e2ee_verify.log'},
        {'step': '11 E2EE device paths', 'verdict': 'BLOCKED', 'commit': commits[11], 'evidence': 'steps/step11.json'},
        {'step': '12 enterprise gates', 'verdict': 'PARTIAL', 'commit': commits[12], 'evidence': 'steps/step12.json'},
        {'step': '13 WS/Group device', 'verdict': 'BLOCKED', 'commit': commits[13], 'evidence': 'steps/step13.json'},
        {'step': '14 pages traversal', 'verdict': 'BLOCKED', 'commit': commits[14], 'evidence': 'steps/step14.json + results/summary.json'},
        {'step': '15 final closeout', 'verdict': 'PASS(framework)/BLOCKED(device domains)', 'commit': commits[15], 'evidence': 'steps/step15_gate_final.txt'},
    ]
    acceptance_rows = [
        ('ATF-001/002/003', 'PASS', 'baseline manifest + 78 fixture events parse+scan clean'),
        ('ATF-101/102/103', 'PASS', 'capture NameError fixed; shared final-config; remote/half-cred/missing-device fail-closed before spawn (14 tests)'),
        ('ATF-201/202/203/204', 'PASS', 'machine-event verdicts, retry taxonomy, unique targets, deterministic sanitized HTML renderer (44 tests)'),
        ('ATF-301/302/303', 'PASS', 'requirement/risk enums, env cannot relax, 25 specs migrated without widening (27 tests)'),
        ('ATF-401/402/403', 'PASS', 'catalog 130 targets/173 pages bidirectional, drift fail-closed, byte-stable regen (12 tests)'),
        ('ATF-501/502/503', 'PASS', 'fresh-clone full plan, HEAD-bound cache + B/C-only rebind, schema/lease fail-closed (66 tests)'),
        ('ATF-601/602/603', 'PASS', 'unified gate double-run 0/0 no diff, 5 negative injections fail, CI same entry (7 tests)'),
        ('ATF-701/702/703', 'PASS', 'evidence complete, owned-path commits only, verdict vocabulary enforced'),
        ('DOM-001/002/003', 'PASS', '173 pages/1872 functions/44 capabilities/13 features mapped; 6-account fixture contract (38 tests)'),
        ('E2EE-001', 'PARTIAL', 'App 842 passed 0 fail (56 credential-gated skips); backend 424/425 - 1 fixture-defect FAIL (c2g stage mock gap, repo read-only)'),
        ('E2EE-002', 'PASS', 'fail-closed negatives evidenced across 8 capabilities (surv step10_failclosed_survey.json)'),
        ('E2EE-003', 'PASS', 'no skip/TODO promoted; blocked kept explicit'),
        ('E2EE-101/102', 'BLOCKED', 'BLOCKED_PRODUCT_DRIFT (interop scripts gate on full-selected manifest, regen unauthorized) + BLOCKED_BACKEND_IDENTITY (D2=false)'),
        ('E2EE-103', 'PASS', 'no keys/credentials/contacts in evidence; device ids truncated'),
        ('ENT-001', 'PASS', 'App 139 + backend org/ent 99 & cs 201 passed; DB modules cancelled=BLOCKED_BACKEND_MIGRATION_DIRTY'),
        ('ENT-002', 'PASS_WITH_GAPS', 'owner invariant/default workspace/member lifecycle asserted; DB-facing enterprise message/asset BLOCKED'),
        ('ENT-003', 'PASS', 'cross-org cache isolation, degraded old-session, archived, 403/409 mappings fail closed'),
        ('WG-001/002/003', 'BLOCKED', 'device+D2 preconditions unmet; B-level alternative: workspace 162 + group 500 App contract passed'),
        ('FULL-001', 'PASS', '1872 stable function ids, bidirectional diff 0'),
        ('FULL-002', 'BLOCKED', '0/3744 device executions: android gradle (flutter_vodozemac config + local proxy down), macos pod (flutter_sound no podspec)'),
        ('FULL-003', 'PASS', 'counts verified 3744=0+0+0+3744, PLANNED/UNKNOWN=0, shard runner resumable'),
        ('CPM-001/002/003', 'BLOCKED', 'device path + D2=false; B-level App batches channel/moment/project all green (3x exit 0)'),
        ('FINAL-001..004', 'PASS(framework)', 'double gate 0/0 at final HEAD 3efd6876, no new diff, single HTML, deterministic'),
    ]
    domains = [
        ('Framework (Steps 1-8)', 'PASS', 'gate double-run green; 171 tooling tests; fail-closed everywhere'),
        ('All Pages / Functions', 'BLOCKED', '1872 functions x 2 platforms discovered; device execution 0 (build env); B-level 1643+contract passed as correlated evidence'),
        ('E2EE', 'PARTIAL', 'B: App 842 + backend 424/425 passed, 8 fail-closed negative families; A: BLOCKED (drift+backend); 1 backend fixture FAIL recorded'),
        ('Enterprise / Organization', 'PARTIAL', 'B: App 139 + backend 300 passed + both feature matrices PASS (3-tier, tree-hash restored); DB modules BLOCKED (migration_dirty)'),
        ('Workspace / Group', 'PARTIAL', 'B: 662 App contract + 13 backend relation tests passed; A multi-role BLOCKED'),
        ('Channel', 'BLOCKED', 'A-level closed loop BLOCKED; B-level channel batch green (8 files)'),
        ('Moment', 'BLOCKED', 'A-level BLOCKED; B-level moment batch green (6 files/dirs)'),
        ('Project', 'BLOCKED', 'A-level BLOCKED; B-level project batch green (2 file groups)'),
    ]
    decisions = [
        'D-A Regenerate product feature routes (unblocks E2EE interop + profile-dependent targets): needs explicit user approval (plan forbids auto-regen)',
        'D-B Start local backend node + repair imboy_v1 migration_dirty (unblocks DB eunit modules + D2 fixture writes): H2_BACKEND_MUTATION unauthorized',
        'D-C Provide dedicated fixture accounts (6-role org A/B set): credentials never requested from user by policy',
        'D-D flutter_vodozemac android gradle plugin config (product build fix) blocks ALL android device tests',
        'D-E flutter_sound macos podspec missing blocks ALL macos device tests (macos/* is a protected zone)',
        'D-F local proxy 127.0.0.1:7897 (gradle.properties) was down during run; retry after proxy is up',
        'D-G backend e2ee fixture defect: e2ee_offline_sender_did_tests stage_group_arity mock gap (1/425) - backend repo read-only this run',
    ]
    counts = summary.get('counts', summary)
    data = {
        'run_id': 'hardening-20260918T151153Z',
        'overall_verdict': 'PARTIAL',
        'overall_rationale': 'Framework hardening (Steps 1-9, 15) fully PASS with a green double-run gate; device-level A evidence for E2EE/Workspace/Group/pages/Channel/Moment/Project is BLOCKED by product build environment + missing local backend + route drift - all recorded with reproducible reasons, none silently skipped.',
        'baseline': {
            'app_head_start': '0a167e9df3f512a55c78da77fb53b92dd6054969',
            'app_head_final': step15_head,
            'backend_head': '196d9359869034f13ac895665a842e325dfa9b8b (unchanged, read-only)',
            'startup_dirty': 'both repos clean at session start (0 dirty/untracked)',
            'app_commits_this_run': '11 (5319294c..3efd6876, precise pathspecs, no push)',
        },
        'environment': {
            'devices_seen': 'android real XWE6R19916004085 (redacted in artifacts), macos desktop; iPhone wireless untouched (H1)',
            'backend_reachable': 'false (9800/9700 down; local PG up but migration_dirty)',
            'd2_isolated_fixture_write': 'false',
            'route_drift': 'generated_product_feature_routes.dart stale vs backend manifest (BLOCKED_PRODUCT_DRIFT)',
        },
        'steps': steps_table,
        'acceptance': [{'id': a, 'verdict': b, 'evidence': c} for a, b, c in acceptance_rows],
        'domains': [{'domain': d, 'verdict': v, 'summary': s} for d, v, s in domains],
        'counts': {
            'functions_discovered': counts.get('discovered_functions'),
            'function_platform_pairs': counts.get('function_platform_pairs'),
            'device_pass': counts.get('pass', 0), 'device_fail': counts.get('fail', 0),
            'device_flaky': counts.get('flaky', 0), 'device_blocked': counts.get('blocked'),
            'excluded': counts.get('excluded', 0), 'planned_unknown': 0, 'new_entry': 0,
            'app_b_level_batches': '7 batches / 153 files / 1643 passed / 0 failed / 56 credential-gated skips',
            'app_cmp_batches': 'channel+moment+project 3 batches exit 0',
            'backend_e2ee': '424 passed / 1 failed (fixture defect) / 0 skipped',
            'backend_scoped_eunit': 'org+ent 99, cs 201 passed; 2 DB modules cancelled (migration_dirty)',
            'backend_feature_matrices': 'enterprise 3-tier PASS; customer-service 2-tier PASS (tree hash restored)',
            'tooling_tests': '171 across 12 files, all green at final HEAD',
        },
        'fail_items': [
            {'item': 'backend e2ee_offline_sender_did_tests:stage_group_arity_omits_sender_did_test', 'reason': 'c2g stage mock incomplete -> persistent_term badarg; single-run reproduces; backend repo read-only'},
            {'item': 'macos device build', 'reason': 'flutter_sound lacks macos podspec; macos/* protected zone'},
            {'item': 'android device build', 'reason': 'flutter_vodozemac gradle config (implementation not found / kotlin-android needs AGP) + local proxy 7897 down during first attempt'},
        ],
        'flaky_items': [],
        'blocked_items': [
            {'scope': 'E2EE device interop', 'reason': 'BLOCKED_PRODUCT_DRIFT + BLOCKED_BACKEND_IDENTITY'},
            {'scope': 'WS/Group multi-role device', 'reason': 'BLOCKED_BACKEND_IDENTITY + credentials + drift'},
            {'scope': 'All-pages device traversal', 'reason': 'android BLOCKED_DEVICE_BUILD_GRADLE x1872; macos BLOCKED_DEVICE_BUILD_POD_MISSING x1872'},
            {'scope': 'Channel/Moment/Project closed loops', 'reason': 'device + D2=false'},
            {'scope': 'backend DB eunit (2 modules)', 'reason': 'BLOCKED_BACKEND_MIGRATION_DIRTY'},
        ],
        'decisions_needed': decisions,
        'evidence_index': [
            'steps/step1.json .. step15 json', 'results/summary.json', 'results/function_platform_results.jsonl',
            'shards/{macos_probe,android_probe,android_probe2}/', 'steps/step10_12_app/*.log',
            'gate summary: test/auto_test/reports/gate/gate_summary.json',
        ],
    }
    out = RR / 'test-report.html'
    blob = render_test_report_html(data, out)
    # determinism double-render check
    blob2 = render_test_report_html(data, out)
    assert blob == blob2, 'renderer not deterministic'
    print(f'rendered {out} ({len(blob)} bytes, deterministic)')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())

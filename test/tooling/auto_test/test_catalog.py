"""Step 5 tooling tests: catalog determinism, set-diff drift, impact mapping.

ATF-401 全部 integration test 文件 catalogued/excluded；数量或集合漂移失败。
ATF-402 lib/page + 模块化页面 + route target 全部 mapped/excluded；缺失与反向悬空为 0。
ATF-403 连续生成两次字节一致；catalog --check 通过。
"""
from __future__ import annotations

import copy
import json
import subprocess
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / 'scripts'))

from auto_test_lib import discovery  # noqa: E402


class TestCatalogGeneration(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.catalog = discovery.generate_catalog(ROOT)

    def test_billing_route_component_matches_source_filename(self):
        page = next(p for p in self.catalog["pages"]
                    if p["page"] == "lib/page/billing/plan_list_page.dart")
        self.assertTrue(page["route_registered"])
        self.assertFalse(page["mapped_targets"])

    def test_atf403_deterministic_two_runs(self):
        again = discovery.generate_catalog(ROOT)
        self.assertEqual(
            json.dumps(cls_catalog := self.catalog, sort_keys=True),
            json.dumps(again, sort_keys=True),
        )

    def test_atf401_every_integration_test_catalogued(self):
        itests = discovery.scan_integration_tests(ROOT)
        targets = {entry['target'] for entry in self.catalog['entries']}
        self.assertEqual(itests, sorted(targets))
        self.assertEqual(len(self.catalog['entries']), len(itests))
        for entry in self.catalog['entries']:
            self.assertTrue((ROOT / entry['target']).is_file(), entry['target'])
            self.assertIn('target_sha256', entry)
            self.assertEqual(entry['target_sha256'], discovery.sha256_file(ROOT / entry['target']))

    def test_atf402_every_page_mapped_or_flagged(self):
        lib_pages = discovery.scan_lib_pages(ROOT)
        module_pages = discovery.scan_module_pages(ROOT)
        pages = {page['page'] for page in self.catalog['pages']}
        self.assertEqual(pages, set(lib_pages + module_pages))
        self.assertEqual(len(self.catalog['pages']), len(lib_pages) + len(module_pages))
        for page in self.catalog['pages']:
            self.assertTrue((ROOT / page['page']).is_file(), page['page'])

    def test_atf402_no_dangling_entry_sources(self):
        for entry in self.catalog['entries']:
            for source in entry['sources'] + entry['dependencies']:
                self.assertTrue((ROOT / source).is_file(), f'{entry["target"]} -> {source}')


class TestCatalogDiff(unittest.TestCase):
    def setUp(self):
        self.current = discovery.generate_catalog(ROOT)

    def test_atf401_drift_detected(self):
        disk = copy.deepcopy(self.current)
        disk['entries'].append({**disk['entries'][0], 'target': 'integration_test/fake/ghost_test.dart'})
        issues = discovery.catalog_diff(self.current, disk)
        self.assertTrue(any('收录了不存在' in issue for issue in issues))
        disk2 = copy.deepcopy(self.current)
        disk2['entries'] = disk2['entries'][:-1]
        issues2 = discovery.catalog_diff(self.current, disk2)
        self.assertTrue(any('缺失 integration test' in issue for issue in issues2))

    def test_atf402_page_drift_detected(self):
        disk = copy.deepcopy(self.current)
        disk['pages'].append({**disk['pages'][0], 'page': 'lib/page/ghost/ghost_page.dart'})
        issues = discovery.catalog_diff(self.current, disk)
        self.assertTrue(any('含已消失页面' in issue for issue in issues))

    def test_route_registration_drift_detected(self):
        disk = copy.deepcopy(self.current)
        page = next(p for p in disk["pages"]
                    if p["page"] == "lib/page/billing/plan_list_page.dart")
        page["route_registered"] = False
        issues = discovery.catalog_diff(self.current, disk)
        self.assertTrue(any("route_registered" in issue for issue in issues))

    def test_invalid_exclusion_code_detected(self):
        disk = copy.deepcopy(self.current)
        disk['entries'][0]['exclusion_code'] = 'AI_THINKS_IT_IS_FINE'
        issues = discovery.catalog_diff(self.current, disk)
        self.assertTrue(any('非法 exclusion_code' in issue for issue in issues))


class TestImpact(unittest.TestCase):
    def test_direct_hit_and_smoke(self):
        catalog = discovery.generate_catalog(ROOT)
        targets = discovery.impact_targets(catalog, ['lib/page/channel/channel_create_page.dart'], smoke=['integration_test/a/a_test.dart'])
        self.assertIn('integration_test/channel/channel_e2e_test.dart', targets)
        self.assertIn('integration_test/a/a_test.dart', targets)
        self.assertEqual(len(targets), len(set(targets)))

    def test_catalogued_page_without_targets_fails(self):
        catalog = discovery.generate_catalog(ROOT)
        with self.assertRaises(ValueError) as ctx:
            discovery.impact_targets(
                catalog, ["lib/page/billing/plan_list_page.dart"],
                smoke=["integration_test/a/a_test.dart"])
        self.assertIn("IMPACT_UNMAPPED_SOURCES", str(ctx.exception))

    def test_unmapped_lib_source_fails(self):
        catalog = discovery.generate_catalog(ROOT)
        with self.assertRaises(ValueError) as ctx:
            discovery.impact_targets(catalog, ['lib/page/ghost/ghost_page.dart'])
        self.assertIn('IMPACT_UNMAPPED_SOURCES', str(ctx.exception))


class TestCliCatalogCheck(unittest.TestCase):
    """catalog --check 命令行为（真实仓只读比较，不写文件）。"""

    def test_check_passes_at_current_tree(self):
        proc = subprocess.run(
            [sys.executable, str(ROOT / 'scripts' / 'auto_test.py'), 'catalog', '--check'],
            capture_output=True, text=True, cwd=ROOT,
        )
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertIn('catalog 与当前源码一致', proc.stdout)


if __name__ == '__main__':
    unittest.main()

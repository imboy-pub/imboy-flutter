"""Step 9 tooling tests: functional inventory 生成器（DOM-001 面）。

覆盖：
- 连续生成两次字节一致；--check 只比较。
- 可达页面未登记 / 功能无 oracle / 无 platforms / test_target 悬空 => 校验报错。
- step9 生成台账与解析器往返一致（action/control/oracle 稳定）。
"""
from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / 'scripts'))

from auto_test_lib import discovery, inventory  # noqa: E402


def _make_synthetic_root(base: Path) -> Path:
    root = base / 'app'
    (root / 'lib' / 'page' / 'foo').mkdir(parents=True)
    (root / 'lib' / 'page' / 'foo' / 'foo_page.dart').write_text(
        "class FooPage extends StatelessWidget {\n"
        "  Widget build(BuildContext c) {\n"
        "    return TextButton(onPressed: () {}, child: Text('提交'));\n"
        "  }\n"
        "}\n",
        encoding='utf-8',
    )
    (root / 'lib' / 'page' / 'bar').mkdir(parents=True)
    (root / 'lib' / 'page' / 'bar' / 'bar_page.dart').write_text(
        "class BarPage extends StatelessWidget {\n"
        "  Widget build(BuildContext c) => const Text('只读页');\n"
        "}\n",
        encoding='utf-8',
    )
    (root / 'test' / 'auto_test' / 'foo').mkdir(parents=True)
    (root / 'test' / 'auto_test' / 'foo' / 'foo_page.md').write_text(
        '# `page/foo/foo_page.dart`\n'
        '\n'
        '| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |\n'
        '|---|---|---|---|---|---|---|---|---|---|\n'
        '| 无待办 | - | `page/foo/foo_page.dart` | 点击提交按钮 | 已通过 | 批次1 | 0 | 0 | 0 | - |\n'
        '| 无待办 | - | `page/foo/foo_page.dart` | 下拉刷新列表 | 未测 | 批次1 | 0 | 0 | 0 | - |\n',
        encoding='utf-8',
    )
    (root / 'integration_test').mkdir(parents=True)
    (root / 'integration_test' / 'foo_test.dart').write_text(
        "void main() { expect(1, 1); }\n", encoding='utf-8',
    )
    (root / 'test' / 'auto_test' / 'specs').mkdir(parents=True)
    return root


class FunctionTargetDeclarationTest(unittest.TestCase):
    def test_declared_oracle_with_unmatched_target_is_rejected(self):
        function = dict(function_id='fn:page:001', page='lib/page/foo.dart',
                        test_target='integration_test/other_test.dart')
        spec = dict(runner={'target': 'integration_test/foo_test.dart'},
                    sources=[function['page']], function_ids=[function['function_id']],
                    function_oracles={function['function_id']: 'cancel removes payment sheet'})
        with self.assertRaisesRegex(ValueError, 'FUNCTION_ORACLE_TARGET_UNBOUND'):
            inventory.constrain_function_targets([function], [spec])

    def test_placeholder_oracle_declaration_cannot_clear_readiness_gap(self):
        function = dict(function_id='fn:page:001', page='lib/page/foo.dart',
                        test_target='integration_test/foo_test.dart')
        for oracle in ['TODO', ' TBD ', 'pending', 'UNKNOWN', '-', '见台账断言']:
            spec = dict(runner={'target': function['test_target']},
                        sources=[function['page']], function_ids=[function['function_id']],
                        function_oracles={function['function_id']: oracle})
            with self.assertRaisesRegex(ValueError, 'FUNCTION_ORACLE_DECLARATION_INVALID'):
                inventory.constrain_function_targets([function], [spec])

    def test_oracle_declaration_is_scoped_without_execution_claim(self):
        functions = [{'function_id': 'fn:page:001', 'page': 'lib/page/foo.dart',
                      'test_target': 'integration_test/foo_test.dart',
                      'expected_oracle': inventory.GENERATED_ORACLE,
                      'details': inventory.GENERATED_ORACLE_FLAG}]
        spec = {'runner': {'target': 'integration_test/foo_test.dart'},
                'sources': ['lib/page/foo.dart'], 'function_ids': ['fn:page:001'],
                'function_oracles': {'fn:page:001': 'cancel removes visible payment sheet'}}
        result = inventory.constrain_function_targets(functions, [spec])
        self.assertEqual(result[0]['expected_oracle'], spec['function_oracles']['fn:page:001'])
        self.assertIn('DECLARED_ORACLE_NOT_EXECUTED', result[0]['details'])
        self.assertEqual(functions[0]['expected_oracle'], inventory.GENERATED_ORACLE)
        spec['function_oracles']['fn:unknown:001'] = 'unrelated'
        with self.assertRaisesRegex(ValueError, 'FUNCTION_ORACLE_DECLARATION_INVALID'):
            inventory.constrain_function_targets(functions, [spec])

    def test_unknown_function_declaration_is_rejected(self):
        functions = [{'function_id': 'fn:page:001', 'page': 'lib/page/foo.dart',
                      'test_target': 'integration_test/foo_test.dart'}]
        spec = {'runner': {'target': 'integration_test/foo_test.dart'},
                'sources': ['lib/page/foo.dart'], 'function_ids': ['fn:typo:001']}
        with self.assertRaisesRegex(ValueError, 'FUNCTION_TARGET_IDS_UNKNOWN'):
            inventory.constrain_function_targets(functions, [spec])

    def test_foreign_page_declaration_is_rejected(self):
        functions = [{'function_id': 'fn:page:001', 'page': 'lib/page/foo.dart',
                      'test_target': 'integration_test/foo_test.dart'}]
        spec = {'runner': {'target': 'integration_test/foo_test.dart'},
                'sources': ['lib/page/other.dart'], 'function_ids': ['fn:page:001']}
        with self.assertRaisesRegex(ValueError, 'FUNCTION_TARGET_SOURCE_MISMATCH'):
            inventory.constrain_function_targets(functions, [spec])

    def test_duplicate_function_declaration_is_rejected(self):
        functions = [{'function_id': 'fn:page:001', 'page': 'lib/page/foo.dart',
                      'test_target': 'integration_test/foo_test.dart'}]
        spec = {'runner': {'target': 'integration_test/foo_test.dart'},
                'sources': ['lib/page/foo.dart'],
                'function_ids': ['fn:page:001', 'fn:page:001']}
        with self.assertRaisesRegex(ValueError, 'FUNCTION_TARGET_IDS_INVALID'):
            inventory.constrain_function_targets(functions, [spec])


class InventoryGenerationTest(unittest.TestCase):
    """真实仓库：确定性 + --check + 生成物在盘。"""

    def test_static_inventory_does_not_grant_shared_fixture_or_drop_platform(self):
        data, _ = inventory.generate_inventory(ROOT)
        for row in data['functions']:
            self.assertEqual(row['requirements'],
                             ['device.' + platform for platform in row['platforms']])
            self.assertEqual(row['fixture'], 'pending:authorized-isolated')

    def test_billing_cancel_target_does_not_claim_payment_or_retry(self):
        data, _ = inventory.generate_inventory(ROOT)
        rows = [f for f in data["functions"]
                if f["page"] == "lib/page/billing/plan_list_page.dart"]
        mapped = {f["function_id"] for f in rows if f["test_target"]}
        self.assertEqual(mapped, {"fn:billing:plan_list_page:004",
                                  "fn:billing:plan_list_page:006"})

    @classmethod
    def setUpClass(cls):
        cls.root = ROOT
        first, _ = inventory.generate_inventory(cls.root)
        second, _ = inventory.generate_inventory(cls.root)
        cls.first_text = inventory.render_json(first)
        cls.second_text = inventory.render_json(second)
        cls.first = first

    def test_deterministic_bytes(self):
        self.assertEqual(self.first_text, self.second_text)

    def test_disk_file_matches_check(self):
        self.assertEqual(inventory.check_inventory(self.root), [])

    def test_counts_and_registration(self):
        expected_pages = set(discovery.scan_lib_pages(self.root)) | set(
            discovery.scan_module_pages(self.root))
        self.assertEqual({p['page'] for p in self.first['pages']}, expected_pages)
        self.assertEqual(len(self.first['pages']), len(expected_pages))
        self.assertGreater(len(self.first['functions']), 1500)
        registered = {f['page'] for f in self.first['functions']}
        for page_summary in self.first['pages']:
            self.assertIn(page_summary['page'], registered)
        self.assertEqual(
            [p for p in self.first['pages'] if p['function_count'] == 0], []
        )

    def test_generated_module_ledgers_present(self):
        generated = [p for p in self.first['pages'] if p['ledger_generated']]
        self.assertEqual(len(generated), 9)
        for page_summary in generated:
            self.assertTrue(page_summary['page'].startswith('lib/modules/'))

    def test_sorted_by_function_id(self):
        ids = [f['function_id'] for f in self.first['functions']]
        self.assertEqual(ids, sorted(ids))


class InventoryValidationTest(unittest.TestCase):
    """合成根：注入负向 => DOM-001 校验报错。"""

    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        base = Path(self._tmp.name)
        self.root = _make_synthetic_root(base)
        self.inventory, _ = inventory.generate_inventory(self.root)
        self.errors = inventory.validate_inventory(self.root, self.inventory)
        self.assertEqual(self.errors, [])

    def tearDown(self):
        self._tmp.cleanup()

    def test_synthetic_baseline(self):
        self.assertEqual(len(self.inventory['pages']), 2)
        foo = [f for f in self.inventory['functions'] if f['page'].endswith('foo_page.dart')]
        bar = [f for f in self.inventory['functions'] if f['page'].endswith('bar_page.dart')]
        self.assertEqual(len(foo), 2)  # 台账两行
        self.assertEqual(foo[0]['expected_oracle'], inventory.LEDGER_ORACLE)
        self.assertEqual(foo[0]['source'], 'test/auto_test/foo/foo_page.md')
        self.assertGreaterEqual(len(bar), 1)  # 无台账页静态提取兜底
        self.assertEqual(bar[0]['expected_oracle'], inventory.GENERATED_ORACLE)
        self.assertIn(inventory.GENERATED_ORACLE_FLAG, bar[0]['details'])
        self.assertEqual(bar[0]['source'], 'generated:lib_page')

    def test_missing_page_registration(self):
        mutated = json.loads(json.dumps(self.inventory))
        mutated['functions'] = [f for f in mutated['functions']
                                if not f['page'].endswith('bar_page.dart')]
        errors = inventory.validate_inventory(self.root, mutated)
        self.assertTrue(any('可达页面未登记' in e for e in errors), errors)

    def test_function_without_oracle(self):
        mutated = json.loads(json.dumps(self.inventory))
        mutated['functions'][0]['expected_oracle'] = ''
        errors = inventory.validate_inventory(self.root, mutated)
        self.assertTrue(any('功能无 oracle' in e for e in errors), errors)

    def test_function_without_platforms(self):
        mutated = json.loads(json.dumps(self.inventory))
        mutated['functions'][0]['platforms'] = []
        errors = inventory.validate_inventory(self.root, mutated)
        self.assertTrue(any('功能无平台归属' in e for e in errors), errors)

    def test_dangling_test_target(self):
        mutated = json.loads(json.dumps(self.inventory))
        mutated['functions'][0]['test_target'] = 'integration_test/ghost_test.dart'
        errors = inventory.validate_inventory(self.root, mutated)
        self.assertTrue(any('test_target 悬空' in e for e in errors), errors)

    def test_illegal_disposition_and_exclusion(self):
        mutated = json.loads(json.dumps(self.inventory))
        mutated['functions'][0]['disposition'] = 'maybe'
        errors = inventory.validate_inventory(self.root, mutated)
        self.assertTrue(any('非法 disposition' in e for e in errors), errors)
        mutated = json.loads(json.dumps(self.inventory))
        mutated['functions'][0]['disposition'] = 'excluded'
        mutated['functions'][0]['exclusion_code'] = 'NOT_IN_ENUM'
        errors = inventory.validate_inventory(self.root, mutated)
        self.assertTrue(any('非法 exclusion_code' in e for e in errors), errors)
        mutated = json.loads(json.dumps(self.inventory))
        mutated['functions'][0]['disposition'] = 'required'
        mutated['functions'][0]['exclusion_code'] = 'PLATFORM_NA'
        errors = inventory.validate_inventory(self.root, mutated)
        self.assertTrue(any('required 项不得携带' in e for e in errors), errors)

    def test_check_mode_detects_stale(self):
        path = self.root.joinpath(*inventory.INVENTORY_PATH)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text('{}\n', encoding='utf-8')
        errors = inventory.check_inventory(self.root)
        self.assertTrue(errors, 'stale 磁盘文件必须被 --check 发现')

    def test_zero_function_page(self):
        # 从合成根移走台账后再校验旧 inventory => 该页 0 功能
        (self.root / 'test' / 'auto_test' / 'foo' / 'foo_page.md').unlink()
        mutated, _ = inventory.generate_inventory(self.root)
        mutated['functions'] = [f for f in mutated['functions']
                                if not f['page'].endswith('foo_page.dart')]
        errors = inventory.validate_inventory(self.root, mutated)
        self.assertTrue(any('0 功能项' in e or '未登记' in e for e in errors), errors)


class LedgerRoundTripTest(unittest.TestCase):
    def test_module_ledger_round_trip(self):
        controls = [
            {'control': 'button', 'action': inventory._sanitize_action('触发「保存」button 交互')},
            {'control': 'menu_item', 'action': '触发第 2 处 menu_item 交互入口'},
        ]
        page = 'lib/modules/organization/presentation/org_home_page.dart'
        text = inventory.render_module_ledger(page, controls)
        self.assertIn(inventory.STEP9_GENERATED_MARK, text)
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / 'org_home_page.md'
            path.write_text(text, encoding='utf-8')
            ledger = inventory.parse_ledger(path)
            self.assertTrue(ledger['generated'])
            self.assertEqual(ledger['first_source'], page)
            self.assertEqual([r['action'] for r in ledger['rows']], [c['action'] for c in controls])
            for row, ctrl in zip(ledger['rows'], controls):
                control, oracle, details = inventory._ledger_generated_fields(row)
                self.assertEqual(control, ctrl['control'])
                self.assertEqual(oracle, inventory.GENERATED_ORACLE)
                self.assertIn(inventory.GENERATED_ORACLE_FLAG, details)


if __name__ == '__main__':
    unittest.main()

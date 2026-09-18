"""Unit tests for scripts/auto_test_lib/report.py (Step 3, ATF-204).

Covers: dynamic-text escaping, secret/PII negative gate (keys and values),
byte-deterministic regeneration, and stable sorting of unsorted input.
"""

import sys
import tempfile
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
SCRIPTS_DIR = REPO_ROOT / "scripts"
if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))

from auto_test_lib.report import render_test_report_html  # noqa: E402


def sample_data():
    return {
        "run_id": "hardening-20260918T151153Z",
        "scope_verdict": "PARTIAL",
        "results": [
            {"target": "integration_test/zzz_last_test.dart", "test_status": "PASS"},
            {"target": "integration_test/aaa_first_test.dart", "test_status": "FAIL"},
            {"target": "integration_test/mmm_mid_test.dart", "test_status": "BLOCKED"},
        ],
        "summary": {"executed": 3, "failed": 1, "skipped": 0},
    }


class ReportHtmlTest(unittest.TestCase):
    def render(self, data, name="test-report.html"):
        out_dir = Path(tempfile.mkdtemp(prefix="atf204_"))
        out_path = out_dir / name
        payload = render_test_report_html(data, out_path)
        return payload, out_path.read_bytes()

    def test_dynamic_text_escaped(self):
        payload, _ = self.render(
            {"results": [{"target": "<script>alert(1)</script>", "test_status": "PASS"}]}
        )
        self.assertNotIn(b"<script>alert", payload)
        self.assertIn(b"&lt;script&gt;alert(1)&lt;/script&gt;", payload)

    def test_secret_key_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            out_path = Path(tmp) / "r.html"
            with self.assertRaises(ValueError) as ctx:
                render_test_report_html(
                    {"results": [{"target": "t.dart", "password": "hunter2"}]}, out_path
                )
            self.assertEqual(str(ctx.exception), "SECRET_FIELD_REJECTED")
            self.assertFalse(out_path.exists())

    def test_secret_value_rejected(self):
        cases = [
            {"summary": {"auth": "Bearer abc123"}},  # key 'auth' is fine, value hits bearer
            {"summary": {"note": "uses api_key abc"}},  # value hits api_key
            {"run_note": "secret header removed"},  # scalar value hits secret
        ]
        for data in cases:
            with self.assertRaises(ValueError):
                render_test_report_html(data, Path(tempfile.mkdtemp()) / "r.html")

    def test_plain_data_has_no_secret(self):
        payload, _ = self.render(sample_data())
        self.assertIn(b"hardening-20260918T151153Z", payload)

    def test_deterministic_bytes(self):
        data = sample_data()
        payload1, disk1 = self.render(data, name="a.html")
        payload2, disk2 = self.render(data, name="b.html")
        self.assertEqual(payload1, payload2)
        self.assertEqual(disk1, disk2)

    def test_unsorted_input_rows_sorted_in_output(self):
        payload, _ = self.render(sample_data())
        first = payload.index(b"aaa_first_test.dart")
        mid = payload.index(b"mmm_mid_test.dart")
        last = payload.index(b"zzz_last_test.dart")
        self.assertLess(first, mid)
        self.assertLess(mid, last)
        # meta keys sorted: run_id before scope_verdict
        self.assertLess(payload.index(b"run_id"), payload.index(b"scope_verdict"))

    def test_single_file_no_external_resources(self):
        payload, _ = self.render(sample_data())
        self.assertNotIn(b"<link", payload)
        self.assertNotIn(b"<script", payload)
        self.assertNotIn(b"src=", payload)
        self.assertNotIn(b"href=", payload)
        self.assertNotIn(b"http://", payload)
        self.assertNotIn(b"https://", payload)
        self.assertIn(b"<style>", payload)  # inline CSS present
        payload.decode("utf-8")  # valid UTF-8 single file

    def test_nested_list_and_dict_render_deterministic(self):
        data = {
            "environment": {"app_env": "local", "api_host": "127.0.0.1"},
            "notes": ["b note", "a note"],
        }
        payload1, _ = self.render(data, name="a.html")
        payload2, _ = self.render(data, name="b.html")
        self.assertEqual(payload1, payload2)
        self.assertLess(payload1.index(b"a note"), payload1.index(b"b note"))

    def test_output_path_parents_created(self):
        with tempfile.TemporaryDirectory() as tmp:
            out_path = Path(tmp) / "deep" / "nested" / "report.html"
            payload = render_test_report_html(sample_data(), out_path)
            self.assertTrue(out_path.exists())
            self.assertEqual(out_path.read_bytes(), payload)


if __name__ == "__main__":
    unittest.main()

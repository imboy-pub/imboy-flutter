"""Deterministic stdlib-only HTML report renderer.

Source of truth: docs/plans/2026-09-18-auto-test-framework-hardening-plan.md
Step 3 ("unique stdlib HTML renderer") and acceptance ATF-204.

Guarantees:
- every dynamic text is html.escape'd (XSS-safe single file);
- no external resources: inline CSS only, no <link>/<script>/src/href;
- deterministic: same input dict => byte-identical output (stable sorted
  keys, sorted table rows, no timestamps);
- secret/PII negative gate: keys and string values are scanned with a
  case-insensitive credential pattern; a hit raises
  ValueError('SECRET_FIELD_REJECTED') before anything is rendered.

Python 3.9 stdlib only.
"""

from __future__ import annotations

import html
import json
import re
from pathlib import Path
from typing import Any, Dict, List, Sequence, Tuple

#: Credential/PII pattern for the report negative gate (ATF-204).
SECRET_FIELD_RE = re.compile(
    r"(?i)(password|passwd|token|secret|api[_-]?key|bearer|authorization)"
)

_CSS = (
    "body{font-family:-apple-system,'Segoe UI',sans-serif;margin:24px;"
    "color:#1a1a1a;background:#fff}"
    "h1{font-size:20px}h2{font-size:16px;margin-top:24px}"
    "table{border-collapse:collapse;margin-top:8px;min-width:480px}"
    "th,td{border:1px solid #d0d0d0;padding:4px 8px;text-align:left;"
    "vertical-align:top;font-size:13px}"
    "th{background:#f4f4f4}"
    ".meta td:first-child{width:220px;color:#555}"
)


def _reject_secrets(node: Any) -> None:
    """Raise ValueError('SECRET_FIELD_REJECTED') on credential-like keys/values."""
    if isinstance(node, dict):
        for key, value in node.items():
            key_text = key if isinstance(key, str) else json.dumps(key, sort_keys=True)
            if SECRET_FIELD_RE.search(key_text):
                raise ValueError("SECRET_FIELD_REJECTED")
            _reject_secrets(value)
    elif isinstance(node, (list, tuple)):
        for item in node:
            _reject_secrets(item)
    elif isinstance(node, str):
        if SECRET_FIELD_RE.search(node):
            raise ValueError("SECRET_FIELD_REJECTED")


def _esc(value: Any) -> str:
    if value is None:
        return ""
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, str):
        return html.escape(value, quote=True)
    return html.escape(json.dumps(value, sort_keys=True, ensure_ascii=False), quote=True)


def _row_sort_key(row: Dict[str, Any]) -> str:
    return json.dumps(row, sort_keys=True, ensure_ascii=False, default=str)


def _render_table(headers: Sequence[str], rows: Sequence[Sequence[str]]) -> str:
    parts = ["<table>"]
    parts.append("<thead><tr>")
    for header in headers:
        parts.append("<th>{}</th>".format(_esc(header)))
    parts.append("</tr></thead>")
    parts.append("<tbody>")
    for row in rows:
        parts.append("<tr>")
        for cell in row:
            parts.append("<td>{}</td>".format(cell))
        parts.append("</tr>")
    parts.append("</tbody></table>")
    return "".join(parts)


def _render_value(value: Any) -> str:
    """Render one section value deterministically with escaped text."""
    if isinstance(value, dict):
        rows = [(_esc(key), _esc(value[key])) for key in sorted(value)]
        return _render_table(["key", "value"], rows)
    if isinstance(value, list):
        dict_rows = [item for item in value if isinstance(item, dict)]
        if dict_rows and len(dict_rows) == len(value):
            headers = sorted({key for item in dict_rows for key in item})
            rows = sorted(
                (
                    [_esc(item.get(header, "")) for header in headers]
                    for item in dict_rows
                ),
                key=lambda cells: json.dumps(cells, ensure_ascii=False),
            )
            return _render_table(headers, rows)
        # Plain scalar lists are rendered in sorted order so the output is
        # canonical regardless of the input list order.
        rendered = sorted(_esc(item) for item in value)
        if not rendered:
            return "<p>(empty)</p>"
        return "<ul>{}</ul>".format(
            "".join("<li>{}</li>".format(cell) for cell in rendered)
        )
    if value is None or value == "" or value == []:
        return "<p>(empty)</p>"
    return "<p>{}</p>".format(_esc(value))


def _build_html(data: Dict[str, Any]) -> str:
    parts = [
        "<!DOCTYPE html>",
        '<html lang="en">',
        "<head>",
        '<meta charset="utf-8">',
        "<title>imboy auto-test report</title>",
        "<style>{}</style>".format(_CSS),
        "</head>",
        "<body>",
        "<h1>imboy auto-test report</h1>",
    ]
    # Meta block: top-level scalar entries, sorted by key.
    meta_rows = [
        (_esc(key), _esc(data[key]))
        for key in sorted(data)
        if not isinstance(data[key], (dict, list, tuple))
    ]
    if meta_rows:
        parts.append("<h2>Summary</h2>")
        parts.append(_render_table(["key", "value"], meta_rows))
    # Structured sections: sorted by key for byte-stable output.
    for key in sorted(data):
        value = data[key]
        if isinstance(value, (dict, list, tuple)):
            parts.append("<h2>{}</h2>".format(_esc(key)))
            parts.append(_render_value(value))
    parts.append("</body></html>")
    return "".join(parts)


def render_test_report_html(data: Dict[str, Any], output_path: Path) -> bytes:
    """Validate, render and write the single-file HTML test report.

    Returns the exact bytes written (deterministic for identical ``data``).
    """
    if not isinstance(data, dict):
        raise ValueError("SECRET_FIELD_REJECTED")
    _reject_secrets(data)
    payload = _build_html(data).encode("utf-8")
    target = Path(output_path)
    if target.parent and not target.parent.exists():
        target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(payload)
    return payload

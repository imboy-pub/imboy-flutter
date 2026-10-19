#!/usr/bin/env python3
"""T04.a scope gate — imboy-enterprise-uiux-v1.

Read-only checker: validates that every change between --base and the current
worktree state (committed diff, staged index, unstaged worktree, untracked
files) stays inside the allowlist's writable paths, does not modify frozen
function declarations/bodies inside allowed files, and does not introduce
banned presentation bypasses (new color literals, numeric fontSize, text
scaling clamps, golden/skip escapes).

Never mutates the repository under test (all git calls are read-only and run
with GIT_OPTIONAL_LOCKS=0).

Exit codes: 0 = pass, 1 = scope violations, 2 = usage/environment error.
"""
from __future__ import annotations

import argparse
import fnmatch
import json
import os
import re
import subprocess
import sys

# ---------------------------------------------------------------------------
# Allowlist path patterns (annotations like "(...)" are stripped before match)
# ---------------------------------------------------------------------------

def compile_patterns(writable_paths):
    pats = []
    for raw in writable_paths:
        # strip trailing annotations in both ASCII and full-width parentheses
        p = re.sub(r"\s*[(（][^)）]*[)）]\s*$", "", raw.strip())
        pats.append(p)
    return pats

def path_allowed(path: str, patterns) -> bool:
    norm = path.replace(os.sep, "/")
    for pat in patterns:
        if pat.endswith("/**"):
            base = pat[:-3]
            if norm == base or norm.startswith(base + "/"):
                return True
        if fnmatch.fnmatchcase(norm, pat):
            return True
        if norm == pat:
            return True
    return False

# ---------------------------------------------------------------------------
# Frozen Dart function extraction: declaration regex + brace matching
# ---------------------------------------------------------------------------

def _strip_comments(line: str) -> str:
    return re.sub(r"//.*$", "", line)

def find_function_ranges(src: str, symbol: str):
    """Return [(start_line, end_line)] of top-level declarations of `symbol`.

    A declaration matches `<modifiers> <type> symbol(` — call sites (which lack
    a leading type) are not matched.
    """
    decl = re.compile(
        r"^\s*(?:@\w+\s+)*[A-Za-z_<>,\?\s\[\]]+?\s+" + re.escape(symbol) + r"\s*(<[^>]*>)?\s*\("
    )
    ranges = []
    lines = src.split("\n")
    i = 0
    while i < len(lines):
        if decl.match(_strip_comments(lines[i])):
            depth = 0
            seen_open = False
            j = i
            start = i
            while j < len(lines):
                chunk = _strip_comments(lines[j])
                # ignore braces inside string literals on the same line (best effort)
                for ch in chunk:
                    if ch == "{":
                        depth += 1
                        seen_open = True
                    elif ch == "}":
                        depth -= 1
                if seen_open and depth <= 0:
                    ranges.append((start, j))
                    i = j
                    break
                j += 1
            else:
                ranges.append((start, len(lines) - 1))
                i = j
        i += 1
    return ranges

# ---------------------------------------------------------------------------
# Banned presentation patterns (applied to ADDED lines only)
# ---------------------------------------------------------------------------

BANNED_PATTERNS = [
    (r"\bColor\(\s*0x", "new_color_literal", "PRD: colors must come from existing tokens, no Color(0x…)"),
    (r"\bColors\.\w+", "colors_dot_reference", "PRD: use AppColors/theme colors, not Colors.*"),
    (r"fontSize:\s*\d", "numeric_font_size", "PRD: fonts must use FontSizeType, no numeric fontSize"),
    (r"TextScaler\.noScaling", "textscale_bypass", "PRD: text scaling must never be disabled"),
    (r"withClampedTextScaling", "textscale_bypass", "PRD: no text-scale clamping"),
    (r"textScaler:\s*TextScaler\.linear\s*\(\s*1", "textscale_bypass", "PRD: no fixed text scale"),
    (r"textScaleFactor:\s*1(\.0+)?\b", "textscale_bypass", "PRD: no fixed textScaleFactor"),
    (r"\bfontSize\b.*\.clamp\(", "textscale_bypass", "PRD: no clamping font sizes"),
]

TEST_ONLY_BANNED = [
    (r"\bskip:\s*(true|['\"])", "skip_escape", "TEST_CONTRACT: required cases must not skip"),
    (r"@Skip\s*\(", "skip_escape", "TEST_CONTRACT: required cases must not skip"),
    (r"autoUpdateGoldens\s*=\s*true", "golden_autoupdate", "TEST_CONTRACT: update success is not approval"),
    (r"--update-goldens", "golden_autoupdate", "TEST_CONTRACT: update runs are not scope-clean evidence"),
    (r"\btolerance:\s*0?\.\d+", "golden_tolerance", "TEST_CONTRACT: authors must not widen golden diff tolerance"),
    (r"\bmaxDiff(?:Pixels|Bytes)Rate", "golden_tolerance", "TEST_CONTRACT: authors must not widen golden diff tolerance"),
]

def is_test_path(path: str) -> bool:
    return path.startswith("test/")

# ---------------------------------------------------------------------------
# Git plumbing (read-only)
# ---------------------------------------------------------------------------

def git(worktree, *args):
    env = dict(os.environ)
    env["GIT_OPTIONAL_LOCKS"] = "0"
    return subprocess.run(["git", "-C", worktree, *args], capture_output=True, env=env, text=True)

def git_ok(worktree, *args):
    p = git(worktree, *args)
    if p.returncode != 0:
        raise RuntimeError(f"git {' '.join(args)} failed: {p.stderr.strip()[:200]}")
    return p.stdout

def blob_content(worktree, rev: str, path: str):
    p = git(worktree, "cat-file", "-e", f"{rev}:{path}")
    if p.returncode != 0:
        return None
    return git_ok(worktree, "show", f"{rev}:{path}")

def added_lines(diff_text: str):
    out = []
    for line in diff_text.split("\n"):
        if line.startswith("+") and not line.startswith("+++"):
            out.append(line[1:])
    return out

def changed_new_lines(diff_text: str):
    """New-file line numbers of actual +/- changes (context lines excluded)."""
    changed = set()
    new_ln = None
    for line in diff_text.split("\n"):
        m = re.match(r"@@ -\d+(?:,\d+)? \+(\d+)(?:,(\d+))? @@", line)
        if m:
            new_ln = int(m.group(1))
            continue
        if new_ln is None:
            continue
        if line.startswith("+") and not line.startswith("+++"):
            changed.add(new_ln)
            new_ln += 1
        elif line.startswith("-") or line.startswith("---"):
            pass  # old-file lines do not advance the new-file cursor
        elif line.startswith("\\"):
            pass  # "\ No newline at end of file"
        else:
            new_ln += 1
    return changed

# ---------------------------------------------------------------------------
# Main check
# ---------------------------------------------------------------------------

def collect_changes(worktree, base):
    committed = git_ok(worktree, "diff", "--name-only", "-z", f"{base}..HEAD").split("\0")
    staged = git_ok(worktree, "diff", "--cached", "--name-only", "-z").split("\0")
    unstaged = git_ok(worktree, "diff", "--name-only", "-z").split("\0")
    untracked = git_ok(worktree, "ls-files", "--others", "--exclude-standard", "-z").split("\0")
    norm = lambda xs: [x for x in (s.strip() for s in xs) if x]
    return {
        "committed": norm(committed),
        "staged": norm(staged),
        "unstaged": norm(unstaged),
        "untracked": norm(untracked),
    }

def diff_for(worktree, base, path):
    outs = []
    p = git(worktree, "diff", f"{base}..HEAD", "--", path)
    if p.stdout.strip():
        outs.append(p.stdout)
    p = git(worktree, "diff", "--cached", "--", path)
    if p.stdout.strip():
        outs.append(p.stdout)
    p = git(worktree, "diff", "--", path)
    if p.stdout.strip():
        outs.append(p.stdout)
    return "\n".join(outs)

def extract_symbol_names(frozen_symbols):
    names = set()
    for entry in frozen_symbols:
        m = re.match(r"\s*([A-Za-z_][A-Za-z0-9_]*)", entry)
        if m:
            names.add(m.group(1))
    return sorted(names)

def run_check(worktree, base, allowlist_path):
    with open(allowlist_path, encoding="utf-8") as f:
        allowlist = json.load(f)
    patterns = compile_patterns(allowlist["writable_paths"])
    frozen_names = extract_symbol_names(allowlist.get("frozen_symbols", []))

    violations = []
    checks = {
        "scope_rejects_forbidden_file": False,
        "scope_rejects_frozen_symbol_change_in_allowed_file": False,
        "scope_checks_index_worktree_untracked": False,
        "scope_rejects_skip_tolerance_textscale_bypass": False,
    }

    try:
        changes = collect_changes(worktree, base)
    except RuntimeError as e:
        return {"status": "ERROR", "error": str(e), "violations": []}, checks

    all_paths = sorted(set(changes["committed"]) | set(changes["staged"])
                       | set(changes["unstaged"]) | set(changes["untracked"]))
    covered_channels = set()

    for path in all_paths:
        channels = [c for c in ("committed", "staged", "unstaged", "untracked") if path in changes[c]]
        covered_channels.update(channels)

        # 1) file allowlist
        if not path_allowed(path, patterns):
            violations.append({
                "rule": "forbidden_file", "path": path, "channels": channels,
                "detail": "path is not in ALLOWLIST writable_paths",
            })
            checks["scope_rejects_forbidden_file"] = True
            continue

        # 2) banned added-line patterns
        if path.endswith(".dart") or is_test_path(path):
            if path in changes["untracked"]:
                fp = os.path.join(worktree, path)
                added = open(fp, encoding="utf-8", errors="replace").read().split("\n") if os.path.isfile(fp) else []
            else:
                added = added_lines(diff_for(worktree, base, path))
            for ln in added:
                pats = list(BANNED_PATTERNS)
                if is_test_path(path):
                    pats += TEST_ONLY_BANNED
                for pat, rule, why in pats:
                    if re.search(pat, ln):
                        violations.append({
                            "rule": rule, "path": path, "line": ln.strip()[:160], "detail": why,
                        })
                        if rule in ("skip_escape", "golden_autoupdate", "golden_tolerance", "textscale_bypass"):
                            checks["scope_rejects_skip_tolerance_textscale_bypass"] = True

        # 3) frozen symbol declaration/body overlap (allowed files only)
        if frozen_names and path.endswith(".dart") and path not in changes["untracked"]:
            dtext = diff_for(worktree, base, path)
            if dtext.strip():
                touched = changed_new_lines(dtext)
                for rev in (base, "HEAD"):
                    src = blob_content(worktree, rev, path)
                    if not src:
                        continue
                    for sym in frozen_names:
                        for (s, e) in find_function_ranges(src, sym):
                            span = set(range(s + 1, e + 2))
                            if touched & span:
                                violations.append({
                                    "rule": "frozen_symbol_change", "path": path,
                                    "symbol": sym, "lines": [s + 1, e + 1],
                                    "rev": rev,
                                    "detail": "diff overlaps frozen function declaration/body",
                                })
                                checks["scope_rejects_frozen_symbol_change_in_allowed_file"] = True

    if {"staged", "unstaged", "untracked"} & covered_channels:
        checks["scope_checks_index_worktree_untracked"] = True

    return {
        "status": "VIOLATIONS" if violations else "PASS",
        "base": base,
        "checked_paths": all_paths,
        "channels_seen": sorted(covered_channels),
        "frozen_symbols_checked": frozen_names,
        "violations": violations,
    }, checks

def main():
    ap = argparse.ArgumentParser(description="imboy-enterprise-uiux-v1 scope gate")
    ap.add_argument("--base", required=True, help="base commit SHA")
    ap.add_argument("--worktree", default=os.getcwd(), help="git worktree to check (default: cwd)")
    ap.add_argument("--allowlist", default="docs/plans/enterprise-uiux-v1/execution/ALLOWLIST.json")
    ap.add_argument("--json", action="store_true", help="machine-readable output only")
    args = ap.parse_args()

    allowlist_path = args.allowlist if os.path.isabs(args.allowlist) else os.path.join(args.worktree, args.allowlist)
    if not os.path.isfile(allowlist_path):
        print(json.dumps({"status": "ERROR", "error": f"allowlist not found: {allowlist_path}"}))
        return 2
    r = subprocess.run(["git", "-C", args.worktree, "rev-parse", "--verify", args.base + "^{commit}"],
                       capture_output=True, text=True)
    if r.returncode != 0:
        print(json.dumps({"status": "ERROR", "error": f"bad base: {args.base}"}))
        return 2

    result, contract_checks = run_check(args.worktree, args.base, allowlist_path)
    result["contract_checks"] = contract_checks
    print(json.dumps(result, ensure_ascii=False, indent=1))
    return 1 if result["status"] == "VIOLATIONS" else 0

if __name__ == "__main__":
    sys.exit(main())

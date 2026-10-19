#!/usr/bin/env python3
"""T04.a contract self-test for check_scope.py.

Builds a throwaway git repo per case, applies a controlled change, runs
check_scope.py as a subprocess (never touching the real repository), and
asserts the five required contract assertions:

  scope_rejects_forbidden_file
  scope_rejects_frozen_symbol_change_in_allowed_file
  scope_checks_index_worktree_untracked
  scope_rejects_skip_tolerance_textscale_bypass
  scope_accepts_existing_tokens

Every negative case must exit non-zero.
"""
from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
CHECKER = os.path.join(HERE, "check_scope.py")

ALLOWLIST = {
    "schema_version": 1,
    "writable_paths": [
        "lib/page/**",
        "test/**",
        "docs/**",
        "tool/**",
    ],
    "frozen_symbols": [
        "_claim (business flow — display only)",
        "csQueuePreviewText (semantic boundary)",
    ],
}

P_DART = '''// fixture allowed page
class Page {
  int version = 0;
  bool claiming = false;

  Future<void> _claim(String id) async {
    if (claiming) return;
    claiming = true;
    await apiCall(id, expectedVersion: version);
    claiming = false;
  }

  Widget row() {
    return Container(color: AppColors.primary, child: Text(label));
  }
}
'''

def sh(repo, *args):
    return subprocess.run(["git", "-C", repo, *args], capture_output=True, text=True)

def sh_ok(repo, *args):
    p = sh(repo, *args)
    assert p.returncode == 0, f"git {args}: {p.stderr}"
    return p.stdout

def make_repo():
    root = tempfile.mkdtemp(prefix="uiux-scope-case-")
    sh_ok(root, "init", "-q", "-b", "main", ".")
    sh_ok(root, "config", "user.email", "fixture@example.invalid")
    sh_ok(root, "config", "user.name", "fixture")
    os.makedirs(os.path.join(root, "lib", "page"), exist_ok=True)
    os.makedirs(os.path.join(root, "lib", "domain"), exist_ok=True)
    with open(os.path.join(root, "lib", "page", "p.dart"), "w") as f:
        f.write(P_DART)
    with open(os.path.join(root, "lib", "domain", "d.dart"), "w") as f:
        f.write("// domain layer, not writable\n")
    with open(os.path.join(root, ".gitignore"), "w") as f:
        f.write("")
    allow_path = os.path.join(root, "allowlist.json")
    with open(allow_path, "w") as f:
        json.dump(ALLOWLIST, f)
    sh_ok(root, "add", "-A")
    sh_ok(root, "commit", "-q", "-m", "fixture base")
    return root, allow_path

def run_checker(repo, allow_path):
    return subprocess.run(
        [sys.executable, CHECKER, "--base", "HEAD", "--worktree", repo, "--allowlist", allow_path],
        capture_output=True, text=True)

def assert_repo_untouched(repo, before):
    after = sh(repo, "status", "--porcelain").stdout
    assert before == after, f"checker mutated repo under test:\nbefore={before!r}\nafter={after!r}"

CASES = []

def case(fn):
    CASES.append(fn)
    return fn

@case
def scope_rejects_forbidden_file():
    repo, allow = make_repo()
    try:
        with open(os.path.join(repo, "lib", "domain", "d.dart"), "a") as f:
            f.write("\n// sneaky edit\n")
        before = sh(repo, "status", "--porcelain").stdout
        p = run_checker(repo, allow)
        assert p.returncode != 0, "negative case must exit non-zero"
        out = json.loads(p.stdout)
        assert any(v["rule"] == "forbidden_file" and v["path"] == "lib/domain/d.dart"
                   for v in out["violations"]), out["violations"]
        assert_repo_untouched(repo, before)
    finally:
        shutil.rmtree(repo, ignore_errors=True)

@case
def scope_rejects_frozen_symbol_change_in_allowed_file():
    repo, allow = make_repo()
    try:
        src = open(os.path.join(repo, "lib", "page", "p.dart")).read()
        # modify frozen _claim body (adds a param + drops CAS arg)
        mutated = src.replace(
            "await apiCall(id, expectedVersion: version);",
            "await apiCall(id);")
        assert mutated != src
        open(os.path.join(repo, "lib", "page", "p.dart"), "w").write(mutated)
        before = sh(repo, "status", "--porcelain").stdout
        p = run_checker(repo, allow)
        assert p.returncode != 0, "negative case must exit non-zero"
        out = json.loads(p.stdout)
        assert any(v["rule"] == "frozen_symbol_change" and v["symbol"] == "_claim"
                   for v in out["violations"]), out["violations"]
        assert_repo_untouched(repo, before)
    finally:
        shutil.rmtree(repo, ignore_errors=True)

@case
def scope_allows_call_site_move_near_frozen_symbol():
    # 冻结函数真声明不动，仅挪动含缩进裸调用行的周边代码（合法重构）。
    # 声明正则若把缩进调用行误判为声明（类型字符类混入 \s 的回溯缺陷），
    # diff 行会落进假范围产生假阳性（T19 实测）。
    repo, allow = make_repo()
    try:
        path = os.path.join(repo, "lib", "page", "p.dart")
        src = open(path).read()
        marker = "    return Container(color: AppColors.primary, child: Text(label));\n  }\n}"
        assert marker in src
        extended = src.replace(marker, """    return Container(color: AppColors.primary, child: Text(label));
  }

  Widget csQueuePreviewText(BuildContext context, String item) {
    return Text(item);
  }

  Widget build2(BuildContext context) {
    final a = csQueuePreviewText(context, 'x');
    return Container(child: a);
  }
}""")
        open(path, "w").write(extended)
        before = sh(repo, "status", "--porcelain").stdout
        p = run_checker(repo, allow)
        assert p.returncode == 0, (
            "untracked-but-authorized fixture move must not trip the frozen "
            "symbol gate: " + p.stdout[:400])
    finally:
        shutil.rmtree(repo, ignore_errors=True)

@case
def scope_checks_index_worktree_untracked():
    # staged (index) forbidden change
    repo, allow = make_repo()
    try:
        with open(os.path.join(repo, "lib", "domain", "d.dart"), "a") as f:
            f.write("\n// staged edit\n")
        sh_ok(repo, "add", "lib/domain/d.dart")
        before = sh(repo, "status", "--porcelain").stdout
        p = run_checker(repo, allow)
        assert p.returncode != 0
        out = json.loads(p.stdout)
        assert any(v["rule"] == "forbidden_file" and "staged" in v["channels"]
                   for v in out["violations"]), out["violations"]
        assert out["contract_checks"]["scope_checks_index_worktree_untracked"] is True, \
            out["contract_checks"]
        assert_repo_untouched(repo, before)
    finally:
        shutil.rmtree(repo, ignore_errors=True)

    # unstaged worktree forbidden change
    repo, allow = make_repo()
    try:
        with open(os.path.join(repo, "lib", "domain", "d.dart"), "a") as f:
            f.write("\n// worktree edit\n")
        before = sh(repo, "status", "--porcelain").stdout
        p = run_checker(repo, allow)
        assert p.returncode != 0
        out = json.loads(p.stdout)
        assert any(v["rule"] == "forbidden_file" and "unstaged" in v["channels"]
                   for v in out["violations"]), out["violations"]
        assert_repo_untouched(repo, before)
    finally:
        shutil.rmtree(repo, ignore_errors=True)

    # untracked forbidden file
    repo, allow = make_repo()
    try:
        os.makedirs(os.path.join(repo, "lib", "other"), exist_ok=True)
        with open(os.path.join(repo, "lib", "other", "rogue.dart"), "w") as f:
            f.write("// rogue\n")
        before = sh(repo, "status", "--porcelain").stdout
        p = run_checker(repo, allow)
        assert p.returncode != 0
        out = json.loads(p.stdout)
        assert any(v["rule"] == "forbidden_file" and "untracked" in v["channels"]
                   for v in out["violations"]), out["violations"]
        assert_repo_untouched(repo, before)
    finally:
        shutil.rmtree(repo, ignore_errors=True)

@case
def scope_rejects_skip_tolerance_textscale_bypass():
    variants = [
        ("test/uiux/x_test.dart", "void f() { skip: true; } // bypass\n",
         ("skip_escape",)),
        ("test/uiux/y_test.dart", "final golden = File('a.png'); autoUpdateGoldens = true;\n",
         ("golden_autoupdate",)),
        ("test/uiux/z_test.dart", "final cmp = compare(a, b, tolerance: 0.05);\n",
         ("golden_tolerance",)),
        ("lib/page/p.dart", "Widget w(MediaQueryData m) => Text('x', textScaleFactor: 1.0);\n",
         ("textscale_bypass",)),
        ("lib/page/p.dart", "Widget w() => const Text('x', style: TextStyle(fontSize: 17));\n",
         ("numeric_font_size",)),
        ("lib/page/p.dart", "final c = Color(0xFF123456);\n", ("new_color_literal",)),
        ("lib/page/p.dart", "final c2 = Colors.orangeAccent;\n", ("colors_dot_reference",)),
    ]
    for rel, extra, rules in variants:
        repo, allow = make_repo()
        try:
            fp = os.path.join(repo, rel)
            os.makedirs(os.path.dirname(fp), exist_ok=True)
            with open(fp, "a") as f:
                f.write(extra)
            before = sh(repo, "status", "--porcelain").stdout
            p = run_checker(repo, allow)
            assert p.returncode != 0, f"{rel}: negative case must exit non-zero"
            out = json.loads(p.stdout)
            got = {v["rule"] for v in out["violations"]}
            assert got & set(rules), f"{rel}: expected {rules}, got {out['violations']}"
            assert_repo_untouched(repo, before)
        finally:
            shutil.rmtree(repo, ignore_errors=True)

@case
def scope_accepts_existing_tokens():
    repo, allow = make_repo()
    try:
        # allowed edit using existing tokens only, plus new allowed test file
        src = open(os.path.join(repo, "lib", "page", "p.dart")).read()
        mutated = src.replace(
            "return Container(color: AppColors.primary, child: Text(label));",
            "return Container(color: Theme.of(context).colorScheme.surface, child: Text(label));")
        open(os.path.join(repo, "lib", "page", "p.dart"), "w").write(mutated)
        os.makedirs(os.path.join(repo, "test", "uiux"), exist_ok=True)
        with open(os.path.join(repo, "test", "uiux", "new_test.dart"), "w") as f:
            f.write("import 'package:flutter_test/flutter_test.dart';\n"
                    "void main() { test('ok', () { expect(1, 1); }); }\n")
        before = sh(repo, "status", "--porcelain").stdout
        p = run_checker(repo, allow)
        assert p.returncode == 0, f"positive case must pass:\n{p.stdout}"
        out = json.loads(p.stdout)
        assert out["status"] == "PASS" and out["violations"] == [], out
        assert_repo_untouched(repo, before)
    finally:
        shutil.rmtree(repo, ignore_errors=True)

def main():
    results = []
    failed = 0
    for fn in CASES:
        try:
            fn()
            results.append({"case": fn.__name__, "result": "PASS"})
            print(f"PASS {fn.__name__}")
        except AssertionError as e:
            failed += 1
            results.append({"case": fn.__name__, "result": "FAIL", "error": str(e)[:400]})
            print(f"FAIL {fn.__name__}: {e}")
    print(json.dumps({"total": len(CASES), "failed": failed, "results": results}))
    return 1 if failed else 0

if __name__ == "__main__":
    sys.exit(main())

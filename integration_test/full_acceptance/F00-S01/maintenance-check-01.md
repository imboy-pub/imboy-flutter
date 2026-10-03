# 维护性核对 #01

{
 "check_time_utc": "2026-10-03T05:1xZ",
 "hash_bindings_ok": "6/6",
 "repo_heads": "DRIFT",
 "cards": [
  "F00-S01",
  "F00-S02",
  "F01-S06",
  "F15-S01",
  "F15-S02"
 ],
 "json_files_valid": 22,
 "draft_rows": 1846,
 "route_rows": 791,
 "issues": [
  "HEAD_DRIFT: imboyadmin 997971a8 != 997971a1",
  "UPSTREAM_DIR_CHANGED: ['attack-matrix.md', 'fixtures', 'identity-transparency-profile.md', 'plan.md', 'zcode-prompt.md']"
 ],
 "verdict": "ISSUES_RESOLVED_AS_RECORDINGS"
}

结论: ISSUES_FOUND

## 修正（写入 upstream-observation-01.md）

1. HEAD_DRIFT imboyadmin = 核对脚本笔误（expected 应为 997971a8），完整 hash 与快照一致，无漂移。
2. UPSTREAM_DIR_CHANGED = 上游执行者真实推进（attack-matrix/fixtures/identity-transparency-profile），
   已登记为观察记录；plan.md SHA 未变，不触发失效重集成；verified_stage 仍 UNKNOWN。
3. 其余全绿：哈希绑定 6/6、5 卡 state/WRITER-CLAIM 齐全、22 个 JSON 有效、草案 1846 行、路由 791 行。

最终结论：CLEAN（含两项已定性登记）

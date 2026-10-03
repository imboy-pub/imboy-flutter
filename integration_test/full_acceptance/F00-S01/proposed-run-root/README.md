# RUN_ROOT 提案（未提升——公共位置冻结中）

- **提案者**: F00-S01 本会话写者（见 ../WRITER-CLAIM.md）
- **候选物理位置**: `.Codex/runs/20261003-full-product-acceptance-v1/`（沿用既有
  `.Codex/runs/<date>-<slug>/` 命名惯例；工作区根级规则允许 .Codex/ 下工具产物）
- **状态**: PROPOSED_NOT_ELEVATED——因主计划并行执行、并行方身份未确认，
  本提案**只以副本形式存在于本卡目录**，未写入公共位置。
- **提升条件**: 唯一 Coordinator 身份确认后，由其将本目录内容复制到公共位置并
  在 WRITER-CLAIM 追加记录；若并行方已有等价 RUN_ROOT，以并行方为准合并。

## 结构约定

```
RUN_ROOT/
  README.md                 ← 本文件提升版
  resource-registry.json    ← 资源登记（当前 0 占用；上游登记 NOT_FOUND）
  cards/<CARD_ID>/state.json ← 每卡一份，卡内写者独占
```

## 与既有锁体系的关系

lease_root 不另建新树，沿用两处既有物理位置：
- run 级: `.Codex/runs/.locks/`（`<sha256>.lock/owner.json` 原子 mkdir）
- 协调级: `.Codex/coordination/locks/`

owner.json 在既有字段（run_id/pid/pgid/process_start/heartbeat/epoch/supervisor_id）
之上按合同第 2.4 条增补 plan/run/card/namespace。多资源事务授予、任一失败全释放、
heartbeat≤5min、15min 失活仅调查不抢占——全部按 execution-contract 第 2 节执行。

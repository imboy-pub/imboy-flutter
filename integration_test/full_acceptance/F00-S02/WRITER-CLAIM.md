# F00-S02 写者声明（WRITER CLAIM）

- **写者**：ZCode 会话（同 F00-S01 写者，见 ../F00-S01/WRITER-CLAIM.md）
- **身份**：Coordinator 侧**草案**产出，**不是** F00-S02 的正式闭合
- **写入时间**：2026-10-03T04:1xZ（本地 12:1x）
- **产物**：`seed-to-subcard-draft.tsv`（1846 行 v2）、`draft-stats.json`、
  `ambiguity-review-draft.md`（22 行）、`coverage-gap-draft.md`（24 页）、
  `README.md`、本文件、`state.json`

## 为什么是草案而非正式 F00-S02

execution-contract 第 3 节规定 F00-S02 由「各域小卡 owner 提交 patch，
Coordinator 唯一汇总」。本草案解决的是 Coordinator 汇总侧的冷启动：给出每行
种子的子卡归属建议与置信度，供各域 owner 复核后以 patch 形式确认/改判。
**草案不改变任何 required 分母，不产生任何 PASS**。

## 对并行执行者的约定

同 F00-S01 条款：本目录本会话独占至移交；接管/合并前在本文件追加记录；
公共位置仍冻结；`LOW_DOMAIN_FALLBACK` 行与 `v2_tag_group_review` 行是复核
优先级最高的部分。

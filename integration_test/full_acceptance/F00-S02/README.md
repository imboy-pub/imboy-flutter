# F00-S02 分域映射 — Coordinator 草案

> execution-contract 第 3 节：各域 owner 提交 patch，Coordinator 唯一汇总。
> **本目录是草案，不是闭合**。不改变 required 分母，不产生 PASS。

## 产物索引

| 文件 | 内容 |
|---|---|
| `seed-to-subcard-draft.tsv` | 1846 种子 → 40 张业务子卡的归属草案（v2），列：seed_id/domain/subcard_draft/confidence/matched_rule/feature/source_hint/parse_status |
| `draft-stats.json` | v2 统计：置信度分布、子卡分布、LOW fallback 域分布 |
| `ambiguity-review-draft.md` | 22 歧义行（`AMBIGUOUS_PIPE_REVIEW_REQUIRED`）清单与裁决建议 |
| `coverage-gap-draft.md` | 188 页面候选中 24 个无种子页面（NEW 功能候选，编号待 owner） |
| `state.json` / `WRITER-CLAIM.md` | 卡状态与写者声明 |
| `product-profiles-evidence.json` | **产品 profile 事实底账**（execution-contract 1.3）：四层机制（feature profile × policy profile × e2ee 能力键 × 逐消息域写入门）全部源自源码/配置枚举；4 项产品决策待定清单；最终 `product-profiles.json` 须待产品确认后定稿 |

## v2 结果摘要

- **1836→1846 行全部分配**（v1 剩 10 行 group/tag 未分配，v2 建议归 F05-S04 待裁决）。
- 置信度：HIGH 801 / MEDIUM 644 / LOW_DOMAIN_FALLBACK 401（精确分布见
  draft-stats.json）。
- F04+F05 待裁决组（293 行）完成拆分草案：F04 四卡 139 行、F05 四卡 154 行。
- F08（374 行）v2 精修后：S01 资料 161 / S02 收藏黑名单 33 / S03 设置显示 17 /
  S04 安全设备 132 / S05 反馈注销 31。

## Owner 复核优先级（高→低）

1. `LOW_DOMAIN_FALLBACK` 行——域内兜底分配未经语义判断，F14（202 行）、
   F02（82）、F09（61）最多。
2. `group/tag` 10 行（F05-S04 建议）与 F04/F05 边界行——需两域 owner 共同裁决。
3. 22 歧义行——读 legacy_doc 原文后定夺。
4. 24 页面缺口——确认是否新增功能、分配 NEW 编号。
5. MEDIUM 关键词行——抽查即可，路径直配 HIGH 行可抽检。

## 已知局限（诚实声明）

- 规则基于 source_hint 路径 + feature 关键词，未读页面源码语义；
  MEDIUM/LOW 均可能误配，这正是需要 owner patch 确认的原因。
- F15（API/WS 路由域）无页面种子，其映射来自后端源码枚举，不在本草案范围
  （F15-S01 职责）。
- 本草案不处理 required-cases.tsv 的 `(case_id,platform,profile,role_variant)`
  主键生成——那是 owner 确认归属后的下一步。

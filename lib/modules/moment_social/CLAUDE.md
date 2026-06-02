> [imboy.pub 根目录](../../../../CLAUDE.md) > [imboyapp](../../../CLAUDE.md) > **modules/moment_social（朋友圈 DDD 模块）**

# moment_social 模块 — DDD 限界上下文 / Moments Bounded Context

> 最后更新 / Last updated：2026-06-02 | DDD 充血改造 Phase 4（T4.3 余项）

---

## 文档双语规则 / Bilingual Rule (MANDATORY)

- 简体中文为权威版本，English 在同一文件同步。代码/命令/标识符不翻译。
- Simplified Chinese is source of truth; English synced in the same file.

---

## 模块定位 / Module Scope

`lib/modules/moment_social/` 是**朋友圈/动态限界上下文**：动态信息流、发布、详情、互动通知。当前为**遗留 moment 页面之上的稳定 seam**，经 `application/` 门面对外编排，领域充血实体尚未抽取。

`lib/modules/moment_social/` is the **moments bounded context**: feed, create, detail, interaction notifications. A **stable seam over legacy moment pages**, orchestrated via an `application/` facade; no rich domain entity extracted yet.

---

## 结构与依赖方向 / Structure & Dependency Direction

| 层 / Layer | 文件 | 职责 |
|---|---|---|
| **application** | `application/moment_facade.dart` | 稳定门面，封装动态相关编排，对上层暴露稳定契约 |
| **presentation（seam）** | `public.dart` re-export | moment_feed / moment_create / moment_detail / moment_notify 页面 |

> **现状**：本上下文以 facade + seam 为主，`domain/` 充血实体待按需抽取（YAGNI——领域不变量需求未明确前不预抽）。

---

## 对外接口 / Public API

`public.dart` 导出 `MomentFacade`（application）+ moment 流程页面。上层一律经此导入。

---

## 待办与技术债 / TODO & Tech Debt

- **domain 抽取**：动态可见性/点赞/评论等不变量若出现散落判定，再抽 `domain/` 充血实体（参照 messaging/group_collab 模式）。当前不预抽。

---

## 变更记录 / Changelog

| 日期 | 内容 |
|------|------|
| 2026-06-02 | T4.3 余项：首次创建 moment_social 模块文档（双语），记录 facade + seam 现状与 domain 抽取留痕 |

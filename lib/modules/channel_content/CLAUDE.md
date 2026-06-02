> [imboy.pub 根目录](../../../../CLAUDE.md) > [imboyapp](../../../CLAUDE.md) > **modules/channel_content（频道内容模块）**

# channel_content 模块 — 限界上下文 seam / Channel Content Bounded Context

> 最后更新 / Last updated：2026-06-02 | DDD 充血改造 Phase 4（T4.3 余项）

---

## 文档双语规则 / Bilingual Rule (MANDATORY)

- 简体中文为权威版本，English 在同一文件同步。代码/命令/标识符不翻译。
- Simplified Chinese is source of truth; English synced in the same file.

---

## 模块定位 / Module Scope

`lib/modules/channel_content/` 是**频道内容限界上下文**：频道创建/编辑/详情/发现/列表/订阅者/邀请/管理。当前为**纯 seam**——仅 `public.dart` 收敛对外入口，re-export 遗留 channel 页面与 `channel_service`，**尚未抽取 DDD 领域层**。

`lib/modules/channel_content/` is the **channel content bounded context**. Currently a **pure seam** — `public.dart` only, re-exporting legacy channel pages and `channel_service`; no DDD domain layer extracted yet.

---

## 结构 / Structure

| 层 / Layer | 文件 | 职责 |
|---|---|---|
| **presentation（seam）** | `public.dart` | 收敛频道入口：channel_admin / create / detail / discover / edit / invitation / list / subscriber 页面 + `channel_provider` + `channel_service` |

> **现状**：本上下文为遗留代码之上的稳定 seam，`domain/`/`application/`/`infrastructure/` 暂未抽取。上层经 `public.dart` 导入，**勿深链 page/service 内部**——为后续 DDD 抽取保留迁移自由度。

---

## 待办与技术债 / TODO & Tech Debt

- **DDD 抽取（按需）**：频道权限/订阅/可见性等不变量若出现散落判定，再抽 `domain/` 充血实体与仓储端口（参照 messaging 模式）。当前不预抽（YAGNI）。

---

## 变更记录 / Changelog

| 日期 | 内容 |
|------|------|
| 2026-06-02 | T4.3 余项：首次创建 channel_content 模块文档（双语），记录 seam 现状与抽取留痕 |

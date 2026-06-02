> [imboy.pub 根目录](../../../../CLAUDE.md) > [imboyapp](../../../CLAUDE.md) > **modules/ops_governance（运维治理模块）**

# ops_governance 模块 — 限界上下文 seam / Ops Governance Bounded Context

> 最后更新 / Last updated：2026-06-02 | DDD 充血改造 Phase 4（T4.3 余项）

---

## 文档双语规则 / Bilingual Rule (MANDATORY)

- 简体中文为权威版本，English 在同一文件同步。代码/命令/标识符不翻译。
- Simplified Chinese is source of truth; English synced in the same file.

---

## 模块定位 / Module Scope

`lib/modules/ops_governance/` 是**运维治理限界上下文**：反馈、设置（暗色/字号/语言/存储/帮助）、版本与升级、通知、特性开关、用户设备管理、注销账号。当前为**纯 seam**——仅 `public.dart` 收敛对外入口，re-export 遗留 mine/设置页面与服务（`feature_registry` / `NotificationService` / `AppVersionApi` / `FeedbackApi`），**尚未抽取 DDD 领域层**。

`lib/modules/ops_governance/` is the **ops governance bounded context**: feedback, settings, version/upgrade, notification, feature flags, user devices, account logout. Currently a **pure seam** — `public.dart` only; no DDD domain layer extracted yet.

---

## 结构 / Structure

| 层 / Layer | 文件 | 职责 |
|---|---|---|
| **presentation/service（seam）** | `public.dart` | 收敛运维治理入口：feedback / setting / dark_model / font_size / language / storage_space / help / logout_account / user_device 页面 + `upgrade` + `feature_registry` + `NotificationService` + `AppVersionApi` + `FeedbackApi` |

> **现状**：遗留代码之上的稳定 seam，`domain/` 暂未抽取。上层经 `public.dart` 导入，**勿深链内部**。

---

## 待办与技术债 / TODO & Tech Debt

- **DDD 抽取（按需）**：特性开关/设备策略等不变量若出现散落判定，再抽 `domain/`。当前以 seam + 既有 service 为主（YAGNI）。

---

## 变更记录 / Changelog

| 日期 | 内容 |
|------|------|
| 2026-06-02 | T4.3 余项：首次创建 ops_governance 模块文档（双语），记录 seam 现状与抽取留痕 |

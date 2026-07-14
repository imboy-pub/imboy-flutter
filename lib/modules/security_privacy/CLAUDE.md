> [imboy.pub 根目录](../../../../CLAUDE.md) > [imboyapp](../../../CLAUDE.md) > **modules/security_privacy（安全隐私模块）**

# security_privacy 模块 — 限界上下文 seam / Security & Privacy Bounded Context

> 最后更新 / Last updated：2026-06-02 | DDD 充血改造 Phase 4（T4.3 余项）

---

## 文档双语规则 / Bilingual Rule (MANDATORY)

- 简体中文为权威版本，English 在同一文件同步。代码/命令/标识符不翻译。
- Simplified Chinese is source of truth; English synced in the same file.

---

## 模块定位 / Module Scope

`lib/modules/security_privacy/` 是**安全隐私限界上下文**：端到端加密（E2EE）密钥、口令/恢复密钥加密的云/本地备份（与 Matrix 4S 等价，密钥找回唯一路径）、健康检查。当前为**纯 seam**——仅 `public.dart` 收敛对外入口，re-export E2EE 设置页面与一组 E2EE 服务，**尚未抽取 DDD 领域层**。
（自研社交恢复 Shamir 分片、设备间 RSA 中转传输已下线，2026-07-14。）

`lib/modules/security_privacy/` is the **security & privacy bounded context**: E2EE keys, password/recovery-key encrypted cloud/local backup (Matrix 4S-equivalent, the sole key-recovery path), health check. Currently a **pure seam** — `public.dart` only; no DDD domain layer extracted yet. (Self-hosted Shamir social recovery + RSA device transfer removed 2026-07-14.)

---

## 结构 / Structure

| 层 / Layer | 文件 | 职责 |
|---|---|---|
| **presentation/service（seam）** | `public.dart` | 收敛 E2EE 入口：e2ee_key_recovery / backup_* 页面 + `e2ee_crypto_service`（含 generateRecoveryKey）/ `e2ee_key_service` / `e2ee_service` / `e2ee_local_backup_service` / `e2ee_health_check_service` 等服务 |

> **现状**：遗留代码之上的稳定 seam，`domain/` 暂未抽取。E2EE 为安全敏感域，任何领域抽取须经安全评审 + 严格回归。上层经 `public.dart` 导入，**勿深链内部**。

---

## 待办与技术债 / TODO & Tech Debt

- **DDD 抽取（按需，高敏感）**：密钥生命周期/恢复门限/转移握手等不变量若需内聚，再抽 `domain/` 充血实体——但 E2EE 改动须安全评审 + 真机端到端回归，不宜随手抽取。
- **跨上下文**：`e2ee_service` 被 messaging 的 `message_model_mapper`（T4.4b）用于消息解密——跨上下文协作经稳定服务入口。

---

## 变更记录 / Changelog

| 日期 | 内容 |
|------|------|
| 2026-06-02 | T4.3 余项：首次创建 security_privacy 模块文档（双语），记录 E2EE seam 现状与高敏感抽取约束 |

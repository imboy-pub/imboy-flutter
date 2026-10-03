# 安全策略 / Security Policy — imboyapp（Flutter 客户端）

> imboyapp 是 IMBoy 的移动客户端（Android / iOS），持有设备 E2EE 密钥、
> 本地消息库与附件缓存。本文件声明移动端的披露面与支持策略；
> 全平台统一策略（响应 SLA、PGP、公告流程）见后端主仓
> [imboy/SECURITY.md](https://github.com/imboy-pub/imboy/blob/main/SECURITY.md)，
> 两处冲突时以主仓为准。

---

## 受支持的版本 / Supported Versions

| 版本 | 状态 | 支持截止 |
|------|------|---------|
| 跟随 `1.0.0-alpha.x` 公测线 | ⚠️ 公测中，尽力而为修复 | —— |
| `0.8.x`（app） | ⚠️ 仅修高危 | 1.0.0 GA 后 3 个月 |
| `< 0.8` | ❌ 不再支持 | —— |

版本号以 `pubspec.yaml` 的 `version` 与应用商店发布号为准。

---

## 漏洞上报 / Reporting a Vulnerability

**请不要通过公开 Issue 报告安全漏洞。**

<!-- TODO(用户填写)：本仓独立上报渠道待定。
     当前请使用后端主仓 SECURITY.md 的渠道（security@imboy.pub /
     GitHub Security Advisory），并注明影响组件为 imboyapp。
     若 imboyapp 需要独立渠道（专属邮箱 / advisory 仓库），
     由维护者补充在此处，勿由 AI 或贡献者代填。 -->

当前渠道（指回主仓）：

1. 邮件：见 [imboy/SECURITY.md](https://github.com/imboy-pub/imboy/blob/main/SECURITY.md) 上报渠道一节（支持 PGP）。
2. GitHub Security Advisory：在后端主仓私密上报，注明 `component: imboyapp`。

### 请在报告中包含

- App 版本、平台（Android/iOS）、系统版本
- 复现步骤（最小 PoC；本地数据库/密钥相关问题请附带设备是否越狱/root）
- 影响评估（密钥泄露 / 明文落地 / 降级攻击 / 本地未授权访问 / 其他）

---

## 安全边界声明 / Scope

### 在范围内

- 本地密钥材料保护：Keystore/Keychain 外泄、pickle key 管理、
  备份文件加密（PBKDF2 参数、GCM 认证）、备份导出/导入边界
- E2EE 协议客户端实现：Olm/Megolm（vodozemac）调用面、PFv3 信封
  解析、密钥协商（X3DH claim）、TOFU/安全号码、降级与回退路径
- 未加密出口：日志/通知/剪贴板中的明文泄露、元数据暴露面
- 本地存储：SQLite 加密、附件缓存清理、剪贴板驻留
- 供应链：`pubspec.lock` 依赖中的已知漏洞（尤其 flutter_vodozemac /
  crypto / pointycastle 等密码学关键依赖）

### 不在范围内

- 后端服务漏洞（请报主仓）
- 需要物理持有已解锁设备且已越狱/root 的本地攻击（超出威胁模型，
  详见 E2EE 审计报告的威胁定义）
- 缺失加密的暴力穷举（无具体弱点的泛泛报告）

---

## 依赖供应链 / Supply Chain

- SBOM 与 CVE 扫描：`bash scripts/sbom_check.sh`（osv-scanner，
  CycloneDX 1.5 + OSV 查询；产物输出到仓外临时目录，不入仓）
- 密码学关键依赖版本变更须在 CHANGELOG 安全段记录
  （`flutter_vodozemac` / `crypto` / `pointycastle`）
- 新增涉及加密/网络/存储的第三方依赖需经过准入评审（安全性 + 维护活跃度）

---

## 安全相关文档索引

- E2EE 审计：`imboy/docs/security/audits/e2ee-2026-09-07/E2EE_AUDIT_REPORT.md`
- E2EE 元数据可见性矩阵：`imboy/docs/compliance/e2ee-visibility-matrix.md`
- 生产加固计划：`imboy/docs/design/2026-10-03-e2ee-production-excellence/plan.md`

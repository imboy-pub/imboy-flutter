# 安全政策 / Security Policy

[English](#security-policy) | 简体中文

---

## 安全政策

### 支持版本 / Supported Versions

| 版本 | 支持状态 |
|------|----------|
| 最新发布版 (latest) | ✅ 安全更新支持 |
| 上一个主版本 | ⚠️ 仅重大漏洞 |
| 更早版本 | ❌ 不支持 |

### 报告漏洞 / Reporting a Vulnerability

**请勿在 GitHub Issues 中公开报告安全漏洞。**

请通过以下方式私下报告：

- **邮箱**：andyzhengper@gmail.com
- **响应时间**：工作日 72 小时内确认收到
- **披露流程**：确认漏洞后协商负责任的公开披露时间（通常 90 天内）

### 范围 / Scope

以下内容在安全报告范围内：

- 消息内容泄露（E2EE 绕过）
- 身份认证 / 授权绕过
- 本地数据库（SQLite）未授权访问
- WebSocket / WebRTC 中间人攻击
- 资源 URL 授权签名伪造
- 个人信息（PII）数据泄露

以下内容**不在**安全报告范围内：

- 已知的第三方依赖漏洞（请直接上报给对应库）
- 需要物理访问设备的攻击
- 社会工程学攻击

---

## Security Policy

### Supported Versions

| Version | Supported |
|---------|-----------|
| Latest release | ✅ Security updates |
| Previous major | ⚠️ Critical only |
| Older versions | ❌ Not supported |

### Reporting a Vulnerability

**Please do NOT report security vulnerabilities via GitHub Issues.**

Report privately via:

- **Email**: andyzhengper@gmail.com
- **Response time**: Acknowledgement within 72 business hours
- **Disclosure**: Coordinated disclosure negotiated after confirmation (typically within 90 days)

### Scope

In scope:

- Message content leakage (E2EE bypass)
- Authentication / authorization bypass
- Local SQLite database unauthorized access
- WebSocket / WebRTC man-in-the-middle
- Resource URL authorization signature forgery
- PII data leakage

Out of scope:

- Known vulnerabilities in third-party dependencies (report to the library directly)
- Attacks requiring physical device access
- Social engineering

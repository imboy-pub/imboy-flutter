<!-- Generated: 2026-06-18 | Last updated: 2026-06-18 CST -->

# 架构文档索引 | Architecture Documentation Index

**本 CODEMAPS 包的最后生成时间 / Last Generated:** 2026-06-18 CST
**覆盖范围 / Coverage:** lib/ (773 files) + test/ (204 files)
**总 Token 数 / Total Tokens:** ~3200 (精简架构文档)

---

## 快速导航 | Quick Navigation

### 1️⃣ 架构总览 | System Architecture
**文件：** [`architecture.md`](./architecture.md)

适合阅读对象：
- 新加入团队的工程师（理解整体设计）
- 架构决策者（理解选型原因）
- 系统维护者（理解各模块职责）

**核心内容：**
- ✅ 技术栈速查表
- ✅ 数据流图（消息管道 + 通知网关）
- ✅ 模块映射 (lib/ 773 文件组织)
- ✅ Service 子模块结构
- ✅ 关键服务列表
- ✅ 最近重大变化 (2026-06)

**关键概念：**
```
用户 → Page (ConsumerWidget)
  → Provider/Notifier (Riverpod)
    → InboundPipeline (Chain of Responsibility)
      → DeduplicationStage (去重)
    → Repository (SQLite)
    ← NotificationGateway (纯函数决策)
```

---

### 2️⃣ 前端架构 | Frontend Architecture
**文件：** [`frontend.md`](./frontend.md)

适合阅读对象：
- Flutter/UI 工程师
- 页面开发者
- 组件库维护者

**核心内容：**
- ✅ 页面树（22 个特性模块，368 files）
- ✅ 组件层次（111 个可复用组件）
- ✅ ChatPage Mixin 分层架构（8 个 Mixin，关注点分离）
- ✅ 路由导航（go_router 完整路由表）
- ✅ 状态管理流（Riverpod Provider 模式）
- ✅ 关键 Provider/Notifier 伪代码
- ✅ 设计令牌（色彩、间距、触达区域）

**最近更新：**
- 页面文件数 313 → 368（主要来自 page/mine +85、page/chat +29、page/group +10、page/contact +1）
- 模块精细化（messaging +22, security_privacy, identity 等 8 个 DDD 模块确立）
- ChatPage Mixin 架构稳定（1808 行）

---

### 3️⃣ 数据架构 | Data Architecture
**文件：** [`data.md`](./data.md)

适合阅读对象：
- 数据库工程师
- 后端协作者
- 数据迁移负责人

**核心内容：**
- ✅ 数据库配置（SQLCipher v19, AES-256 加密）
- ✅ 核心表（msg_c2c, msg_c2g, conversation, group_member 等）
- ✅ 仓库层（18 个 Repo 类）
- ✅ 模型层（31 个数据模型）
- ✅ 迁移系统（upgrade.sql, downgrade.sql）
- ✅ 加密架构（密钥存储、DB 加密、备份）
- ✅ ID 系统（TSID、conv_key、conv_seq）

**最近迁移 (v21)：**
- 消息去重索引 `COALESCE(comment_id, '')` 修复（moment_notify 表）
- E2EE 架构完善（private_key 存储、key_id 一致性）
- 频道表全系稳定 (channel, channel_message, channel_subscription)

---

### 4️⃣ 依赖管理 | Dependency Management
**文件：** [`dependencies.md`](./dependencies.md)

适合阅读对象：
- 构建工程师
- 依赖升级负责人
- 安全审计员

**核心内容：**
- ✅ 外部服务映射（后端、Sentry、Firebase、高德地图）
- ✅ 核心依赖列表（80+ 包分类明细）
- ✅ 版本约束策略（锁定 vs 浮动）
- ✅ 技术债清单
  - 🔴 Critical: win32 5.x override (file_picker 升级阻塞)
  - 🟡 High: GetX 遗留迁移 (进度 ~60%)
  - 🟡 High: CachedNetworkImage 弃用指南
- ✅ 安全审计（已知漏洞检查）
- ✅ 更新检查清单 & 升级路线图

---

## 使用指南 | How to Use

### 场景 1：理解系统架构

```
1. 阅读 architecture.md § 技术栈
2. 阅读 architecture.md § 数据流
3. 阅读 architecture.md § 关键服务
4. 参考 CLAUDE.md § WebSocket API v2.0（消息格式）
```

### 场景 2：开发新页面

```
1. 阅读 frontend.md § 路由导航（找到合适的路由节点）
2. 阅读 frontend.md § 状态管理流（学习 Riverpod Provider 模式）
3. 参考 frontend.md § 关键 Provider 伪代码
4. 阅读 lib/DESIGN.md（UI 设计约束）
```

### 场景 3：修改数据库表

```
1. 阅读 data.md § 核心表（确认表名和字段）
2. 阅读 data.md § 仓库层（找到对应 Repo 类）
3. 编写迁移脚本 assets/migrations/upgrade.sql
4. 更新 data.md § 迁移系统 并记录版本
```

### 场景 4：升级依赖

```
1. 检查 dependencies.md § 技术债清单
2. 运行 dependencies.md § 更新检查清单
3. 更新 pubspec.yaml，运行 flutter pub get
4. 重新生成代码 dart run build_runner build
5. 运行完整测试 flutter test
6. 更新本 INDEX.md 元数据
```

---

## 文档更新周期 | Documentation Maintenance Schedule

| 频率 / Frequency | 任务 / Task | 检查点 / Checkpoints |
|-----------|---------|---------|
| **每周** / Weekly | 检查 git log，合并显著变化 (>30% 内容) | `git log --since "7 days ago"` |
| **每月** / Monthly | 更新元数据（文件数、Token 数、ETA） | 更新本文 § 快速导航 |
| **每季** / Quarterly | 技术债清单审查与升级规划 | dependencies.md § 升级路线图 |
| **每半年** / Semi-annually | 完整内容审计（一致性、准确性） | 全文逐行验证 |

---

## 三大关键理解 | Three Key Insights

### 1. 消息处理管道 (Pipeline Architecture)

```
原始消息 (WebSocket / S2C)
  ↓
InboundPipeline.execute(message)
  ├── Stage 1: DeduplicationStage
  │   └── 消息去重（防重复推送）
  ├── Stage 2: ValidationStage (可扩展)
  │   └── 消息格式校验
  └── Stage 3: ... (链式可拓展)

管道特性：
✅ 纯 Dart，不依赖 Flutter / sqflite
✅ 责任链模式，任何 stage 返回 null 就中断
✅ 每个 stage 可对消息做变换
✅ 消息处理完全可测试化
```

### 2. 通知决策网关 (Notification Gateway)

```
消息到达
  ↓
evaluateNotification({
  isFromSelf,        // 是否自己发的
  isUserInChat,      // 是否在聊天页
  isMuted,           // 会话是否静音
  isMentioned,       // 是否被 @
  ...
})
  ↓
优先级决策：
  1️⃣ isFromSelf = true         → Suppressed('from_self')
  2️⃣ isUserInChat = true       → Suppressed('in_chat')
  3️⃣ msgId 重复                 → Suppressed('duplicate')
  4️⃣ isMuted && !isMentioned   → Suppressed('muted')
  5️⃣ 其他（含 @穿透）           → Allow
```

### 3. DDD 模块化架构（2026-06 确立）

```
lib/modules/ (38 文件, 8 个领域)
├── messaging/        22  C2C/C2G 消息领域（充血模型）
├── social_graph/      3  好友关系与关系链
├── group_collab/      5  群组协作（任务/投票/日程）
├── identity/          3  身份认证与账户管理
├── security_privacy/  1  端对端加密与隐私
├── moment_social/     2  朋友圈与社交动态
├── channel_content/   1  频道内容订阅
└── ops_governance/    1  运营治理（举报/审核）

特点：
✅ 边界清晰，单向依赖
✅ 每个模块独立演进（待建 CLAUDE.md）
✅ API 层由 page/ 调用（依赖注入）
```

---

## 常见问题 | FAQ

**Q: 添加新页面，应该从何开始？**
A: 从 `frontend.md § 路由导航` 找到合适的路由节点，然后参考 `DESIGN.md` 的设计约束，最后参考现有页面的 Mixin 模式（ChatPage）。

**Q: 如何理解消息从 WebSocket 到 UI 的全流程？**
A: 依次阅读：`architecture.md § 数据流` → `CLAUDE.md § WebSocket API v2.0` → `service/CLAUDE.md § MessageService` → `frontend.md § ChatPage Mixin`

**Q: 数据库表怎么改？**
A: 先写 `assets/migrations/upgrade.sql`，然后在 `MigrationService._onUpgrade()` 中触发执行，最后更新 `data.md` 并提交迁移说明。

**Q: 为什么资源 URL 需要通过 AssetsService.viewUrl()？**
A: 服务端对所有资源 URL 签名（3600s 有效期）防止盗链，直接使用原始 URL 会 401，必须重新授权。详见 `CLAUDE.md § 资源 URL 授权规范`。

**Q: DDD 模块怎么用？**
A: 模块内部按 domain → entity → service → repository 组织，暴露 public API，由 page/ 层通过 Provider 依赖注入调用。详见各模块 CLAUDE.md（待建）。

---

## 相关文档 | Related Documentation

| 文档 / Doc | 位置 / Location | 用途 / Purpose |
|-----------|---------|---------|
| **CLAUDE.md** | `./` | 项目契约、双语规范、WebSocket API v2.0 |
| **DESIGN.md** | `./` | UI/UX 设计规范、颜色令牌、排版系统 |
| **功能状态清单** | `./docs/feature-status.md` | Feature Flag 矩阵、前后端实现状态、待解除条件 |
| **服务层文档** | `./lib/service/CLAUDE.md` | WebSocket、消息、数据库、加密 |
| **页面层文档** | `./lib/page/CLAUDE.md` | 页面模块概览、路由说明 |
| **组件层文档** | `./lib/component/CLAUDE.md` | 可复用组件、工具函数 |
| **数据层文档** | `./lib/store/CLAUDE.md` | API 客户端、Model、Repository |
| **后端接口** | `../imboy/` | Erlang/OTP 服务端代码 |

---

## 版本历史 | Version History

| 版本 / Version | 日期 / Date | 变化 / Changes |
|-----------|---------|---------|
| **2.5** | 2026-06-18 | 773 文件更新（+69）；DDD 模块确立（8 个）；page/mine/group/contact 扩充；store 模型 31/repo 18 |
| **2.4** | 2026-04-17 | 添加 Pipeline + NotificationGateway，更新频道模块，完全重写 dependencies.md |
| **2.3** | 2026-04-10 | 初始 CODEMAPS 生成（architecture, frontend, data, dependencies） |

---

## 项目维护者 / Project Maintainers

- **文档维护:** @leeyi (每周审查更新)
- **架构决策:** 技术团队 (季度评审)
- **代码同步:** CI/CD 自动验证

---

**下一个更新检查点：** 2026-06-25 (7 days)
**下一个重大审计：** 2026-07-18 (1 month)
**下一个模块审视：** 2026-09-18 (Q3)

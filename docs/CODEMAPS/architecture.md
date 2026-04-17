<!-- Generated: 2026-04-17 | Files scanned: 704 (lib/) + 204 (test/) | Token estimate: ~950 -->

# 架构总览 | Architecture Overview

**最后更新 / Last Updated:** 2026-04-17 CST
**状态 / Status:** Riverpod 100% migrated, Pipeline + Notification Gateway added

---

## 系统类型 | System Type

单 Flutter 应用（跨平台 IM）+ 嵌入式插件
Single Flutter application (cross-platform IM) with embedded plugins.

---

## 技术栈 | Tech Stack

| 层级 / Layer | 技术 / Tech | 模式 / Pattern |
|-----------|---------|---------|
| 表现层 / Presentation | Flutter 3.8+ / Material 3 | MVVM |
| 状态管理 / State | Riverpod 3.3.1（100% 迁移自 GetX）| Provider |
| 路由 / Routing | go_router 17.0.1 | 声明式 / Declarative |
| 数据 / Data | Repository + SQLite (SQLCipher AES-256) | Clean Architecture |
| 网络 / Network | Dio 5.9 (HTTP/2) + WebSocket | REST + Real-time |
| 加密 / Crypto | E2EE (RSA+AES), Shamir 密钥碎片 | Zero-trust |
| 国际化 / i18n | slang 4.14 (code-gen) | 11 languages |
| 平台 / Platform | iOS, Android, macOS, Web | 跨平台 / Cross-platform |

---

## 数据流 | Data Flow

```
用户操作 / User Action
  → 页面 (ConsumerWidget)
    → Provider/Notifier (Riverpod)
      → 消息管道 (InboundPipeline) ──→ 去重阶段 (DeduplicationStage)
      → 仓库 (Repository / SQLite) ──┐
      → API 客户端 (Dio/HTTP) ├→ 数据模型 / Model
      → WebSocket (实时) ┘
    ← 通知网关 (NotificationGateway) → 系统通知 / System Notification
    ← 状态更新 / State Update
  ← UI 重建 / UI Rebuild
```

---

## 模块映射 | Module Map (lib/)

```
lib/                    704 files
├── page/               313  屏幕/路由视图 (22 个特性模块)
├── component/          113  可复用组件 & 工具
├── service/            102  核心服务 (WebSocket, 消息, DB, E2EE, Pipeline)
├── store/               74  API(32) + Model(25) + Repo(17)
├── config/              19  环境配置, 初始化, 路由, 常量
├── modules/             13  领域模块 (messaging, security)
├── theme/               13  颜色, 排版, 间距
├── i18n/                11  生成的翻译文件
├── app_core/             3  特性标志, 路由守卫
├── utils/                2  TSID, 会话密钥生成
├── plugins/              2  插件系统
├── features/             1  实验性功能
├── main.dart                 入口点 (Sentry 初始化)
└── run.dart                  备选入口 (全局错误处理器)
```

---

## 服务子模块 | Service Subdirectories

```
service/                102 files
├── pipeline/            2  消息入站管道 + 去重阶段 (Chain of Responsibility)
├── e2ee/               18  E2EE 加密服务 (RSA, Shamir, Key management)
├── events/             12  S2C 事件派发器 (group_edit, role_change, mute...)
├── protocol/            3  WebSocket 协议处理
├── cache/               2  消息缓存 + 查询缓存
└── [90 core services]      WebSocket, 消息, SQLite, 存储, 通知, 迁移等
```

---

## 插件结构 | Plugin Structure

```
plugin/
├── flutter_chat_ui/   107  自定义聊天 UI (8 个消息类型子包)
├── jverify/             5  极光验证 SDK
└── r_upgrade/           8  应用升级功能
```

---

## 关键架构决策 | Key Architectural Decisions

| 决策 / Decision | 实现 / Implementation | 理由 / Rationale |
|-----------|---------|---------|
| 消息管道 / Message Pipeline | `InboundPipeline` + `DeduplicationStage` | 可拓展、纯 Dart、支持链式处理 |
| 通知决策 / Notification Gate | `NotificationGateway.evaluateNotification()` | 纯函数、可测试、解耦业务逻辑 |
| SQLCipher 加密 / Encryption | 强制 AES-256 全库加密，无可选项 | 所有本地数据安全第一 |
| 用户隔离 / User Isolation | `{env}_{uid}.db` 独立数据库 | 防数据泄露，支持多账号 |
| TSID 跨栈一致性 | String 字段（客户端）vs binary（后端） | 整数精度与 JSON 兼容性平衡 |
| 会话密钥 / Conv Key | `c2c:{min_uid}:{max_uid}` 或 `c2g:{gid}` | 确定性、可排序、支持快速查询 |

---

## 关键服务 | Key Services

| 服务 / Service | 文件 / File | 职责 / Responsibility |
|-----------|---------|---------|
| **WebSocket** | `websocket.dart` | 连接管理、心跳、自动重连 |
| **消息核心** / Message Core | `message.dart` + `message_*.dart` | 发送、接收、重试、离线处理 |
| **消息管道** / Message Pipeline | `pipeline/inbound_pipeline.dart` | 责任链处理、去重、转换 |
| **通知网关** / Notification Gate | `notification_gateway.dart` | 通知决策（自己/正在聊/静音/@穿透） |
| **SQLite DB** | `sqlite.dart` + `cached_sqlite_service.dart` | CRUD + 缓存 + 事务 + WAL |
| **迁移 / Migration** | `migration_service.dart` | 版本升级、备份、恢复 |
| **加密 / E2EE** | `e2ee/**/*.dart` | RSA + AES-GCM + Shamir 密钥 |
| **存储 / Storage** | `storage.dart` + `storage_secure.dart` | KV 对存储 + 安全存储 |
| **事件总线 / Event Bus** | `event_bus.dart` | 服务间解耦通信 |
| **S2C 派发** / S2C Dispatch | `message_s2c.dart` + `*_s2c.dart` | 服务端推送事件处理 |

---

## 状态管理拓扑 | State Management Topology

```
Riverpod Providers (100% migrated)
├── 页面 Provider / Page                   (ChatProvider, ConversationProvider, etc.)
├── 数据源 Provider / Data Source           (UserRepoProvider, MessageRepoProvider)
├── 聚合 Provider / Aggregator             (UnreadCountProvider, OfflineProvider)
├── 缓存 Provider / Cache                  (CachedImageProvider, QueryCacheProvider)
└── 全局 Provider / Global                 (WebSocketStatusProvider, UserProvider)

Key Notifiers:
├── ChatNotifier              管理当前聊天状态、消息列表、输入框
├── ConversationNotifier      管理会话列表、未读数、最后消息
├── ContactNotifier           管理联系人、搜索、标签
└── [其他页面 Notifier]
```

---

## 命名约定 | Naming Conventions

| 类型 / Type | 后缀 / Suffix | 示例 / Example |
|-----------|---------|---------|
| 页面 / Page | `_page.dart` | `chat_page.dart`, `group_detail_page.dart` |
| 提供者 / Provider | `_provider.dart` | `chat_provider.dart`, `contact_provider.dart` |
| 模型 / Model | `_model.dart` | `message_model.dart`, `conversation_model.dart` |
| 仓库 / Repository | `_repo.dart` / `_repo_sqlite.dart` | `message_repo_sqlite.dart` |
| API 客户端 / API | `_api.dart` | `message_api.dart`, `user_api.dart` |
| S2C 派发 / S2C | `_s2c.dart` | `group_edit_s2c.dart`, `message_s2c.dart` |
| 纯函数规则 / Pure Rules | `_rules.dart` | `notification_gateway.dart`, `mention_all_rules.dart` |
| 服务 / Service | `.dart` | `websocket.dart`, `sqlite.dart` |

---

## 注视重点 | Important Notes

**🚨 最近重大变化 / Recent Major Changes:**
1. **InboundPipeline** (2026-04-17)：去重 + 可拓展的消息处理链
2. **NotificationGateway** (2026-04-17)：纯函数通知决策（支持 @穿透免打扰）
3. **Riverpod 100%** (2026-01-16)：完全删除 GetX，所有状态管理迁移完成
4. **频道模块** (2026-04-15)：新增频道订阅、群组频道置顶区
5. **群成员禁言** (2026-04-15)：跨栈完整闭环（数据库 → S2C → 权限规则 → UI）

**⚠️ 已知债务 / Known Tech Debt:**
- `pubspec.yaml` 中 3 个 `win32` 版本 override（`file_picker` 迁移 win32 6.x 后解锁）
- Android 模拟器不支持（仅使用真机开发 / Android 开发必须用真机）
- 部分 Service 仍使用 GetIt 单例（逐步迁移到 Riverpod）

---

**相关文档 / Related Docs**
- [`frontend.md`](./frontend.md) — 页面树、组件层次、路由
- [`data.md`](./data.md) — 数据库表、模型、迁移
- [`dependencies.md`](./dependencies.md) — 外部依赖、版本
- [`backend.md`](./backend.md) — 后端服务接口（Erlang/OTP）

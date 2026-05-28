<!-- Generated: 2026-05-27 | Files: 704 lib/ + 204 test/ | See also: INDEX.md, architecture.md, frontend.md -->

# CODEMAPS Overview / 总览

> 双语 / Bilingual: 中文权威，English mirror.
> 本文件是 imboyapp Flutter 客户端 CODEMAPS 的聚焦索引，补充 INDEX.md 中缺少的层级图和核心数据流细节。
> This file is the focused index for the imboyapp Flutter client CODEMAPS, adding layer diagrams and core data flow details not in INDEX.md.

---

## 文件索引 | File Index

| 文件 / File | 内容 / Content |
|---|---|
| [INDEX.md](./INDEX.md) | 全包索引、快速导航 / Full package index, quick navigation |
| [architecture.md](./architecture.md) | 技术栈、数据流、模块映射、服务子模块 / Stack, data flow, module map, service subdirs |
| [frontend.md](./frontend.md) | 页面树、组件库、路由配置 / Page tree, component lib, routing |
| [backend.md](./backend.md) | API 端点映射、Store/Repo 结构 / API endpoint map, Store/Repo structure |
| [data.md](./data.md) | SQLite schema v21、Model 定义、迁移脚本 / SQLite schema, Model defs, migrations |
| [dependencies.md](./dependencies.md) | pubspec 依赖、平台插件约束 / pubspec deps, platform plugin constraints |

---

## Flutter 层级图 | Flutter Layer Diagram

```
┌─────────────────────────────────────────────────────────┐
│                  page/ (313 files)                       │
│  ConsumerWidget 路由页面，22 个特性模块                    │
│  Feature modules: chat, group, moment, profile, e2ee…   │
└─────────────────────────┬───────────────────────────────┘
                          │ Riverpod Provider/Notifier
┌─────────────────────────▼───────────────────────────────┐
│               component/ (113 files)                     │
│  可复用 Widget（Avatar, ChatBubble, IMBoyInput…）         │
│  Reusable widgets; design tokens via AppColors/AppSpacing│
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│                 service/ (102 files)                     │
│  核心业务服务 / Core business services                    │
│  ├── WebSocketService          实时连接管理               │
│  ├── MessageService            消息收发编排               │
│  ├── DatabaseService           SQLite 连接池              │
│  ├── pipeline/InboundPipeline  入站消息管道               │
│  ├── pipeline/DeduplicationStage 去重阶段                 │
│  ├── e2ee/ (18)                端到端加密                 │
│  ├── events/ (12)              S2C 事件派发               │
│  ├── protocol/ (3)             WS 协议处理                │
│  └── cache/ (2)                消息缓存                   │
└─────────────────────────┬───────────────────────────────┘
                          │ Repository pattern
┌─────────────────────────▼───────────────────────────────┐
│                  store/ (74 files)                       │
│  ├── api/ (32)    Dio HTTP 客户端封装                     │
│  ├── model/ (25)  数据模型（MessageModel.id = String Xid）│
│  └── repo/ (17)   Repository 接口 + SQLite 实现           │
└─────────────────────────┬───────────────────────────────┘
                          │
          ┌───────────────┴───────────────┐
          │                               │
┌─────────▼──────────┐        ┌──────────▼──────────┐
│  SQLite (sqflite)  │        │  Dio HTTP / WebSocket│
│  schema v21        │        │  → imboy 后端         │
│  SQLCipher AES-256 │        │  Erlang/OTP           │
└────────────────────┘        └─────────────────────┘

┌─────────────────────────────────────────────────────────┐
│  config/ (19)   环境配置、go_router 路由、常量            │
│  theme/ (13)    AppColors · AppSpacing · FontSizeType    │
│  i18n/ (11)     slang 生成，zh-CN 权威，11 语言支持       │
│  modules/ (13)  领域模块 (messaging, security)           │
│  utils/ (2)     TSID 工具、会话密钥生成                   │
└─────────────────────────────────────────────────────────┘
```

---

## 核心数据流 | Core Data Flow

### WebSocket → MessageService → SQLite → UI

```
后端推送 / Server Push
  │  WebSocket frame (JSON)
  ▼
WebSocketService (lib/service/)
  │  onMessage callback
  ▼
InboundPipeline (lib/service/pipeline/inbound_pipeline.dart)
  │  Chain of Responsibility
  ▼
DeduplicationStage (lib/service/pipeline/deduplication_stage.dart)
  │  幂等去重（conv_seq / msg_id）
  ▼
MessageService (lib/service/)
  │  业务分发：C2C / C2G / S2C 事件
  ├──► events/EventDispatcher (lib/service/events/)   # S2C 系统事件
  │       → group_edit / role_change / mute / kick…
  ▼
MessageRepository (lib/store/repo/)
  │  SQLite insert / upsert（schema v21）
  ▼
Riverpod Notifier 状态更新 / State Invalidation
  │  ref.invalidate / ref.notifyListeners
  ▼
ConsumerWidget UI 重建 / UI Rebuild
  │  ListView.builder / ChatBubble
  ▼
用户可见 / Visible to User
```

### 用户发送消息 | User Sends Message

```
UI (ChatInputWidget)
  → MessageService.send(content, convKey)
    → MessageRepository.insertOptimistic()     # 乐观插入本地
    → api/MessageApi.send()                    # Dio POST /msg/c2c
      → 后端 msg_handler → msg_c2c_logic
    → WebSocket ACK 回调
      → MessageRepository.confirmDelivered()   # 更新状态
```

### 附件资源加载 | Asset URL Authorization

```
任意附件 URL
  → AssetsService.viewUrl(url)     # 重新授权，有效期 3600s
    → cachedImageProvider(url)     # 内置授权调用
      → IMBoyCacheManager          # flutter_cache_manager
        → CachedNetworkImage       # 渲染
```

> **CRITICAL**: 禁止直接用 `Image.network(url)` 或 `CachedNetworkImage(url)`。
> **CRITICAL**: Never use `Image.network(url)` or `CachedNetworkImage(url)` directly.

---

## Service → Page → Module 对应关系 | Service → Page → Module Map

| Service | 对应 Page 模块 / Page Module | 关键 Provider |
|---|---|---|
| `WebSocketService` | 全局 / Global | `webSocketProvider` |
| `MessageService` | `page/chat/` | `messageListProvider`, `conversationProvider` |
| `DatabaseService` | 全局 / Global | `databaseProvider` |
| `e2ee/E2eeService` | `page/chat/`, `page/profile/` | `e2eeStateProvider` |
| `events/EventDispatcher` | `page/group/`, `page/chat/` | `groupInfoProvider` |
| `NotificationGateway` | 全局 / Global | `notificationProvider` |
| `AssetsService` | `component/` (Avatar, ImageViewer) | `assetsProvider` |

---

## 关键文件速查 | Key Files Quick Reference

### 入口 | Entry

```
lib/main.dart                     # Sentry 初始化、ProviderScope、go_router
lib/run.dart                      # 全局错误处理器入口
lib/config/router.dart            # go_router 路由声明
lib/app_core/feature_flags.dart   # 特性开关
```

### 消息管道 | Message Pipeline

```
lib/service/websocket_service.dart
lib/service/message_service.dart
lib/service/pipeline/inbound_pipeline.dart
lib/service/pipeline/deduplication_stage.dart
lib/service/events/                            # S2C 事件派发器
```

### 数据层 | Data Layer

```
lib/store/repo/message_repository.dart        # 消息 CRUD（SQLite）
lib/store/repo/conversation_repository.dart   # 会话 CRUD
lib/store/model/message_model.dart            # id: String (Xid base32hex)
lib/store/api/message_api.dart                # Dio 封装
assets/migrations/                            # SQLite v1→v21 迁移脚本
```

### 主题 | Theme

```
lib/theme/app_colors.dart                     # #2474E5 品牌蓝、iosBlue、iosRed
lib/theme/app_spacing.dart                    # 间距 Token（水平 padding=16pt）
lib/theme/font_size_type.dart                 # 字号 Token
```

### E2EE

```
lib/service/e2ee/                             # RSA-OAEP-256 + AES-256-GCM
lib/service/e2ee/shamir_service.dart          # Shamir 密钥碎片
```

---

## 约定速查 | Convention Quick Reference

| 规范 / Rule | 要点 / Detail |
|---|---|
| 消息 ID 类型 | `MessageModel.id` 为 `String`（Xid base32hex）；禁止 `int.tryParse` |
| 资源 URL | 必须经 `AssetsService.viewUrl` 重授权后使用 |
| 颜色 | 品牌蓝 `AppColors.primary (#2474E5)`；禁止硬编码 hex |
| 最小触达区 | ≥ 44×44pt |
| 聊天气泡 | 圆角 20pt；发送用 `brand`，接收用 `surface` |
| SQLite 版本 | `_dbVersion = 21`；迁移脚本在 `assets/migrations/` |
| 状态管理 | 100% Riverpod；禁止残留 GetX |
| 路由 | go_router 声明式；路由定义在 `lib/config/router.dart` |
| i18n | 先改 `zh-CN.i18n.yaml` → `dart run slang` → 同步其他语言 |
| 平台保留区 | `ios/`、`macos/`、`plugin/r_upgrade` 禁止修改 |

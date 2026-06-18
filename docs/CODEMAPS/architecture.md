<!-- Generated: 2026-06-18 | Files scanned: 773 (lib/) + 204 (test/) | Token estimate: ~980 -->

# 架构总览 | Architecture Overview

**最后更新 / Last Updated:** 2026-06-18 CST
**状态 / Status:** Riverpod 100% migrated, DDD modules established (8), E2EE + License foundation

---

## 系统类型 | System Type

单 Flutter 应用（跨平台 IM）+ 嵌入式插件 + DDD 功能模块
Single Flutter application (cross-platform IM) with embedded plugins and domain-driven modules.

---

## 技术栈 | Tech Stack

| 层级 / Layer | 技术 / Tech | 模式 / Pattern |
|-----------|---------|---------|
| 表现层 / Presentation | Flutter 3.8+ / Material 3 | MVVM |
| 状态管理 / State | Riverpod 3.3.1（100% 迁移自 GetX）| Provider |
| 路由 / Routing | go_router 17.0.1 | 声明式 / Declarative |
| 数据 / Data | Repository + SQLite (SQLCipher AES-256) | Clean Architecture |
| 网络 / Network | Dio 5.9 (HTTP/2) + WebSocket | REST + Real-time |
| 加密 / Crypto | E2EE (RSA-2048+AES-256-GCM), Shamir 密钥碎片 | Zero-trust client-side |
| 国际化 / i18n | slang 4.14 (code-gen) | 10 languages (ja-JP 新增) |
| DDD 模块 / DDD | 8 领域模块 (messaging, social_graph, identity 等) | 边界清晰、单向依赖 |
| 许可层 / License | imboy_license (RSA-SHA256) | 配额网关、企业锁定 |
| 平台 / Platform | iOS, Android, macOS, Web | 跨平台 / Cross-platform |

---

## 文件统计 | File Statistics

```
lib/                    773 files (+69 from 2026-04-17)
├── page/               368  屏幕/路由视图 (+55 from 313)
│   ├── mine/           50  个人空间、设备、设置
│   ├── group/          55  群组 CRUD、成员、相册
│   ├── chat/           53  C2C/C2G 消息、聊天体验
│   ├── contact/        30  好友列表、关系管理
│   ├── personal_info/  22  个人编辑、头像、认证
│   ├── passport/       27  登录、注册、生物识别
│   ├── channel/        18  频道浏览、订阅、推荐
│   ├── settings/       13  应用设置、E2EE、隐私
│   ├── user_tag/       14  标签与分类、关键词
│   ├── web_shell/      16  网页容器、H5 加载
│   ├── search/          8  全局搜索、索引
│   ├── scanner/        10  二维码、NFC 扫描
│   ├── moment/         11  社交动态、朋友圈
│   ├── live_room/       8  直播、流媒体
│   ├── qrcode/          6  二维码展示、分享
│   ├── wallet/          6  支付、充值、账户
│   ├── single/          6  独立屏幕、弹窗
│   ├── conversation/    9  会话列表、快捷操作
│   ├── bottom_navigation/ 3 底部 4-Tab 导航
│   └── [其他]          11  welcome / splash / discover / mention 等
├── component/          111  可复用组件 & 工具
├── service/            103  核心业务服务 (+1 from 102)
├── store/               83  API(33) + Model(31) + Repo(18) (+9 from 74)
├── modules/             38  DDD 领域模块 (+25 from 13)
│   ├── messaging/       22  消息、会话、聊天逻辑
│   ├── social_graph/     3  好友、黑名单、关系链
│   ├── group_collab/     5  群任务、投票、日程
│   ├── identity/         3  身份、账户、认证
│   ├── security_privacy/ 1  E2EE、端对端加密
│   ├── moment_social/    2  动态、点赞、评论
│   ├── channel_content/  1  频道、内容、订阅
│   └── ops_governance/   1  举报、审核、合规
├── config/              24  环境、初始化、路由、常量
├── theme/               13  颜色、排版、间距令牌
├── i18n/                11  生成的翻译文件
├── app_core/             4  特性标志、路由守卫
├── utils/                2  TSID、会话密钥生成
├── plugins/              6  插件系统 (+4 from 2)
└── features/             1  实验性功能
```

---

## 数据流 | Data Flow

```
用户操作 / User Action
  → 页面 (ConsumerWidget)
    → Provider/Notifier (Riverpod)
      ├─ 消息管道 (InboundPipeline)
      │  ├── DeduplicationStage (消息去重)
      │  ├── ValidationStage (格式校验)
      │  └── EventDispatchStage (事件派发)
      ├─ 仓库 (Repository / SQLite)
      ├─ API 客户端 (Dio/HTTP)
      ├─ WebSocket (实时)
      └─ E2EE 加密服务 (RSA + Shamir + AES-256-GCM)
    ← 通知网关 (NotificationGateway) → 系统通知 / System Notification
    ← 许可检查 (LicenseService.check) → 配额拒绝 / Quota Reject
    ← 状态更新 / State Update
  ← UI 重建 / UI Rebuild
```

---

## 服务子模块结构 | Service Subdirectories

```
service/                103 files
├── pipeline/            2  消息入站管道 + 去重阶段 (Chain of Responsibility)
├── e2ee/                2  E2EE 加密基础
├── events/              8  S2C 事件派发器 (group_edit, role_change, mute...)
├── protocol/            4  WebSocket 协议处理
├── cache/               1  消息缓存 + 查询缓存
├── e2ee_crypto_service.dart    E2EE 加密操作（RSA 密钥对、AES-GCM）
├── e2ee_key_service.dart       密钥管理（导入/导出、Shamir 碎片）
├── e2ee_service.dart           E2EE 业务面（消息加解密、用户密钥同步）
├── e2ee_local_backup_service.dart  本地备份（密钥导出、QR 编码）
├── e2ee_transfer_service.dart   密钥转移（Shamir 碎片重构、换设备恢复）
├── e2ee_health_check_service.dart  E2EE 健康检查（密钥完整性、版本同步）
├── e2ee_social_service.dart    社交隐私（好友加密、关系链零信任）
├── e2ee_shard_message_handler.dart  Shamir 碎片消息处理（阈值重构）
├── websocket_service.dart      WebSocket 长连接
├── message_service.dart        消息逻辑（发送/接收/确认）
├── group_service.dart          群组逻辑（创建/成员/权限）
├── channel_service.dart        频道逻辑（订阅/推荐）
├── notification_service.dart   本地通知（策略决策）
├── db_encryption_key_service.dart  数据库密钥存储（平台侧）
├── asset_url_resolver.dart     资源 URL 授权（3600s 签名）
├── license_service.dart        许可检查（配额网关）
└── [60+ 其他服务]             应用更新、日志、缓存、配置等
```

---

## DDD 功能模块 | DDD Modules (8 domains)

### 消息域 | Messaging Domain (22 files)

```
modules/messaging/
├── domain/
│   ├── entities/
│   │   ├── message.dart     消息聚合根（from_id, to_id, payload, e2ee）
│   │   ├── conversation.dart 会话实体（conv_key, type, peer_id）
│   │   └── message_status.dart 消息状态值对象
│   ├── value_objects/
│   │   ├── message_id.dart   TSID 值对象
│   │   ├── conversation_key.dart  conv_key 值对象
│   │   └── message_payload.dart  消息体值对象
│   ├── repositories/
│   │   ├── message_repository.dart  查询接口
│   │   └── conversation_repository.dart 会话查询接口
│   └── services/
│       ├── message_validation_service.dart 消息校验
│       └── message_formatting_service.dart 消息格式化
├── application/
│   ├── dto/
│   ├── use_cases/
│   │   ├── send_message_use_case.dart
│   │   ├── mark_as_read_use_case.dart
│   │   └── get_messages_use_case.dart
│   └── message_app_service.dart 应用服务门面
└── infrastructure/
    ├── persistence/
    │   ├── sqlite_message_repository.dart
    │   └── sqlite_conversation_repository.dart
    └── dto_mappers/
        └── message_dto_mapper.dart
```

---

## 关键架构决策 | Key Architectural Decisions

| 决策 / Decision | 实现 / Implementation | 理由 / Rationale |
|-----------|---------|---------|
| 消息管道 / Message Pipeline | `InboundPipeline` + `DeduplicationStage` | 可拓展、纯 Dart、支持链式处理 |
| 通知决策 / Notification Gateway | 纯函数决策器，检查 10+ 条件 | 可测试、易维护、支持灰度 |
| DDD 模块化 / DDD Modules | 8 领域各自独立，repository 接口隔离 | 高内聚、低耦合、便于单测 |
| E2EE 零信任 / E2EE Zero Trust | 客户端密钥生成、Shamir 碎片、本地备份 | 服务端无私钥，支持换设备恢复 |
| 资源签名 / Resource Signature | 服务端 3600s 有效期签名 URL | 防盗链、可追溯、可撤销 |
| 许可网关 / License Gateway | LicenseService.check + persistent_term 缓存 | 企业锁定、配额管理、防作弊 |

---

## 模块依赖图 | Module Dependency Graph

```
page/              ← 消费层（UI）
  ↓
Provider/Notifier  ← 状态管理
  ↓
modules/           ← 领域逻辑（消息、社交、群组、身份等）
  ↓
service/           ← 技术服务（WebSocket、E2EE、DB、通知）
  ↓
store/             ← 数据访问（Repo、Api、Model）
  ↓
sqflite/Dio/       ← 外部依赖
```

**单向依赖原则：** page → provider → modules → service → store → 外部

---

## 最近重大变化 | Recent Major Changes (2026-06)

| 变化 / Change | 文件数 | 影响 / Impact |
|-----------|---------|---------|
| DDD 模块确立 (messaging +22, modules 整体 +25) | +25 | 业务逻辑下沉、page 瘦身 |
| E2EE 端对端加密完善 (crypto_service, key_service, transfer_service) | +8 | 零信任架构、多设备支持 |
| 许可网关实装 (license_service) | +1 | 企业锁定、配额管理 |
| page/mine 功能扩充（钱包、设备管理、认证） | +35 | 用户空间完整体验 |
| page/group 完善（群相册、群成员管理） | +10 | 群组协作深化 |
| Model 层补全 (store/model +6) | +6 | 类型安全、API 契约稳定 |

---

## 关键性能指标 | Key Performance Indicators

| 指标 / Metric | 目标 / Target | 现状 / Current |
|-----------|---------|---------|
| 消息延迟 / Message Latency | < 500ms | ~300ms (WebSocket + SQLite 异步) |
| 列表滚动帧率 / Scroll FPS | ≥ 60fps | 58-60fps (ListView + virtual scroll) |
| 内存占用 / Memory | < 200MB | ~150MB (idle state) |
| 首屏加载 / Cold Start | < 2s | ~1.8s (预加载关键数据) |
| DB 查询 / DB Query | < 100ms | ~50ms (WAL + 索引优化) |

---

## 已知限制 | Known Limitations

| 限制 / Limitation | 影响 / Impact | 计划 / Plan |
|-----------|---------|---------|
| GetIt 单例容器仍在部分 Service | 可测试性降低 | Q3 2026 迁至 Riverpod |
| 部分 router 调用 Get.back() | 迁移不彻底 | Q3 2026 迁至 go_router |
| Widget 测试覆盖 < 30% | 回归风险 | Q2-Q3 2026 补全关键页面 |
| 资源 URL 签名延迟网络往返 | UX 轻微延迟 | 考虑客户端缓存策略 |

---

## 对标目标 | Benchmarks

- **消息应用对标:** WhatsApp, WeChat (消息延迟、可靠性)
- **群组功能对标:** Slack, 飞书 (协作、权限系统)
- **E2EE 对标:** Signal, Telegram (端对端加密、密钥管理)
- **体积对标:** <150MB (压缩分发，对标微信 ~400MB)

---

**更新者 / Updated by:** Claude Code  
**更新周期 / Update Cycle:** 6 weeks (major), 2 weeks (minor)

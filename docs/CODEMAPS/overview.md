<!-- Generated: 2026-06-18 | Files: 773 lib/ + 204 test/ | See also: INDEX.md, architecture.md, frontend.md -->

# CODEMAPS Overview / 总览

> 双语 / Bilingual: 中文权威，English mirror.
> 本文件是 imboyapp Flutter 客户端 CODEMAPS 的聚焦索引，补充 INDEX.md 中缺少的层级图和核心数据流细节。
> This file is the focused index for the imboyapp Flutter client CODEMAPS, adding layer diagrams and core data flow details not in INDEX.md.

---

## 文件索引 | File Index

| 文件 / File | 内容 / Content |
|---|---|
| [INDEX.md](./INDEX.md) | 全包索引、快速导航 / Full package index, quick navigation |
| [architecture.md](./architecture.md) | 技术栈、数据流、模块映射、DDD 模块 / Stack, data flow, module map, DDD |
| [frontend.md](./frontend.md) | 页面树、组件库、ChatPage Mixin、路由配置 / Page tree, component lib, routing |
| [backend.md](./backend.md) | API 端点映射、Store/Repo 结构 / API endpoint map, Store/Repo structure |
| [data.md](./data.md) | SQLite schema v21、Model 定义、迁移脚本、加密架构 / SQLite schema, Models, migrations, crypto |
| [dependencies.md](./dependencies.md) | pubspec 依赖、平台插件约束、技术债 / pubspec deps, platform constraints |

---

## Flutter 层级图 | Flutter Layer Diagram

```
┌──────────────────────────────────────────────────────────────┐
│                  page/ (368 files) ↑ +55                     │
│  ConsumerWidget 路由页面，22 个特性模块                       │
│  Feature modules: mine, group, chat, contact, passport…     │
│  主要增长：mine (+35), group (+10), chat (+29)                │
└──────────────────────────┬──────────────────────────────────┘
                           │ Riverpod Provider/Notifier
┌──────────────────────────▼──────────────────────────────────┐
│               component/ (111 files)                        │
│  可复用 Widget（Avatar, ChatBubble, IMBoyInput…）            │
│  Reusable widgets; design tokens via AppColors/AppSpacing   │
└──────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────┐
│                 service/ (103 files) ↑ +1                    │
│  核心业务服务 / Core business services                       │
│  ├── WebSocketService          实时连接管理                   │
│  ├── MessageService            消息收发编排                   │
│  ├── DatabaseService           SQLite 连接池                 │
│  ├── E2EEService (8 sub)       端到端加密 + 零信任密钥        │
│  ├── E2EEKeyService            密钥管理、Shamir 碎片         │
│  ├── E2EETransferService       换设备恢复                     │
│  ├── LicenseService            许可检查、配额网关            │
│  ├── pipeline/InboundPipeline  入站消息管道                   │
│  ├── pipeline/DeduplicationStage 去重阶段                     │
│  ├── events/ (8)               S2C 事件派发                   │
│  ├── protocol/ (4)             WS 协议处理                    │
│  └── cache/ (1)                消息缓存                       │
└──────────────────────────┬──────────────────────────────────┘
                           │ Repository pattern
┌──────────────────────────▼──────────────────────────────────┐
│                  store/ (83 files) ↑ +9                      │
│  ├── api/ (33)        Dio HTTP 客户端封装 ↑ +1               │
│  ├── model/ (31)      数据模型 ↑ +6                          │
│  │   MessageModel.id = String Xid                            │
│  │   新增: LicenseQuotaModel, E2EESessionModel               │
│  └── repo/ (18)       Repository 接口 + SQLite 实现 ↑ +1      │
└──────────────────────────┬──────────────────────────────────┘
                           │
          ┌────────────────┴────────────────┐
          │                                  │
┌─────────▼──────────┐        ┌──────────────▼──────────┐
│  SQLite (sqflite)  │        │  Dio HTTP / WebSocket   │
│  schema v21        │        │  → imboy 后端            │
│  SQLCipher AES-256 │        │  Erlang/OTP 28+         │
│  moment_notify去重 │        │  License验证、配额拒    │
└────────────────────┘        └─────────────────────────┘

┌──────────────────────────────────────────────────────────────┐
│  config/ (24) ↑ +5    环境配置、go_router 路由、常量          │
│  theme/ (13)          AppColors · AppSpacing · FontSizeType  │
│  i18n/ (11)           slang 生成，zh-CN 权威，10 语言         │
│  modules/ (38) ↑ +25  8 个 DDD 领域模块（messaging, 身份…）  │
│  app_core/ (4)        特性开关、路由守卫                       │
│  utils/ (2)           TSID 工具、会话密钥生成                 │
│  plugins/ (6) ↑ +4    插件体系（builtin / contracts）        │
└──────────────────────────────────────────────────────────────┘
```

---

## 核心数据流 | Core Data Flow

### 1. 消息收发流 | Message Flow

```
发送消息 / Send Message:
┌────────────┐
│ ChatPage   │  用户输入，点击发送
│ input.dart │
└──────┬─────┘
       │ ref.read(chatNotifier.notifier).sendMessage(msg)
       ▼
┌──────────────────────┐
│ ChatNotifier         │  构建 MessageModel
│ (Riverpod)           │  • from_id, to_id, payload
└──────┬───────────────┘  • created_at (ms)
       │                   • msg_type (text/image/…)
       ├─→ 1. 乐观更新 UI (status=pending)
       │
       ├─→ 2. 调用 API
       │       │ POST /v1/message/send
       │       │ payload: MessageCreateRequest
       │       └─→ e2ee_crypto_service.encrypt() ──→ AES-256-GCM
       │
       ├─→ 3. SQLite 持久化 (INSERT INTO msg_c2c)
       │
       └─→ 4. 状态更新 (status=sent/failed)
            UI 自动重建

接收消息 / Receive Message:
┌──────────────────────┐
│ WebSocketService     │  S2C 推送
│ (Persistent conn)    │  event: "message"
└──────┬───────────────┘
       │
       ▼
┌──────────────────────┐
│ InboundPipeline      │  责任链：Stage1 → Stage2 → Stage3
│ execute(rawMsg)      │
└──────┬───────────────┘
       │
       ├─→ Stage 1: DeduplicationStage
       │   • 检查 msg_id 是否已存在
       │   • 已存在 → return null（中断管道）
       │   • 否则 → 继续
       │
       ├─→ Stage 2: ValidationStage
       │   • 校验 payload 格式、签名
       │   • 非法 → throw exception
       │
       ├─→ Stage 3: DecryptionStage
       │   • e2ee_crypto_service.decrypt()
       │   • RSA-2048 解密会话密钥
       │   • AES-256-GCM 解密消息体
       │
       └─→ Stage 4: PersistenceStage
           • INSERT INTO msg_c2c
           • 更新 conversation.last_msg
           • 增加 unread_count

通知决策 / Notification Gateway:
┌──────────────────────────────────────┐
│ evaluateNotification({               │
│   isFromSelf,      // 自己发的       │
│   isUserInChat,    // 在聊天页       │
│   isMuted,         // 静音           │
│   isMentioned,     // 被 @           │
│   ...              // 其他条件        │
│ })                                    │
└──────┬───────────────────────────────┘
       │
       ├─→ isFromSelf=true       → Suppressed('from_self')
       ├─→ isUserInChat=true     → Suppressed('in_chat')
       ├─→ msgId 重复            → Suppressed('duplicate')
       ├─→ isMuted && !isMentioned → Suppressed('muted')
       └─→ 其他                 → Allow → showNotification()
```

---

### 2. 群组管理流 | Group Management Flow

```
创建群组 / Create Group:
┌──────────────────┐
│ CreateGroupPage  │  用户填写群名、成员、权限
└──────┬───────────┘
       │
       ▼
┌──────────────────────┐
│ GroupNotifier        │  ref.read(groupNotifier.notifier).createGroup()
│ (Riverpod)           │
└──────┬───────────────┘
       │
       ├─→ 1. 校验（群名长度、成员数…）
       │
       ├─→ 2. 生成 Xid（TSID）
       │
       ├─→ 3. POST /v1/group/create
       │       response: GroupModel
       │
       ├─→ 4. SQLite 事务
       │       INSERT INTO group (id, name, owner_id, …)
       │       INSERT INTO group_member (gid, uid, role, …) × N
       │
       └─→ 5. 更新 state（状态机）
            页面跳转 → GroupDetailPage

修改群成员 / Modify Group Members:
├─→ 删除成员：DELETE FROM group_member WHERE gid=X AND uid=Y
├─→ 禁言：UPDATE group_member SET is_mute=true, mute_until=TS WHERE …
├─→ 转移群主：UPDATE group SET owner_id=NEW_UID WHERE id=X
└─→ 群公告：UPDATE group SET notice=TEXT WHERE id=X
```

---

### 3. E2EE 密钥流 | E2EE Key Flow

```
初次登录 / First Login:
┌─────────────────────┐
│ PassportPage        │  用户登录成功
└──────┬──────────────┘
       │
       ▼
┌────────────────────────────────┐
│ E2EEInitializationService      │
│ .initialize()                  │
└──────┬─────────────────────────┘
       │
       ├─→ 1. 检查本地是否存在 RSA 密钥对
       │
       ├─→ 2. 若不存在，生成新密钥
       │       • RSA-2048: (private_key, public_key)
       │       • kid = TSID()
       │
       ├─→ 3. 加密私钥（用 KDF 本地密钥）
       │       private_key_encrypted = AES-256-GCM(
       │         plaintext: private_key_pem,
       │         key: KDF(master_password)
       │       )
       │
       ├─→ 4. 存储到 SQLite
       │       user_key_pair {
       │         uid, public_key, private_key_encrypted, kid
       │       }
       │
       ├─→ 5. 上传公钥到后端
       │       POST /v1/e2ee/upload-public-key
       │       payload: {public_key, kid}
       │
       └─→ 6. 生成 Shamir 密钥碎片（5片，3片恢复）
               存储到 message_key_shard 表

消息加密 / Message Encryption (Sender):
┌────────────────┐
│ ChatNotifier   │  sendMessage(msg)
└────┬───────────┘
     │
     ├─→ 1. 获取接收方公钥
     │       api.getPublicKey(to_id)
     │
     ├─→ 2. 生成会话密钥（16字节随机）
     │       sessionKey = Random.secureRandom(16)
     │
     ├─→ 3. 加密会话密钥
     │       encryptedSessionKey = RSA-2048-OAEP(sessionKey, pub_key)
     │
     ├─→ 4. 加密消息体
     │       encrypted = AES-256-GCM(payload, sessionKey)
     │       → {ciphertext, iv, tag}
     │
     └─→ 5. 组装 e2ee blob
             e2ee = {
               kid, encrypted_session_key, ciphertext, iv, tag
             }
             PUT INTO msg_c2c (e2ee)

消息解密 / Message Decryption (Recipient):
┌──────────────┐
│ DecrptionStage
└────┬─────────┘
     │
     ├─→ 1. 读取本地私钥
     │       user_key_pair.private_key_encrypted
     │       private_key = AES-256-GCM-decrypt(
     │         ciphertext: private_key_encrypted,
     │         key: KDF(master_password)
     │       )
     │
     ├─→ 2. 解密会话密钥
     │       sessionKey = RSA-2048-OAEP-decrypt(
     │         encryptedSessionKey, private_key
     │       )
     │
     ├─→ 3. 解密消息体
     │       payload = AES-256-GCM-decrypt(
     │         ciphertext, sessionKey, iv, tag
     │       )
     │
     └─→ 4. 保存到 SQLite
             plaintext 消息仍加密存储（数据库层 SQLCipher）

换设备恢复 / Cross-Device Recovery:
┌─────────────────────────────────────┐
│ E2EETransferService.exportShards()   │
│ (旧设备)                              │
└─────────┬───────────────────────────┘
          │
          ├─→ 1. 获取 Shamir 5 个碎片
          │       message_key_shard table
          │
          ├─→ 2. 编码为 QR code
          │       JSON: {shard1, shard2, shard3, shard4, shard5}
          │
          └─→ 3. 用户扫描 QR
              ↓
┌──────────────────────────────────┐
│ E2EETransferService.importShards()│
│ (新设备)                           │
└─────────┬────────────────────────┘
          │
          ├─→ 1. 用户选择 3 个碎片
          │
          ├─→ 2. Shamir 秘密共享重构原私钥
          │       recovered_key = shamir_reconstruct(shard1, shard2, shard3)
          │
          ├─→ 3. 存储到新设备 SQLite
          │       user_key_pair { uid, public_key, private_key_encrypted }
          │
          └─→ 4. 历史消息自动解密
              使用重构的私钥解密旧消息
```

---

### 4. 许可检查流 | License Check Flow

```
启动时 / App Startup:
┌──────────────────────────┐
│ main.dart / run.dart     │
│ (Sentry 初始化)           │
└──────┬───────────────────┘
       │
       ▼
┌──────────────────────────┐
│ LicenseService.init()    │  后台任务
└──────┬───────────────────┘
       │
       ├─→ 1. 从 SharedPreferences 读取 license_key
       │
       ├─→ 2. 验证签名 (RSA-SHA256)
       │       verify(license_key) → {max_users, max_nodes, expires_at}
       │
       ├─→ 3. 检查过期时间
       │       if (expires_at < now) → warn / block
       │
       └─→ 4. 缓存配额到 persistent_term
               config: {max_users: 500, expires_at: 1726622400}

用户签up / User Signup:
┌──────────────┐
│ PassportPage │  用户点击注册
└──────┬───────┘
       │
       ▼
┌──────────────────────┐
│ LicenseService       │
│ .check_user_quota()  │  商务关键！
└──────┬───────────────┘
       │
       ├─→ 1. 查询当前用户数
       │       SELECT COUNT(*) FROM contact
       │
       ├─→ 2. 比较 max_users
       │       if (current_users >= max_users) {
       │         return LicenseQuota.EXCEEDED
       │       }
       │
       └─→ 3. 允许注册
           API 调用 → POST /v1/user/register
           ↓
           响应：新用户 uid
           ↓
           SaveToSQLite: contact { uid, nickname, avatar, … }
```

---

## 关键服务清单 | Key Services Checklist

| 服务 / Service | 文件 / File | 职责 / Responsibility |
|-----------|---------|---------|
| **WebSocketService** | service/websocket_service.dart | 与后端 WebSocket 连接、心跳、重连 |
| **MessageService** | service/message_service.dart | 消息发送、接收、确认、撤销 |
| **DatabaseService** | service/cached_sqlite_service.dart | SQLite 连接、查询缓存、事务 |
| **E2EECryptoService** | service/e2ee_crypto_service.dart | RSA 加解密、AES-256-GCM、签名验证 |
| **E2EEKeyService** | service/e2ee_key_service.dart | 密钥生成、导入导出、Shamir 碎片 |
| **E2EETransferService** | service/e2ee_transfer_service.dart | 换设备恢复、密钥转移 |
| **LicenseService** | service/license_service.dart | 许可验证、配额检查、企业锁定 |
| **InboundPipeline** | service/pipeline/inbound_pipeline.dart | 消息入站处理链 |
| **DeduplicationStage** | service/pipeline/dedup_stage.dart | 消息去重 |
| **NotificationGateway** | service/notification_gateway.dart | 通知决策（纯函数） |
| **EventBus** | service/event_bus.dart | S2C 事件派发 (group_edit, mute, …) |
| **AssetsService** | service/assets.dart | 资源 URL 授权（3600s 签名） |
| **DynamicAvatarService** | service/dynamic_avatar_service.dart | 从联系人/群组获取最新头像 |

---

## 测试结构 | Test Structure

```
test/
├── unit/               单元测试（逻辑、算法、数据转换）
│   ├── service/        Service 的纯函数测试
│   ├── repository/     Repository 接口单测（Mock SQLite）
│   ├── model/          数据模型反序列化测试
│   └── util/           工具函数单测
│
├── widget/             Widget 测试（组件隔离）
│   ├── page/           页面 Widget 测试（ProviderScope 包裹）
│   ├── component/      组件库单测
│   └── theme/          主题/Token 测试
│
└── integration/        集成测试（E2E，真实 DB/网络）
    ├── auth_flow.dart
    ├── message_flow.dart
    ├── e2ee_flow.dart
    └── group_flow.dart

基线：204 文件（2026-06-11）
```

---

## 依赖概览 | Dependencies Overview

| 类别 / Category | 包数 / Count | 示例 / Examples |
|-----------|---------|---------|
| 状态管理 / State | 2 | Riverpod 3.3.1, Provider |
| 网络 / Network | 3 | Dio 5.9, WebSocket, http |
| 本地存储 / Storage | 3 | sqflite 2.4, sqlcipher_flutter, shared_preferences |
| UI / UI | 8+ | Material 3, Cupertino, cached_network_image, … |
| 数学/加密 / Crypto | 4 | pointycastle, crypto, uuid |
| 国际化 / i18n | 2 | slang 4.14, intl |
| 媒体 / Media | 5+ | image_picker, video_player, audio_session, … |
| 平台 / Platform | 4+ | iOS plugins (jverify, r_upgrade, …) |

详见 [dependencies.md](./dependencies.md)

---

## 关键概念速记 | Quick Concepts

| 概念 | 含义 | 示例 |
|------|------|------|
| **Xid** | TSID Base32hex，消息唯一 ID | `msg_id = "6w1mxvk2z"` |
| **conv_key** | 会话唯一键 | `c2c:123:456` 或 `c2g:789` |
| **kid** | 密钥 ID，标记 RSA 公钥版本 | 换设备时查询旧 kid 的密钥 |
| **EntityId** | 前端类型，String 的 Xid | 防止 `int.tryParse` 陷阱 |
| **Provider** | Riverpod 状态容器 | `final chatProvider = FutureProvider(…)` |
| **Notifier** | Provider 的业务逻辑 | `class ChatNotifier extends StateNotifier<…>` |
| **Mixin** | 分层行为 | `ChatPage with ChatMessageHandler, ChatInputHandler` |
| **Repository** | 数据访问接口 | `MessageRepository.getMessages(convKey)` |

---

**更新者 / Updated by:** Claude Code  
**更新周期 / Update Cycle:** 6 weeks (major), 2 weeks (minor)  
**同步检查点 / Sync Checkpoints:** [INDEX.md](./INDEX.md) 元数据 ✓ | [architecture.md](./architecture.md) 技术栈 ✓ | [frontend.md](./frontend.md) 页面树 ✓

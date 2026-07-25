<!-- Generated: 2026-06-18 | Files scanned: 103 (services) + 33 (APIs) + 18 (repos) | Token estimate: ~900 -->

# Service & API Architecture

**最后更新 / Last Updated:** 2026-06-18 CST

---

## Service Layer (lib/service/, 103 files)

### 核心 WebSocket 服务 | Core WebSocket Services

```
websocket_service.dart          → 连接管理、自动重连、心跳
websocket_provider.dart         → Riverpod Provider 暴露
websocket_message_queue.dart    → 出站队列（离线缓存）
ack_manager.dart                → 送达/已读确认
event_subscription_manager.dart → 事件订阅管理（S2C）
protocol/                       → WebSocket 协议处理（4 files）
  ├── protocol_handler.dart
  ├── protocol_message.dart
  ├── protocol_encoder.dart
  └── protocol_decoder.dart
```

### 消息处理服务 | Message Processing Services

```
message_service.dart            → 消息收发编排（业务门面）
message_provider.dart           → Riverpod Provider（消息列表状态）
message_offline_service.dart    → 离线消息拉取、同步
message_retry_service.dart      → 失败消息重试（指数退避）
message_webrtc_service.dart     → WebRTC 信令消息
message_type_normalizer.dart    → 消息类型归一化（支持 9 种）
active_conversation_notifier.dart → 当前会话上下文（来自 route param）

消息管道 / Message Pipeline:
pipeline/
  ├── inbound_pipeline.dart          入站消息处理链（Stage Chain）
  ├── deduplication_stage.dart       去重阶段（CRITICAL）
  ├── validation_stage.dart          格式校验阶段
  ├── decryption_stage.dart          E2EE 解密阶段
  └── event_dispatch_stage.dart      事件派发阶段

消息缓存 / Message Cache:
cache/
  ├── message_cache.dart             内存缓存（last 100 msgs）
  └── query_cache_service.dart       查询结果缓存（expires 5min）
```

### 数据库服务 | Database Services

```
cached_sqlite_service.dart      → SQLCipher DB 连接、CRUD、事务、缓存
  • 版本：v21 (2026-06 最新)
  • 加密：AES-256
  • 模式：WAL (并发读、原子写)
  • 缓存：64MB + 查询缓存 (LRU)

migration_service.dart          → 版本迁移管理
  • upgrade.sql: v1 → v21
  • downgrade.sql: 向后兼容
  • 自动触发（应用启动检查）

db_encryption_key_service.dart  → 数据库密钥管理
  • iOS: Keychain 存储
  • Android: EncryptedSharedPreferences
  • macOS: Keychain
  
backup_service.dart             → 数据库备份/恢复
restore_service.dart            → 恢复流程（验证完整性）
```

### E2EE 加密服务 (8 files) | E2EE Encryption Services

```
e2ee_service.dart               → E2EE 生命周期管理（初始化、同步）
e2ee_crypto_service.dart        → 加解密操作
  • RSA-2048-OAEP 密钥加密
  • AES-256-GCM 消息加密
  • HMAC-SHA256 签名验证
  • KDF (PBKDF2) 本地密钥导出

e2ee_key_service.dart           → 密钥生成、导入导出
  • RSA 密钥对生成 (2048-bit)
  • PEM 格式编解码
  • 本地加密存储（KDF + AES-256）

e2ee_transfer_service.dart      → 设备间密钥转移
  • Shamir 秘密共享 (5 片、3 恢复)
  • QR 编码 / 二维码扫描
  • 碎片重构算法

e2ee_health_check_service.dart  → E2EE 健康检查
  • 密钥完整性验证
  • 版本同步检查
  • 损坏恢复

e2ee_social_service.dart        → 社交隐私（好友加密、关系链零信任）
e2ee_settings.dart              → 每个会话的 E2EE 配置开关
e2ee_local_backup_service.dart  → 本地备份（导出密钥、QR）
e2ee_shard_message_handler.dart → Shamir 碎片消息处理
```

### 事件派发服务 | Event Dispatch Services

```
events/                         (8 files)
├── event_bus.dart              → 跨服务事件总线（Pub/Sub）
├── group_event_handler.dart    → 群组事件 (group_edit, member_change, role_update)
├── message_event_handler.dart  → 消息事件 (msg_read, msg_recall)
├── user_event_handler.dart     → 用户事件 (profile_update, online_status)
├── mute_event_handler.dart     → 禁言事件 (mute_add, mute_remove, mute_expires)
├── mention_event_handler.dart  → @提及事件 (mention_all, mention_user)
├── media_event_handler.dart    → 媒体事件 (file_uploaded, image_processed)
└── notification_event_handler.dart → 通知事件 (system_notification, push)
```

### 许可网关服务 | License & Quota Services

```
license_service.dart            → 许可证管理、配额检查
  • RSA-SHA256 签名验证
  • max_users / max_nodes 配额
  • 过期时间检查
  • persistent_term 缓存

license_error_handler.dart      → 许可错误处理（返回 403）
license_sync_service.dart       → 许可同步（定期从后端检查）
```

### 存储服务 | Storage Services

```
storage_service.dart            → SharedPreferences（非敏感数据）
storage_secure_service.dart     → FlutterSecureStorage（tokens, keys）
secure_key_service.dart         → AES 密钥管理（导出用）
secure_token_storage_service.dart → 认证 token 存储（refresh_token）
```

### 资源服务 | Resource Services

```
assets_service.dart             → 资源 URL 授权
  • GET /v1/assets/view/:resource_id (request token)
  • 3600s 有效期
  • 签名防篡改

asset_url_resolver.dart         → URL 本地化处理
  • 获取授权 URL
  • 缓存策略 (if-modified-since)

dynamic_avatar_service.dart     → 头像动态获取
  • 从 contact / group 获取最新头像
  • 缓存过期策略 (1 hour)
```

### 通知服务 | Notification Services

```
notification_service.dart       → 本地通知（flutter_local_notifications）
notification_gateway.dart       → 通知决策逻辑（纯函数）
  • isFromSelf → Suppressed
  • isUserInChat → Suppressed
  • isMuted && !isMentioned → Suppressed
  • 其他 → Allow

push_notification_service.dart  → FCM 推送注册、消息处理
notification_settings_service.dart → 通知偏好设置（静音、优先级）
```

### 应用核心服务 | App Core Services

```
network_monitor_service.dart    → 网络状态跟踪 (connectivity_plus)
app_logger_service.dart         → 结构化日志记录（带 context）
sentry_service.dart             → 错误追踪、性能监控
app_version_tracker_service.dart → 版本跟踪、更新提示
app_upgrade_service.dart        → 应用更新流程管理
app_upgrade_orchestrator.dart   → 更新协调（检查、下载、安装）
app_downgrade_cleaner.dart      → 版本回滚清理
feature_registry.dart           → Feature Flag 注册表
```

---

## API 客户端层 | API Client Layer (33 files)

```
api/

认证相关 / Authentication:
├── passport_api.dart           → POST /v1/passport/login, /register, /logout
├── auth_token_api.dart         → POST /v1/auth/refresh-token
└── biometric_auth_api.dart     → POST /v1/auth/biometric-login

用户管理 / User Management:
├── user_api.dart               → GET/POST /v1/user/{profile, devices, settings}
├── user_device_api.dart        → GET/DELETE /v1/user/devices/{id}
├── user_profile_api.dart       → GET/PUT /v1/user/profile
└── user_tag_api.dart           → CRUD /v1/user/tags

好友关系 / Friend Relations:
├── contact_api.dart            → GET /v1/contact/list, search
├── friend_api.dart             → POST /v1/friend/{add, accept, reject, block}
├── friend_request_api.dart     → GET /v1/friend/requests
└── block_list_api.dart         → GET/DELETE /v1/block-list

群组管理 / Group Management:
├── group_api.dart              → CRUD /v1/group
├── group_member_api.dart       → POST /v1/group/{id}/members
├── group_album_api.dart        → GET /v1/group/{id}/albums
└── group_notice_api.dart       → GET/PUT /v1/group/{id}/notice

消息 / Messages:
├── message_api.dart            → GET /v1/message/history, POST send
├── message_ack_api.dart        → POST /v1/message/ack
├── message_search_api.dart     → GET /v1/message/search
└── message_forward_api.dart    → POST /v1/message/{id}/forward

频道 / Channels:
├── channel_api.dart            → CRUD /v1/channel
├── channel_message_api.dart    → GET /v1/channel/{id}/messages
├── channel_subscription_api.dart → POST /v1/channel/{id}/subscribe
└── channel_recommendation_api.dart → GET /v1/channel/recommended

社交 / Social:
├── moment_api.dart             → POST /v1/moment, GET feed
├── moment_comment_api.dart     → POST /v1/moment/{id}/comment
├── moment_like_api.dart        → POST /v1/moment/{id}/like
└── moment_notification_api.dart → GET /v1/moment/notifications

E2EE / End-to-End Encryption:
├── e2ee_api.dart               → POST /v1/e2ee/{upload-public-key, get-public-key}
├── e2ee_key_sync_api.dart      → GET /v1/e2ee/key-metadata
└── e2ee_backup_api.dart        → POST /v1/e2ee/backup

资源 / Resources:
├── assets_api.dart             → GET /v1/assets/view/:id (signed URL)
├── file_upload_api.dart        → POST /v1/assets/upload (presigned URL)
└── image_processing_api.dart   → POST /v1/assets/process (resize, format)

许可 / License:
├── license_api.dart            → GET /v1/license/verify
├── license_quota_api.dart      → GET /v1/license/quota
└── license_sync_api.dart       → POST /v1/license/sync

搜索 / Search:
├── search_api.dart             → GET /v1/search/messages
├── search_contacts_api.dart    → GET /v1/search/contacts
└── search_groups_api.dart      → GET /v1/search/groups

通知 / Notifications:
├── notification_api.dart       → GET /v1/notification/preferences
└── notification_settings_api.dart → PUT /v1/notification/settings
```

---

## 数据访问层 | Data Access Layer (18 repositories)

| Repository | 类型 | 主要方法 |
|-----------|------|--------|
| `MessageRepository` | SQLite | getMessages, saveMessage, updateStatus, deleteMessage |
| `ConversationRepository` | SQLite | getConversations, updateConversation, pin, mute |
| `ContactRepository` | SQLite | getContacts, addContact, removeContact, getRemark |
| `FriendRepository` | SQLite | getFriends, getPending, getBlocked, addFriend |
| `GroupRepository` | SQLite | getGroup, createGroup, updateGroup, deleteGroup |
| `GroupMemberRepository` | SQLite | getMembers, addMember, removeMember, setRole, setMute |
| `UserDeviceRepository` | SQLite | getDevices, addDevice, removeDevice, getLastLogin |
| `UserKeyPairRepository` | SQLite | getKeyPair, saveKeyPair, deleteKeyPair, getKid |
| `MessageKeyShardRepository` | SQLite | getShards, saveShards, reconstructFromShards |
| `UserTagRepository` | SQLite | getTags, createTag, deleteTag, assignUsers |
| `ChannelRepository` | SQLite | getChannels, getChannel, subscribe, unsubscribe |
| `ChannelMessageRepository` | SQLite | getMessages, saveMessage, deleteMessage |
| `MomentRepository` | SQLite | getMoments, createMoment, deleteMoment, likeMoment |
| `MomentCommentRepository` | SQLite | addComment, deleteComment, getComments |
| `MomentNotifyRepository` | SQLite | getNotifications, markAsRead, deleteNotify |
| `LicenseRepository` | SQLite | getLicense, saveLicense, checkExpiry, checkQuota |
| `CacheRepository` | Memory LRU | set, get, invalidate, clear |
| `MigrationRepository` | SQLite | recordMigration, getMigrations, rollback |

---

## 数据模型层 | Model Layer (31 models)

### 消息模型 | Message Models

```
MessageModel {
  id: String,           // Xid Base32hex（非 int！）
  from_id: int,
  to_id: int,           // C2C 模式
  gid: int,             // C2G 模式
  msg_type: String,     // text/image/video/voice/file/location/card
  payload: Map<String, dynamic>,
  e2ee: E2EEPayload?,   // 加密元数据
  created_at: int,      // 毫秒时间戳
  status: String,       // pending/sent/received/read/failed
  ack_id: int?,
  mention_ids: List<int>?,  // C2G 中的 @list
  reply_to_id: String?, // 引用回复
}

ConversationModel {
  conv_key: String,     // c2c:min_uid:max_uid | c2g:gid | channel:cid
  type: String,         // c2c | c2g | channel
  peer_id: String,      // uid | gid | cid (ChatPage 路由参数)
  title: String,
  avatar: String,       // 授权后的 URL
  last_msg: String,     // 摘要
  last_msg_time: int,   // 毫秒
  unread_count: int,
  notice_disabled: bool,
  pinned: bool,
  updated_at: int,
}
```

### 联系人模型 | Contact Models

```
ContactModel {
  uid: int,
  nickname: String,
  remark: String,       // 备注名（优先展示）
  avatar: String,
  status: String,       // online/offline/away
  last_seen: int,
  created_at: int,
}

FriendModel {
  from_id: int,
  to_id: int,
  status: String,       // pending/accepted/blocked
  created_at: int,
}

UserTagModel {
  id: String,           // TSID
  uid: int,
  name: String,
  color: String,
  users: List<int>,     // JSON 数组
}
```

### 群组模型 | Group Models

```
GroupModel {
  id: int,
  name: String,
  owner_id: int,
  description: String,
  avatar: String,
  notice: String,
  rules: Map<String, dynamic>,  // JSON 权限规则
  created_at: int,
}

GroupMemberModel {
  gid: int,
  uid: int,
  role: String,         // owner/admin/member
  is_join: bool,        // false = 待审批
  is_mute: bool,
  mute_until: int?,     // nullable
  joined_at: int,
}
```

### E2EE 模型 | E2EE Models

```
UserKeyPairModel {
  uid: int,
  public_key: String,   // PEM 格式
  private_key_encrypted: Uint8List,  // 已加密
  kid: String,          // 密钥 ID (TSID)
  created_at: int,
}

MessageKeyShardModel {
  uid: int,
  shard_index: int,     // 1..5
  shard_data_encrypted: Uint8List,
  backup_device_id: String?,
  created_at: int,
}

E2EEPayload {
  kid: String,          // 公钥版本
  encrypted_session_key: Uint8List,  // RSA 加密的会话密钥
  ciphertext: Uint8List,              // AES-256-GCM 加密的消息
  iv: Uint8List,                      // 初始向量
  tag: Uint8List,                     // GCM 认证标签
}
```

---

## API 协议 | API Protocol

### 请求格式 | Request Format

```
POST /v1/message/send
Authorization: Bearer {jwt_token}
Content-Type: application/json

{
  "to_id": 123,              // 接收方 UID
  "msg_type": "text",
  "payload": {
    "text": "Hello"
  },
  "e2ee": {
    "kid": "6w1mxvk2z",
    "encrypted_session_key": "base64...",
    "ciphertext": "base64...",
    "iv": "base64...",
    "tag": "base64..."
  }
}
```

### 响应格式 | Response Format

```
200 OK
{
  "code": 0,
  "message": "OK",
  "data": {
    "id": "6w1mxvk2z",
    "status": "sent",
    "created_at": 1726622400000
  }
}

400 BAD_REQUEST
{
  "code": 40001,
  "message": "Invalid payload format"
}

403 FORBIDDEN (License)
{
  "code": 40301,
  "message": "User quota exceeded",
  "data": {
    "max_users": 500,
    "current_users": 500
  }
}

401 UNAUTHORIZED
{
  "code": 40101,
  "message": "Token expired"
}
```

---

## 服务间通信 | Inter-Service Communication

```
页面发送消息流：
ChatPage
  ↓ (ref.read)
ChatNotifier
  ↓
MessageService.sendMessage()
  ├─→ MessageValidationService (校验)
  ├─→ E2EECryptoService (加密)
  ├─→ MessageApi.send() (HTTP POST)
  ├─→ MessageRepository.saveMessage() (SQLite)
  └─→ NotificationGateway (本地通知决策)

服务器推送流：
WebSocketService
  ↓ (receive event)
InboundPipeline
  ├─→ DeduplicationStage
  ├─→ ValidationStage
  ├─→ DecryptionStage (E2EECryptoService)
  ├─→ EventDispatchStage
  ├─→ MessageRepository.saveMessage()
  └─→ ChatNotifier (state update via ref.notifier)
      ↓
      UI rebuild
```

---

**更新者 / Updated by:** Claude Code  
**更新周期 / Update Cycle:** 6 weeks (API changes), Monthly (service additions)

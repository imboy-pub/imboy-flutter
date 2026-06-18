<!-- Generated: 2026-06-18 | Files scanned: 18 (repos) + 31 (models) + 1 (service) | Token estimate: ~750 -->

# 数据架构 | Data Architecture

**最后更新 / Last Updated:** 2026-06-18 CST

---

## 数据库 | Database

| 属性 / Property | 值 / Value | 说明 / Notes |
|-----------|---------|---------|
| 引擎 / Engine | SQLCipher (AES-256 加密) | 所有本地数据全库加密 |
| 版本 / Version | v21 (最新迁移 2026-06) | 消息去重索引修复、E2EE 稳定、许可网关基础 |
| 模式 / Mode | WAL (Write-Ahead Logging) | 并发读、原子写 |
| 缓存 / Cache | 64MB | 查询性能优化 |
| 隔离 / Isolation | `{env}_{uid}.db` | 每个用户独立数据库 |
| 模板 / Template | `assets/example10.db` | 首次登录复制使用 |
| 平台 / Platforms | iOS (Keychain), Android (EncryptedSharedPreferences), macOS (Keychain) | 加密密钥存储 |

---

## 核心表 | Core Tables

### 消息表 | Message Tables

```
msg_c2c  (C2C 私聊消息)
├── id (TSID)              唯一 ID
├── from_id (int)          发送者 ID
├── to_id (int)            接收者 ID
├── msg_type (text)        消息类型 (text/image/voice/video/file/location/card)
├── payload (text)         消息内容 (JSON)
├── e2ee (blob)            E2EE 加密元数据 (kid, ciphertext, iv, tag)
├── created_at (int)       创建时间戳 (ms)
├── status (text)          状态 (pending/sent/received/read/failed)
├── ack_id (int)           ACK 确认 ID
└── ...

msg_c2g  (C2G 群聊消息)
├── id (TSID)
├── from_id (int)          发送者 ID
├── gid (int)              群组 ID
├── msg_type (text)
├── payload (text)
├── e2ee (blob)
├── created_at (int)
├── mention_ids (text)     提及的 uid 列表 (JSON 数组 | "all")
├── status (text)
└── ...

msg_c2s  (C2S 客户端请求)
msg_s2c  (S2C 服务端推送)
```

### 会话表 | Conversation Table

```
conversation
├── conv_key (text)        主键 (c2c:min_uid:max_uid | c2g:gid | channel:cid)
├── type (text)            类型 (c2c | c2g | channel)
├── peer_id (text)         对方 uid | gid | cid (ChatPage 路由参数)
├── title (text)           会话标题
├── avatar (text)          头像 URL（授权后）
├── last_msg (text)        最后消息摘要
├── last_msg_time (int)    最后消息时间戳
├── unread_count (int)     未读数
├── notice_disabled (bool) 免打扰标志
├── pinned (bool)          是否置顶
├── updated_at (int)       更新时间戳
└── ...
```

### 联系人表 | Contact & Friend Tables

```
contact  (联系人基础信息)
├── uid (int)              用户 ID
├── nickname (text)        昵称
├── remark (text)          备注名（优先用于展示）
├── avatar (text)          头像 URL
├── status (text)          状态 (online/offline/away)
├── last_seen (int)        最后在线时间戳
├── created_at (int)       添加时间
└── ...

friend_relationship  (好友关系)
├── from_id (int)
├── to_id (int)
├── status (text)          状态 (pending/accepted/blocked/deleted)
├── created_at (int)
└── ...

block_list  (黑名单)
├── uid (int)              拥有者
├── blocked_uid (int)      被拉黑用户
├── created_at (int)
└── ...

user_tag  (用户标签)
├── id (TSID)
├── uid (int)              标签所有者
├── name (text)            标签名
├── color (text)           颜色代码
├── users (text)           标签包含的 uid 列表 (JSON 数组)
└── ...
```

### 群组表 | Group Tables

```
group  (群组基础)
├── id (int)               群组 ID
├── name (text)            群名称
├── owner_id (int)         群主 ID
├── description (text)     群描述
├── avatar (text)          群头像 URL
├── notice (text)          群公告
├── rules (text)           群规则 (JSON)
├── created_at (int)
└── ...

group_member  (群成员)
├── gid (int)              群组 ID
├── uid (int)              成员 ID
├── role (text)            角色 (owner/admin/member)
├── is_join (boolean)      是否已加入（false=待审）
├── is_mute (boolean)      是否禁言
├── mute_until (int)       禁言截止时间戳 (nullable)
├── joined_at (int)        加入时间
└── ...

group_album  (群相册)
├── id (TSID)
├── gid (int)              所属群组
├── title (text)           相册标题
├── cover_url (text)       封面 URL
├── item_count (int)       照片数
├── created_by (int)       创建人 ID
├── created_at (int)
└── ...

group_album_item  (相册照片)
├── id (TSID)
├── album_id (TSID)
├── image_url (text)       图片 URL
├── uploaded_by (int)      上传人 ID
├── created_at (int)
└── ...
```

### 频道表 | Channel Tables

```
channel  (频道)
├── id (int)               频道 ID
├── name (text)            频道名称
├── description (text)     描述
├── avatar (text)          头像 URL
├── owner_id (int)         频道所有者
├── is_public (boolean)    是否公开
├── created_at (int)
└── ...

channel_message  (频道消息)
├── id (TSID)
├── cid (int)              频道 ID
├── from_id (int)          发送者 ID
├── msg_type (text)
├── payload (text)
├── created_at (int)
├── status (text)
└── ...

channel_subscription  (频道订阅)
├── uid (int)              用户 ID
├── cid (int)              频道 ID
├── subscribed_at (int)    订阅时间
├── muted (boolean)        是否静音
└── ...
```

### 社交动态表 | Moment Tables

```
moment  (动态)
├── id (TSID)
├── from_id (int)          发布人 ID
├── content (text)         内容
├── images (text)          图片 URL 列表 (JSON)
├── videos (text)          视频 URL 列表 (JSON)
├── visibility (text)      可见性 (public/friends/private)
├── created_at (int)
└── ...

moment_like  (动态点赞)
├── moment_id (TSID)
├── uid (int)              点赞人 ID
├── created_at (int)
└── ...

moment_comment  (动态评论)
├── id (TSID)
├── moment_id (TSID)
├── from_id (int)          评论人 ID
├── content (text)
├── reply_to_id (TSID)     回复的评论 ID (nullable)
├── created_at (int)
└── ...

moment_notify  (动态通知，含去重)
├── id (TSID)
├── moment_id (TSID)
├── notify_type (text)     (like / comment)
├── comment_id (TSID)      若为 comment，指向该评论 (nullable, 用于去重)
├── from_id (int)
├── to_id (int)
├── is_read (boolean)
├── created_at (int)
├── INDEX (moment_id, COALESCE(comment_id, ''))  v21 新增，防重复通知
└── ...
```

### 认证与账户表 | Auth Tables

```
user_device  (已登设备)
├── id (TSID)
├── uid (int)              用户 ID
├── device_name (text)     设备名称
├── device_type (text)     设备类型 (ios/android/macos/web)
├── os_version (text)      系统版本
├── app_version (text)     App 版本
├── last_login (int)       最后登录时间
├── is_active (boolean)    是否活跃（用于远程登出）
└── ...

login_attempt  (登录尝试)
├── id (TSID)
├── uid (int)
├── attempt_time (int)
├── status (text)          (success / failed)
├── failure_reason (text)  失败原因 (nullable)
└── ...

biometric_auth  (生物识别认证)
├── uid (int)
├── biometric_type (text)  (fingerprint / face)
├── is_enabled (boolean)
├── enrolled_at (int)
└── ...
```

### E2EE 加密表 | E2EE Tables

```
user_key_pair  (RSA 密钥对)
├── uid (int)              用户 ID
├── public_key (text)      公钥 (PEM 格式)
├── private_key_encrypted (blob)  加密的私钥（用本地 KDF 密钥）
├── kid (TSID)             密钥 ID
├── created_at (int)
└── ...

message_key_shard  (Shamir 密钥碎片)
├── uid (int)
├── shard_index (int)      碎片编号 (1..5)
├── shard_data_encrypted (blob)  加密碎片
├── backup_device_id (TSID)  备份到的设备 (nullable)
├── created_at (int)
└── ...

e2ee_session  (会话密钥)
├── conv_key (text)        会话标识
├── session_key (blob)     AES-256 会话密钥（加密存储）
├── created_at (int)
├── expires_at (int)
└── ...
```

### 许可表 | License Tables

```
license_record  (许可记录)
├── id (TSID)
├── license_key (text)     许可证文本
├── max_users (int)        最大用户数
├── max_nodes (int)        最大节点数（服务端连接）
├── licensee (text)        被授予方
├── expires_at (int)       过期时间戳
├── is_active (boolean)    是否激活
└── ...
```

---

## 仓库层 | Repository Layer (18 repos)

| Repository | 职责 | 核心方法 |
|-----------|------|--------|
| `MessageRepository` | 消息 CRUD、查询 | saveMessage, getMessages, markAsRead, deleteMessage |
| `ConversationRepository` | 会话管理 | getConversations, updateConversation, pinConversation, setNoticeDisabled |
| `ContactRepository` | 联系人管理 | getContacts, addContact, removeContact, updateRemark |
| `FriendRepository` | 好友关系 | getFriends, sendFriendRequest, acceptFriendRequest, blockFriend |
| `GroupRepository` | 群组基础 | createGroup, getGroup, updateGroup, deleteGroup |
| `GroupMemberRepository` | 群成员管理 | addMember, removeMember, updateRole, setMute |
| `UserDeviceRepository` | 设备管理 | addDevice, getDevices, removeDevice, updateLastLogin |
| `UserKeyPairRepository` | RSA 密钥对 | saveKeyPair, getKeyPair, deleteKeyPair, getKid |
| `MessageKeyShardRepository` | Shamir 碎片 | saveShards, getShards, reconstructFromShards |
| `UserTagRepository` | 用户标签 | createTag, updateTag, deleteTag, assignUsersToTag |
| `ChannelRepository` | 频道管理 | getChannels, createChannel, updateChannel, deleteChannel |
| `ChannelMessageRepository` | 频道消息 | saveMessage, getMessages, deleteMessage |
| `MomentRepository` | 社交动态 | createMoment, getMoments, deleteMoment, likeMoment |
| `MomentCommentRepository` | 动态评论 | addComment, deleteComment, getComments |
| `MomentNotifyRepository` | 动态通知 | saveNotify, getNotifications, markAsRead |
| `LicenseRepository` | 许可管理 | saveLicense, getLicense, checkExpiry, checkUserQuota |
| `CacheRepository` | 缓存管理（SQLite 查询缓存） | set, get, invalidate, clear |
| `MigrationRepository` | 迁移跟踪 | recordMigration, getMigrations, rollback |

---

## 模型层 | Model Layer (31 models)

| 模型 / Model | 来源 / Source | 用途 / Purpose |
|-----------|---------|---------|
| `MessageModel` | msg_c2c / msg_c2g | 消息 DTO（UI 展示）|
| `ConversationModel` | conversation | 会话列表数据 |
| `ContactModel` | contact | 联系人展示 |
| `FriendModel` | friend_relationship | 好友关系 |
| `UserModel` | API + contact | 用户资料 |
| `UserTagModel` | user_tag | 标签数据 |
| `GroupModel` | group | 群组基础 |
| `GroupMemberModel` | group_member | 群成员信息 |
| `GroupAlbumModel` | group_album | 群相册 |
| `GroupAlbumItemModel` | group_album_item | 相册照片 |
| `ChannelModel` | channel | 频道信息 |
| `ChannelMessageModel` | channel_message | 频道消息 |
| `ChannelSubscriptionModel` | channel_subscription | 频道订阅 |
| `MomentModel` | moment | 社交动态 |
| `MomentLikeModel` | moment_like | 点赞数据 |
| `MomentCommentModel` | moment_comment | 评论数据 |
| `MomentNotifyModel` | moment_notify | 动态通知 |
| `UserDeviceModel` | user_device | 设备信息 |
| `BiometricAuthModel` | biometric_auth | 生物识别状态 |
| `UserKeyPairModel` | user_key_pair | RSA 密钥对（不含明文私钥）|
| `MessageKeyShardModel` | message_key_shard | Shamir 碎片（加密存储）|
| `E2EESessionModel` | e2ee_session | 会话密钥 |
| `MessageStatusModel` | 值对象 | 消息状态枚举 |
| `ConversationTypeModel` | 值对象 | 会话类型枚举 |
| `UserRoleModel` | 值对象 | 群成员角色枚举 |
| `MomentVisibilityModel` | 值对象 | 动态可见性枚举 |
| `LicenseModel` | license_record | 许可证信息 |
| `LicenseQuotaModel` | 值对象 | 配额检查结果 |
| `ApiErrorModel` | API 响应 | 错误信息 DTO |
| `PaginationModel` | 值对象 | 分页信息 |
| `SearchResultModel` | 复合 | 搜索结果聚合 |

---

## API 层 | API Client Layer (33 clients)

| API 客户端 / API | 端点 / Endpoint | 职责 / Purpose |
|-----------|---------|---------|
| `PassportApi` | /v1/passport/* | 登录、注册、认证 |
| `UserApi` | /v1/user/* | 用户资料、设备管理 |
| `ContactApi` | /v1/contact/* | 联系人管理、搜索 |
| `FriendApi` | /v1/friend/* | 好友关系、申请处理 |
| `GroupApi` | /v1/group/* | 群组 CRUD、成员管理 |
| `MessageApi` | /v1/message/* | 消息历史、ACK |
| `ChannelApi` | /v1/channel/* | 频道管理、订阅 |
| `MomentApi` | /v1/moment/* | 动态发布、评论、点赞 |
| `AssetsApi` | /v1/assets/* | 资源上传、签名 URL |
| `NotificationApi` | /v1/notification/* | 通知设置、偏好 |
| `SearchApi` | /v1/search/* | 全局搜索、索引 |
| `E2EEApi` | /v1/e2ee/* | 公钥交换、密钥同步 |
| `LicenseApi` | /v1/license/* | 许可验证、配额查询 |
| [+20 more] | 各功能域 | ... |

---

## 迁移系统 | Migration System

```
assets/migrations/
├── upgrade.sql          升级脚本（向前兼容）
├── downgrade.sql        回滚脚本（向后兼容）
└── [历史版本]

迁移版本号：v1 ~ v21
每个版本号由版本号和 timestamp 组成（精确到秒）

v21 迁移 (2026-06)：
  - 添加 moment_notify.comment_id (nullable)
  - 创建组合索引：(moment_id, COALESCE(comment_id, ''))
  - 修复：防止重复通知（like 用 COALESCE 处理）
  - E2EE 表稳定化
  - 许可表新增
```

---

## 加密架构 | Encryption Architecture

### 数据库加密 | Database Encryption

```
密钥生成 (Platform-specific):
  ├── iOS:       Keychain (ECB, 加密密钥自动保管)
  ├── Android:   EncryptedSharedPreferences (AES-GCM)
  └── macOS:     Keychain (同 iOS)

库加密 (SQLCipher):
  ├── 算法：      AES-256-CBC
  ├── 密钥导出：  PBKDF2 (rounds=64000)
  └── WAL 模式：  原子性 + 并发读
```

### 消息 E2EE | Message E2EE

```
发送流程 (Sender → Recipient):
  1. 生成会话密钥（首次）或取缓存
  2. 用会话密钥加密消息体（AES-256-GCM）
  3. 用接收方公钥加密会话密钥（RSA-2048-OAEP）
  4. 组装：{encrypted_payload, encrypted_session_key, iv, tag}
  5. 发送到服务端

接收流程 (Server → Recipient):
  1. 从数据库读取私钥（加密存储）
  2. 解密会话密钥（RSA 解密）
  3. 解密消息体（AES-256-GCM）
  4. 验证完整性（GCM tag）
  5. 保存到 SQLite（仍加密）
```

### 换设备恢复 | Cross-Device Recovery

```
密钥转移流程:
  1. 客户端导出 Shamir 密钥碎片（5 片，3 片可恢复）
  2. 本地生成 QR code（编码 5 个碎片）
  3. 新设备扫描 QR → 导入 3 个碎片 → Shamir 算法重构原私钥
  4. 重建成功后，关闭旧设备对该会话的访问
  5. 历史消息自动解密（使用重构的私钥）
```

---

## 常见查询优化 | Common Query Optimizations

| 查询 / Query | 优化 / Optimization | 预期性能 / Performance |
|-----------|---------|---------|
| 获取会话列表 | 索引：(type, updated_at DESC) | ~10ms (1000 行) |
| 分页加载消息 | 索引：(conv_key, created_at DESC)，用 LIMIT + OFFSET | ~50ms (100 条) |
| 搜索联系人 | LIKE 查询 + FTS (Full-Text Search) 可选 | ~30ms (1000 行) |
| 群成员查询 | 索引：(gid, is_join) 用于过滤已加入成员 | ~5ms |
| 获取未读数 | 索引：(type, unread_count > 0) | ~1ms |

---

## 数据一致性原则 | Data Consistency Principles

| 原则 / Principle | 实施 / Implementation | 检查 / Verification |
|-----------|---------|---------|
| 关键路径事务 | SQLite BEGIN/COMMIT（消息发送、会话创建） | 事务测试 + 断网恢复测试 |
| 唯一约束 | PRIMARY KEY (msg_id, conv_key) 防重 | 插入重复消息，应被拒 |
| 外键约束 | contact → user (uid)，group_member → group (gid) | 删除校验（级联/拒绝） |
| 软删除 | 敏感表用 is_deleted 标志（msg, moment, contact） | 查询时自动过滤 deleted=0 |

---

**更新者 / Updated by:** Claude Code  
**更新周期 / Update Cycle:** Monthly (schema changes), Quarterly (performance review)

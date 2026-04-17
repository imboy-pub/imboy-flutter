<!-- Generated: 2026-04-17 | Files scanned: 17 (repos) + 25 (models) | Token estimate: ~720 -->

# 数据架构 | Data Architecture

**最后更新 / Last Updated:** 2026-04-17 CST

---

## 数据库 | Database

| 属性 / Property | 值 / Value | 说明 / Notes |
|-----------|---------|---------|
| 引擎 / Engine | SQLCipher (AES-256 加密) | 所有本地数据全库加密 |
| 版本 / Version | v19 (最新迁移 2026-04) | 支持群成员禁言、@所有人权限 |
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
├── id (TSID)          唯一 ID
├── from_id (int)      发送者 ID
├── to_id (int)        接收者 ID
├── msg_type (text)    消息类型 (text/image/voice/video/file/location/card)
├── payload (text)     消息内容 (JSON)
├── e2ee (blob)        E2EE 加密元数据
├── created_at (int)   创建时间戳 (ms)
├── status (text)      状态 (pending/sent/received/read/failed)
├── ack_id (int)       ACK 确认 ID
└── ...

msg_c2g  (C2G 群聊消息)
├── id (TSID)
├── from_id (int)      发送者 ID
├── gid (int)          群组 ID
├── msg_type (text)
├── payload (text)
├── e2ee (blob)
├── created_at (int)
├── mention_ids (text) 提及的 uid 列表 (JSON 数组 | "all")
├── status (text)
└── ...

msg_c2s  (C2S 客户端请求)
msg_s2c  (S2C 服务端推送)
```

### 会话表 | Conversation Table

```
conversation
├── conv_key (text)    主键 (c2c:min_uid:max_uid | c2g:gid)
├── type (text)        类型 (c2c | c2g | channel)
├── peer_id (text)     对方 uid | gid (used in ChatPage route)
├── title (text)       会话标题
├── avatar (text)      头像 URL
├── last_msg (text)    最后消息摘要
├── last_msg_time (int) 最后消息时间戳
├── unread_count (int) 未读数
├── notice_disabled (bool)  免打扰标志 (2026-04新增)
├── pinned (bool)      是否置顶 (频道 2026-04新增)
├── updated_at (int)
└── ...
```

### 联系人表 | Contact & Friend Tables

```
contact  (联系人)
├── uid (int)          用户 ID
├── nickname (text)    昵称
├── remark (text)      备注名 (优先用于展示)
├── avatar (text)      头像 URL
├── status (int)       在线状态 (0=offline, 1=online)
├── created_at (int)
└── ...

new_friend  (好友请求)
├── id (TSID)
├── from_uid (int)     请求者
├── to_uid (int)       接收者
├── msg (text)         验证消息
├── status (int)       状态 (0=pending, 1=accepted, 2=rejected)
├── created_at (int)
└── ...

user_denylist  (黑名单)
├── uid (int)          阻止的用户 ID
├── created_at (int)
└── ...
```

### 群组表 | Group Tables

```
group_info  (群组信息)
├── gid (int)          群组 ID
├── name (text)        群组名称
├── avatar (text)      群头像 URL
├── description (text) 群描述
├── owner_uid (int)    群主 uid
├── member_count (int) 成员数
├── created_at (int)
├── notice_disabled (bool)  免打扰标志 (2026-04)
└── ...

group_member  (群成员)
├── gid (int)          群组 ID
├── uid (int)          用户 ID
├── role (int)         角色 (1=member, 2=guest, 3=admin, 4=owner, 5=vice_owner)
├── nickname (text)    群内昵称 (可选，为空用联系人昵称)
├── mute_until (int)   禁言截止时间戳 (ms, NULL=未禁言) (2026-04新增)
├── joined_at (int)
└── ...

group_album  (群相册)
├── id (TSID)
├── gid (int)
├── title (text)
├── cover_url (text)
├── msg_count (int)
└── ...
```

### 频道表 | Channel Tables (2026-04 New)

```
channel
├── id (TSID)          频道 ID
├── name (text)        频道名称
├── type (text)        频道类型 (public/private)
├── subscriber_count (int)  订阅者数
├── created_at (int)
└── ...

channel_message  (频道消息)
├── id (TSID)
├── channel_id (TSID)
├── from_id (int)      发送者
├── payload (text)
├── created_at (int)
└── ...

channel_subscription  (频道订阅)
├── channel_id (TSID)
├── uid (int)          订阅用户
├── subscribed_at (int)
└── ...
```

### 用户数据表 | User Data Tables

```
user_tag  (用户标签)
├── id (TSID)
├── uid (int)          标签所有者
├── name (text)        标签名
├── color (text)       标签颜色
├── members (text)     成员 uid 列表 (JSON 数组)
├── created_at (int)
└── ...

user_collect  (收藏/收藏夹)
├── id (TSID)
├── uid (int)          所有者
├── msg_id (TSID)      被收藏的消息 ID
├── collected_at (int)
└── ...

user_device  (设备注册)
├── id (TSID)
├── uid (int)
├── device_id (text)   设备标识符
├── device_name (text) 设备名称 (iPhone 15 Pro)
├── platform (text)    平台 (ios/android/macos)
├── registered_at (int)
└── ...
```

---

## 仓库层 | Repository Layer (lib/store/repository/)

```
Singleton pattern (GetIt)
└── All repos registered in AppInitializer

关键仓库：

message_repo_sqlite.dart
  ├── insertOrUpdate(message)
  ├── findById(msgId)
  ├── findByConvKey(convKey, {limit, offset})  分页
  ├── deleteById(msgId)
  ├── markAsRead(msgIds)
  └── batchInsert(messages)

conversation_repo_sqlite.dart
  ├── findAll({orderBy})
  ├── findByKey(convKey)
  ├── updateLastMessage(convKey, msg, unread)
  ├── increaseUnread(convKey, delta)
  ├── setNoticeDisabled(convKey, bool)  免打扰 (2026-04)
  └── deleteByKey(convKey)

contact_repo_sqlite.dart
  ├── insert(contact)
  ├── update(contact)
  ├── findByUid(uid)
  ├── findAll()
  ├── search(query)
  └── delete(uid)

group_repo_sqlite.dart
  ├── insert(group)
  ├── update(group)
  ├── findByGid(gid)
  ├── findAll()
  └── delete(gid)

group_member_repo_sqlite.dart
  ├── insert(member)
  ├── update(gid, uid, {role, mute_until, ...})  支持禁言更新 (2026-04)
  ├── findByGid(gid)
  ├── findByUid(uid)
  └── delete(gid, uid)

channel_repo_sqlite.dart  (新增 2026-04)
  ├── insert(channel)
  ├── findAll()
  ├── findBySubscriber(uid)
  └── delete(id)

user_repo_local.dart  (内存单例)
  ├── currentUid
  ├── currentUser
  ├── setCurrentUser(user)
  └── logout()

user_tag_repo_sqlite.dart
  ├── insert(tag)
  ├── update(tag)
  ├── deleteById(tagId)
  └── findAll(uid)

user_collect_repo_sqlite.dart
  ├── collect(msgId)
  ├── uncollect(msgId)
  ├── findAll(uid)
  └── isCollected(msgId)

user_device_repo_sqlite.dart
  ├── register(device)
  ├── findAll(uid)
  └── delete(deviceId)

user_denylist_repo_sqlite.dart
  ├── block(uid)
  ├── unblock(uid)
  ├── findAll()
  └── isBlocked(uid)

new_friend_repo_sqlite.dart
  ├── insert(request)
  ├── updateStatus(id, status)
  ├── findAll(toUid)
  └── delete(id)

message_fts_repo.dart  (全文搜索)
  ├── index(message)
  ├── search(query, convKey)
  └── deleteByMsgId(msgId)
```

---

## 模型层 | Model Layer (lib/store/model/)

```
关键模型（25 个文件）:

message_model.dart
  ├── id (TSID)
  ├── type (c2c/c2g/c2s/s2c)
  ├── fromId, toId, gid
  ├── msgType (text/image/voice/video/file/location/card)
  ├── payload (JSON 序列化)
  ├── e2ee (加密元数据)
  ├── mentionIds ([@某人 | "all"])  (2026-04 新增)
  ├── createdAt (TSID 时间戳)
  ├── status (pending/sent/received/read/failed)
  └── isMuted() / isMentioned()  助手方法

conversation_model.dart
  ├── convKey (c2c:min_uid:max_uid | c2g:gid)
  ├── type (c2c/c2g/channel)
  ├── peerId (uid 或 gid，用于 route param)
  ├── title, avatar
  ├── lastMsg, lastMsgTime
  ├── unreadCount
  ├── noticeDisabled (2026-04 新增)
  └── pinnedChannels (频道 2026-04)

contact_model.dart
  ├── uid
  ├── nickname, remark, avatar
  ├── status (online/offline)
  └── displayName (返回 remark 或 nickname)

group_model.dart
  ├── gid
  ├── name, avatar, description
  ├── ownerUid, memberCount
  └── isOwner(currentUid)  助手方法

group_member_model.dart
  ├── gid, uid
  ├── role (1..5)
  ├── nickname (群内昵称)
  ├── muteUntilMs (禁言截止，NULL=未禁言)  (2026-04 新增)
  ├── joinedAt
  └── isMuted()  (2026-04 新增)
  └── isGroupAdmin() / isGroupOwner()  助手方法

channel_model.dart  (新增 2026-04)
  ├── id (TSID)
  ├── name
  ├── type (public/private)
  ├── subscriberCount
  └── createdAt

entity_image.dart
  ├── url, width, height
  └── thumbnail

entity_video.dart
  ├── url, duration, size
  └── thumbnail

entity_attachment.dart
  ├── id, url, type, size
  └── metadata
```

---

## 迁移系统 | Migration System

```
assets/migrations/
├── upgrade.sql      版本升级脚本 (v1 → v19)
└── downgrade.sql    版本降级脚本

迁移流程 (lib/service/migration_service.dart):
1. 检查 PRAGMA user_version
2. 创建快照备份 (自动清理 7 天以上)
3. 执行 SQL 脚本 (部分脚本可选)
4. 验证表结构
5. 更新 user_version

关键迁移（最近）:
v18 → v19 (2026-04)
├── ALTER TABLE group_member ADD COLUMN mute_until INTEGER NULL
├── CREATE INDEX idx_group_member_mute ON group_member(gid, mute_until)
└── (为群成员禁言支持)
```

---

## 加密架构 | Encryption Architecture

### 密钥存储 | Key Storage

```
flutter_secure_storage (平台: Keychain/EncryptedSharedPreferences)

└── db_cipher_key_{uid}        256-bit hex (SQLCipher 密码)
└── e2ee_private_key            E2EE RSA 私钥
└── e2ee_public_key             E2EE RSA 公钥
└── e2ee_device_id              设备标识符
└── e2ee_key_id                 密钥版本 ID
└── e2ee_shard_{id}             Shamir 恢复片段
```

### 数据库加密 | DB Encryption

```
新建数据库:
  sqlite3 'path' 'PRAGMA key = "hex:..."'

现有明文数据库升级:
  1. ATTACH DATABASE 'encrypted.db' KEY 'hex:...'
  2. 迁移表数据
  3. 原子替换 (rename + unlink)
  4. 自动备份 → {path}.pre_encrypt.bak

备份清理:
  > 7 天的 pre_encrypt.bak 自动删除
```

---

## ID 系统 | ID System

| ID 类型 / Type | 格式 / Format | 范围 / Range | 用途 / Usage |
|-----------|---------|---------|---------|
| TSID | BIGINT (64-bit) | 生成式，按时间递增 | 所有实体 ID (msg, contact, tag, device) |
| 用户 UID | TSID 字符串或整数 | 后端生成 | 用户标识、群成员 uid |
| 群组 GID | TSID 字符串或整数 | 后端生成 | 群组标识 |
| conv_key | `c2c:{min_uid}:{max_uid}` | 确定性 | 会话主键 |
| conv_key | `c2g:{gid}` | 确定性 | 群聊会话主键 |
| conv_seq | per-conversation sequence | 单调递增 | 会话内消息同步序号 |

**TSID 跨栈兼容性 (2026-04新增约束):**
```dart
// 客户端：String 类型（JSON 兼容，防精度丢失）
final uid = "1838294017982465";  // String, not int

// 数据库：INTEGER（SQLite 64-bit）
final id = 1838294017982465;     // int, native type

// API 通信：String in JSON
{"from": "1838294017982465"}     // Always String in JSON

// Repo 自动转换：
message_repo_sqlite.dart:
  WHERE from_id = ? whereArgs: [int.parse(fromIdString)]
```

---

## 最近变化 | Recent Updates (Apr 2026)

| 迁移 / Migration | 表 / Table | 字段 / Column | 用途 / Purpose |
|-----------|---------|---------|---------|
| v19 | group_member | mute_until (INT NULL) | 群成员禁言（支持 2026-04 slice-1~10） |
| v18 | conversation | notice_disabled (BOOL) | 会话免打扰（2026-04 新增） |
| v17 | channel* | * | 频道表全系（2026-04 新增频道模块） |
| v16 | msg_c2g | mention_ids (TEXT) | 消息提及列表（@所有人支持） |

---

## 性能指标 | Performance Notes

| 操作 / Operation | 优化 / Optimization | 预期时间 / Expected Time |
|-----------|---------|---------|
| 加载初始消息 50 条 | 索引 + 分页 | < 100ms |
| 搜索联系人 (全文) | FTS (Full-Text Search) | < 50ms |
| 查询会话列表 | 单表扫描 + ORDER BY | < 200ms |
| 插入新消息 | 批量插入 (batchInsert) | < 50ms (per msg) |
| 数据库备份 | 并行 I/O | 1-5s (DB size dependent) |

---

**相关文档 / Related Docs**
- [`architecture.md`](./architecture.md) — 服务层对数据的访问
- [`frontend.md`](./frontend.md) — UI 如何消费数据
- [`CLAUDE.md`](../../CLAUDE.md) — WebSocket API v2.0 消息格式

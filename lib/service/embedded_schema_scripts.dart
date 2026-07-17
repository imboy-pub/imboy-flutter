// 建表/迁移 DDL —— 内嵌为 Dart 常量，不再依赖运行时 rootBundle 加载 assets 文件。
//
// 背景：assets/migrations/*.sql 曾在部分设备/构建下被 rootBundle.loadString 报
// "Unable to load asset"（资源包未包含该文件，常见于增量构建未刷新
// flutter_assets）。baseline_schema.sql 失败会导致新用户首次建库必然失败并连带
// 触发 SQLCipher 无密钥兜底重开（sqlcipherCodecAttach: no key）；upgrade/
// downgrade.sql 失败则更隐蔽——MigrationService._loadMigrationScripts 原先 catch
// 住异常返回空 map，版本迁移会被静默跳过而不报错。三者都是数据库能否正确
// 建立/迁移的阻断点，因此都不适合继续依赖资源包这一层间接性。
//
// ponytail: 与 assets/migrations/{baseline_schema,upgrade,downgrade}.sql 内容
// 保持同步（这些 .sql 文件仍保留作为人类可读的参考副本）；baseline 历史上只
// 定型过一次，upgrade/downgrade 随版本号增长偶尔追加，手工同步的维护成本可
// 接受。若未来改动频繁到手工同步不可靠，再上生成脚本（从 .sql 生成本文件）。
const String kBaselineSchemaSql = r"""
CREATE TABLE contact (
    auto_id INTEGER PRIMARY KEY,
    user_id INTEGER NOT NULL,
    peer_id INTEGER NOT NULL,
    nickname TEXT NOT NULL DEFAULT '',
    avatar TEXT NOT NULL DEFAULT '',
    gender INTEGER NOT NULL DEFAULT 0,
    account TEXT NOT NULL DEFAULT '',
    status TEXT NOT NULL DEFAULT '',
    remark TEXT DEFAULT '',
    tag TEXT DEFAULT '',
    region TEXT DEFAULT '',
    sign TEXT NOT NULL DEFAULT '',
    source TEXT NOT NULL DEFAULT '',
    updated_at INTEGER NOT NULL DEFAULT 0,
    is_friend INTEGER NOT NULL DEFAULT 0,
    is_from INTEGER NOT NULL DEFAULT 0,
    category_id INTEGER NOT NULL DEFAULT 0,
    CONSTRAINT uk_FromTo UNIQUE (user_id, peer_id)
);
CREATE INDEX i_UserId_IsFriend_UpdateTime ON contact (user_id, is_friend, updated_at);
CREATE INDEX i_UserId_CategoryId ON contact (user_id, category_id);
CREATE INDEX i_Nickname ON contact (nickname);
CREATE INDEX i_Remark ON contact (remark);
CREATE INDEX i_Tag ON contact (tag);
CREATE INDEX idx_contact_user_id_peer_id ON contact (user_id, peer_id);
CREATE TABLE new_friend (
    auto_id INTEGER PRIMARY KEY,
    uid INTEGER NOT NULL,
    from_id INTEGER NOT NULL,
    to_id INTEGER NOT NULL,
    nickname TEXT NOT NULL DEFAULT '',
    avatar TEXT NOT NULL DEFAULT '',
    msg TEXT NOT NULL DEFAULT '',
    status TEXT NOT NULL DEFAULT '',
    payload TEXT DEFAULT '',
    updated_at INTEGER NOT NULL DEFAULT 0,
    created_at INTEGER NOT NULL DEFAULT 0,
    CONSTRAINT uk_FromTo UNIQUE (from_id, to_id)
);
CREATE TABLE user_denylist (
    auto_id INTEGER PRIMARY KEY,
    user_id INTEGER NOT NULL,
    denied_user_id INTEGER NOT NULL,
    nickname TEXT NOT NULL DEFAULT '',
    avatar TEXT NOT NULL DEFAULT '',
    gender INTEGER NOT NULL DEFAULT 0,
    account TEXT NOT NULL DEFAULT '',
    region TEXT DEFAULT '',
    sign TEXT NOT NULL DEFAULT '',
    source TEXT NOT NULL DEFAULT '',
    remark TEXT DEFAULT '',
    created_at INTEGER NOT NULL DEFAULT 0,
    CONSTRAINT i_Uid_DeniedUid UNIQUE (user_id, denied_user_id)
);
CREATE TABLE user_device (
    auto_id INTEGER PRIMARY KEY,
    user_id INTEGER NOT NULL,
    device_id TEXT NOT NULL DEFAULT '',
    device_name TEXT NOT NULL DEFAULT '',
    device_type TEXT NOT NULL DEFAULT '',
    last_active_at INTEGER NOT NULL DEFAULT 0,
    device_vsn TEXT DEFAULT '',
    CONSTRAINT i_Uid_DeviceId UNIQUE (user_id, device_id)
);
CREATE TABLE user_collect (
    auto_id INTEGER PRIMARY KEY,
    user_id INTEGER NOT NULL,
    kind INTEGER NOT NULL DEFAULT 0,
    -- kind_id 是 String Xid（消息id等），必须 TEXT（QA#31，v22 迁移）
    kind_id TEXT NOT NULL DEFAULT '',
    source TEXT NOT NULL DEFAULT '',
    remark TEXT NOT NULL DEFAULT '',
    tag TEXT NOT NULL DEFAULT '',
    updated_at INTEGER NOT NULL DEFAULT 0,
    created_at INTEGER NOT NULL DEFAULT 0,
    info TEXT DEFAULT '',
    CONSTRAINT i_Uid_KindId UNIQUE (user_id, kind_id)
);
CREATE INDEX i_Source ON user_collect (source);
CREATE INDEX idx_user_collect_user_id_kind ON user_collect (user_id, kind);
CREATE TABLE user_tag (
    auto_id INTEGER PRIMARY KEY,
    user_id INTEGER NOT NULL,
    tag_id INTEGER NOT NULL DEFAULT 0,
    scene INTEGER NOT NULL DEFAULT 0,
    name TEXT NOT NULL DEFAULT '',
    subtitle TEXT NOT NULL DEFAULT '',
    referer_time INTEGER NOT NULL DEFAULT 0,
    updated_at INTEGER NOT NULL DEFAULT 0,
    created_at INTEGER NOT NULL DEFAULT 0,
    CONSTRAINT i_Uid_Scene_Name UNIQUE (user_id, scene, name)
);
CREATE INDEX idx_user_tag_user_id_scene ON user_tag (user_id, scene);
CREATE TABLE group_notice (
    id INTEGER PRIMARY KEY,
    group_id INTEGER NOT NULL,
    user_id INTEGER NOT NULL,
    edit_user_id INTEGER NOT NULL DEFAULT 0,
    body TEXT DEFAULT '',
    status INTEGER NOT NULL DEFAULT 0,
    expired_at INTEGER DEFAULT 0,
    updated_at INTEGER DEFAULT 0,
    created_at INTEGER NOT NULL
);
CREATE INDEX i_Gid_Status_ExpiredAt ON group_notice (group_id, status, expired_at ASC);
CREATE TABLE IF NOT EXISTS "group" (
    id INTEGER PRIMARY KEY,
    type INTEGER DEFAULT 1,
    join_limit INTEGER DEFAULT 2,
    content_limit INTEGER DEFAULT 2,
    user_id_sum INTEGER NOT NULL DEFAULT 0,
    owner_uid INTEGER NOT NULL,
    creator_uid INTEGER NOT NULL,
    member_max INTEGER NOT NULL DEFAULT 1000,
    member_count INTEGER NOT NULL DEFAULT 1,
    introduction TEXT NOT NULL DEFAULT '',
    avatar TEXT NOT NULL DEFAULT '',
    title TEXT NOT NULL DEFAULT '',
    status INTEGER NOT NULL DEFAULT 1,
    updated_at INTEGER DEFAULT 0,
    created_at INTEGER NOT NULL,
    pinned_msg TEXT
);
CREATE TABLE group_member (
    id INTEGER PRIMARY KEY,
    group_id INTEGER NOT NULL,
    user_id INTEGER NOT NULL,
    nickname TEXT DEFAULT '',
    avatar TEXT DEFAULT '',
    sign TEXT DEFAULT '',
    account TEXT DEFAULT '',
    invite_code TEXT DEFAULT '',
    alias TEXT DEFAULT '',
    description TEXT DEFAULT '',
    role INTEGER DEFAULT 0,
    is_join INTEGER DEFAULT 0,
    join_mode TEXT,
    status INTEGER NOT NULL DEFAULT 1,
    updated_at INTEGER DEFAULT 0,
    created_at INTEGER NOT NULL
);
CREATE UNIQUE INDEX uk_Gid_Uid ON group_member (group_id, user_id);
CREATE INDEX i_Uid_Gid_IsJoin ON group_member (user_id, group_id, is_join);
CREATE INDEX idx_group_member_user_id_status ON group_member (user_id, status);
CREATE TABLE user_group (
    id INTEGER PRIMARY KEY,
    user_id INTEGER NOT NULL,
    group_id INTEGER NOT NULL,
    remark TEXT DEFAULT '',
    setting TEXT NOT NULL,
    status INTEGER DEFAULT 1 NOT NULL,
    updated_at INTEGER DEFAULT 0,
    created_at INTEGER NOT NULL
);
CREATE TABLE conversation (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER,
    peer_id INTEGER,
    avatar TEXT,
    title TEXT,
    subtitle TEXT,
    region TEXT,
    sign TEXT,
    unread_num INTEGER,
    "type" TEXT,
    msg_type TEXT,
    is_show INTEGER,
    last_time INTEGER,
    last_msg_id INTEGER,
    last_msg_status INTEGER,
    payload TEXT
);
-- sqlite_sequence is auto-managed by SQLite, do not create manually
CREATE INDEX i_cv_UserId_IsShow_LastTime ON conversation (user_id, is_show, last_time);
CREATE UNIQUE INDEX uk_cv_Type_From_To ON conversation ("type", user_id, peer_id);
CREATE INDEX idx_conversation_user_id_last_time ON conversation (user_id, last_time DESC);
CREATE TABLE msg_c2c (
    auto_id INTEGER PRIMARY KEY,
    id INTEGER NOT NULL,
    msg_type TEXT,
    from_id INTEGER,
    to_id INTEGER,
    conversation_uk3 TEXT,
    e2ee TEXT,
    payload TEXT,
    created_at INTEGER,
    topic_id INTEGER,
    status INTEGER,
    is_author INTEGER,
    type TEXT DEFAULT 'C2C',
    action TEXT DEFAULT '',
    CONSTRAINT uk_MsgId UNIQUE (id)
);
CREATE INDEX idx_msg_c2c_conversation_status_author ON msg_c2c (conversation_uk3, status, is_author);
CREATE INDEX idx_msg_c2c_conversation_created_at ON msg_c2c (conversation_uk3, created_at);
CREATE INDEX idx_msg_c2c_conversation_topic_id ON msg_c2c (conversation_uk3, topic_id);
CREATE INDEX idx_msg_c2c_conversation_uk3 ON msg_c2c (conversation_uk3);
CREATE INDEX idx_msg_c2c_from_to_created ON msg_c2c (from_id, to_id, created_at DESC);
CREATE INDEX idx_msg_c2c_msg_type ON msg_c2c (msg_type);
CREATE INDEX idx_msg_c2c_unread_count ON msg_c2c (conversation_uk3, is_author, auto_id);
CREATE INDEX idx_msg_c2c_status ON msg_c2c (status);
CREATE TABLE msg_c2g (
    auto_id INTEGER PRIMARY KEY,
    id INTEGER NOT NULL,
    msg_type TEXT,
    from_id INTEGER,
    to_id INTEGER,
    conversation_uk3 TEXT,
    e2ee TEXT,
    payload TEXT,
    created_at INTEGER,
    topic_id INTEGER,
    status INTEGER,
    is_author INTEGER,
    type TEXT DEFAULT 'C2G',
    action TEXT DEFAULT '',
    CONSTRAINT uk_MsgId UNIQUE (id)
);
CREATE INDEX idx_msg_c2g_conversation_status_author ON msg_c2g (conversation_uk3, status, is_author);
CREATE INDEX idx_msg_c2g_conversation_created_at ON msg_c2g (conversation_uk3, created_at);
CREATE INDEX idx_msg_c2g_conversation_topic_id ON msg_c2g (conversation_uk3, topic_id);
CREATE INDEX idx_msg_c2g_conversation_uk3 ON msg_c2g (conversation_uk3);
CREATE INDEX idx_msg_c2g_from_to_created ON msg_c2g (from_id, to_id, created_at DESC);
CREATE INDEX idx_msg_c2g_msg_type ON msg_c2g (msg_type);
CREATE INDEX idx_msg_c2g_unread_count ON msg_c2g (conversation_uk3, is_author, auto_id);
CREATE INDEX idx_msg_c2g_status ON msg_c2g (status);
CREATE TABLE msg_c2s (
    auto_id INTEGER PRIMARY KEY,
    id INTEGER NOT NULL,
    msg_type TEXT,
    from_id INTEGER,
    to_id INTEGER,
    conversation_uk3 TEXT,
    e2ee TEXT,
    payload TEXT,
    created_at INTEGER,
    topic_id INTEGER,
    status INTEGER,
    is_author INTEGER,
    type TEXT DEFAULT 'C2S',
    action TEXT DEFAULT '',
    CONSTRAINT uk_MsgId UNIQUE (id)
);
CREATE INDEX idx_msg_c2s_conversation_status_author ON msg_c2s (conversation_uk3, status, is_author);
CREATE INDEX idx_msg_c2s_conversation_created_at ON msg_c2s (conversation_uk3, created_at);
CREATE INDEX idx_msg_c2s_conversation_topic_id ON msg_c2s (conversation_uk3, topic_id);
CREATE INDEX idx_msg_c2s_conversation_uk3 ON msg_c2s (conversation_uk3);
CREATE INDEX idx_msg_c2s_from_to_created ON msg_c2s (from_id, to_id, created_at DESC);
CREATE INDEX idx_msg_c2s_unread_count ON msg_c2s (conversation_uk3, is_author, auto_id);
CREATE INDEX idx_msg_c2s_status ON msg_c2s (status);
CREATE TABLE msg_s2c (
    auto_id INTEGER PRIMARY KEY,
    id INTEGER NOT NULL,
    action TEXT,
    msg_type TEXT,
    from_id INTEGER,
    to_id INTEGER,
    conversation_uk3 TEXT,
    e2ee TEXT,
    payload TEXT,
    created_at INTEGER,
    topic_id INTEGER,
    status INTEGER,
    is_author INTEGER,
    type TEXT DEFAULT 'S2C',
    CONSTRAINT uk_MsgId UNIQUE (id)
);
CREATE INDEX idx_msg_s2c_conversation_status_author ON msg_s2c (conversation_uk3, status, is_author);
CREATE INDEX idx_msg_s2c_conversation_created_at ON msg_s2c (conversation_uk3, created_at);
CREATE INDEX idx_msg_s2c_conversation_topic_id ON msg_s2c (conversation_uk3, topic_id);
CREATE INDEX idx_msg_s2c_conversation_uk3 ON msg_s2c (conversation_uk3);
CREATE INDEX idx_msg_s2c_from_to_created ON msg_s2c (from_id, to_id, created_at DESC);
CREATE INDEX idx_msg_s2c_action ON msg_s2c (action);
CREATE TABLE channel (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    avatar TEXT,
    type INTEGER DEFAULT 0,
    custom_id TEXT UNIQUE,
    creator_id INTEGER NOT NULL,
    subscriber_count INTEGER DEFAULT 0,
    is_verified INTEGER DEFAULT 0,
    tags TEXT,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL
);
CREATE INDEX idx_channel_custom_id ON channel(custom_id);
CREATE INDEX idx_channel_creator_id ON channel(creator_id);
CREATE INDEX idx_channel_type ON channel(type);
CREATE TABLE channel_subscription (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    channel_id INTEGER NOT NULL,
    subscribed_at INTEGER NOT NULL,
    last_read_at INTEGER,
    last_message_id INTEGER,
    unread_count INTEGER DEFAULT 0,
    notifications_enabled INTEGER DEFAULT 1,
    is_pinned INTEGER DEFAULT 0,
    is_muted INTEGER DEFAULT 0,
    FOREIGN KEY (channel_id) REFERENCES channel(id) ON DELETE CASCADE,
    UNIQUE(channel_id)
);
CREATE INDEX idx_subscription_pinned ON channel_subscription(is_pinned);
CREATE INDEX idx_subscription_muted ON channel_subscription(is_muted);
CREATE TABLE channel_message (
    id INTEGER PRIMARY KEY,
    channel_id INTEGER NOT NULL,
    author_id INTEGER,
    author_name TEXT,
    author_avatar TEXT,
    content TEXT,
    msg_type TEXT NOT NULL,
    payload TEXT,
    created_at INTEGER NOT NULL,
    is_pinned INTEGER DEFAULT 0,
    view_count INTEGER DEFAULT 0,
    reaction_summary TEXT,
    my_reactions TEXT,
    FOREIGN KEY (channel_id) REFERENCES channel(id) ON DELETE CASCADE
);
CREATE INDEX idx_channel_msg_channel_id ON channel_message(channel_id);
CREATE INDEX idx_channel_msg_created_at ON channel_message(channel_id, created_at DESC);
CREATE INDEX idx_channel_msg_pinned ON channel_message(channel_id, is_pinned);
CREATE TABLE channel_admin (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    channel_id INTEGER NOT NULL,
    user_id INTEGER NOT NULL,
    role INTEGER DEFAULT 0,
    added_at INTEGER NOT NULL,
    UNIQUE(channel_id, user_id),
    FOREIGN KEY (channel_id) REFERENCES channel(id) ON DELETE CASCADE
);
CREATE INDEX idx_channel_admin_user ON channel_admin(user_id);
CREATE VIRTUAL TABLE msg_c2c_fts USING fts5(
  id,
  conversation_uk3,
  text_content,
  content='',
  tokenize='unicode61 remove_diacritics 2'
)
/* msg_c2c_fts(id,conversation_uk3,text_content) */;
CREATE TABLE IF NOT EXISTS 'msg_c2c_fts_data'(id INTEGER PRIMARY KEY, block BLOB);
CREATE TABLE IF NOT EXISTS 'msg_c2c_fts_idx'(segid, term, pgno, PRIMARY KEY(segid, term)) WITHOUT ROWID;
CREATE TABLE IF NOT EXISTS 'msg_c2c_fts_docsize'(id INTEGER PRIMARY KEY, sz BLOB);
CREATE TABLE IF NOT EXISTS 'msg_c2c_fts_config'(k PRIMARY KEY, v) WITHOUT ROWID;
CREATE VIRTUAL TABLE msg_c2g_fts USING fts5(
  id,
  conversation_uk3,
  text_content,
  content='',
  tokenize='unicode61 remove_diacritics 2'
)
/* msg_c2g_fts(id,conversation_uk3,text_content) */;
CREATE TABLE IF NOT EXISTS 'msg_c2g_fts_data'(id INTEGER PRIMARY KEY, block BLOB);
CREATE TABLE IF NOT EXISTS 'msg_c2g_fts_idx'(segid, term, pgno, PRIMARY KEY(segid, term)) WITHOUT ROWID;
CREATE TABLE IF NOT EXISTS 'msg_c2g_fts_docsize'(id INTEGER PRIMARY KEY, sz BLOB);
CREATE TABLE IF NOT EXISTS 'msg_c2g_fts_config'(k PRIMARY KEY, v) WITHOUT ROWID;
""";

/// 与 assets/migrations/upgrade.sql 内容保持同步（同上，人工同步；参考副本仍保留）。
const String kUpgradeScriptSql = r"""
-- ============================================================
-- 数据库升级脚本
-- SQLite Database Upgrade Scripts
-- ============================================================
-- 说明：
--   每个版本块以 -- VERSION: 开头，包含该版本的所有升级 SQL
--
-- 重要：
--   VERSION 标记的是起始版本号
--   PRAGMA user_version 设置的是升级后的目标版本号
--
-- 标记说明：
--   VERSION: 起始版本号
--   DESC: 版本描述
--
-- 当前状态：
--   当前数据库版本: v9
--   此文件用于未来的版本升级
--
-- 使用方法：
--   1. 应用启动时 MigrationService 自动执行升级
--   2. SqliteService 通过 onUpgrade 回调触发迁移
--
-- 添加新版本的步骤：
--   1. 在下面添加新的 VERSION 块
--   2. 编写升级 SQL
--   3. 设置 PRAGMA user_version = 新版本号
--   4. 在 downgrade.sql 中添加对应的降级脚本
-- ============================================================

-- ============================================================
-- VERSION: 9
-- DESC: 基线版本 - 当前生产环境版本
-- ============================================================
-- 功能说明：这是数据库的基线版本，包含所有核心表结构
-- 表结构：16 张表（消息、会话、联系人、群组、用户相关）
--
-- 主要表：
--   - message, group_message, c2s_message, s2c_message, msg_topic
--   - conversation
--   - contact, new_friend, user_denylist
--   - group, group_member, group_notice, user_group
--   - user_collect, user_tag, user_device
--
-- 当前版本无需升级，此块留空
-- PRAGMA user_version = 9;

-- ============================================================
-- VERSION: 10
-- DESC: WebSocket API v2.0 消息表结构升级
-- ============================================================
-- 功能说明：升级到 WebSocket API v2.0 规范，统一消息表命名
-- 变更内容：
--   1. 重命名消息表：message → msg_c2c, group_message → msg_c2g
--      c2s_message → msg_c2s, s2c_message → msg_s2c
--   2. 新增字段：msg_type (消息类型), action (S2C指令), e2ee (端到端加密)
-- 数据迁移：保留所有现有数据，仅添加新字段并重命名表
--
-- 执行步骤：
--   1. 为每个消息表添加新字段（默认值处理）
--   2. 重命名表（使用 ALTER TABLE RENAME TO）

-- ============================================================
-- Step 1: 为现有消息表添加 v2.0 新增字段
-- ============================================================

-- 为 message 表 (C2C) 添加新字段
-- 注意：type 字段用于存储消息协议类型（C2C、C2G、S2C 等），与 msg_type（内容类型）不同
ALTER TABLE message ADD COLUMN type TEXT DEFAULT 'C2C';
ALTER TABLE message ADD COLUMN msg_type TEXT DEFAULT '';
ALTER TABLE message ADD COLUMN action TEXT DEFAULT '';
ALTER TABLE message ADD COLUMN e2ee TEXT DEFAULT '';

-- 为 group_message 表 (C2G) 添加新字段
ALTER TABLE group_message ADD COLUMN type TEXT DEFAULT 'C2G';
ALTER TABLE group_message ADD COLUMN msg_type TEXT DEFAULT '';
ALTER TABLE group_message ADD COLUMN action TEXT DEFAULT '';
ALTER TABLE group_message ADD COLUMN e2ee TEXT DEFAULT '';

-- 为 c2s_message 表 (C2S) 添加新字段
ALTER TABLE c2s_message ADD COLUMN type TEXT DEFAULT 'C2S';
ALTER TABLE c2s_message ADD COLUMN msg_type TEXT DEFAULT '';
ALTER TABLE c2s_message ADD COLUMN action TEXT DEFAULT '';
ALTER TABLE c2s_message ADD COLUMN e2ee TEXT DEFAULT '';

-- 为 s2c_message 表 (S2C) 添加新字段
ALTER TABLE s2c_message ADD COLUMN type TEXT DEFAULT 'S2C';
ALTER TABLE s2c_message ADD COLUMN msg_type TEXT DEFAULT '';
ALTER TABLE s2c_message ADD COLUMN action TEXT DEFAULT '';
ALTER TABLE s2c_message ADD COLUMN e2ee TEXT DEFAULT '';

-- ============================================================
-- Step 2: 迁移 payload 中的 msg_type 到顶层字段（数据优化）
-- ============================================================
-- 说明：从 payload JSON 中提取 msg_type 字段到新列，提高查询性能
-- 注意：这是可选的数据优化步骤，不执行也不影响功能

-- 更新 message 表的 msg_type 字段
UPDATE message
SET msg_type = json_extract(payload, '$.msg_type')
WHERE msg_type = '' AND json_extract(payload, '$.msg_type') IS NOT NULL;

-- 更新 group_message 表的 msg_type 字段
UPDATE group_message
SET msg_type = json_extract(payload, '$.msg_type')
WHERE msg_type = '' AND json_extract(payload, '$.msg_type') IS NOT NULL;

-- 更新 c2s_message 表的 msg_type 字段
UPDATE c2s_message
SET msg_type = json_extract(payload, '$.msg_type')
WHERE msg_type = '' AND json_extract(payload, '$.msg_type') IS NOT NULL;

-- 更新 s2c_message 表的 msg_type 和 action 字段
UPDATE s2c_message
SET msg_type = json_extract(payload, '$.msg_type')
WHERE msg_type = '' AND json_extract(payload, '$.msg_type') IS NOT NULL;

UPDATE s2c_message
SET action = json_extract(payload, '$.action')
WHERE action = '' AND json_extract(payload, '$.action') IS NOT NULL;

-- ============================================================
-- Step 3: 迁移 e2ee 字段（数据优化）
-- ============================================================

-- 更新 message 表的 e2ee 字段
UPDATE message
SET e2ee = json_extract(payload, '$.e2ee')
WHERE e2ee = '' AND json_extract(payload, '$.e2ee') IS NOT NULL;

-- 更新 group_message 表的 e2ee 字段
UPDATE group_message
SET e2ee = json_extract(payload, '$.e2ee')
WHERE e2ee = '' AND json_extract(payload, '$.e2ee') IS NOT NULL;

-- 更新 c2s_message 表的 e2ee 字段
UPDATE c2s_message
SET e2ee = json_extract(payload, '$.e2ee')
WHERE e2ee = '' AND json_extract(payload, '$.e2ee') IS NOT NULL;

-- 更新 s2c_message 表的 e2ee 字段
UPDATE s2c_message
SET e2ee = json_extract(payload, '$.e2ee')
WHERE e2ee = '' AND json_extract(payload, '$.e2ee') IS NOT NULL;

-- ============================================================
-- Step 4: 删除旧索引
-- ============================================================
-- 说明：表重命名后索引会自动跟随，但为保持一致性，先删除旧索引

DROP INDEX IF EXISTS idx_c2c_msg_conversation_status_author;
DROP INDEX IF EXISTS i_c2c_msg_Conversation_CreatedAt;
DROP INDEX IF EXISTS i_c2c_msg_Conversation_TopicId;
DROP INDEX IF EXISTS idx_message_conversation_uk3;
DROP INDEX IF EXISTS idx_message_from_to_created;

DROP INDEX IF EXISTS idx_c2g_msg_conversation_status_author;
DROP INDEX IF EXISTS i_c2g_msg_Conversation_CreatedAt;
DROP INDEX IF EXISTS i_c2g_msg_Conversation_TopicId;
DROP INDEX IF EXISTS idx_c2g_message_conversation_uk3;

DROP INDEX IF EXISTS idx_c2s_msg_conversation_status_author;
DROP INDEX IF EXISTS i_c2s_msg_Conversation_CreatedAt;
DROP INDEX IF EXISTS i_c2s_msg_Conversation_TopicId;
DROP INDEX IF EXISTS idx_c2s_message_conversation_uk3;
DROP INDEX IF EXISTS idx_c2s_message_from_to_created;

DROP INDEX IF EXISTS idx_s2c_msg_conversation_status_author;
DROP INDEX IF EXISTS i_s2c_msg_Conversation_CreatedAt;
DROP INDEX IF EXISTS i_s2c_msg_Conversation_TopicId;
DROP INDEX IF EXISTS idx_s2c_message_conversation_uk3;
DROP INDEX IF EXISTS idx_s2c_message_from_to_created;

-- ============================================================
-- Step 5: 重命名表为 v2.0 规范名称
-- ============================================================

-- 重命名 C2C 消息表
ALTER TABLE message RENAME TO msg_c2c;

-- 重命名 C2G 消息表
ALTER TABLE group_message RENAME TO msg_c2g;

-- 重命名 C2S 消息表
ALTER TABLE c2s_message RENAME TO msg_c2s;

-- 重命名 S2C 消息表
ALTER TABLE s2c_message RENAME TO msg_s2c;

-- ============================================================
-- Step 6: 创建新索引（使用新表名）
-- ============================================================

-- msg_c2c 表索引
CREATE INDEX IF NOT EXISTS idx_msg_c2c_conversation_status_author
  ON msg_c2c (conversation_uk3, status, is_author);
CREATE INDEX IF NOT EXISTS idx_msg_c2c_conversation_created_at
  ON msg_c2c (conversation_uk3, created_at);
CREATE INDEX IF NOT EXISTS idx_msg_c2c_conversation_topic_id
  ON msg_c2c (conversation_uk3, topic_id);
CREATE INDEX IF NOT EXISTS idx_msg_c2c_conversation_uk3
  ON msg_c2c (conversation_uk3);
CREATE INDEX IF NOT EXISTS idx_msg_c2c_from_to_created
  ON msg_c2c (from_id, to_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_msg_c2c_msg_type
  ON msg_c2c (msg_type);

-- msg_c2g 表索引
CREATE INDEX IF NOT EXISTS idx_msg_c2g_conversation_status_author
  ON msg_c2g (conversation_uk3, status, is_author);
CREATE INDEX IF NOT EXISTS idx_msg_c2g_conversation_created_at
  ON msg_c2g (conversation_uk3, created_at);
CREATE INDEX IF NOT EXISTS idx_msg_c2g_conversation_topic_id
  ON msg_c2g (conversation_uk3, topic_id);
CREATE INDEX IF NOT EXISTS idx_msg_c2g_conversation_uk3
  ON msg_c2g (conversation_uk3);
CREATE INDEX IF NOT EXISTS idx_msg_c2g_from_to_created
  ON msg_c2g (from_id, to_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_msg_c2g_msg_type
  ON msg_c2g (msg_type);

-- msg_c2s 表索引
CREATE INDEX IF NOT EXISTS idx_msg_c2s_conversation_status_author
  ON msg_c2s (conversation_uk3, status, is_author);
CREATE INDEX IF NOT EXISTS idx_msg_c2s_conversation_created_at
  ON msg_c2s (conversation_uk3, created_at);
CREATE INDEX IF NOT EXISTS idx_msg_c2s_conversation_topic_id
  ON msg_c2s (conversation_uk3, topic_id);
CREATE INDEX IF NOT EXISTS idx_msg_c2s_conversation_uk3
  ON msg_c2s (conversation_uk3);
CREATE INDEX IF NOT EXISTS idx_msg_c2s_from_to_created
  ON msg_c2s (from_id, to_id, created_at DESC);

-- msg_s2c 表索引
CREATE INDEX IF NOT EXISTS idx_msg_s2c_conversation_status_author
  ON msg_s2c (conversation_uk3, status, is_author);
CREATE INDEX IF NOT EXISTS idx_msg_s2c_conversation_created_at
  ON msg_s2c (conversation_uk3, created_at);
CREATE INDEX IF NOT EXISTS idx_msg_s2c_conversation_topic_id
  ON msg_s2c (conversation_uk3, topic_id);
CREATE INDEX IF NOT EXISTS idx_msg_s2c_conversation_uk3
  ON msg_s2c (conversation_uk3);
CREATE INDEX IF NOT EXISTS idx_msg_s2c_from_to_created
  ON msg_s2c (from_id, to_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_msg_s2c_action
  ON msg_s2c (action);

-- ============================================================
-- 更新版本号
-- ============================================================
PRAGMA user_version = 10;

-- ============================================================
-- VERSION: 11
-- DESC: 修复 msg_* 表缺少 type 和 action 字段的问题
-- ============================================================
-- 功能说明：修复 VERSION 10 迁移遗漏的字段
-- 变更内容：
--   1. 为所有 msg_* 表添加 type 字段（如果不存在）
--   2. 为所有 msg_* 表添加 action 字段（如果不存在）
--
-- 注意：
--   - type 字段用于存储消息协议类型（C2C、C2G、C2S、S2C）
--   - action 字段用于存储 S2C 消息的指令类型
--   - 此迁移会忽略"重复列"错误，因此可以安全地重复执行

-- ============================================================
-- Step 1: 为 msg_c2c 表添加缺失字段
-- ============================================================
ALTER TABLE msg_c2c ADD COLUMN type TEXT DEFAULT 'C2C';
ALTER TABLE msg_c2c ADD COLUMN action TEXT DEFAULT '';

-- ============================================================
-- Step 2: 为 msg_c2g 表添加缺失字段
-- ============================================================
ALTER TABLE msg_c2g ADD COLUMN type TEXT DEFAULT 'C2G';
ALTER TABLE msg_c2g ADD COLUMN action TEXT DEFAULT '';

-- ============================================================
-- Step 3: 为 msg_c2s 表添加缺失字段
-- ============================================================
ALTER TABLE msg_c2s ADD COLUMN type TEXT DEFAULT 'C2S';
ALTER TABLE msg_c2s ADD COLUMN action TEXT DEFAULT '';

-- ============================================================
-- Step 4: 为 msg_s2c 表添加缺失字段
-- ============================================================
ALTER TABLE msg_s2c ADD COLUMN type TEXT DEFAULT 'S2C';
ALTER TABLE msg_s2c ADD COLUMN action TEXT DEFAULT '';

-- ============================================================
-- 更新版本号
-- ============================================================
PRAGMA user_version = 11;

-- ============================================================
-- VERSION: 12
-- DESC: 最终修复 - 确保 msg_* 表包含所有必需字段
-- ============================================================
-- 功能说明：这是最后的保障迁移，确保所有字段都存在
-- 变更内容：
--   1. 为所有 msg_* 表添加 type 字段（如果不存在）
--   2. 为所有 msg_* 表添加 action 字段（如果不存在）
--
-- 注意：此迁移可以安全地重复执行，会忽略重复列错误

-- ============================================================
-- Step 1: 为 msg_c2c 表确保字段存在
-- ============================================================
ALTER TABLE msg_c2c ADD COLUMN type TEXT DEFAULT 'C2C';
ALTER TABLE msg_c2c ADD COLUMN action TEXT DEFAULT '';

-- ============================================================
-- Step 2: 为 msg_c2g 表确保字段存在
-- ============================================================
ALTER TABLE msg_c2g ADD COLUMN type TEXT DEFAULT 'C2G';
ALTER TABLE msg_c2g ADD COLUMN action TEXT DEFAULT '';

-- ============================================================
-- Step 3: 为 msg_c2s 表确保字段存在
-- ============================================================
ALTER TABLE msg_c2s ADD COLUMN type TEXT DEFAULT 'C2S';
ALTER TABLE msg_c2s ADD COLUMN action TEXT DEFAULT '';

-- ============================================================
-- Step 4: 为 msg_s2c 表确保字段存在
-- ============================================================
ALTER TABLE msg_s2c ADD COLUMN type TEXT DEFAULT 'S2C';
ALTER TABLE msg_s2c ADD COLUMN action TEXT DEFAULT '';

-- ============================================================
-- 更新版本号
-- ============================================================
PRAGMA user_version = 12;

-- ============================================================
-- VERSION: 13
-- DESC: Channel 频道功能 - 新增频道相关表
-- ============================================================
-- 功能说明：添加频道（Channel）功能的数据表
-- 变更内容：
--   1. 创建 channel 表 - 存储频道基础信息
--   2. 创建 channel_subscription 表 - 存储订阅关系
--   3. 创建 channel_message 表 - 存储频道消息
--   4. 创建 channel_admin 表 - 存储频道管理员
--
-- Channel 功能说明：
--   - 频道是一种单向关注型消息订阅机制
--   - 消息流向：管理员 → 订阅者
--   - 成员上限：无限制
--   - 加入方式：关注/订阅
--   - 发言权限：仅管理员/指定编辑

-- ============================================================
-- Step 1: 创建频道基础信息表
-- ============================================================
CREATE TABLE IF NOT EXISTS channel (
    id              TEXT PRIMARY KEY,      -- 频道 ID（UUID）
    name            TEXT NOT NULL,         -- 频道名称
    description     TEXT,                  -- 频道描述
    avatar          TEXT,                  -- 头像 URL
    type            INTEGER DEFAULT 0,     -- 0:公开 1:私有 2:付费
    custom_id       TEXT UNIQUE,           -- 自定义 ID (@xxx)
    creator_id      TEXT NOT NULL,         -- 创建者用户 ID
    subscriber_count INTEGER DEFAULT 0,    -- 订阅数（本地缓存）
    is_verified     INTEGER DEFAULT 0,     -- 是否认证
    tags            TEXT,                  -- 标签 JSON 数组
    created_at      INTEGER NOT NULL,      -- 创建时间戳（毫秒）
    updated_at      INTEGER NOT NULL       -- 更新时间戳（毫秒）
);

-- 频道表索引
CREATE INDEX IF NOT EXISTS idx_channel_custom_id ON channel(custom_id);
CREATE INDEX IF NOT EXISTS idx_channel_creator_id ON channel(creator_id);
CREATE INDEX IF NOT EXISTS idx_channel_type ON channel(type);

-- ============================================================
-- Step 2: 创建频道订阅关系表
-- ============================================================
CREATE TABLE IF NOT EXISTS channel_subscription (
    id                  INTEGER PRIMARY KEY AUTOINCREMENT,
    channel_id          TEXT NOT NULL,         -- 频道 ID
    subscribed_at       INTEGER NOT NULL,      -- 订阅时间戳
    last_read_at        INTEGER,               -- 最后阅读时间戳
    last_message_id     TEXT,                  -- 最后已读消息 ID
    unread_count        INTEGER DEFAULT 0,     -- 未读消息数
    notifications_enabled INTEGER DEFAULT 1,   -- 是否开启通知
    is_pinned           INTEGER DEFAULT 0,     -- 是否置顶
    is_muted            INTEGER DEFAULT 0,     -- 是否免打扰
    FOREIGN KEY (channel_id) REFERENCES channel(id) ON DELETE CASCADE,
    UNIQUE(channel_id)
);

-- 订阅关系表索引
CREATE INDEX IF NOT EXISTS idx_subscription_pinned ON channel_subscription(is_pinned);
CREATE INDEX IF NOT EXISTS idx_subscription_muted ON channel_subscription(is_muted);

-- ============================================================
-- Step 3: 创建频道消息表
-- ============================================================
CREATE TABLE IF NOT EXISTS channel_message (
    id                  TEXT PRIMARY KEY,      -- 消息 ID（UUID）
    channel_id          TEXT NOT NULL,         -- 频道 ID
    author_id           TEXT,                  -- 发布者用户 ID
    author_name         TEXT,                  -- 发布者名称（冗余存储）
    author_avatar       TEXT,                  -- 发布者头像（冗余存储）
    content             TEXT,                  -- 消息内容（文本或JSON）
    msg_type            TEXT NOT NULL,         -- 消息类型
    payload             TEXT,                  -- 扩展数据 JSON
    created_at          INTEGER NOT NULL,      -- 创建时间戳
    is_pinned           INTEGER DEFAULT 0,     -- 是否置顶
    view_count          INTEGER DEFAULT 0,     -- 阅读量（本地缓存）
    reaction_summary    TEXT,                  -- 反应统计 JSON {"👍":100,"❤️":50}
    FOREIGN KEY (channel_id) REFERENCES channel(id) ON DELETE CASCADE
);

-- 频道消息表索引
CREATE INDEX IF NOT EXISTS idx_channel_msg_channel_id ON channel_message(channel_id);
CREATE INDEX IF NOT EXISTS idx_channel_msg_created_at ON channel_message(channel_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_channel_msg_pinned ON channel_message(channel_id, is_pinned);

-- ============================================================
-- Step 4: 创建频道管理员表
-- ============================================================
CREATE TABLE IF NOT EXISTS channel_admin (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    channel_id      TEXT NOT NULL,         -- 频道 ID
    user_id         TEXT NOT NULL,         -- 管理员用户 ID
    role            INTEGER DEFAULT 0,     -- 0:编辑 1:管理员 2:创建者
    added_at        INTEGER NOT NULL,      -- 添加时间戳
    UNIQUE(channel_id, user_id),
    FOREIGN KEY (channel_id) REFERENCES channel(id) ON DELETE CASCADE
);

-- 频道管理员表索引
CREATE INDEX IF NOT EXISTS idx_channel_admin_user ON channel_admin(user_id);

-- ============================================================
-- 更新版本号
-- ============================================================
PRAGMA user_version = 13;

-- ============================================================
-- VERSION: 14
-- DESC: 性能优化 - 添加未读计数和重试队列专用索引
-- ============================================================
-- 功能说明：为核心高频查询添加覆盖索引，提升性能
-- 变更内容：
--   1. 添加 unread_count 专用索引：(conversation_uk3, is_author, auto_id)
--   2. 添加 retry_queue 专用索引：(status)
--
-- 优化场景：
--   - 未读数计算：COUNT(*) WHERE conversation_uk3=? AND is_author=0 AND auto_id>?
--   - 消息重试：SELECT * WHERE status IN (error, sending)

-- ============================================================
-- Step 1: 创建未读计数专用索引
-- ============================================================
-- msg_c2c
CREATE INDEX IF NOT EXISTS idx_msg_c2c_unread_count
  ON msg_c2c (conversation_uk3, is_author, auto_id);

-- msg_c2g
CREATE INDEX IF NOT EXISTS idx_msg_c2g_unread_count
  ON msg_c2g (conversation_uk3, is_author, auto_id);

-- msg_c2s
CREATE INDEX IF NOT EXISTS idx_msg_c2s_unread_count
  ON msg_c2s (conversation_uk3, is_author, auto_id);

-- ============================================================
-- Step 2: 创建重试队列专用索引
-- ============================================================
-- msg_c2c
CREATE INDEX IF NOT EXISTS idx_msg_c2c_status
  ON msg_c2c (status);

-- msg_c2g
CREATE INDEX IF NOT EXISTS idx_msg_c2g_status
  ON msg_c2g (status);

-- msg_c2s
CREATE INDEX IF NOT EXISTS idx_msg_c2s_status
  ON msg_c2s (status);

-- ============================================================
-- V15: 本地全文搜索 (FTS5)
-- ============================================================

-- C2C 消息全文搜索虚拟表
-- content='' 表示外部内容表模式，减少存储开销
-- tokenize='unicode61' 支持中文分词（基于 unicode 字符边界）
CREATE VIRTUAL TABLE IF NOT EXISTS msg_c2c_fts USING fts5(
  id,                     -- 消息 ID (用于关联原表)
  conversation_uk3,       -- 会话标识 (用于按会话过滤)
  text_content,           -- 可搜索的文本内容
  content='',             -- 外部内容模式
  tokenize='unicode61 remove_diacritics 2'
);

-- C2G 消息全文搜索虚拟表
CREATE VIRTUAL TABLE IF NOT EXISTS msg_c2g_fts USING fts5(
  id,
  conversation_uk3,
  text_content,
  content='',
  tokenize='unicode61 remove_diacritics 2'
);

-- ============================================================
-- 更新版本号
-- ============================================================
PRAGMA user_version = 15;

-- ============================================================
-- VERSION: 16
-- DESC: ID字段类型迁移 - TEXT/varchar(40) → INTEGER (对齐后端 PG18 BIGINT)
-- ============================================================
-- 功能说明：将所有 ID 字段从 TEXT 迁移为 INTEGER，与后端 TSID (BIGINT) 对齐
-- 背景：后端 PostgreSQL 18 已完成 TSID 迁移，所有 ID 使用 BIGINT
-- 迁移策略：表重建（CREATE→COPY→DROP→RENAME），SQLite 不支持 ALTER COLUMN TYPE
--
-- 影响表（18 张）：
--   contact, new_friend, user_denylist, user_device, user_collect, user_tag
--   group_notice, conversation, "group", group_member, user_group
--   msg_c2c, msg_c2g, msg_c2s, msg_s2c
--   channel, channel_subscription, channel_message, channel_admin
--
-- CAST 说明：
--   CAST('1838294017982464' AS INTEGER) → 1838294017982464
--   CAST('' AS INTEGER) → 0
--   CAST(NULL AS INTEGER) → NULL
--
-- 索引说明：
--   表重建会销毁原有索引，需重建所有索引（含 VERSION 14 的性能索引）

-- ============================================================
-- Step 1: 重建 contact 表
-- ============================================================
CREATE TABLE contact_new (
    auto_id INTEGER PRIMARY KEY,
    user_id INTEGER NOT NULL,
    peer_id INTEGER NOT NULL,
    nickname TEXT NOT NULL DEFAULT '',
    avatar TEXT NOT NULL DEFAULT '',
    gender INTEGER NOT NULL DEFAULT 0,
    account TEXT NOT NULL DEFAULT '',
    status TEXT NOT NULL DEFAULT '',
    remark TEXT DEFAULT '',
    tag TEXT DEFAULT '',
    region TEXT DEFAULT '',
    sign TEXT NOT NULL DEFAULT '',
    source TEXT NOT NULL DEFAULT '',
    updated_at INTEGER NOT NULL DEFAULT 0,
    is_friend INTEGER NOT NULL DEFAULT 0,
    is_from INTEGER NOT NULL DEFAULT 0,
    category_id INTEGER NOT NULL DEFAULT 0,
    CONSTRAINT uk_FromTo UNIQUE (user_id, peer_id)
);

INSERT INTO contact_new SELECT
    auto_id, CAST(user_id AS INTEGER), CAST(peer_id AS INTEGER),
    nickname, avatar, gender, account, status, remark, tag, region,
    sign, source, updated_at, is_friend, is_from, category_id
FROM contact;

DROP TABLE contact;

ALTER TABLE contact_new RENAME TO contact;

CREATE INDEX IF NOT EXISTS i_UserId_IsFriend_UpdateTime ON contact (user_id, is_friend, updated_at);
CREATE INDEX IF NOT EXISTS i_UserId_CategoryId ON contact (user_id, category_id);
CREATE INDEX IF NOT EXISTS i_Nickname ON contact (nickname);
CREATE INDEX IF NOT EXISTS i_Remark ON contact (remark);
CREATE INDEX IF NOT EXISTS i_Tag ON contact (tag);
CREATE INDEX IF NOT EXISTS idx_contact_user_id_peer_id ON contact (user_id, peer_id);

-- ============================================================
-- Step 2: 重建 new_friend 表
-- ============================================================
CREATE TABLE new_friend_new (
    auto_id INTEGER PRIMARY KEY,
    uid INTEGER NOT NULL,
    from_id INTEGER NOT NULL,
    to_id INTEGER NOT NULL,
    nickname TEXT NOT NULL DEFAULT '',
    avatar TEXT NOT NULL DEFAULT '',
    msg TEXT NOT NULL DEFAULT '',
    status TEXT NOT NULL DEFAULT '',
    payload TEXT DEFAULT '',
    updated_at INTEGER NOT NULL DEFAULT 0,
    created_at INTEGER NOT NULL DEFAULT 0,
    CONSTRAINT uk_FromTo UNIQUE (from_id, to_id)
);

INSERT INTO new_friend_new SELECT
    auto_id, CAST(uid AS INTEGER), CAST(from_id AS INTEGER), CAST(to_id AS INTEGER),
    nickname, avatar, msg, status, payload, updated_at, created_at
FROM new_friend;

DROP TABLE new_friend;

ALTER TABLE new_friend_new RENAME TO new_friend;

-- ============================================================
-- Step 3: 重建 user_denylist 表
-- ============================================================
CREATE TABLE user_denylist_new (
    auto_id INTEGER PRIMARY KEY,
    user_id INTEGER NOT NULL,
    denied_user_id INTEGER NOT NULL,
    nickname TEXT NOT NULL DEFAULT '',
    avatar TEXT NOT NULL DEFAULT '',
    gender INTEGER NOT NULL DEFAULT 0,
    account TEXT NOT NULL DEFAULT '',
    region TEXT DEFAULT '',
    sign TEXT NOT NULL DEFAULT '',
    source TEXT NOT NULL DEFAULT '',
    remark TEXT DEFAULT '',
    created_at INTEGER NOT NULL DEFAULT 0,
    CONSTRAINT i_Uid_DeniedUid UNIQUE (user_id, denied_user_id)
);

INSERT INTO user_denylist_new SELECT
    auto_id, CAST(user_id AS INTEGER), CAST(denied_user_id AS INTEGER),
    nickname, avatar, gender, account, region, sign, source, remark, created_at
FROM user_denylist;

DROP TABLE user_denylist;

ALTER TABLE user_denylist_new RENAME TO user_denylist;

-- ============================================================
-- Step 4: 重建 user_device 表
-- ============================================================
CREATE TABLE user_device_new (
    auto_id INTEGER PRIMARY KEY,
    user_id INTEGER NOT NULL,
    device_id TEXT NOT NULL DEFAULT '',
    device_name TEXT NOT NULL DEFAULT '',
    device_type TEXT NOT NULL DEFAULT '',
    last_active_at INTEGER NOT NULL DEFAULT 0,
    device_vsn TEXT DEFAULT '',
    CONSTRAINT i_Uid_DeviceId UNIQUE (user_id, device_id)
);

INSERT INTO user_device_new SELECT
    auto_id, CAST(user_id AS INTEGER),
    device_id, device_name, device_type, last_active_at, device_vsn
FROM user_device;

DROP TABLE user_device;

ALTER TABLE user_device_new RENAME TO user_device;

-- ============================================================
-- Step 5: 重建 user_collect 表
-- ============================================================
CREATE TABLE user_collect_new (
    auto_id INTEGER PRIMARY KEY,
    user_id INTEGER NOT NULL,
    kind INTEGER NOT NULL DEFAULT 0,
    kind_id INTEGER NOT NULL DEFAULT 0,
    source TEXT NOT NULL DEFAULT '',
    remark TEXT NOT NULL DEFAULT '',
    tag TEXT NOT NULL DEFAULT '',
    updated_at INTEGER NOT NULL DEFAULT 0,
    created_at INTEGER NOT NULL DEFAULT 0,
    info TEXT DEFAULT '',
    CONSTRAINT i_Uid_KindId UNIQUE (user_id, kind_id)
);

INSERT INTO user_collect_new SELECT
    auto_id, CAST(user_id AS INTEGER), kind, CAST(kind_id AS INTEGER),
    source, remark, tag, updated_at, created_at, info
FROM user_collect;

DROP TABLE user_collect;

ALTER TABLE user_collect_new RENAME TO user_collect;

CREATE INDEX IF NOT EXISTS i_Source ON user_collect (source);
CREATE INDEX IF NOT EXISTS idx_user_collect_user_id_kind ON user_collect (user_id, kind);

-- ============================================================
-- Step 6: 重建 user_tag 表
-- ============================================================
CREATE TABLE user_tag_new (
    auto_id INTEGER PRIMARY KEY,
    user_id INTEGER NOT NULL,
    tag_id INTEGER NOT NULL DEFAULT 0,
    scene INTEGER NOT NULL DEFAULT 0,
    name TEXT NOT NULL DEFAULT '',
    subtitle TEXT NOT NULL DEFAULT '',
    referer_time INTEGER NOT NULL DEFAULT 0,
    updated_at INTEGER NOT NULL DEFAULT 0,
    created_at INTEGER NOT NULL DEFAULT 0,
    CONSTRAINT i_Uid_Scene_Name UNIQUE (user_id, scene, name)
);

INSERT INTO user_tag_new SELECT
    auto_id, CAST(user_id AS INTEGER),
    tag_id, scene, name, subtitle, referer_time, updated_at, created_at
FROM user_tag;

DROP TABLE user_tag;

ALTER TABLE user_tag_new RENAME TO user_tag;

CREATE INDEX IF NOT EXISTS idx_user_tag_user_id_scene ON user_tag (user_id, scene);

-- ============================================================
-- Step 7: 重建 group_notice 表
-- ============================================================
CREATE TABLE group_notice_new (
    id INTEGER PRIMARY KEY,
    group_id INTEGER NOT NULL,
    user_id INTEGER NOT NULL,
    edit_user_id INTEGER NOT NULL DEFAULT 0,
    body TEXT DEFAULT '',
    status INTEGER NOT NULL DEFAULT 0,
    expired_at INTEGER DEFAULT 0,
    updated_at INTEGER DEFAULT 0,
    created_at INTEGER NOT NULL
);

INSERT INTO group_notice_new SELECT
    CAST(id AS INTEGER), CAST(group_id AS INTEGER), CAST(user_id AS INTEGER),
    CAST(edit_user_id AS INTEGER), body, status, expired_at, updated_at, created_at
FROM group_notice;

DROP TABLE group_notice;

ALTER TABLE group_notice_new RENAME TO group_notice;

CREATE INDEX IF NOT EXISTS i_Gid_Status_ExpiredAt ON group_notice (group_id, status, expired_at ASC);

-- ============================================================
-- Step 8: 重建 "group" 表
-- ============================================================
CREATE TABLE group_new (
    id INTEGER PRIMARY KEY,
    type INTEGER DEFAULT 1,
    join_limit INTEGER DEFAULT 2,
    content_limit INTEGER DEFAULT 2,
    user_id_sum INTEGER NOT NULL DEFAULT 0,
    owner_uid INTEGER NOT NULL,
    creator_uid INTEGER NOT NULL,
    member_max INTEGER NOT NULL DEFAULT 1000,
    member_count INTEGER NOT NULL DEFAULT 1,
    introduction TEXT NOT NULL DEFAULT '',
    avatar TEXT NOT NULL DEFAULT '',
    title TEXT NOT NULL DEFAULT '',
    status INTEGER NOT NULL DEFAULT 1,
    updated_at INTEGER DEFAULT 0,
    created_at INTEGER NOT NULL,
    pinned_msg TEXT
);

INSERT INTO group_new SELECT
    CAST(id AS INTEGER), type, join_limit, content_limit, user_id_sum,
    CAST(owner_uid AS INTEGER), CAST(creator_uid AS INTEGER),
    member_max, member_count, introduction, avatar, title, status,
    updated_at, created_at, pinned_msg
FROM "group";

DROP TABLE "group";

ALTER TABLE group_new RENAME TO "group";

-- ============================================================
-- Step 9: 重建 group_member 表
-- ============================================================
CREATE TABLE group_member_new (
    id INTEGER PRIMARY KEY,
    group_id INTEGER NOT NULL,
    user_id INTEGER NOT NULL,
    nickname TEXT DEFAULT '',
    avatar TEXT DEFAULT '',
    sign TEXT DEFAULT '',
    account TEXT DEFAULT '',
    invite_code TEXT DEFAULT '',
    alias TEXT DEFAULT '',
    description TEXT DEFAULT '',
    role INTEGER DEFAULT 0,
    is_join INTEGER DEFAULT 0,
    join_mode TEXT,
    status INTEGER NOT NULL DEFAULT 1,
    updated_at INTEGER DEFAULT 0,
    created_at INTEGER NOT NULL
);

INSERT INTO group_member_new SELECT
    CAST(id AS INTEGER), CAST(group_id AS INTEGER), CAST(user_id AS INTEGER),
    nickname, avatar, sign, account, invite_code, alias, description,
    role, is_join, join_mode, status, updated_at, created_at
FROM group_member;

DROP TABLE group_member;

ALTER TABLE group_member_new RENAME TO group_member;

CREATE UNIQUE INDEX IF NOT EXISTS uk_Gid_Uid ON group_member (group_id, user_id);
CREATE INDEX IF NOT EXISTS i_Uid_Gid_IsJoin ON group_member (user_id, group_id, is_join);
CREATE INDEX IF NOT EXISTS idx_group_member_user_id_status ON group_member (user_id, status);

-- ============================================================
-- Step 10: 重建 user_group 表
-- ============================================================
CREATE TABLE user_group_new (
    id INTEGER PRIMARY KEY,
    user_id INTEGER NOT NULL,
    group_id INTEGER NOT NULL,
    remark TEXT DEFAULT '',
    setting TEXT NOT NULL,
    status INTEGER DEFAULT 1 NOT NULL,
    updated_at INTEGER DEFAULT 0,
    created_at INTEGER NOT NULL
);

INSERT INTO user_group_new SELECT
    CAST(id AS INTEGER), CAST(user_id AS INTEGER), CAST(group_id AS INTEGER),
    remark, setting, status, updated_at, created_at
FROM user_group;

DROP TABLE user_group;

ALTER TABLE user_group_new RENAME TO user_group;

-- ============================================================
-- Step 11: 重建 conversation 表
-- ============================================================
CREATE TABLE conversation_new (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER,
    peer_id INTEGER,
    avatar TEXT,
    title TEXT,
    subtitle TEXT,
    region TEXT,
    sign TEXT,
    unread_num INTEGER,
    "type" TEXT,
    msg_type TEXT,
    is_show INTEGER,
    last_time INTEGER,
    last_msg_id INTEGER,
    last_msg_status INTEGER,
    payload TEXT
);

INSERT INTO conversation_new SELECT
    id, CAST(user_id AS INTEGER), CAST(peer_id AS INTEGER),
    avatar, title, subtitle, region, sign, unread_num,
    "type", msg_type, is_show, last_time,
    CAST(last_msg_id AS INTEGER), last_msg_status, payload
FROM conversation;

DROP TABLE conversation;

ALTER TABLE conversation_new RENAME TO conversation;

CREATE INDEX IF NOT EXISTS i_cv_UserId_IsShow_LastTime ON conversation (user_id, is_show, last_time);
CREATE UNIQUE INDEX IF NOT EXISTS uk_cv_Type_From_To ON conversation ("type", user_id, peer_id);
CREATE INDEX IF NOT EXISTS idx_conversation_user_id_last_time ON conversation (user_id, last_time DESC);

-- ============================================================
-- Step 12: 重建 msg_c2c 表
-- ============================================================
CREATE TABLE msg_c2c_new (
    auto_id INTEGER PRIMARY KEY,
    id INTEGER NOT NULL,
    msg_type TEXT,
    from_id INTEGER,
    to_id INTEGER,
    conversation_uk3 TEXT,
    e2ee TEXT,
    payload TEXT,
    created_at INTEGER,
    topic_id INTEGER,
    status INTEGER,
    is_author INTEGER,
    type TEXT DEFAULT 'C2C',
    action TEXT DEFAULT '',
    CONSTRAINT uk_MsgId UNIQUE (id)
);

INSERT INTO msg_c2c_new SELECT
    auto_id, CAST(id AS INTEGER), msg_type,
    CAST(from_id AS INTEGER), CAST(to_id AS INTEGER),
    conversation_uk3, e2ee, payload, created_at, topic_id,
    status, is_author, type, action
FROM msg_c2c;

DROP TABLE msg_c2c;

ALTER TABLE msg_c2c_new RENAME TO msg_c2c;

CREATE INDEX IF NOT EXISTS idx_msg_c2c_conversation_status_author ON msg_c2c (conversation_uk3, status, is_author);
CREATE INDEX IF NOT EXISTS idx_msg_c2c_conversation_created_at ON msg_c2c (conversation_uk3, created_at);
CREATE INDEX IF NOT EXISTS idx_msg_c2c_conversation_topic_id ON msg_c2c (conversation_uk3, topic_id);
CREATE INDEX IF NOT EXISTS idx_msg_c2c_conversation_uk3 ON msg_c2c (conversation_uk3);
CREATE INDEX IF NOT EXISTS idx_msg_c2c_from_to_created ON msg_c2c (from_id, to_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_msg_c2c_msg_type ON msg_c2c (msg_type);
CREATE INDEX IF NOT EXISTS idx_msg_c2c_unread_count ON msg_c2c (conversation_uk3, is_author, auto_id);
CREATE INDEX IF NOT EXISTS idx_msg_c2c_status ON msg_c2c (status);

-- ============================================================
-- Step 13: 重建 msg_c2g 表
-- ============================================================
CREATE TABLE msg_c2g_new (
    auto_id INTEGER PRIMARY KEY,
    id INTEGER NOT NULL,
    msg_type TEXT,
    from_id INTEGER,
    to_id INTEGER,
    conversation_uk3 TEXT,
    e2ee TEXT,
    payload TEXT,
    created_at INTEGER,
    topic_id INTEGER,
    status INTEGER,
    is_author INTEGER,
    type TEXT DEFAULT 'C2G',
    action TEXT DEFAULT '',
    CONSTRAINT uk_MsgId UNIQUE (id)
);

INSERT INTO msg_c2g_new SELECT
    auto_id, CAST(id AS INTEGER), msg_type,
    CAST(from_id AS INTEGER), CAST(to_id AS INTEGER),
    conversation_uk3, e2ee, payload, created_at, topic_id,
    status, is_author, type, action
FROM msg_c2g;

DROP TABLE msg_c2g;

ALTER TABLE msg_c2g_new RENAME TO msg_c2g;

CREATE INDEX IF NOT EXISTS idx_msg_c2g_conversation_status_author ON msg_c2g (conversation_uk3, status, is_author);
CREATE INDEX IF NOT EXISTS idx_msg_c2g_conversation_created_at ON msg_c2g (conversation_uk3, created_at);
CREATE INDEX IF NOT EXISTS idx_msg_c2g_conversation_topic_id ON msg_c2g (conversation_uk3, topic_id);
CREATE INDEX IF NOT EXISTS idx_msg_c2g_conversation_uk3 ON msg_c2g (conversation_uk3);
CREATE INDEX IF NOT EXISTS idx_msg_c2g_from_to_created ON msg_c2g (from_id, to_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_msg_c2g_msg_type ON msg_c2g (msg_type);
CREATE INDEX IF NOT EXISTS idx_msg_c2g_unread_count ON msg_c2g (conversation_uk3, is_author, auto_id);
CREATE INDEX IF NOT EXISTS idx_msg_c2g_status ON msg_c2g (status);

-- ============================================================
-- Step 14: 重建 msg_c2s 表
-- ============================================================
CREATE TABLE msg_c2s_new (
    auto_id INTEGER PRIMARY KEY,
    id INTEGER NOT NULL,
    msg_type TEXT,
    from_id INTEGER,
    to_id INTEGER,
    conversation_uk3 TEXT,
    e2ee TEXT,
    payload TEXT,
    created_at INTEGER,
    topic_id INTEGER,
    status INTEGER,
    is_author INTEGER,
    type TEXT DEFAULT 'C2S',
    action TEXT DEFAULT '',
    CONSTRAINT uk_MsgId UNIQUE (id)
);

INSERT INTO msg_c2s_new SELECT
    auto_id, CAST(id AS INTEGER), msg_type,
    CAST(from_id AS INTEGER), CAST(to_id AS INTEGER),
    conversation_uk3, e2ee, payload, created_at, topic_id,
    status, is_author, type, action
FROM msg_c2s;

DROP TABLE msg_c2s;

ALTER TABLE msg_c2s_new RENAME TO msg_c2s;

CREATE INDEX IF NOT EXISTS idx_msg_c2s_conversation_status_author ON msg_c2s (conversation_uk3, status, is_author);
CREATE INDEX IF NOT EXISTS idx_msg_c2s_conversation_created_at ON msg_c2s (conversation_uk3, created_at);
CREATE INDEX IF NOT EXISTS idx_msg_c2s_conversation_topic_id ON msg_c2s (conversation_uk3, topic_id);
CREATE INDEX IF NOT EXISTS idx_msg_c2s_conversation_uk3 ON msg_c2s (conversation_uk3);
CREATE INDEX IF NOT EXISTS idx_msg_c2s_from_to_created ON msg_c2s (from_id, to_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_msg_c2s_unread_count ON msg_c2s (conversation_uk3, is_author, auto_id);
CREATE INDEX IF NOT EXISTS idx_msg_c2s_status ON msg_c2s (status);

-- ============================================================
-- Step 15: 重建 msg_s2c 表
-- ============================================================
CREATE TABLE msg_s2c_new (
    auto_id INTEGER PRIMARY KEY,
    id INTEGER NOT NULL,
    action TEXT,
    msg_type TEXT,
    from_id INTEGER,
    to_id INTEGER,
    conversation_uk3 TEXT,
    e2ee TEXT,
    payload TEXT,
    created_at INTEGER,
    topic_id INTEGER,
    status INTEGER,
    is_author INTEGER,
    type TEXT DEFAULT 'S2C',
    CONSTRAINT uk_MsgId UNIQUE (id)
);

INSERT INTO msg_s2c_new SELECT
    auto_id, CAST(id AS INTEGER), action, msg_type,
    CAST(from_id AS INTEGER), CAST(to_id AS INTEGER),
    conversation_uk3, e2ee, payload, created_at, topic_id,
    status, is_author, type
FROM msg_s2c;

DROP TABLE msg_s2c;

ALTER TABLE msg_s2c_new RENAME TO msg_s2c;

CREATE INDEX IF NOT EXISTS idx_msg_s2c_conversation_status_author ON msg_s2c (conversation_uk3, status, is_author);
CREATE INDEX IF NOT EXISTS idx_msg_s2c_conversation_created_at ON msg_s2c (conversation_uk3, created_at);
CREATE INDEX IF NOT EXISTS idx_msg_s2c_conversation_topic_id ON msg_s2c (conversation_uk3, topic_id);
CREATE INDEX IF NOT EXISTS idx_msg_s2c_conversation_uk3 ON msg_s2c (conversation_uk3);
CREATE INDEX IF NOT EXISTS idx_msg_s2c_from_to_created ON msg_s2c (from_id, to_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_msg_s2c_action ON msg_s2c (action);

-- ============================================================
-- Step 16: 重建 channel 表
-- ============================================================
CREATE TABLE channel_new (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    avatar TEXT,
    type INTEGER DEFAULT 0,
    custom_id TEXT UNIQUE,
    creator_id INTEGER NOT NULL,
    subscriber_count INTEGER DEFAULT 0,
    is_verified INTEGER DEFAULT 0,
    tags TEXT,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL
);

INSERT INTO channel_new SELECT
    CAST(id AS INTEGER), name, description, avatar, type, custom_id,
    CAST(creator_id AS INTEGER), subscriber_count, is_verified, tags,
    created_at, updated_at
FROM channel;

DROP TABLE channel;

ALTER TABLE channel_new RENAME TO channel;

CREATE INDEX IF NOT EXISTS idx_channel_custom_id ON channel(custom_id);
CREATE INDEX IF NOT EXISTS idx_channel_creator_id ON channel(creator_id);
CREATE INDEX IF NOT EXISTS idx_channel_type ON channel(type);

-- ============================================================
-- Step 17: 重建 channel_subscription 表
-- ============================================================
CREATE TABLE channel_subscription_new (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    channel_id INTEGER NOT NULL,
    subscribed_at INTEGER NOT NULL,
    last_read_at INTEGER,
    last_message_id INTEGER,
    unread_count INTEGER DEFAULT 0,
    notifications_enabled INTEGER DEFAULT 1,
    is_pinned INTEGER DEFAULT 0,
    is_muted INTEGER DEFAULT 0,
    FOREIGN KEY (channel_id) REFERENCES channel(id) ON DELETE CASCADE,
    UNIQUE(channel_id)
);

INSERT INTO channel_subscription_new SELECT
    id, CAST(channel_id AS INTEGER), subscribed_at, last_read_at,
    CAST(last_message_id AS INTEGER), unread_count,
    notifications_enabled, is_pinned, is_muted
FROM channel_subscription;

DROP TABLE channel_subscription;

ALTER TABLE channel_subscription_new RENAME TO channel_subscription;

CREATE INDEX IF NOT EXISTS idx_subscription_pinned ON channel_subscription(is_pinned);
CREATE INDEX IF NOT EXISTS idx_subscription_muted ON channel_subscription(is_muted);

-- ============================================================
-- Step 18: 重建 channel_message 表
-- ============================================================
CREATE TABLE channel_message_new (
    id INTEGER PRIMARY KEY,
    channel_id INTEGER NOT NULL,
    author_id INTEGER,
    author_name TEXT,
    author_avatar TEXT,
    content TEXT,
    msg_type TEXT NOT NULL,
    payload TEXT,
    created_at INTEGER NOT NULL,
    is_pinned INTEGER DEFAULT 0,
    view_count INTEGER DEFAULT 0,
    reaction_summary TEXT,
    FOREIGN KEY (channel_id) REFERENCES channel(id) ON DELETE CASCADE
);

INSERT INTO channel_message_new SELECT
    CAST(id AS INTEGER), CAST(channel_id AS INTEGER), CAST(author_id AS INTEGER),
    author_name, author_avatar, content, msg_type, payload,
    created_at, is_pinned, view_count, reaction_summary
FROM channel_message;

DROP TABLE channel_message;

ALTER TABLE channel_message_new RENAME TO channel_message;

CREATE INDEX IF NOT EXISTS idx_channel_msg_channel_id ON channel_message(channel_id);
CREATE INDEX IF NOT EXISTS idx_channel_msg_created_at ON channel_message(channel_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_channel_msg_pinned ON channel_message(channel_id, is_pinned);

-- ============================================================
-- Step 19: 重建 channel_admin 表
-- ============================================================
CREATE TABLE channel_admin_new (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    channel_id INTEGER NOT NULL,
    user_id INTEGER NOT NULL,
    role INTEGER DEFAULT 0,
    added_at INTEGER NOT NULL,
    UNIQUE(channel_id, user_id),
    FOREIGN KEY (channel_id) REFERENCES channel(id) ON DELETE CASCADE
);

INSERT INTO channel_admin_new SELECT
    id, CAST(channel_id AS INTEGER), CAST(user_id AS INTEGER),
    role, added_at
FROM channel_admin;

DROP TABLE channel_admin;

ALTER TABLE channel_admin_new RENAME TO channel_admin;

CREATE INDEX IF NOT EXISTS idx_channel_admin_user ON channel_admin(user_id);

-- ============================================================
-- 更新版本号
-- ============================================================
PRAGMA user_version = 16;

-- VERSION: 17
-- DESC: C7-β 独立 @ 未读计数 - 为 conversation 表添加 mention_unread 字段
-- ============================================================

-- ============================================================
-- Step 1: 为 conversation 表新增 mention_unread 列（默认 0）
-- ============================================================
ALTER TABLE conversation ADD COLUMN mention_unread INTEGER NOT NULL DEFAULT 0;

-- ============================================================
-- 更新版本号
-- ============================================================
PRAGMA user_version = 17;

-- VERSION: 18
-- DESC: C7-α-1 本地群免打扰 (DND) - 为 conversation 表添加 is_muted 字段
-- ============================================================

-- ============================================================
-- Step 1: 为 conversation 表新增 is_muted 列（默认 0 = 不免打扰）
-- ============================================================
ALTER TABLE conversation ADD COLUMN is_muted INTEGER NOT NULL DEFAULT 0;

-- ============================================================
-- 更新版本号
-- ============================================================
PRAGMA user_version = 18;

-- VERSION: 19
-- DESC: 群成员禁言 - 为 group_member 表添加 mute_until 字段
--       对齐后端 priv/migrations/00000051_group_member_mute.sql。
--       语义：解除禁言的 epoch 毫秒；NULL 表示未被禁言（**不得**退化为 now，
--       否则旧数据会被误判为禁言中）。
-- ============================================================

-- ============================================================
-- Step 1: 为 group_member 表新增 mute_until 列（默认 NULL = 未禁言）
-- ============================================================
ALTER TABLE group_member ADD COLUMN mute_until INTEGER DEFAULT NULL;

-- ============================================================
-- Step 2: 部分索引（仅为禁言中的成员建索引，降低存储与维护成本）
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_group_member_mute_until
  ON group_member(group_id, user_id)
  WHERE mute_until IS NOT NULL;

-- ============================================================
-- 更新版本号
-- ============================================================
PRAGMA user_version = 19;

-- VERSION: 20
-- DESC: 朋友圈通知中心 (Slice A-1) - 新增 moment_notify 表
--       后端 moment_logic_notify:notify_post_liked/3 模式为 no_save，
--       点赞通知不入服务端历史表；客户端必须本地落库才能做通知中心红点
--       与历史列表。评论通知后端 save 但我们仍本地持久化以统一 UX。
-- ============================================================

-- ============================================================
-- Step 1: 创建 moment_notify 表
-- ============================================================
CREATE TABLE IF NOT EXISTS moment_notify (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id TEXT NOT NULL,
  action TEXT NOT NULL,
  moment_id TEXT NOT NULL,
  from_uid TEXT NOT NULL,
  comment_id TEXT,
  is_read INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL
);

-- ============================================================
-- Step 2: 防 S2C 重复的唯一索引
--         action + moment_id + from_uid + comment_id 四元组唯一。
--         moment_like 时 comment_id 为 NULL，SQLite 唯一索引允许多行 NULL，
--         所以评论与点赞不会互相冲突。
-- ============================================================
CREATE UNIQUE INDEX IF NOT EXISTS uq_moment_notify_dedup
  ON moment_notify(user_id, action, moment_id, from_uid, comment_id);

-- ============================================================
-- Step 3: 列表与未读计数加速索引
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_moment_notify_user_read
  ON moment_notify(user_id, is_read, created_at DESC);

-- ============================================================
-- 更新版本号
-- ============================================================
PRAGMA user_version = 20;

-- VERSION: 21
-- DESC: 修复 moment_notify 唯一索引 NULL 语义问题
--       SQLite 的 "NULL != NULL" 语义使 `comment_id IS NULL` 的 moment_like 行
--       无法被原有唯一索引拦截；`ConflictAlgorithm.ignore` 对含 NULL 列组无效，
--       导致重复 S2C 推送会被允许插入（客户端通知中心出现重复项）。
--       解决方案：DROP 旧索引，重建时用 `COALESCE(comment_id, '')` 将 NULL
--       折叠为空串参与唯一约束。moment_like（comment_id=NULL）折叠后
--       以 '' 参与比较，moment_comment（comment_id 非 NULL）按原值比较，
--       两者仍互不冲突（action 已区分）。
-- ============================================================

DROP INDEX IF EXISTS uq_moment_notify_dedup;

CREATE UNIQUE INDEX IF NOT EXISTS uq_moment_notify_dedup
  ON moment_notify(
    user_id,
    action,
    moment_id,
    from_uid,
    COALESCE(comment_id, '')
  );

-- ============================================================
-- 更新版本号
-- ============================================================
PRAGMA user_version = 21;

-- ============================================================
-- VERSION: 22
-- DESC: user_collect.kind_id INTEGER → TEXT（QA#31）
--       消息 id 是 String Xid（base32hex），INTEGER 列使
--       parseModelInt 把 Xid 静默归零为 0：首条 kind_id=0 记录
--       占位后，所有后续收藏均触发 UNIQUE(user_id,kind_id) 冲突
--       且异常未捕获（收藏功能实质坏死、用户零感知）。
--       重建表为 TEXT 列，并清除历史 kind_id=0/'0' 脏行
--       （本地缓存，可从服务端重拉）。
-- ============================================================

CREATE TABLE user_collect_new (
    auto_id INTEGER PRIMARY KEY,
    user_id INTEGER NOT NULL,
    kind INTEGER NOT NULL DEFAULT 0,
    kind_id TEXT NOT NULL DEFAULT '',
    source TEXT NOT NULL DEFAULT '',
    remark TEXT NOT NULL DEFAULT '',
    tag TEXT NOT NULL DEFAULT '',
    updated_at INTEGER NOT NULL DEFAULT 0,
    created_at INTEGER NOT NULL DEFAULT 0,
    info TEXT DEFAULT '',
    CONSTRAINT i_Uid_KindId UNIQUE (user_id, kind_id)
);

INSERT INTO user_collect_new (
    auto_id, user_id, kind, kind_id, source, remark, tag,
    updated_at, created_at, info
)
SELECT auto_id, user_id, kind, CAST(kind_id AS TEXT), source, remark, tag,
    updated_at, created_at, info
FROM user_collect
WHERE CAST(kind_id AS TEXT) NOT IN ('0', '');

DROP TABLE user_collect;
ALTER TABLE user_collect_new RENAME TO user_collect;

CREATE INDEX i_Source ON user_collect (source);
CREATE INDEX idx_user_collect_user_id_kind ON user_collect (user_id, kind);

-- ============================================================
-- 更新版本号
-- ============================================================
PRAGMA user_version = 22;

-- ============================================================
-- VERSION: 23
-- DESC: channel_message 新增 my_reactions 列（当前用户已添加的
--       反应类型 JSON 数组，如 ["like"]）。后端消息列表已随行
--       返回 my_reactions，本地缓存需持久化，否则从缓存渲染时
--       「我已赞」状态丢失（刷新/重进后点赞误走 add 而非 remove）。
-- ============================================================

ALTER TABLE channel_message ADD COLUMN my_reactions TEXT;

-- ============================================================
-- 更新版本号
-- ============================================================
PRAGMA user_version = 23;
""";

/// 与 assets/migrations/downgrade.sql 内容保持同步（同上）。
const String kDowngradeScriptSql = r"""
-- ============================================================
-- 数据库降级脚本
-- SQLite Database Downgrade Scripts
-- ============================================================
-- 说明：
--   每个版本块以 -- VERSION: 开头，包含该版本的所有降级 SQL
--
-- 重要：
--   VERSION 标记的是目标版本号（降级到此版本）
--   PRAGMA user_version 设置的是降级后的版本号
--
-- 标记说明：
--   VERSION: 目标版本号
--   DESC: 版本描述
--
-- 使用方法：
--   1. 应用降级时 MigrationService 自动执行降级
--   2. SqliteService 通过 onDowngrade 回调触发降级
--
-- 注意事项：
--   - 降级可能导致数据丢失，请谨慎操作
--   - 建议在降级前备份数据库
--   - 某些降级可能无法完全还原
-- ============================================================

-- ============================================================
-- VERSION: 9
-- DESC: 降级到基线版本
-- ============================================================
-- 降级说明：从更高版本降级到基线版本 v9
-- 数据影响：高于 v9 版本的新增字段和数据将丢失
--
-- 当前版本无需降级，此块留空
-- PRAGMA user_version = 9;

-- ============================================================
-- VERSION: 10
-- DESC: 从 v10 降级到 v9（回退 WebSocket API v2.0 消息表结构）
-- ============================================================
-- 降级说明：回退 WebSocket API v2.0 更改，恢复旧表名
-- 数据影响：
--   - msg_type, action, e2ee 字段中的数据将丢失
--   - 表名恢复为旧名称（message, group_message, c2s_message, s2c_message）
--   - 所有索引重建为旧格式
--
-- 注意：此降级操作会丢失 v2.0 新增字段的数据，无法恢复

-- ============================================================
-- Step 1: 删除 v10 版本新增的索引
-- ============================================================

-- 删除 msg_c2c 表的索引
DROP INDEX IF EXISTS idx_msg_c2c_conversation_status_author;
DROP INDEX IF EXISTS idx_msg_c2c_conversation_created_at;
DROP INDEX IF EXISTS idx_msg_c2c_conversation_topic_id;
DROP INDEX IF EXISTS idx_msg_c2c_conversation_uk3;
DROP INDEX IF EXISTS idx_msg_c2c_from_to_created;
DROP INDEX IF EXISTS idx_msg_c2c_msg_type;

-- 删除 msg_c2g 表的索引
DROP INDEX IF EXISTS idx_msg_c2g_conversation_status_author;
DROP INDEX IF EXISTS idx_msg_c2g_conversation_created_at;
DROP INDEX IF EXISTS idx_msg_c2g_conversation_topic_id;
DROP INDEX IF EXISTS idx_msg_c2g_conversation_uk3;
DROP INDEX IF EXISTS idx_msg_c2g_from_to_created;
DROP INDEX IF EXISTS idx_msg_c2g_msg_type;

-- 删除 msg_c2s 表的索引
DROP INDEX IF EXISTS idx_msg_c2s_conversation_status_author;
DROP INDEX IF EXISTS idx_msg_c2s_conversation_created_at;
DROP INDEX IF EXISTS idx_msg_c2s_conversation_topic_id;
DROP INDEX IF EXISTS idx_msg_c2s_conversation_uk3;
DROP INDEX IF EXISTS idx_msg_c2s_from_to_created;

-- 删除 msg_s2c 表的索引
DROP INDEX IF EXISTS idx_msg_s2c_conversation_status_author;
DROP INDEX IF EXISTS idx_msg_s2c_conversation_created_at;
DROP INDEX IF EXISTS idx_msg_s2c_conversation_topic_id;
DROP INDEX IF EXISTS idx_msg_s2c_conversation_uk3;
DROP INDEX IF EXISTS idx_msg_s2c_from_to_created;
DROP INDEX IF EXISTS idx_msg_s2c_action;

-- ============================================================
-- Step 2: 重命名表回旧名称
-- ============================================================

-- 重命名 msg_c2c → message
ALTER TABLE msg_c2c RENAME TO message;

-- 重命名 msg_c2g → group_message
ALTER TABLE msg_c2g RENAME TO group_message;

-- 重命名 msg_c2s → c2s_message
ALTER TABLE msg_c2s RENAME TO c2s_message;

-- 重命名 msg_s2c → s2c_message
ALTER TABLE msg_s2c RENAME TO s2c_message;

-- ============================================================
-- Step 3: 删除 v2.0 新增的字段（使用表重建方式）
-- ============================================================
-- 说明：SQLite < 3.35.0 不支持 DROP COLUMN
-- 使用表重建方式：创建新表 → 复制数据 → 删除旧表 → 重命名

-- 删除 message 表的 v2.0 字段（msg_type, action, e2ee）
-- 注意：这些字段中的数据将丢失
CREATE TABLE IF NOT EXISTS message_new (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  type TEXT NOT NULL DEFAULT 'C2C',
  from_id TEXT NOT NULL,
  to_id TEXT NOT NULL,
  payload TEXT NOT NULL,
  status INTEGER NOT NULL DEFAULT 0,
  is_author INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL,
  conversation_uk3 TEXT NOT NULL,
  topic_id INTEGER NOT NULL DEFAULT 0
);
INSERT INTO message_new (id, type, from_id, to_id, payload, status, is_author, created_at, conversation_uk3, topic_id)
  SELECT id, type, from_id, to_id, payload, status, is_author, created_at, conversation_uk3, topic_id FROM message;
DROP TABLE message;
ALTER TABLE message_new RENAME TO message;

-- 删除 group_message 表的 v2.0 字段
CREATE TABLE IF NOT EXISTS group_message_new (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  type TEXT NOT NULL DEFAULT 'C2G',
  from_id TEXT NOT NULL,
  to_id TEXT NOT NULL,
  payload TEXT NOT NULL,
  status INTEGER NOT NULL DEFAULT 0,
  is_author INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL,
  conversation_uk3 TEXT NOT NULL,
  topic_id INTEGER NOT NULL DEFAULT 0
);
INSERT INTO group_message_new (id, type, from_id, to_id, payload, status, is_author, created_at, conversation_uk3, topic_id)
  SELECT id, type, from_id, to_id, payload, status, is_author, created_at, conversation_uk3, topic_id FROM group_message;
DROP TABLE group_message;
ALTER TABLE group_message_new RENAME TO group_message;

-- 删除 c2s_message 表的 v2.0 字段
CREATE TABLE IF NOT EXISTS c2s_message_new (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  type TEXT NOT NULL DEFAULT 'C2S',
  from_id TEXT NOT NULL,
  to_id TEXT NOT NULL,
  payload TEXT NOT NULL,
  status INTEGER NOT NULL DEFAULT 0,
  is_author INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL,
  conversation_uk3 TEXT NOT NULL,
  topic_id INTEGER NOT NULL DEFAULT 0
);
INSERT INTO c2s_message_new (id, type, from_id, to_id, payload, status, is_author, created_at, conversation_uk3, topic_id)
  SELECT id, type, from_id, to_id, payload, status, is_author, created_at, conversation_uk3, topic_id FROM c2s_message;
DROP TABLE c2s_message;
ALTER TABLE c2s_message_new RENAME TO c2s_message;

-- 删除 s2c_message 表的 v2.0 字段
CREATE TABLE IF NOT EXISTS s2c_message_new (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  type TEXT NOT NULL DEFAULT 'S2C',
  from_id TEXT NOT NULL,
  to_id TEXT NOT NULL,
  payload TEXT NOT NULL,
  status INTEGER NOT NULL DEFAULT 0,
  is_author INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL,
  conversation_uk3 TEXT NOT NULL,
  topic_id INTEGER NOT NULL DEFAULT 0
);
INSERT INTO s2c_message_new (id, type, from_id, to_id, payload, status, is_author, created_at, conversation_uk3, topic_id)
  SELECT id, type, from_id, to_id, payload, status, is_author, created_at, conversation_uk3, topic_id FROM s2c_message;
DROP TABLE s2c_message;
ALTER TABLE s2c_message_new RENAME TO s2c_message;

-- ============================================================
-- Step 4: 重建旧版本索引
-- ============================================================

-- message 表索引 (C2C)
CREATE INDEX IF NOT EXISTS idx_c2c_msg_conversation_status_author
  ON message (conversation_uk3, status, is_author);
CREATE INDEX IF NOT EXISTS i_c2c_msg_Conversation_CreatedAt
  ON message (conversation_uk3, created_at);
CREATE INDEX IF NOT EXISTS i_c2c_msg_Conversation_TopicId
  ON message (conversation_uk3, topic_id);
CREATE INDEX IF NOT EXISTS idx_message_conversation_uk3
  ON message (conversation_uk3);
CREATE INDEX IF NOT EXISTS idx_message_from_to_created
  ON message (from_id, to_id, created_at DESC);

-- group_message 表索引 (C2G)
CREATE INDEX IF NOT EXISTS idx_c2g_msg_conversation_status_author
  ON group_message (conversation_uk3, status, is_author);
CREATE INDEX IF NOT EXISTS i_c2g_msg_Conversation_CreatedAt
  ON group_message (conversation_uk3, created_at);
CREATE INDEX IF NOT EXISTS i_c2g_msg_Conversation_TopicId
  ON group_message (conversation_uk3, topic_id);
CREATE INDEX IF NOT EXISTS idx_c2g_message_conversation_uk3
  ON group_message (conversation_uk3);

-- c2s_message 表索引 (C2S)
CREATE INDEX IF NOT EXISTS idx_c2s_msg_conversation_status_author
  ON c2s_message (conversation_uk3, status, is_author);
CREATE INDEX IF NOT EXISTS i_c2s_msg_Conversation_CreatedAt
  ON c2s_message (conversation_uk3, created_at);
CREATE INDEX IF NOT EXISTS i_c2s_msg_Conversation_TopicId
  ON c2s_message (conversation_uk3, topic_id);
CREATE INDEX IF NOT EXISTS idx_c2s_message_conversation_uk3
  ON c2s_message (conversation_uk3);
CREATE INDEX IF NOT EXISTS idx_c2s_message_from_to_created
  ON c2s_message (from_id, to_id, created_at DESC);

-- s2c_message 表索引 (S2C)
CREATE INDEX IF NOT EXISTS idx_s2c_msg_conversation_status_author
  ON s2c_message (conversation_uk3, status, is_author);
CREATE INDEX IF NOT EXISTS i_s2c_msg_Conversation_CreatedAt
  ON s2c_message (conversation_uk3, created_at);
CREATE INDEX IF NOT EXISTS i_s2c_msg_Conversation_TopicId
  ON s2c_message (conversation_uk3, topic_id);
CREATE INDEX IF NOT EXISTS idx_s2c_message_conversation_uk3
  ON s2c_message (conversation_uk3);
CREATE INDEX IF NOT EXISTS idx_s2c_message_from_to_created
  ON s2c_message (from_id, to_id, created_at DESC);

-- ============================================================
-- 更新版本号
-- ============================================================
PRAGMA user_version = 9;
-- ============================================================
-- VERSION: 17
-- DESC: 从 v17 降级到 v16（移除 conversation.mention_unread 字段）
-- ============================================================
-- SQLite 3.35 前不支持 DROP COLUMN，采用重建表模式

CREATE TABLE conversation_v16 (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER,
    peer_id INTEGER,
    avatar TEXT,
    title TEXT,
    subtitle TEXT,
    region TEXT,
    sign TEXT,
    unread_num INTEGER,
    "type" TEXT,
    msg_type TEXT,
    is_show INTEGER,
    last_time INTEGER,
    last_msg_id INTEGER,
    last_msg_status INTEGER,
    payload TEXT
);

INSERT INTO conversation_v16
    (id, user_id, peer_id, avatar, title, subtitle, region, sign,
     unread_num, "type", msg_type, is_show, last_time,
     last_msg_id, last_msg_status, payload)
SELECT
    id, user_id, peer_id, avatar, title, subtitle, region, sign,
    unread_num, "type", msg_type, is_show, last_time,
    last_msg_id, last_msg_status, payload
FROM conversation;

DROP TABLE conversation;

ALTER TABLE conversation_v16 RENAME TO conversation;

-- 重建 conversation 表的 v16 索引
CREATE INDEX IF NOT EXISTS i_cv_UserId_IsShow_LastTime ON conversation (user_id, is_show, last_time);
CREATE UNIQUE INDEX IF NOT EXISTS uk_cv_Type_From_To ON conversation ("type", user_id, peer_id);
CREATE INDEX IF NOT EXISTS idx_conversation_user_id_last_time ON conversation (user_id, last_time DESC);

PRAGMA user_version = 16;

-- ============================================================
-- VERSION: 18
-- DESC: 从 v18 降级到 v17（移除 conversation.is_muted，保留 mention_unread）
-- ============================================================

CREATE TABLE conversation_v17 (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER,
    peer_id INTEGER,
    avatar TEXT,
    title TEXT,
    subtitle TEXT,
    region TEXT,
    sign TEXT,
    unread_num INTEGER,
    "type" TEXT,
    msg_type TEXT,
    is_show INTEGER,
    last_time INTEGER,
    last_msg_id INTEGER,
    last_msg_status INTEGER,
    payload TEXT,
    mention_unread INTEGER NOT NULL DEFAULT 0
);

INSERT INTO conversation_v17
    (id, user_id, peer_id, avatar, title, subtitle, region, sign,
     unread_num, "type", msg_type, is_show, last_time,
     last_msg_id, last_msg_status, payload, mention_unread)
SELECT
    id, user_id, peer_id, avatar, title, subtitle, region, sign,
    unread_num, "type", msg_type, is_show, last_time,
    last_msg_id, last_msg_status, payload, mention_unread
FROM conversation;

DROP TABLE conversation;

ALTER TABLE conversation_v17 RENAME TO conversation;

-- 重建 v17 conversation 索引（与 v18 前完全一致）
CREATE INDEX IF NOT EXISTS i_cv_UserId_IsShow_LastTime ON conversation (user_id, is_show, last_time);
CREATE UNIQUE INDEX IF NOT EXISTS uk_cv_Type_From_To ON conversation ("type", user_id, peer_id);
CREATE INDEX IF NOT EXISTS idx_conversation_user_id_last_time ON conversation (user_id, last_time DESC);

PRAGMA user_version = 17;
""";

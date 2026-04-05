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

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

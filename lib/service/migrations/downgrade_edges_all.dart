// 降级边（块 31,29,28,10,17..25；缺口边见 migration_script_planner）
//
// WP3 bootstrap 从 assets/migrations/*.sql 机械提取（2026-08-27）；
// headerComment + sql 拼接 == 原块原文（生成器 --check 守护字节级一致）。
// 此后本文件是唯一真源；元数据修改必须过 migration_manifest_test.dart。
library;

import 'package:imboy/service/migration_manifest.dart';

const List<MigrationEdge> kDowngradeEdgesAll = [
  MigrationEdge(
    id: 'downgrade_v32_恢复_group_user_id_sum_列',
    fromVersion: 32,
    toVersion: 31,
    description: '从 v32 降级到 v31（group 恢复 user_id_sum 列，历史值置 0）。',
    reversible: false,
    dataLoss: true,
    requiresResync: false,
    preconditions: [
      'downgrade 前 v32 schema 处于一致状态（integrity/foreign_key check 通过）',
    ],
    postconditions: ['v31 结构生效：PRAGMA user_version = 31'],
    affectedObjects: ['group'],
    headerComment:
        r"""-- ============================================================
-- VERSION: 32
-- DESC: 从 v32 降级到 v31（group 恢复 user_id_sum 列）。
--       降级配对边：恢复列结构（ADD COLUMN 带 DEFAULT，无需重建表），
--       历史 sum 值不还原（恒 0）——该列本就是已退役的死数据。
-- ============================================================

""",
    sql:
        r"""ALTER TABLE "group" ADD COLUMN user_id_sum INTEGER NOT NULL DEFAULT 0;

-- ============================================================
-- 更新版本号
-- ============================================================
PRAGMA user_version = 31;

""",
  ),
  MigrationEdge(
    id: 'legacy_downgrade_v31_从_v31_降级到_v30',
    fromVersion: 31,
    toVersion: 30,
    description:
        '从 v31 降级到 v30（移除 channel 表 visibility/access_type/join_policy',
    reversible: false,
    dataLoss: true,
    requiresResync: false,
    preconditions: [
      'downgrade 前 v31 schema 处于一致状态（integrity/foreign_key check 通过）',
    ],
    postconditions: ['v30 结构生效：PRAGMA user_version = 30'],
    affectedObjects: [
      'channel',
      'channel_v30',
      'idx_channel_creator_id',
      'idx_channel_custom_id',
      'idx_channel_type',
    ],
    headerComment:
        r"""-- ============================================================
-- VERSION: 31
-- DESC: 从 v31 降级到 v30（移除 channel 表 visibility/access_type/join_policy
--       三列，恢复 type 列为唯一权威与 idx_channel_type 索引）
-- ============================================================

""",
    sql: r"""CREATE TABLE channel_v30 (
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
    updated_at INTEGER NOT NULL,
    user_role INTEGER DEFAULT 0,
    is_subscribed INTEGER DEFAULT 0,
    has_purchased INTEGER DEFAULT 0
);

INSERT INTO channel_v30 (
    id, name, description, avatar, type, custom_id, creator_id,
    subscriber_count, is_verified, tags, created_at, updated_at,
    user_role, is_subscribed, has_purchased
)
SELECT
    id, name, description, avatar, type, custom_id, creator_id,
    subscriber_count, is_verified, tags, created_at, updated_at,
    user_role, is_subscribed, has_purchased
FROM channel;

DROP TABLE channel;
ALTER TABLE channel_v30 RENAME TO channel;

CREATE INDEX IF NOT EXISTS idx_channel_custom_id ON channel(custom_id);
CREATE INDEX IF NOT EXISTS idx_channel_creator_id ON channel(creator_id);
CREATE INDEX IF NOT EXISTS idx_channel_type ON channel(type);

PRAGMA user_version = 30;

""",
  ),
  MigrationEdge(
    id: 'legacy_downgrade_v29_从_v29_降级到_v28',
    fromVersion: 29,
    toVersion: 28,
    description: '从 v29 降级到 v28（删除频道消息发布 outbox）',
    reversible: false,
    dataLoss: true,
    requiresResync: true,
    preconditions: [
      'downgrade 前 v29 schema 处于一致状态（integrity/foreign_key check 通过）',
    ],
    postconditions: ['v28 结构生效：PRAGMA user_version = 28'],
    affectedObjects: ['channel_publish_outbox'],
    headerComment:
        r"""-- ============================================================
-- VERSION: 29
-- DESC: 从 v29 降级到 v28（删除频道消息发布 outbox）
-- ============================================================

""",
    sql: r"""DROP TABLE IF EXISTS channel_publish_outbox;
PRAGMA user_version = 28;

""",
  ),
  MigrationEdge(
    id: 'legacy_downgrade_v28_从_v28_降级到_v27',
    fromVersion: 28,
    toVersion: 27,
    description: '从 v28 降级到 v27（删除频道消息本地 outbox）',
    reversible: false,
    dataLoss: true,
    requiresResync: true,
    preconditions: [
      'downgrade 前 v28 schema 处于一致状态（integrity/foreign_key check 通过）',
    ],
    postconditions: ['v27 结构生效：PRAGMA user_version = 27'],
    affectedObjects: ['channel_message_outbox'],
    headerComment:
        r"""-- ============================================================
-- VERSION: 28
-- DESC: 从 v28 降级到 v27（删除频道消息本地 outbox）
-- ============================================================

""",
    sql: r"""DROP TABLE IF EXISTS channel_message_outbox;
PRAGMA user_version = 27;

""",
  ),
  MigrationEdge(
    id: 'legacy_downgrade_v10_从_v10_降级到_v9',
    fromVersion: 10,
    toVersion: 9,
    description: '从 v10 降级到 v9（回退 WebSocket API v2.0 消息表结构）',
    reversible: false,
    dataLoss: true,
    requiresResync: true,
    preconditions: [
      'downgrade 前 v10 schema 处于一致状态（integrity/foreign_key check 通过）',
    ],
    postconditions: ['v9 结构生效：PRAGMA user_version = 9'],
    affectedObjects: [
      'c2s_message',
      'c2s_message_new',
      'group_message',
      'group_message_new',
      'i_c2c_msg_Conversation_CreatedAt',
      'i_c2c_msg_Conversation_TopicId',
      'i_c2g_msg_Conversation_CreatedAt',
      'i_c2g_msg_Conversation_TopicId',
      'i_c2s_msg_Conversation_CreatedAt',
      'i_c2s_msg_Conversation_TopicId',
      'i_s2c_msg_Conversation_CreatedAt',
      'i_s2c_msg_Conversation_TopicId',
      'idx_c2c_msg_conversation_status_author',
      'idx_c2g_message_conversation_uk3',
      'idx_c2g_msg_conversation_status_author',
      'idx_c2s_message_conversation_uk3',
      'idx_c2s_message_from_to_created',
      'idx_c2s_msg_conversation_status_author',
      'idx_message_conversation_uk3',
      'idx_message_from_to_created',
      'idx_msg_c2c_conversation_created_at',
      'idx_msg_c2c_conversation_status_author',
      'idx_msg_c2c_conversation_topic_id',
      'idx_msg_c2c_conversation_uk3',
      'idx_msg_c2c_from_to_created',
      'idx_msg_c2c_msg_type',
      'idx_msg_c2g_conversation_created_at',
      'idx_msg_c2g_conversation_status_author',
      'idx_msg_c2g_conversation_topic_id',
      'idx_msg_c2g_conversation_uk3',
      'idx_msg_c2g_from_to_created',
      'idx_msg_c2g_msg_type',
      'idx_msg_c2s_conversation_created_at',
      'idx_msg_c2s_conversation_status_author',
      'idx_msg_c2s_conversation_topic_id',
      'idx_msg_c2s_conversation_uk3',
      'idx_msg_c2s_from_to_created',
      'idx_msg_s2c_action',
      'idx_msg_s2c_conversation_created_at',
      'idx_msg_s2c_conversation_status_author',
      'idx_msg_s2c_conversation_topic_id',
      'idx_msg_s2c_conversation_uk3',
      'idx_msg_s2c_from_to_created',
      'idx_s2c_message_conversation_uk3',
      'idx_s2c_message_from_to_created',
      'idx_s2c_msg_conversation_status_author',
      'message',
      'message_new',
      'msg_c2c',
      'msg_c2g',
      'msg_c2s',
      'msg_s2c',
      's2c_message',
      's2c_message_new',
    ],
    headerComment:
        r"""-- ============================================================
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

""",
    sql: r"""-- ============================================================
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
""",
  ),
  MigrationEdge(
    id: 'legacy_downgrade_v17_从_v17_降级到_v16',
    fromVersion: 17,
    toVersion: 16,
    description: '从 v17 降级到 v16（移除 conversation.mention_unread 字段）',
    reversible: false,
    dataLoss: true,
    requiresResync: true,
    preconditions: [
      'downgrade 前 v17 schema 处于一致状态（integrity/foreign_key check 通过）',
    ],
    postconditions: ['v16 结构生效：PRAGMA user_version = 16'],
    affectedObjects: [
      'conversation',
      'conversation_v16',
      'i_cv_UserId_IsShow_LastTime',
      'idx_conversation_user_id_last_time',
      'uk_cv_Type_From_To',
    ],
    headerComment:
        r"""-- ============================================================
-- VERSION: 17
-- DESC: 从 v17 降级到 v16（移除 conversation.mention_unread 字段）
-- ============================================================
-- SQLite 3.35 前不支持 DROP COLUMN，采用重建表模式

""",
    sql: r"""CREATE TABLE conversation_v16 (
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

""",
  ),
  MigrationEdge(
    id: 'legacy_downgrade_v18_从_v18_降级到_v17',
    fromVersion: 18,
    toVersion: 17,
    description: '从 v18 降级到 v17（移除 conversation.is_muted，保留 mention_unread）',
    reversible: false,
    dataLoss: true,
    requiresResync: true,
    preconditions: [
      'downgrade 前 v18 schema 处于一致状态（integrity/foreign_key check 通过）',
    ],
    postconditions: ['v17 结构生效：PRAGMA user_version = 17'],
    affectedObjects: [
      'conversation',
      'conversation_v17',
      'i_cv_UserId_IsShow_LastTime',
      'idx_conversation_user_id_last_time',
      'uk_cv_Type_From_To',
    ],
    headerComment:
        r"""-- ============================================================
-- VERSION: 18
-- DESC: 从 v18 降级到 v17（移除 conversation.is_muted，保留 mention_unread）
-- ============================================================

""",
    sql: r"""CREATE TABLE conversation_v17 (
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

""",
  ),
  MigrationEdge(
    id: 'legacy_downgrade_v19_从_v19_降级到_v18',
    fromVersion: 19,
    toVersion: 18,
    description: '从 v19 降级到 v18（移除 group_member.mute_until 列）',
    reversible: false,
    dataLoss: true,
    requiresResync: true,
    preconditions: [
      'downgrade 前 v19 schema 处于一致状态（integrity/foreign_key check 通过）',
    ],
    postconditions: ['v18 结构生效：PRAGMA user_version = 18'],
    affectedObjects: [
      'group_member',
      'group_member_v18',
      'i_Uid_Gid_IsJoin',
      'idx_group_member_mute_until',
      'idx_group_member_user_id_status',
      'uk_Gid_Uid',
    ],
    headerComment: r"""-- VERSION: 19
-- DESC: 从 v19 降级到 v18（移除 group_member.mute_until 列）
-- ============================================================
-- SQLite < 3.35 不支持 DROP COLUMN，用重建表模式删列。
-- 重建表结构 = group_member v18 基线（无 mute_until）。
""",
    sql: r"""CREATE TABLE group_member_v18 (
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

INSERT INTO group_member_v18 (
    id, group_id, user_id, nickname, avatar, sign, account, invite_code,
    alias, description, role, is_join, join_mode, status, updated_at, created_at
)
SELECT
    id, group_id, user_id, nickname, avatar, sign, account, invite_code,
    alias, description, role, is_join, join_mode, status, updated_at, created_at
FROM group_member;

DROP TABLE group_member;
ALTER TABLE group_member_v18 RENAME TO group_member;

DROP INDEX IF EXISTS idx_group_member_mute_until;
CREATE UNIQUE INDEX IF NOT EXISTS uk_Gid_Uid ON group_member (group_id, user_id);
CREATE INDEX IF NOT EXISTS i_Uid_Gid_IsJoin ON group_member (user_id, group_id, is_join);
CREATE INDEX IF NOT EXISTS idx_group_member_user_id_status ON group_member (user_id, status);

PRAGMA user_version = 18;

""",
  ),
  MigrationEdge(
    id: 'legacy_downgrade_v20_从_v20_降级到_v19',
    fromVersion: 20,
    toVersion: 19,
    description: '从 v20 降级到 v19（删除 moment_notify 表）',
    reversible: false,
    dataLoss: true,
    requiresResync: true,
    preconditions: [
      'downgrade 前 v20 schema 处于一致状态（integrity/foreign_key check 通过）',
    ],
    postconditions: ['v19 结构生效：PRAGMA user_version = 19'],
    affectedObjects: ['moment_notify'],
    headerComment:
        r"""-- ============================================================
-- VERSION: 20
-- DESC: 从 v20 降级到 v19（删除 moment_notify 表）
-- ============================================================

""",
    sql: r"""DROP TABLE IF EXISTS moment_notify;
PRAGMA user_version = 19;

""",
  ),
  MigrationEdge(
    id: 'legacy_downgrade_v21_从_v21_降级到_v20',
    fromVersion: 21,
    toVersion: 20,
    description: '从 v21 降级到 v20（恢复 moment_notify 唯一索引旧语义）',
    reversible: false,
    dataLoss: true,
    requiresResync: true,
    preconditions: [
      'downgrade 前 v21 schema 处于一致状态（integrity/foreign_key check 通过）',
    ],
    postconditions: ['v20 结构生效：PRAGMA user_version = 20'],
    affectedObjects: ['uq_moment_notify_dedup'],
    headerComment:
        r"""-- ============================================================
-- VERSION: 21
-- DESC: 从 v21 降级到 v20（恢复 moment_notify 唯一索引旧语义）
-- ============================================================

""",
    sql: r"""DROP INDEX IF EXISTS uq_moment_notify_dedup;
CREATE UNIQUE INDEX IF NOT EXISTS uq_moment_notify_dedup
  ON moment_notify(user_id, action, moment_id, from_uid, comment_id);

PRAGMA user_version = 20;

""",
  ),
  MigrationEdge(
    id: 'legacy_downgrade_v22_从_v22_降级到_v21',
    fromVersion: 22,
    toVersion: 21,
    description: '从 v22 降级到 v21（user_collect.kind_id TEXT → INTEGER 回退）',
    reversible: false,
    dataLoss: true,
    requiresResync: true,
    preconditions: [
      'downgrade 前 v22 schema 处于一致状态（integrity/foreign_key check 通过）',
    ],
    postconditions: ['v21 结构生效：PRAGMA user_version = 21'],
    affectedObjects: [
      'i_Source',
      'idx_user_collect_user_id_kind',
      'user_collect',
      'user_collect_v21',
    ],
    headerComment:
        r"""-- ============================================================
-- VERSION: 22
-- DESC: 从 v22 降级到 v21（user_collect.kind_id TEXT → INTEGER 回退）
-- ============================================================
-- 重建表为 INTEGER 列（v22 之前的结构），数据经 CAST 回退
""",
    sql: r"""CREATE TABLE user_collect_v21 (
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

INSERT INTO user_collect_v21 (
    auto_id, user_id, kind, kind_id, source, remark, tag,
    updated_at, created_at, info
)
SELECT auto_id, user_id, kind, CAST(kind_id AS INTEGER), source, remark, tag,
    updated_at, created_at, info
FROM user_collect;

DROP TABLE user_collect;
ALTER TABLE user_collect_v21 RENAME TO user_collect;

CREATE INDEX IF NOT EXISTS i_Source ON user_collect (source);
CREATE INDEX IF NOT EXISTS idx_user_collect_user_id_kind ON user_collect (user_id, kind);

PRAGMA user_version = 21;

""",
  ),
  MigrationEdge(
    id: 'legacy_downgrade_v23_从_v23_降级到_v22',
    fromVersion: 23,
    toVersion: 22,
    description: '从 v23 降级到 v22（移除 channel_message.my_reactions 列）',
    reversible: false,
    dataLoss: true,
    requiresResync: true,
    preconditions: [
      'downgrade 前 v23 schema 处于一致状态（integrity/foreign_key check 通过）',
    ],
    postconditions: ['v22 结构生效：PRAGMA user_version = 22'],
    affectedObjects: [
      'channel_message',
      'channel_message_v22',
      'idx_channel_msg_channel_id',
    ],
    headerComment:
        r"""-- ============================================================
-- VERSION: 23
-- DESC: 从 v23 降级到 v22（移除 channel_message.my_reactions 列）
-- ============================================================

""",
    sql: r"""CREATE TABLE channel_message_v22 (
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

INSERT INTO channel_message_v22 (
    id, channel_id, author_id, author_name, author_avatar, content,
    msg_type, payload, created_at, is_pinned, view_count, reaction_summary
)
SELECT
    id, channel_id, author_id, author_name, author_avatar, content,
    msg_type, payload, created_at, is_pinned, view_count, reaction_summary
FROM channel_message;

DROP TABLE channel_message;
ALTER TABLE channel_message_v22 RENAME TO channel_message;

CREATE INDEX IF NOT EXISTS idx_channel_msg_channel_id ON channel_message(channel_id);

PRAGMA user_version = 22;

""",
  ),
  MigrationEdge(
    id: 'legacy_downgrade_v24_从_v24_降级到_v23',
    fromVersion: 24,
    toVersion: 23,
    description: '从 v24 降级到 v23（移除 contact.account_type 列）',
    reversible: false,
    dataLoss: true,
    requiresResync: true,
    preconditions: [
      'downgrade 前 v24 schema 处于一致状态（integrity/foreign_key check 通过）',
    ],
    postconditions: ['v23 结构生效：PRAGMA user_version = 23'],
    affectedObjects: [
      'contact',
      'contact_v23',
      'i_Nickname',
      'i_Remark',
      'i_Tag',
      'i_UserId_CategoryId',
      'i_UserId_IsFriend_UpdateTime',
      'idx_contact_user_id_peer_id',
    ],
    headerComment:
        r"""-- ============================================================
-- VERSION: 24
-- DESC: 从 v24 降级到 v23（移除 contact.account_type 列）
-- ============================================================

""",
    sql: r"""CREATE TABLE contact_v23 (
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
    last_seen_at INTEGER,
    CONSTRAINT uk_FromTo UNIQUE (user_id, peer_id)
);

INSERT INTO contact_v23 (
    auto_id, user_id, peer_id, nickname, avatar, gender, account, status,
    remark, tag, region, sign, source, updated_at, is_friend, is_from,
    category_id, last_seen_at
)
SELECT
    auto_id, user_id, peer_id, nickname, avatar, gender, account, status,
    remark, tag, region, sign, source, updated_at, is_friend, is_from,
    category_id, last_seen_at
FROM contact;

DROP TABLE contact;
ALTER TABLE contact_v23 RENAME TO contact;

CREATE INDEX IF NOT EXISTS i_UserId_IsFriend_UpdateTime ON contact (user_id, is_friend, updated_at);
CREATE INDEX IF NOT EXISTS i_UserId_CategoryId ON contact (user_id, category_id);
CREATE INDEX IF NOT EXISTS i_Nickname ON contact (nickname);
CREATE INDEX IF NOT EXISTS i_Remark ON contact (remark);
CREATE INDEX IF NOT EXISTS i_Tag ON contact (tag);
CREATE INDEX IF NOT EXISTS idx_contact_user_id_peer_id ON contact (user_id, peer_id);

PRAGMA user_version = 23;

""",
  ),
  MigrationEdge(
    id: 'legacy_downgrade_v25_从_v25_降级到_v24',
    fromVersion: 25,
    toVersion: 24,
    description: '从 v25 降级到 v24（移除 msg_c2c.sender_did 列）',
    reversible: false,
    dataLoss: true,
    requiresResync: true,
    preconditions: [
      'downgrade 前 v25 schema 处于一致状态（integrity/foreign_key check 通过）',
    ],
    postconditions: ['v24 结构生效：PRAGMA user_version = 24'],
    affectedObjects: [
      'idx_msg_c2c_conversation_created_at',
      'idx_msg_c2c_conversation_status_author',
      'idx_msg_c2c_conversation_topic_id',
      'idx_msg_c2c_conversation_uk3',
      'idx_msg_c2c_from_to_created',
      'idx_msg_c2c_msg_type',
      'idx_msg_c2c_status',
      'idx_msg_c2c_unread_count',
      'msg_c2c',
      'msg_c2c_v24',
    ],
    headerComment:
        r"""-- ============================================================
-- VERSION: 25
-- DESC: 从 v25 降级到 v24（移除 msg_c2c.sender_did 列）
-- ============================================================

""",
    sql: r"""CREATE TABLE msg_c2c_v24 (
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

INSERT INTO msg_c2c_v24 (
    auto_id, id, msg_type, from_id, to_id, conversation_uk3, e2ee, payload,
    created_at, topic_id, status, is_author, type, action
)
SELECT
    auto_id, id, msg_type, from_id, to_id, conversation_uk3, e2ee, payload,
    created_at, topic_id, status, is_author, type, action
FROM msg_c2c;

DROP TABLE msg_c2c;
ALTER TABLE msg_c2c_v24 RENAME TO msg_c2c;

CREATE INDEX IF NOT EXISTS idx_msg_c2c_conversation_status_author ON msg_c2c (conversation_uk3, status, is_author);
CREATE INDEX IF NOT EXISTS idx_msg_c2c_conversation_created_at ON msg_c2c (conversation_uk3, created_at);
CREATE INDEX IF NOT EXISTS idx_msg_c2c_conversation_topic_id ON msg_c2c (conversation_uk3, topic_id);
CREATE INDEX IF NOT EXISTS idx_msg_c2c_conversation_uk3 ON msg_c2c (conversation_uk3);
CREATE INDEX IF NOT EXISTS idx_msg_c2c_from_to_created ON msg_c2c (from_id, to_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_msg_c2c_msg_type ON msg_c2c (msg_type);
CREATE INDEX IF NOT EXISTS idx_msg_c2c_unread_count ON msg_c2c (conversation_uk3, is_author, auto_id);
CREATE INDEX IF NOT EXISTS idx_msg_c2c_status ON msg_c2c (status);

PRAGMA user_version = 24;
""",
  ),
];

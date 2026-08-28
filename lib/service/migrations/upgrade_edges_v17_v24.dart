// 升级边 v16→v24（块 17..24）
//
// WP3 bootstrap 从 assets/migrations/*.sql 机械提取（2026-08-27）；
// headerComment + sql 拼接 == 原块原文（生成器 --check 守护字节级一致）。
// 此后本文件是唯一真源；元数据修改必须过 migration_manifest_test.dart。
library;

import 'package:imboy/service/migration_manifest.dart';

const List<MigrationEdge> kUpgradeEdgesV17V24 = [
  MigrationEdge(
    id: 'legacy_upgrade_v17_C7_β_独立_未读计数_为_conversation_表添加_mention_',
    fromVersion: 16,
    toVersion: 17,
    description: 'C7-β 独立 @ 未读计数 - 为 conversation 表添加 mention_unread 字段',
    reversible: true,
    dataLoss: false,
    requiresResync: false,
    preconditions: [
      'upgrade 前 v16 schema 处于一致状态（integrity/foreign_key check 通过）',
    ],
    postconditions: ['v17 结构生效：PRAGMA user_version = 17'],
    affectedObjects: ['conversation'],
    headerComment: r"""-- VERSION: 17
-- DESC: C7-β 独立 @ 未读计数 - 为 conversation 表添加 mention_unread 字段
-- ============================================================

""",
    sql: r"""-- ============================================================
-- Step 1: 为 conversation 表新增 mention_unread 列（默认 0）
-- ============================================================
ALTER TABLE conversation ADD COLUMN mention_unread INTEGER NOT NULL DEFAULT 0;

-- ============================================================
-- 更新版本号
-- ============================================================
PRAGMA user_version = 17;

""",
  ),
  MigrationEdge(
    id: 'legacy_upgrade_v18_C7_α_1_本地群免打扰',
    fromVersion: 17,
    toVersion: 18,
    description: 'C7-α-1 本地群免打扰 (DND) - 为 conversation 表添加 is_muted 字段',
    reversible: true,
    dataLoss: false,
    requiresResync: false,
    preconditions: [
      'upgrade 前 v17 schema 处于一致状态（integrity/foreign_key check 通过）',
    ],
    postconditions: ['v18 结构生效：PRAGMA user_version = 18'],
    affectedObjects: ['conversation'],
    headerComment: r"""-- VERSION: 18
-- DESC: C7-α-1 本地群免打扰 (DND) - 为 conversation 表添加 is_muted 字段
-- ============================================================

""",
    sql: r"""-- ============================================================
-- Step 1: 为 conversation 表新增 is_muted 列（默认 0 = 不免打扰）
-- ============================================================
ALTER TABLE conversation ADD COLUMN is_muted INTEGER NOT NULL DEFAULT 0;

-- ============================================================
-- 更新版本号
-- ============================================================
PRAGMA user_version = 18;

""",
  ),
  MigrationEdge(
    id: 'legacy_upgrade_v19_群成员禁言_为_group_member_表添加_mute_until_字段',
    fromVersion: 18,
    toVersion: 19,
    description: '群成员禁言 - 为 group_member 表添加 mute_until 字段',
    reversible: true,
    dataLoss: false,
    requiresResync: false,
    preconditions: [
      'upgrade 前 v18 schema 处于一致状态（integrity/foreign_key check 通过）',
    ],
    postconditions: ['v19 结构生效：PRAGMA user_version = 19'],
    affectedObjects: ['group_member', 'idx_group_member_mute_until'],
    headerComment: r"""-- VERSION: 19
-- DESC: 群成员禁言 - 为 group_member 表添加 mute_until 字段
--       对齐后端 priv/migrations/00000051_group_member_mute.sql。
--       语义：解除禁言的 epoch 毫秒；NULL 表示未被禁言（**不得**退化为 now，
--       否则旧数据会被误判为禁言中）。
-- ============================================================

""",
    sql: r"""-- ============================================================
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

""",
  ),
  MigrationEdge(
    id: 'legacy_upgrade_v20_朋友圈通知中心',
    fromVersion: 19,
    toVersion: 20,
    description: '朋友圈通知中心 (Slice A-1) - 新增 moment_notify 表',
    reversible: true,
    dataLoss: false,
    requiresResync: false,
    preconditions: [
      'upgrade 前 v19 schema 处于一致状态（integrity/foreign_key check 通过）',
    ],
    postconditions: ['v20 结构生效：PRAGMA user_version = 20'],
    affectedObjects: [
      'idx_moment_notify_user_read',
      'moment_notify',
      'uq_moment_notify_dedup',
    ],
    headerComment: r"""-- VERSION: 20
-- DESC: 朋友圈通知中心 (Slice A-1) - 新增 moment_notify 表
--       后端 moment_logic_notify:notify_post_liked/3 模式为 no_save，
--       点赞通知不入服务端历史表；客户端必须本地落库才能做通知中心红点
--       与历史列表。评论通知后端 save 但我们仍本地持久化以统一 UX。
-- ============================================================

""",
    sql: r"""-- ============================================================
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

""",
  ),
  MigrationEdge(
    id: 'legacy_upgrade_v21_修复_moment_notify_唯一索引_NULL_语义问题',
    fromVersion: 20,
    toVersion: 21,
    description: '修复 moment_notify 唯一索引 NULL 语义问题',
    reversible: true,
    dataLoss: false,
    requiresResync: false,
    preconditions: [
      'upgrade 前 v20 schema 处于一致状态（integrity/foreign_key check 通过）',
    ],
    postconditions: ['v21 结构生效：PRAGMA user_version = 21'],
    affectedObjects: ['uq_moment_notify_dedup'],
    headerComment: r"""-- VERSION: 21
-- DESC: 修复 moment_notify 唯一索引 NULL 语义问题
--       SQLite 的 "NULL != NULL" 语义使 `comment_id IS NULL` 的 moment_like 行
--       无法被原有唯一索引拦截；`ConflictAlgorithm.ignore` 对含 NULL 列组无效，
--       导致重复 S2C 推送会被允许插入（客户端通知中心出现重复项）。
--       解决方案：DROP 旧索引，重建时用 `COALESCE(comment_id, '')` 将 NULL
--       折叠为空串参与唯一约束。moment_like（comment_id=NULL）折叠后
--       以 '' 参与比较，moment_comment（comment_id 非 NULL）按原值比较，
--       两者仍互不冲突（action 已区分）。
-- ============================================================

""",
    sql: r"""DROP INDEX IF EXISTS uq_moment_notify_dedup;

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

""",
  ),
  MigrationEdge(
    id: 'legacy_upgrade_v22_user_collect_kind_id_INTEGER_TEXT',
    fromVersion: 21,
    toVersion: 22,
    description: 'user_collect.kind_id INTEGER → TEXT（QA#31）',
    reversible: true,
    dataLoss: true,
    requiresResync: false,
    preconditions: [
      'upgrade 前 v21 schema 处于一致状态（integrity/foreign_key check 通过）',
    ],
    postconditions: ['v22 结构生效：PRAGMA user_version = 22'],
    affectedObjects: [
      'i_Source',
      'idx_user_collect_user_id_kind',
      'user_collect',
      'user_collect_new',
    ],
    headerComment:
        r"""-- ============================================================
-- VERSION: 22
-- DESC: user_collect.kind_id INTEGER → TEXT（QA#31）
--       消息 id 是 String Xid（base32hex），INTEGER 列使
--       parseModelInt 把 Xid 静默归零为 0：首条 kind_id=0 记录
--       占位后，所有后续收藏均触发 UNIQUE(user_id,kind_id) 冲突
--       且异常未捕获（收藏功能实质坏死、用户零感知）。
--       重建表为 TEXT 列，并清除历史 kind_id=0/'0' 脏行
--       （本地缓存，可从服务端重拉）。
-- ============================================================

""",
    sql: r"""CREATE TABLE user_collect_new (
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

""",
  ),
  MigrationEdge(
    id: 'legacy_upgrade_v23_channel_message_新增_my_reactions_列',
    fromVersion: 22,
    toVersion: 23,
    description: 'channel_message 新增 my_reactions 列（当前用户已添加的',
    reversible: true,
    dataLoss: false,
    requiresResync: false,
    preconditions: [
      'upgrade 前 v22 schema 处于一致状态（integrity/foreign_key check 通过）',
    ],
    postconditions: ['v23 结构生效：PRAGMA user_version = 23'],
    affectedObjects: ['channel_message'],
    headerComment:
        r"""-- ============================================================
-- VERSION: 23
-- DESC: channel_message 新增 my_reactions 列（当前用户已添加的
--       反应类型 JSON 数组，如 ["like"]）。后端消息列表已随行
--       返回 my_reactions，本地缓存需持久化，否则从缓存渲染时
--       「我已赞」状态丢失（刷新/重进后点赞误走 add 而非 remove）。
-- ============================================================

""",
    sql: r"""ALTER TABLE channel_message ADD COLUMN my_reactions TEXT;

-- ============================================================
-- 更新版本号
-- ============================================================
PRAGMA user_version = 23;

""",
  ),
  MigrationEdge(
    id: 'legacy_upgrade_v24_contact_新增_account_type_列',
    fromVersion: 23,
    toVersion: 24,
    description: 'contact 新增 account_type 列（0=真人 1=AI 助手 2=官方',
    reversible: true,
    dataLoss: false,
    requiresResync: false,
    preconditions: [
      'upgrade 前 v23 schema 处于一致状态（integrity/foreign_key check 通过）',
    ],
    postconditions: ['v24 结构生效：PRAGMA user_version = 24'],
    affectedObjects: ['contact'],
    headerComment:
        r"""-- ============================================================
-- VERSION: 24
-- DESC: contact 新增 account_type 列（0=真人 1=AI 助手 2=官方
--       机器人）。透明 AI 徽章数据源：好友同步/资料 payload 随行
--       返回 account_type，本地持久化供会话列表/聊天标题/资料页
--       BotBadge 渲染。服务端只读投影，客户端无写入路径。
-- ============================================================

""",
    sql:
        r"""ALTER TABLE contact ADD COLUMN account_type INTEGER NOT NULL DEFAULT 0;

-- ============================================================
-- 更新版本号
-- ============================================================
PRAGMA user_version = 24;

""",
  ),
];

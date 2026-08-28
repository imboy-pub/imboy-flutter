import 'package:imboy/service/migrations/manifest_all.dart';

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
    last_seen_at INTEGER,
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
    -- v25: PFv3 context binding #6（ADR 15 §3.3）。与 upgrade.sql VERSION 25
    -- 必须同步；漏一处即「全新安装」与「存量升级」schema 分叉。
    sender_did TEXT,
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
    updated_at INTEGER NOT NULL,
    user_role INTEGER DEFAULT 0,
    is_subscribed INTEGER DEFAULT 0,
    has_purchased INTEGER DEFAULT 0
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

// ---------------------------------------------------------------------------
// 迁移脚本 —— WP3（2026-08-27）起为 manifest 生成物
//
// kUpgradeScriptSql / kDowngradeScriptSql 原为手工维护的大常量（历史版本
// 在此逐块复制 SQL）。单一真源现迁移至
// lib/service/migrations/manifest_all.dart 的类型化 MigrationManifest；
// 本文件按原布局（文件头 preamble + 各边 headerComment + sql）重组字符串，
// 与 assets/migrations/*.sql 保持字节级一致（由 migration_manifest_test.dart
// 与 tool/generate_sqlite_migrations.dart --check 双重守护）。
// kBaselineSchemaSql 仍为手工维护（历史上只定型过一次）。
// ---------------------------------------------------------------------------

/// upgrade.sql 文件头 + `VERSION: 9` 空占位块原文（生成布局的一部分）。
const String _kUpgradeFilePreamble =
    r"""-- ============================================================
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

""";

/// downgrade.sql 文件头 + `VERSION: 9` 空占位块原文。
const String _kDowngradeFilePreamble =
    r"""-- ============================================================
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

""";

/// 从迁移清单重组 upgrade.sql 全文（与生成器输出一致，字节级可复现）。
String buildUpgradeSqlFromManifest() {
  final sb = StringBuffer(_kUpgradeFilePreamble);
  for (final e in kMigrationManifest.upgradesByTo.values) {
    sb.write(e.headerComment);
    sb.write(e.sql);
  }
  return sb.toString();
}

/// 从迁移清单重组 downgrade.sql 全文（与生成器输出一致，字节级可复现）。
/// 边顺序 = manifest 声明顺序（保持历史文件块序：31,29,28,10,17..25）。
String buildDowngradeSqlFromManifest() {
  final sb = StringBuffer(_kDowngradeFilePreamble);
  for (final e in kMigrationManifest.downgradesByFrom.values) {
    sb.write(e.headerComment);
    sb.write(e.sql);
  }
  return sb.toString();
}

/// 升级脚本全文（manifest 生成物；下方历史手工常量已退役删除）。
String get kUpgradeScriptSql => buildUpgradeSqlFromManifest();

/// 降级脚本全文（manifest 生成物）。
String get kDowngradeScriptSql => buildDowngradeSqlFromManifest();

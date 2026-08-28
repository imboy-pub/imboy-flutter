// 升级边 v24→v31（块 25..31）
//
// WP3 bootstrap 从 assets/migrations/*.sql 机械提取（2026-08-27）；
// headerComment + sql 拼接 == 原块原文（生成器 --check 守护字节级一致）。
// 此后本文件是唯一真源；元数据修改必须过 migration_manifest_test.dart。
library;

import 'package:imboy/service/migration_manifest.dart';

const List<MigrationEdge> kUpgradeEdgesV25V31 = [
  MigrationEdge(
    id: 'legacy_upgrade_v25_msg_c2c_新增_sender_did_列',
    fromVersion: 24,
    toVersion: 25,
    description: 'msg_c2c 新增 sender_did 列（发送方设备 ID）。',
    reversible: true,
    dataLoss: false,
    requiresResync: false,
    preconditions: [
      'upgrade 前 v24 schema 处于一致状态（integrity/foreign_key check 通过）',
    ],
    postconditions: ['v25 结构生效：PRAGMA user_version = 25'],
    affectedObjects: ['msg_c2c'],
    headerComment:
        r"""-- ============================================================
-- VERSION: 25
-- DESC: msg_c2c 新增 sender_did 列（发送方设备 ID）。
--       服务端在 WebSocket 认证态注入信封顶层，客户端不可伪造。
--       PFv3 接收侧 context binding 第 6 项（ADR 15 §3.3）拿它与受认证的
--       protected_header.sender_did 硬比对。实时路径在内存帧里就有，
--       离线（decrypt-on-read）路径必须持久化，否则重连拉取的 v3 消息
--       永久判 context_mismatch_sender_did 不可读。
--       可空：迁移前落库的旧行保持 NULL，如实失配（fail-closed），
--       不得回填空串——空串会把「没提供」与「设备 ID 是空串」混为一谈。
--       仅 msg_c2c：C2G 当前走 Megolm v2（非 PFv3），不需要该列。
-- ============================================================

""",
    sql: r"""ALTER TABLE msg_c2c ADD COLUMN sender_did TEXT;

-- ============================================================
-- 更新版本号
-- ============================================================
PRAGMA user_version = 25;

""",
  ),
  MigrationEdge(
    id: 'legacy_upgrade_v26_contact_新增_last_seen_at_列',
    fromVersion: 25,
    toVersion: 26,
    description: 'contact 新增 last_seen_at 列（最后在线时间戳，毫秒）。',
    reversible: false,
    dataLoss: false,
    requiresResync: false,
    preconditions: [
      'upgrade 前 v25 schema 处于一致状态（integrity/foreign_key check 通过）',
    ],
    postconditions: ['v26 结构生效：PRAGMA user_version = 26'],
    affectedObjects: ['contact'],
    headerComment:
        r"""-- ============================================================
-- VERSION: 26
-- DESC: contact 新增 last_seen_at 列（最后在线时间戳，毫秒）。
--       后端 /api/v1/friend/list、/api/v1/user/show、/api/v1/friend/confirm
--       均返回 last_seen_at，但旧表无该列 → 落库被丢弃 → 详情页
--       lastSeenAt 永远为 0 → UserOnlineTimeHelper 显示"从未上线"
--       （即使对方在线）。本列持久化后，详情页可正确显示最后上线时间。
--       可空：迁移前落库的旧行保持 NULL（语义=未知/从未记录），
--       与 UserOnlineTimeHelper 的 lastSeenTimestamp==null 分支一致。
-- ============================================================

""",
    sql: r"""ALTER TABLE contact ADD COLUMN last_seen_at INTEGER;

-- ============================================================
-- 更新版本号
-- ============================================================
PRAGMA user_version = 26;

""",
  ),
  MigrationEdge(
    id: 'legacy_upgrade_v27_channel_表补_user_role_is_subscribed_两列',
    fromVersion: 26,
    toVersion: 27,
    description: 'channel 表补 user_role / is_subscribed 两列。',
    reversible: false,
    dataLoss: false,
    requiresResync: false,
    preconditions: [
      'upgrade 前 v26 schema 处于一致状态（integrity/foreign_key check 通过）',
    ],
    postconditions: ['v27 结构生效：PRAGMA user_version = 27'],
    affectedObjects: ['channel'],
    headerComment:
        r"""-- ============================================================
-- VERSION: 27
-- DESC: channel 表补 user_role / is_subscribed 两列。
--       ChannelModel.toMap() 一直输出这两个字段，但建表语句（baseline 与
--       Step 16 的 channel_new 重建）都没有它们 → 任何 ChannelRepo 写入都抛
--       "table channel has no column named user_role" → 订阅频道、频道信息
--       本地缓存、订阅通知落库全部静默失败（后端已成功，客户端 UI 不更新）。
--       实测：点「订阅」后端返回 user_role=3/is_subscribed=1，本地 INSERT 崩，
--       按钮仍显示「订阅」、订阅数仍为 0。
--       user_role: 0=无角色 1=订阅者 2=管理员 3=创建者（ChannelUserRole）
--       is_subscribed: 0/1
-- ============================================================

""",
    sql: r"""ALTER TABLE channel ADD COLUMN user_role INTEGER DEFAULT 0;
ALTER TABLE channel ADD COLUMN is_subscribed INTEGER DEFAULT 0;

-- ============================================================
-- 更新版本号
-- ============================================================
PRAGMA user_version = 27;

""",
  ),
  MigrationEdge(
    id: 'legacy_upgrade_v28_频道消息本地可靠待同步_outbox',
    fromVersion: 27,
    toVersion: 28,
    description: '频道消息本地可靠待同步 outbox。',
    reversible: true,
    dataLoss: false,
    requiresResync: false,
    preconditions: [
      'upgrade 前 v27 schema 处于一致状态（integrity/foreign_key check 通过）',
    ],
    postconditions: ['v28 结构生效：PRAGMA user_version = 28'],
    affectedObjects: [
      'channel_message_outbox',
      'idx_channel_message_outbox_due',
    ],
    headerComment:
        r"""-- ============================================================
-- VERSION: 28
-- DESC: 频道消息本地可靠待同步 outbox。
--       API 成功后若本地频道/消息写入失败，保存完整消息快照，待下次同步重放；
--       避免仅依赖内存和后续偶然拉取。
-- ============================================================

""",
    sql: r"""CREATE TABLE IF NOT EXISTS channel_message_outbox (
    message_id INTEGER PRIMARY KEY,
    channel_id INTEGER NOT NULL,
    payload TEXT NOT NULL,
    attempts INTEGER NOT NULL DEFAULT 0,
    next_attempt_at INTEGER NOT NULL,
    last_error TEXT,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_channel_message_outbox_due
    ON channel_message_outbox(next_attempt_at, channel_id);

PRAGMA user_version = 28;

""",
  ),
  MigrationEdge(
    id: 'legacy_upgrade_v29_频道消息发布可靠重试_outbox',
    fromVersion: 28,
    toVersion: 29,
    description: '频道消息发布可靠重试 outbox。',
    reversible: true,
    dataLoss: false,
    requiresResync: false,
    preconditions: [
      'upgrade 前 v28 schema 处于一致状态（integrity/foreign_key check 通过）',
    ],
    postconditions: ['v29 结构生效：PRAGMA user_version = 29'],
    affectedObjects: [
      'channel_publish_outbox',
      'idx_channel_publish_outbox_due',
    ],
    headerComment:
        r"""-- ============================================================
-- VERSION: 29
-- DESC: 频道消息发布可靠重试 outbox。
--       网络超时或请求失败时保存原始发布参数与 request_id，待进入频道或同步时重放；
--       服务端按 request_id 幂等，避免“服务端已成功但客户端未收到响应”造成重复消息。
-- ============================================================

""",
    sql: r"""CREATE TABLE IF NOT EXISTS channel_publish_outbox (
    request_id TEXT PRIMARY KEY,
    channel_id TEXT NOT NULL,
    content TEXT NOT NULL,
    msg_type TEXT NOT NULL,
    payload TEXT,
    attempts INTEGER NOT NULL DEFAULT 0,
    next_attempt_at INTEGER NOT NULL,
    last_error TEXT,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_channel_publish_outbox_due
    ON channel_publish_outbox(next_attempt_at, channel_id);

PRAGMA user_version = 29;

""",
  ),
  MigrationEdge(
    id: 'legacy_upgrade_v30_channel_新增_has_purchased_列',
    fromVersion: 29,
    toVersion: 30,
    description: 'channel 新增 has_purchased 列（付费频道购买权益）。',
    reversible: false,
    dataLoss: false,
    requiresResync: false,
    preconditions: [
      'upgrade 前 v29 schema 处于一致状态（integrity/foreign_key check 通过）',
    ],
    postconditions: ['v30 结构生效：PRAGMA user_version = 30'],
    affectedObjects: ['channel'],
    headerComment:
        r"""-- ============================================================
-- VERSION: 30
-- DESC: channel 新增 has_purchased 列（付费频道购买权益）。
--       ChannelModel.toMap() 会持久化购买态；缺少本列会导致已购买频道
--       保存失败，并在重启/本地缓存恢复后重新显示 paywall。
--       旧设备默认 0，随后由频道详情接口回填真实购买状态。
-- ============================================================

""",
    sql: r"""ALTER TABLE channel ADD COLUMN has_purchased INTEGER DEFAULT 0;

PRAGMA user_version = 30;

""",
  ),
  MigrationEdge(
    id: 'legacy_upgrade_v31_频道访问模型正交化_channel_新增_visibility_access_t',
    fromVersion: 30,
    toVersion: 31,
    description: '频道访问模型正交化 — channel 新增 visibility/access_type/join_policy',
    reversible: true,
    dataLoss: false,
    requiresResync: false,
    preconditions: [
      'upgrade 前 v30 schema 处于一致状态（integrity/foreign_key check 通过）',
    ],
    postconditions: ['v31 结构生效：PRAGMA user_version = 31'],
    affectedObjects: ['channel', 'idx_channel_type'],
    headerComment:
        r"""-- ============================================================
-- VERSION: 31
-- DESC: 频道访问模型正交化 — channel 新增 visibility/access_type/join_policy
--       三列，并从旧 type 列回填（与后端 00000072 迁移的映射及幂等守卫一致）：
--         type=0 公开免费 → (0,0,0)；type=1 私有 → (1,0,1)；type=2 付费 → (0,1,3)；
--         非法 type 置 (-1,-1,-1) 哨兵，ChannelModel 对其 fail-closed 锁定。
--       旧 type 列保留为兼容列（不再读写），勿删。
-- ============================================================

""",
    sql: r"""ALTER TABLE channel ADD COLUMN visibility INTEGER DEFAULT 0;
ALTER TABLE channel ADD COLUMN access_type INTEGER DEFAULT 0;
ALTER TABLE channel ADD COLUMN join_policy INTEGER DEFAULT 0;

-- 幂等守卫（AND 三字段 = 0）：重复执行不覆盖已漂移/已修正的数据
UPDATE channel SET visibility = 0, access_type = 0, join_policy = 0
 WHERE type = 0 AND visibility = 0 AND access_type = 0 AND join_policy = 0;
UPDATE channel SET visibility = 1, access_type = 0, join_policy = 1
 WHERE type = 1 AND visibility = 0 AND access_type = 0 AND join_policy = 0;
UPDATE channel SET visibility = 0, access_type = 1, join_policy = 3
 WHERE type = 2 AND visibility = 0 AND access_type = 0 AND join_policy = 0;
UPDATE channel SET visibility = -1, access_type = -1, join_policy = -1
 WHERE type NOT IN (0, 1, 2)
   AND visibility = 0 AND access_type = 0 AND join_policy = 0;

DROP INDEX IF EXISTS idx_channel_type;

PRAGMA user_version = 31;
""",
  ),
];

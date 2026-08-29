// 升级边 v31→v32（块 32）
//
// P0 终局（2026-08-29）：group.user_id_sum 列退役。
// 服务端已随迁移 00000079 删除该列并停发载荷（imboy 仓 e253867a）；
// 客户端 userIdSum 为纯存储零业务读取（排重注释声称的逻辑不存在），
// 本边把本地 SQLite 的死列一并清掉。此后本文件是唯一真源；
// 元数据修改必须过 migration_manifest_test.dart。
library;

import 'package:imboy/service/migration_manifest.dart';

const List<MigrationEdge> kUpgradeEdgesV32 = [
  MigrationEdge(
    id: 'upgrade_v32_group_移除_user_id_sum_列',
    fromVersion: 31,
    toVersion: 32,
    description: 'group 移除 user_id_sum 列（服务端字段已退役，本地死列清理）。',
    reversible: true,
    dataLoss: true,
    requiresResync: false,
    preconditions: [
      'upgrade 前 v31 schema 处于一致状态（integrity/foreign_key check 通过）',
    ],
    postconditions: ['v32 结构生效：PRAGMA user_version = 32'],
    affectedObjects: ['group', 'group_v32'],
    headerComment:
        r"""-- ============================================================
-- VERSION: 32
-- DESC: group 移除 user_id_sum 列。
--       服务端迁移 00000079 已删除该列（SUM(bigint) 约 85 人溢出，
--       且同成员集允许多群后签名语义不复存在），载荷不再下发；
--       客户端 userIdSum 纯存储零业务读取，属死列。
--       SQLite < 3.35 不支持 DROP COLUMN，按仓内惯例走
--       建新表 → 拷数据 → 删旧表 → 改名 的重建方式。
--       降级可逆：down 边以 ADD COLUMN 恢复（历史 sum 值不还原，置 0）。
-- ============================================================

""",
    sql: r"""CREATE TABLE IF NOT EXISTS "group_v32" (
    id INTEGER PRIMARY KEY,
    type INTEGER DEFAULT 1,
    join_limit INTEGER DEFAULT 2,
    content_limit INTEGER DEFAULT 2,
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
INSERT INTO "group_v32" (
    id, type, join_limit, content_limit, owner_uid, creator_uid,
    member_max, member_count, introduction, avatar, title, status,
    updated_at, created_at, pinned_msg
)
SELECT
    id, type, join_limit, content_limit, owner_uid, creator_uid,
    member_max, member_count, introduction, avatar, title, status,
    updated_at, created_at, pinned_msg
FROM "group";
DROP TABLE "group";
ALTER TABLE "group_v32" RENAME TO "group";

-- ============================================================
-- 更新版本号
-- ============================================================
PRAGMA user_version = 32;

""",
  ),
];

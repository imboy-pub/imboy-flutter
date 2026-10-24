// 升级边 v33→v34（块 34）
//
// E2EE 收藏 v1（PLAN docs/design/2026-10-24-e2ee-collect，服务端迁移 227）：
// user_collect 本地表新增 generation（记录修订号：一切持久化变更 +1，
// CAS 与跨设备同步检测唯一信号——重包裹亦推进，key_version 变化不漏检）
// 与 key_version（0=legacy 明文行；>0=sealed 行，info 为客户端密文 base64）。
// 与服务端行级元数据对齐；本地解密缓存与冲突重读依赖此二列。
library;

import 'package:imboy/service/migration_manifest.dart';

const List<MigrationEdge> kUpgradeEdgesV34 = [
  MigrationEdge(
    id: 'upgrade_v34_user_collect 增加 generation 与 key_version 列',
    fromVersion: 33,
    toVersion: 34,
    description:
        'E2EE 收藏 v1：user_collect 增加 generation/key_version 列（服务端迁移 227 对齐）。',
    reversible: true,
    dataLoss: false,
    requiresResync: false,
    preconditions: [
      'upgrade 前 v33 schema 处于一致状态（integrity/foreign_key check 通过）',
    ],
    postconditions: [
      'user_collect 含 generation INTEGER NOT NULL DEFAULT 0 与 key_version INTEGER NOT NULL DEFAULT 0：PRAGMA user_version = 34',
    ],
    affectedObjects: ['user_collect'],
    headerComment:
        r"""-- ============================================================
-- VERSION: 34
-- DESC: E2EE 收藏 v1（PLAN 2026-10-24-e2ee-collect / 服务端迁移 227）：
--       user_collect 增加 generation（记录修订号）与 key_version
--       （0=legacy，>0=sealed）两列。存量行默认 0/0（legacy 语义不变）。
--       降级可逆：down 边 DROP COLUMN（旧版本客户端不识别 sealed 行）。
-- ============================================================

""",
    sql: r"""ALTER TABLE user_collect ADD COLUMN generation INTEGER NOT NULL DEFAULT 0;
ALTER TABLE user_collect ADD COLUMN key_version INTEGER NOT NULL DEFAULT 0;
PRAGMA user_version = 34;""",
  ),
];

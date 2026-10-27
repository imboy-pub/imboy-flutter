import 'package:imboy/service/migration_manifest.dart';

const List<MigrationEdge> kDowngradeEdgesV34V35 = [
  MigrationEdge(
    id: 'downgrade_v35_删除_msg四表_conv_seq_与_accepted_at',
    fromVersion: 35,
    toVersion: 34,
    description: '从 v35 降级到 v34（删除消息四表 conv_seq/accepted_at 与排序索引；可空列，旧版客户端回到 auto_id 顺序语义）。',
    reversible: false,
    dataLoss: false,
    requiresResync: true,
    preconditions: ['downgrade 前 v35 schema 处于一致状态'],
    postconditions: [
      '消息四表不含 conv_seq/accepted_at 列与 *_conversation_conv_seq 索引：PRAGMA user_version = 34',
    ],
    affectedObjects: [
      'msg_c2c',
      'msg_c2g',
      'msg_c2s',
      'msg_s2c',
      'idx_msg_c2c_conversation_conv_seq',
      'idx_msg_c2g_conversation_conv_seq',
      'idx_msg_c2s_conversation_conv_seq',
      'idx_msg_s2c_conversation_conv_seq',
    ],
    headerComment:
        r"""-- ============================================================
-- VERSION: 35
-- DESC: 从 v35 降级到 v34（删除消息四表 conv_seq/accepted_at 列与
--       (conversation_uk3, conv_seq) 排序索引）。列值丢失后需服务端
--       重同步方可恢复权威序（requiresResync）；旧版客户端回到
--       created_at/auto_id 顺序语义（同毫秒乱序窗口重现，属可接受回退）。
-- ============================================================

""",
    sql: r"""DROP INDEX IF EXISTS idx_msg_s2c_conversation_conv_seq;
DROP INDEX IF EXISTS idx_msg_c2s_conversation_conv_seq;
DROP INDEX IF EXISTS idx_msg_c2g_conversation_conv_seq;
DROP INDEX IF EXISTS idx_msg_c2c_conversation_conv_seq;
ALTER TABLE msg_s2c DROP COLUMN accepted_at;
ALTER TABLE msg_s2c DROP COLUMN conv_seq;
ALTER TABLE msg_c2s DROP COLUMN accepted_at;
ALTER TABLE msg_c2s DROP COLUMN conv_seq;
ALTER TABLE msg_c2g DROP COLUMN accepted_at;
ALTER TABLE msg_c2g DROP COLUMN conv_seq;
ALTER TABLE msg_c2c DROP COLUMN accepted_at;
ALTER TABLE msg_c2c DROP COLUMN conv_seq;
PRAGMA user_version = 34;""",
  ),
  MigrationEdge(
    id: 'downgrade_v34_删除_user_collect_E2EE收藏v1元数据列',
    fromVersion: 34,
    toVersion: 33,
    description: '从 v34 降级到 v33（删除 user_collect 的 E2EE 收藏 v1 元数据列）。',
    reversible: true,
    dataLoss: false,
    requiresResync: true,
    preconditions: [
      'downgrade 前 v34 schema 处于一致状态',
      '无未同步的 sealed 收藏编辑（sealed 行降级后回到 legacy 语义不可再 CAS）',
    ],
    postconditions: [
      'user_collect 不含 generation/key_version/attach_file_hash256 列：PRAGMA user_version = 33',
    ],
    affectedObjects: ['user_collect'],
    headerComment:
        r"""-- ============================================================
-- VERSION: 34
-- DESC: 从 v34 降级到 v33（删除 user_collect.generation / key_version /
--       attach_file_hash256，E2EE 收藏 v1 元数据列）。
-- ============================================================

""",
    sql: r"""ALTER TABLE user_collect DROP COLUMN attach_file_hash256;
ALTER TABLE user_collect DROP COLUMN key_version;
ALTER TABLE user_collect DROP COLUMN generation;
PRAGMA user_version = 33;""",
  ),
];

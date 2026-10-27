// 升级边 v34→v35（块 35）
//
// R07 phase1（PLAN IMBoy_Timezone_Repair_V1）：会话消息权威排序与首次接受事实列。
// - conv_seq：服务端权威会话内序号（BIGINT 语义，SQLite INTEGER）。NULL=服务端
//   尚未给出（存量旧消息 / 兼容窗口），**绝不本地伪造**；来源仅限可信
//   archive/offline/ACK 数据（接线属 R07-wire phase2）。
// - accepted_at：首次服务端接受时间（毫秒 int）。NULL=无该事实；只写一次，
//   不覆盖已有值；不回填 now。
// 同一毫秒多条消息 / 离线乱序到达时，auto_id 顺序 != 真实顺序；conv_seq 是
// 唯一权威。会话内稳定排序定义见 lib/store/model/message_order.dart。
// 降级可逆：down 边先 DROP INDEX 再 DROP COLUMN（无数据丢失）。
library;

import 'package:imboy/service/migration_manifest.dart';

const List<MigrationEdge> kUpgradeEdgesV35 = [
  MigrationEdge(
    id: 'upgrade_v35_msg四表增加_conv_seq_与_accepted_at',
    fromVersion: 34,
    toVersion: 35,
    description: 'R07 会话权威排序：msg_c2c/msg_c2g/msg_c2s/msg_s2c 四表增加可空 conv_seq（服务端会话内序号）与 accepted_at（首次服务端接受毫秒），并加 (conversation_uk3, conv_seq) 排序/游标索引。存量行保持 NULL（不伪造、不清库）。',
    reversible: true,
    dataLoss: false,
    requiresResync: false,
    preconditions: [
      'upgrade 前 v34 schema 处于一致状态（integrity/foreign_key check 通过）',
    ],
    postconditions: [
      '消息四表含可空 conv_seq/accepted_at INTEGER 列且均为 NULL 默认；',
      '每表存在 idx_msg_<t>_conversation_conv_seq (conversation_uk3, conv_seq)；',
      '既有行数据不变：PRAGMA user_version = 35',
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
-- DESC: R07 phase1：消息四表增加 conv_seq（服务端权威会话内序号，可空）
--       与 accepted_at（首次服务端接受毫秒，可空）两列，并各建
--       (conversation_uk3, conv_seq) 排序/游标索引。存量行为 NULL
--       （不伪造序号、不清库）；同毫秒/乱序场景以 conv_seq 为权威序。
--       降级可逆：down 边先 DROP INDEX 再 DROP COLUMN。
-- ============================================================

""",
    sql: r"""ALTER TABLE msg_c2c ADD COLUMN conv_seq INTEGER;
ALTER TABLE msg_c2c ADD COLUMN accepted_at INTEGER;
ALTER TABLE msg_c2g ADD COLUMN conv_seq INTEGER;
ALTER TABLE msg_c2g ADD COLUMN accepted_at INTEGER;
ALTER TABLE msg_c2s ADD COLUMN conv_seq INTEGER;
ALTER TABLE msg_c2s ADD COLUMN accepted_at INTEGER;
ALTER TABLE msg_s2c ADD COLUMN conv_seq INTEGER;
ALTER TABLE msg_s2c ADD COLUMN accepted_at INTEGER;
CREATE INDEX IF NOT EXISTS idx_msg_c2c_conversation_conv_seq ON msg_c2c (conversation_uk3, conv_seq);
CREATE INDEX IF NOT EXISTS idx_msg_c2g_conversation_conv_seq ON msg_c2g (conversation_uk3, conv_seq);
CREATE INDEX IF NOT EXISTS idx_msg_c2s_conversation_conv_seq ON msg_c2s (conversation_uk3, conv_seq);
CREATE INDEX IF NOT EXISTS idx_msg_s2c_conversation_conv_seq ON msg_s2c (conversation_uk3, conv_seq);
PRAGMA user_version = 35;""",
  ),
];

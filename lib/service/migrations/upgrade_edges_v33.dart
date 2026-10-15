// 升级边 v32→v33（块 33）
//
// W5-01（附件生命周期 V5）：新增 attachment_upload_task 表——
// 上传任务的持久化检查点（AC08 进程重启恢复）。
// 边界（02-main-plan W5-01）：保存 key 引用/密文描述/阶段/业务幂等键；
// 不持久化 URL；敏感密钥（contentKey/baseNonce）只存安全存储，
// 本表仅保存 key_ref 引用；阶段只能前进，恢复不得重新随机 seal。
// 此后本文件是唯一真源；元数据修改必须过 migration_manifest_test.dart。
library;

import 'package:imboy/service/migration_manifest.dart';

const List<MigrationEdge> kUpgradeEdgesV33 = [
  MigrationEdge(
    id: 'upgrade_v33_新增_attachment_upload_task_表',
    fromVersion: 32,
    toVersion: 33,
    description: '新增 attachment_upload_task 上传任务持久化检查点表（AC08 恢复）。',
    reversible: true,
    dataLoss: false,
    requiresResync: false,
    preconditions: [
      'upgrade 前 v32 schema 处于一致状态（integrity/foreign_key check 通过）',
    ],
    postconditions: [
      'attachment_upload_task 表与阶段索引生效：PRAGMA user_version = 33',
    ],
    affectedObjects: ['attachment_upload_task'],
    headerComment:
        r"""-- ============================================================
-- VERSION: 33
-- DESC: 新增 attachment_upload_task（附件上传任务持久化检查点）。
--       每个远程阶段边界（presign/put/confirm）await 落一行检查点，
--       进程被杀后按 stage 续传：密钥材料经 key_ref 从安全存储取回，
--       同 key 同密文恢复；材料缺失则显式 abandoned 并新建任务新 key。
--       不持久化 URL；服务端只收密文 hash。
--       降级可逆：down 边直接 DROP（未完成任务由升级端显式新建）。
-- ============================================================

""",
    sql: r"""CREATE TABLE IF NOT EXISTS "attachment_upload_task" (
    "id" TEXT PRIMARY KEY,
    "user_id" TEXT NOT NULL,
    "scope" TEXT NOT NULL,
    "scope_ref" TEXT,
    "file_name" TEXT NOT NULL,
    "mime" TEXT NOT NULL,
    "plain_size" INTEGER NOT NULL,
    "plain_sha256" TEXT NOT NULL,
    "object_key" TEXT,
    "upload_path" TEXT,
    "business_intent" TEXT,
    "stage" TEXT NOT NULL,
    "cipher" TEXT,
    "binding_hash" TEXT,
    "key_ref" TEXT,
    "ciphertext_sha256" TEXT,
    "anchor_msg_id" TEXT,
    "last_error" TEXT,
    "created_at" INTEGER NOT NULL,
    "updated_at" INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS "idx_attachment_upload_task_user_stage"
    ON "attachment_upload_task"("user_id", "stage");
PRAGMA user_version = 33;""",
  ),
];

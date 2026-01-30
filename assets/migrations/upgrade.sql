-- ============================================================
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

-- ============================================================
-- VERSION: 10
-- DESC: WebSocket API v2.0 消息表结构升级
-- ============================================================
-- 功能说明：升级到 WebSocket API v2.0 规范，统一消息表命名
-- 变更内容：
--   1. 重命名消息表：message → msg_c2c, group_message → msg_c2g
--      c2s_message → msg_c2s, s2c_message → msg_s2c
--   2. 新增字段：msg_type (消息类型), action (S2C指令), e2ee (端到端加密)
-- 数据迁移：保留所有现有数据，仅添加新字段并重命名表
--
-- 执行步骤：
--   1. 为每个消息表添加新字段（默认值处理）
--   2. 重命名表（使用 ALTER TABLE RENAME TO）

-- ============================================================
-- Step 1: 为现有消息表添加 v2.0 新增字段
-- ============================================================

-- 为 message 表 (C2C) 添加新字段
-- 注意：type 字段用于存储消息协议类型（C2C、C2G、S2C 等），与 msg_type（内容类型）不同
ALTER TABLE message ADD COLUMN type TEXT DEFAULT 'C2C';
ALTER TABLE message ADD COLUMN msg_type TEXT DEFAULT '';
ALTER TABLE message ADD COLUMN action TEXT DEFAULT '';
ALTER TABLE message ADD COLUMN e2ee TEXT DEFAULT '';

-- 为 group_message 表 (C2G) 添加新字段
ALTER TABLE group_message ADD COLUMN type TEXT DEFAULT 'C2G';
ALTER TABLE group_message ADD COLUMN msg_type TEXT DEFAULT '';
ALTER TABLE group_message ADD COLUMN action TEXT DEFAULT '';
ALTER TABLE group_message ADD COLUMN e2ee TEXT DEFAULT '';

-- 为 c2s_message 表 (C2S) 添加新字段
ALTER TABLE c2s_message ADD COLUMN type TEXT DEFAULT 'C2S';
ALTER TABLE c2s_message ADD COLUMN msg_type TEXT DEFAULT '';
ALTER TABLE c2s_message ADD COLUMN action TEXT DEFAULT '';
ALTER TABLE c2s_message ADD COLUMN e2ee TEXT DEFAULT '';

-- 为 s2c_message 表 (S2C) 添加新字段
ALTER TABLE s2c_message ADD COLUMN type TEXT DEFAULT 'S2C';
ALTER TABLE s2c_message ADD COLUMN msg_type TEXT DEFAULT '';
ALTER TABLE s2c_message ADD COLUMN action TEXT DEFAULT '';
ALTER TABLE s2c_message ADD COLUMN e2ee TEXT DEFAULT '';

-- ============================================================
-- Step 2: 迁移 payload 中的 msg_type 到顶层字段（数据优化）
-- ============================================================
-- 说明：从 payload JSON 中提取 msg_type 字段到新列，提高查询性能
-- 注意：这是可选的数据优化步骤，不执行也不影响功能

-- 更新 message 表的 msg_type 字段
UPDATE message
SET msg_type = json_extract(payload, '$.msg_type')
WHERE msg_type = '' AND json_extract(payload, '$.msg_type') IS NOT NULL;

-- 更新 group_message 表的 msg_type 字段
UPDATE group_message
SET msg_type = json_extract(payload, '$.msg_type')
WHERE msg_type = '' AND json_extract(payload, '$.msg_type') IS NOT NULL;

-- 更新 c2s_message 表的 msg_type 字段
UPDATE c2s_message
SET msg_type = json_extract(payload, '$.msg_type')
WHERE msg_type = '' AND json_extract(payload, '$.msg_type') IS NOT NULL;

-- 更新 s2c_message 表的 msg_type 和 action 字段
UPDATE s2c_message
SET msg_type = json_extract(payload, '$.msg_type')
WHERE msg_type = '' AND json_extract(payload, '$.msg_type') IS NOT NULL;

UPDATE s2c_message
SET action = json_extract(payload, '$.action')
WHERE action = '' AND json_extract(payload, '$.action') IS NOT NULL;

-- ============================================================
-- Step 3: 迁移 e2ee 字段（数据优化）
-- ============================================================

-- 更新 message 表的 e2ee 字段
UPDATE message
SET e2ee = json_extract(payload, '$.e2ee')
WHERE e2ee = '' AND json_extract(payload, '$.e2ee') IS NOT NULL;

-- 更新 group_message 表的 e2ee 字段
UPDATE group_message
SET e2ee = json_extract(payload, '$.e2ee')
WHERE e2ee = '' AND json_extract(payload, '$.e2ee') IS NOT NULL;

-- 更新 c2s_message 表的 e2ee 字段
UPDATE c2s_message
SET e2ee = json_extract(payload, '$.e2ee')
WHERE e2ee = '' AND json_extract(payload, '$.e2ee') IS NOT NULL;

-- 更新 s2c_message 表的 e2ee 字段
UPDATE s2c_message
SET e2ee = json_extract(payload, '$.e2ee')
WHERE e2ee = '' AND json_extract(payload, '$.e2ee') IS NOT NULL;

-- ============================================================
-- Step 4: 删除旧索引
-- ============================================================
-- 说明：表重命名后索引会自动跟随，但为保持一致性，先删除旧索引

DROP INDEX IF EXISTS idx_c2c_msg_conversation_status_author;
DROP INDEX IF EXISTS i_c2c_msg_Conversation_CreatedAt;
DROP INDEX IF EXISTS i_c2c_msg_Conversation_TopicId;
DROP INDEX IF EXISTS idx_message_conversation_uk3;
DROP INDEX IF EXISTS idx_message_from_to_created;

DROP INDEX IF EXISTS idx_c2g_msg_conversation_status_author;
DROP INDEX IF EXISTS i_c2g_msg_Conversation_CreatedAt;
DROP INDEX IF EXISTS i_c2g_msg_Conversation_TopicId;
DROP INDEX IF EXISTS idx_c2g_message_conversation_uk3;

DROP INDEX IF EXISTS idx_c2s_msg_conversation_status_author;
DROP INDEX IF EXISTS i_c2s_msg_Conversation_CreatedAt;
DROP INDEX IF EXISTS i_c2s_msg_Conversation_TopicId;
DROP INDEX IF EXISTS idx_c2s_message_conversation_uk3;
DROP INDEX IF EXISTS idx_c2s_message_from_to_created;

DROP INDEX IF EXISTS idx_s2c_msg_conversation_status_author;
DROP INDEX IF EXISTS i_s2c_msg_Conversation_CreatedAt;
DROP INDEX IF EXISTS i_s2c_msg_Conversation_TopicId;
DROP INDEX IF EXISTS idx_s2c_message_conversation_uk3;
DROP INDEX IF EXISTS idx_s2c_message_from_to_created;

-- ============================================================
-- Step 5: 重命名表为 v2.0 规范名称
-- ============================================================

-- 重命名 C2C 消息表
ALTER TABLE message RENAME TO msg_c2c;

-- 重命名 C2G 消息表
ALTER TABLE group_message RENAME TO msg_c2g;

-- 重命名 C2S 消息表
ALTER TABLE c2s_message RENAME TO msg_c2s;

-- 重命名 S2C 消息表
ALTER TABLE s2c_message RENAME TO msg_s2c;

-- ============================================================
-- Step 6: 创建新索引（使用新表名）
-- ============================================================

-- msg_c2c 表索引
CREATE INDEX IF NOT EXISTS idx_msg_c2c_conversation_status_author
  ON msg_c2c (conversation_uk3, status, is_author);
CREATE INDEX IF NOT EXISTS idx_msg_c2c_conversation_created_at
  ON msg_c2c (conversation_uk3, created_at);
CREATE INDEX IF NOT EXISTS idx_msg_c2c_conversation_topic_id
  ON msg_c2c (conversation_uk3, topic_id);
CREATE INDEX IF NOT EXISTS idx_msg_c2c_conversation_uk3
  ON msg_c2c (conversation_uk3);
CREATE INDEX IF NOT EXISTS idx_msg_c2c_from_to_created
  ON msg_c2c (from_id, to_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_msg_c2c_msg_type
  ON msg_c2c (msg_type);

-- msg_c2g 表索引
CREATE INDEX IF NOT EXISTS idx_msg_c2g_conversation_status_author
  ON msg_c2g (conversation_uk3, status, is_author);
CREATE INDEX IF NOT EXISTS idx_msg_c2g_conversation_created_at
  ON msg_c2g (conversation_uk3, created_at);
CREATE INDEX IF NOT EXISTS idx_msg_c2g_conversation_topic_id
  ON msg_c2g (conversation_uk3, topic_id);
CREATE INDEX IF NOT EXISTS idx_msg_c2g_conversation_uk3
  ON msg_c2g (conversation_uk3);
CREATE INDEX IF NOT EXISTS idx_msg_c2g_from_to_created
  ON msg_c2g (from_id, to_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_msg_c2g_msg_type
  ON msg_c2g (msg_type);

-- msg_c2s 表索引
CREATE INDEX IF NOT EXISTS idx_msg_c2s_conversation_status_author
  ON msg_c2s (conversation_uk3, status, is_author);
CREATE INDEX IF NOT EXISTS idx_msg_c2s_conversation_created_at
  ON msg_c2s (conversation_uk3, created_at);
CREATE INDEX IF NOT EXISTS idx_msg_c2s_conversation_topic_id
  ON msg_c2s (conversation_uk3, topic_id);
CREATE INDEX IF NOT EXISTS idx_msg_c2s_conversation_uk3
  ON msg_c2s (conversation_uk3);
CREATE INDEX IF NOT EXISTS idx_msg_c2s_from_to_created
  ON msg_c2s (from_id, to_id, created_at DESC);

-- msg_s2c 表索引
CREATE INDEX IF NOT EXISTS idx_msg_s2c_conversation_status_author
  ON msg_s2c (conversation_uk3, status, is_author);
CREATE INDEX IF NOT EXISTS idx_msg_s2c_conversation_created_at
  ON msg_s2c (conversation_uk3, created_at);
CREATE INDEX IF NOT EXISTS idx_msg_s2c_conversation_topic_id
  ON msg_s2c (conversation_uk3, topic_id);
CREATE INDEX IF NOT EXISTS idx_msg_s2c_conversation_uk3
  ON msg_s2c (conversation_uk3);
CREATE INDEX IF NOT EXISTS idx_msg_s2c_from_to_created
  ON msg_s2c (from_id, to_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_msg_s2c_action
  ON msg_s2c (action);

-- ============================================================
-- 更新版本号
-- ============================================================
PRAGMA user_version = 10;

-- ============================================================
-- VERSION: 11
-- DESC: 修复 msg_* 表缺少 type 和 action 字段的问题
-- ============================================================
-- 功能说明：修复 VERSION 10 迁移遗漏的字段
-- 变更内容：
--   1. 为所有 msg_* 表添加 type 字段（如果不存在）
--   2. 为所有 msg_* 表添加 action 字段（如果不存在）
--
-- 注意：
--   - type 字段用于存储消息协议类型（C2C、C2G、C2S、S2C）
--   - action 字段用于存储 S2C 消息的指令类型
--   - 此迁移会忽略"重复列"错误，因此可以安全地重复执行

-- ============================================================
-- Step 1: 为 msg_c2c 表添加缺失字段
-- ============================================================
ALTER TABLE msg_c2c ADD COLUMN type TEXT DEFAULT 'C2C';
ALTER TABLE msg_c2c ADD COLUMN action TEXT DEFAULT '';

-- ============================================================
-- Step 2: 为 msg_c2g 表添加缺失字段
-- ============================================================
ALTER TABLE msg_c2g ADD COLUMN type TEXT DEFAULT 'C2G';
ALTER TABLE msg_c2g ADD COLUMN action TEXT DEFAULT '';

-- ============================================================
-- Step 3: 为 msg_c2s 表添加缺失字段
-- ============================================================
ALTER TABLE msg_c2s ADD COLUMN type TEXT DEFAULT 'C2S';
ALTER TABLE msg_c2s ADD COLUMN action TEXT DEFAULT '';

-- ============================================================
-- Step 4: 为 msg_s2c 表添加缺失字段
-- ============================================================
ALTER TABLE msg_s2c ADD COLUMN type TEXT DEFAULT 'S2C';
ALTER TABLE msg_s2c ADD COLUMN action TEXT DEFAULT '';

-- ============================================================
-- 更新版本号
-- ============================================================
PRAGMA user_version = 11;

-- ============================================================
-- VERSION: 12
-- DESC: 最终修复 - 确保 msg_* 表包含所有必需字段
-- ============================================================
-- 功能说明：这是最后的保障迁移，确保所有字段都存在
-- 变更内容：
--   1. 为所有 msg_* 表添加 type 字段（如果不存在）
--   2. 为所有 msg_* 表添加 action 字段（如果不存在）
--
-- 注意：此迁移可以安全地重复执行，会忽略重复列错误

-- ============================================================
-- Step 1: 为 msg_c2c 表确保字段存在
-- ============================================================
ALTER TABLE msg_c2c ADD COLUMN type TEXT DEFAULT 'C2C';
ALTER TABLE msg_c2c ADD COLUMN action TEXT DEFAULT '';

-- ============================================================
-- Step 2: 为 msg_c2g 表确保字段存在
-- ============================================================
ALTER TABLE msg_c2g ADD COLUMN type TEXT DEFAULT 'C2G';
ALTER TABLE msg_c2g ADD COLUMN action TEXT DEFAULT '';

-- ============================================================
-- Step 3: 为 msg_c2s 表确保字段存在
-- ============================================================
ALTER TABLE msg_c2s ADD COLUMN type TEXT DEFAULT 'C2S';
ALTER TABLE msg_c2s ADD COLUMN action TEXT DEFAULT '';

-- ============================================================
-- Step 4: 为 msg_s2c 表确保字段存在
-- ============================================================
ALTER TABLE msg_s2c ADD COLUMN type TEXT DEFAULT 'S2C';
ALTER TABLE msg_s2c ADD COLUMN action TEXT DEFAULT '';

-- ============================================================
-- 更新版本号
-- ============================================================
PRAGMA user_version = 12;
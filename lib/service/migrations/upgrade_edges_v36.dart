// 业务消息 ID 保留原字符串；已被旧版整数转换丢失的内容无法恢复。
// conversation 数值 INTEGER 0 沿用旧读取语义作为空指针；无法区分
// 已被旧 INTEGER affinity 吞掉类型的真实字符串 '0'，不推断恢复。
library;

import 'package:imboy/service/migration_manifest.dart';

const List<MigrationEdge> kUpgradeEdgesV36 = [
  MigrationEdge(
    id: 'upgrade_v36_message_id_text',
    fromVersion: 35,
    toVersion: 36,
    description: '消息四表 id 与 conversation.last_msg_id 改为 TEXT，保留其余列与索引。',
    reversible: false,
    dataLoss: false,
    requiresResync: false,
    preconditions: ['v35 schema 完整'],
    postconditions: ['业务消息 ID 为 TEXT，FTS 独立表保持不变'],
    affectedObjects: [
      'msg_c2c',
      'msg_c2g',
      'msg_c2s',
      'msg_s2c',
      'conversation',
    ],
    headerComment:
        '-- VERSION: 36\n-- DESC: opaque message ID TEXT contract\n\n',
    sql: r"""CREATE TABLE msg_c2c_new (
    accepted_at INTEGER,
    action TEXT DEFAULT '',
    auto_id INTEGER PRIMARY KEY,
    conv_seq INTEGER,
    conversation_uk3 TEXT,
    created_at INTEGER,
    e2ee TEXT,
    from_id INTEGER,
    id TEXT NOT NULL,
    is_author INTEGER,
    msg_type TEXT,
    payload TEXT,
    sender_did TEXT,
    status INTEGER,
    to_id INTEGER,
    topic_id INTEGER,
    type TEXT DEFAULT 'C2C',
    CONSTRAINT uk_MsgId UNIQUE (id)
);
INSERT INTO msg_c2c_new (accepted_at, action, auto_id, conv_seq, conversation_uk3, created_at, e2ee, from_id, id, is_author, msg_type, payload, sender_did, status, to_id, topic_id, type)
SELECT accepted_at, action, auto_id, conv_seq, conversation_uk3, created_at, e2ee, from_id, CAST(id AS TEXT), is_author, msg_type, payload, sender_did, status, to_id, topic_id, type FROM msg_c2c;
DROP TABLE msg_c2c;
ALTER TABLE msg_c2c_new RENAME TO msg_c2c;
CREATE INDEX idx_msg_c2c_conversation_conv_seq ON msg_c2c (conversation_uk3, conv_seq);
CREATE INDEX idx_msg_c2c_conversation_created_at ON msg_c2c (conversation_uk3, created_at);
CREATE INDEX idx_msg_c2c_conversation_status_author ON msg_c2c (conversation_uk3, status, is_author);
CREATE INDEX idx_msg_c2c_conversation_topic_id ON msg_c2c (conversation_uk3, topic_id);
CREATE INDEX idx_msg_c2c_conversation_uk3 ON msg_c2c (conversation_uk3);
CREATE INDEX idx_msg_c2c_from_to_created ON msg_c2c (from_id, to_id, created_at DESC);
CREATE INDEX idx_msg_c2c_msg_type ON msg_c2c (msg_type);
CREATE INDEX idx_msg_c2c_status ON msg_c2c (status);
CREATE INDEX idx_msg_c2c_unread_count ON msg_c2c (conversation_uk3, is_author, auto_id);
CREATE TABLE msg_c2g_new (
    accepted_at INTEGER,
    action TEXT DEFAULT '',
    auto_id INTEGER PRIMARY KEY,
    conv_seq INTEGER,
    conversation_uk3 TEXT,
    created_at INTEGER,
    e2ee TEXT,
    from_id INTEGER,
    id TEXT NOT NULL,
    is_author INTEGER,
    msg_type TEXT,
    payload TEXT,
    status INTEGER,
    to_id INTEGER,
    topic_id INTEGER,
    type TEXT DEFAULT 'C2G',
    CONSTRAINT uk_MsgId UNIQUE (id)
);
INSERT INTO msg_c2g_new (accepted_at, action, auto_id, conv_seq, conversation_uk3, created_at, e2ee, from_id, id, is_author, msg_type, payload, status, to_id, topic_id, type)
SELECT accepted_at, action, auto_id, conv_seq, conversation_uk3, created_at, e2ee, from_id, CAST(id AS TEXT), is_author, msg_type, payload, status, to_id, topic_id, type FROM msg_c2g;
DROP TABLE msg_c2g;
ALTER TABLE msg_c2g_new RENAME TO msg_c2g;
CREATE INDEX idx_msg_c2g_conversation_conv_seq ON msg_c2g (conversation_uk3, conv_seq);
CREATE INDEX idx_msg_c2g_conversation_created_at ON msg_c2g (conversation_uk3, created_at);
CREATE INDEX idx_msg_c2g_conversation_status_author ON msg_c2g (conversation_uk3, status, is_author);
CREATE INDEX idx_msg_c2g_conversation_topic_id ON msg_c2g (conversation_uk3, topic_id);
CREATE INDEX idx_msg_c2g_conversation_uk3 ON msg_c2g (conversation_uk3);
CREATE INDEX idx_msg_c2g_from_to_created ON msg_c2g (from_id, to_id, created_at DESC);
CREATE INDEX idx_msg_c2g_msg_type ON msg_c2g (msg_type);
CREATE INDEX idx_msg_c2g_status ON msg_c2g (status);
CREATE INDEX idx_msg_c2g_unread_count ON msg_c2g (conversation_uk3, is_author, auto_id);
CREATE TABLE msg_c2s_new (
    accepted_at INTEGER,
    action TEXT DEFAULT '',
    auto_id INTEGER PRIMARY KEY,
    conv_seq INTEGER,
    conversation_uk3 TEXT,
    created_at INTEGER,
    e2ee TEXT,
    from_id INTEGER,
    id TEXT NOT NULL,
    is_author INTEGER,
    msg_type TEXT,
    payload TEXT,
    status INTEGER,
    to_id INTEGER,
    topic_id INTEGER,
    type TEXT DEFAULT 'C2S',
    CONSTRAINT uk_MsgId UNIQUE (id)
);
INSERT INTO msg_c2s_new (accepted_at, action, auto_id, conv_seq, conversation_uk3, created_at, e2ee, from_id, id, is_author, msg_type, payload, status, to_id, topic_id, type)
SELECT accepted_at, action, auto_id, conv_seq, conversation_uk3, created_at, e2ee, from_id, CAST(id AS TEXT), is_author, msg_type, payload, status, to_id, topic_id, type FROM msg_c2s;
DROP TABLE msg_c2s;
ALTER TABLE msg_c2s_new RENAME TO msg_c2s;
CREATE INDEX idx_msg_c2s_conversation_conv_seq ON msg_c2s (conversation_uk3, conv_seq);
CREATE INDEX idx_msg_c2s_conversation_created_at ON msg_c2s (conversation_uk3, created_at);
CREATE INDEX idx_msg_c2s_conversation_status_author ON msg_c2s (conversation_uk3, status, is_author);
CREATE INDEX idx_msg_c2s_conversation_topic_id ON msg_c2s (conversation_uk3, topic_id);
CREATE INDEX idx_msg_c2s_conversation_uk3 ON msg_c2s (conversation_uk3);
CREATE INDEX idx_msg_c2s_from_to_created ON msg_c2s (from_id, to_id, created_at DESC);
CREATE INDEX idx_msg_c2s_status ON msg_c2s (status);
CREATE INDEX idx_msg_c2s_unread_count ON msg_c2s (conversation_uk3, is_author, auto_id);
CREATE TABLE msg_s2c_new (
    accepted_at INTEGER,
    action TEXT,
    auto_id INTEGER PRIMARY KEY,
    conv_seq INTEGER,
    conversation_uk3 TEXT,
    created_at INTEGER,
    e2ee TEXT,
    from_id INTEGER,
    id TEXT NOT NULL,
    is_author INTEGER,
    msg_type TEXT,
    payload TEXT,
    status INTEGER,
    to_id INTEGER,
    topic_id INTEGER,
    type TEXT DEFAULT 'S2C',
    CONSTRAINT uk_MsgId UNIQUE (id)
);
INSERT INTO msg_s2c_new (accepted_at, action, auto_id, conv_seq, conversation_uk3, created_at, e2ee, from_id, id, is_author, msg_type, payload, status, to_id, topic_id, type)
SELECT accepted_at, action, auto_id, conv_seq, conversation_uk3, created_at, e2ee, from_id, CAST(id AS TEXT), is_author, msg_type, payload, status, to_id, topic_id, type FROM msg_s2c;
DROP TABLE msg_s2c;
ALTER TABLE msg_s2c_new RENAME TO msg_s2c;
CREATE INDEX idx_msg_s2c_action ON msg_s2c (action);
CREATE INDEX idx_msg_s2c_conversation_conv_seq ON msg_s2c (conversation_uk3, conv_seq);
CREATE INDEX idx_msg_s2c_conversation_created_at ON msg_s2c (conversation_uk3, created_at);
CREATE INDEX idx_msg_s2c_conversation_status_author ON msg_s2c (conversation_uk3, status, is_author);
CREATE INDEX idx_msg_s2c_conversation_topic_id ON msg_s2c (conversation_uk3, topic_id);
CREATE INDEX idx_msg_s2c_conversation_uk3 ON msg_s2c (conversation_uk3);
CREATE INDEX idx_msg_s2c_from_to_created ON msg_s2c (from_id, to_id, created_at DESC);
CREATE TABLE conversation_new (
    avatar TEXT,
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    is_muted INTEGER NOT NULL DEFAULT 0,
    is_show INTEGER,
    last_msg_id TEXT,
    last_msg_status INTEGER,
    last_time INTEGER,
    mention_unread INTEGER NOT NULL DEFAULT 0,
    msg_type TEXT,
    payload TEXT,
    peer_id INTEGER,
    region TEXT,
    sign TEXT,
    subtitle TEXT,
    title TEXT,
    type TEXT,
    unread_num INTEGER,
    user_id INTEGER
);
INSERT INTO conversation_new (avatar, id, is_muted, is_show, last_msg_id, last_msg_status, last_time, mention_unread, msg_type, payload, peer_id, region, sign, subtitle, title, type, unread_num, user_id)
SELECT avatar, id, is_muted, is_show,
    CASE WHEN typeof(last_msg_id) = 'integer' AND last_msg_id = 0 THEN '' ELSE CAST(last_msg_id AS TEXT) END,
    last_msg_status, last_time, mention_unread, msg_type, payload, peer_id, region, sign, subtitle, title, type, unread_num, user_id FROM conversation;
-- Keep the AUTOINCREMENT watermark even if the highest conversation was deleted.
INSERT INTO sqlite_sequence (name, seq)
SELECT 'conversation_new', seq FROM sqlite_sequence
WHERE name = 'conversation' AND NOT EXISTS (SELECT 1 FROM sqlite_sequence WHERE name = 'conversation_new');
UPDATE sqlite_sequence SET seq = MAX(seq, COALESCE((SELECT seq FROM sqlite_sequence WHERE name = 'conversation'), 0))
WHERE name = 'conversation_new';
DROP TABLE conversation;
ALTER TABLE conversation_new RENAME TO conversation;
CREATE INDEX i_cv_UserId_IsShow_LastTime ON conversation (user_id, is_show, last_time);
CREATE INDEX idx_conversation_user_id_last_time ON conversation (user_id, last_time DESC);
CREATE UNIQUE INDEX uk_cv_Type_From_To ON conversation ("type", user_id, peer_id);
PRAGMA user_version = 36;""",
  ),
];

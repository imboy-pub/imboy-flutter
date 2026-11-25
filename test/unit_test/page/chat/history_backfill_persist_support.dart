// BUG#119/R06/R07/W8 历史回填落库共享 fixture（拆分自 history_backfill_persist_test.dart，
// ratchet <800 行约束）：测试 uid/peer/group 常量与真实表 DDL。本文件不含用例。

/// 当前测试账号（与 C2C 行的 from 一致，使 isAuthor=true → peerId=toId）
const String backfillCurrentUid = '1817128709888507904';
const String backfillPeerUid = '1825989847768576000';
const String backfillGroupId = '1818608297223856128';

const String backfillMsgC2cDDL = '''
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
    sender_did TEXT,
    conv_seq INTEGER,
    accepted_at INTEGER,
    CONSTRAINT uk_MsgId UNIQUE (id)
  )
''';

const String backfillMsgC2gDDL = '''
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
    conv_seq INTEGER,
    accepted_at INTEGER,
    CONSTRAINT uk_MsgId UNIQUE (id)
  )
''';

const String backfillConversationDDL = '''
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
    mention_unread INTEGER DEFAULT 0,
    is_muted INTEGER DEFAULT 0,
    "type" TEXT,
    msg_type TEXT,
    is_show INTEGER,
    last_time INTEGER,
    last_msg_id INTEGER,
    last_msg_status INTEGER,
    payload TEXT
  )
''';

const String backfillContactDDL = '''
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
    last_seen_at INTEGER
  )
''';

const String backfillGroupDDL = '''
  CREATE TABLE "group" (
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
  )
''';

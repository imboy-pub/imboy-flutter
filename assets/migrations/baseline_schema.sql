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
-- sqlite_sequence is auto-managed by SQLite, do not create manually
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
    updated_at INTEGER NOT NULL
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

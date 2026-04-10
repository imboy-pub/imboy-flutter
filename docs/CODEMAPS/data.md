<!-- Generated: 2026-04-10 | Files scanned: 15 (repos) + 25 (models) | Token estimate: ~700 -->

# Data Architecture

## Database
- **Engine**: SQLCipher (AES-256 encrypted SQLite)
- **Version**: v16
- **Mode**: WAL (Write-Ahead Logging)
- **Cache**: 64MB
- **Per-user isolation**: `{env}_{uid}.db`
- **Template**: `assets/example10.db` (copied on first login)

## Core Tables
```
msg_c2c          C2C messages (id, from_id, to_id, msg_type, payload, e2ee, ...)
msg_c2g          C2G group messages
msg_c2s          C2S client-to-server messages
msg_s2c          S2C server-to-client messages
conversation     Conversation list (conv_key, last_msg, unread_count, ...)
contact          Contact/friend list
group_info       Group metadata
group_member     Group membership
channel          Channel definitions
channel_msg      Channel messages
user_tag         User tags/labels
user_collect     User favorites/bookmarks
user_device      Device registry
user_denylist    Blocked users
new_friend       Friend requests
```

## Repository Layer (lib/store/repository/, 15 files)
```
message_repo_sqlite.dart       → msg_c2c, msg_c2g, msg_c2s, msg_s2c CRUD
conversation_repo_sqlite.dart  → conversation list, unread management
contact_repo_sqlite.dart       → contact CRUD, search
group_repo_sqlite.dart         → group_info CRUD
group_member_repo_sqlite.dart  → group_member CRUD
channel_repo_sqlite.dart       → channel CRUD
channel_message_repo_sqlite.dart → channel_msg CRUD
user_repo_local.dart           → current user state (singleton)
user_tag_repo_sqlite.dart      → user_tag CRUD
user_collect_repo_sqlite.dart  → favorites CRUD
user_device_repo_sqlite.dart   → device registry CRUD
user_denylist_repo_sqlite.dart → denylist CRUD
new_friend_repo_sqlite.dart    → friend request CRUD
message_fts_repo.dart          → full-text search index
user_repo_provider.dart        → Riverpod provider wrapper
```

## Model Layer (lib/store/model/, 25 files)
```
Key models with fromJson/toJson:
  message_model        → id(TSID), type, from_id, to_id, msg_type, payload, e2ee
  conversation_model   → conv_key, title, avatar, last_msg, unread_count
  contact_model        → uid, nickname, avatar, remark, status
  group_model          → gid, name, avatar, owner_uid, member_count
  group_member_model   → gid, uid, role, nickname
  channel_model        → id, name, type, subscriber_count
  attachment_model     → id, url, type, size, metadata
  entity_image         → url, width, height, thumbnail
  entity_video         → url, duration, thumbnail, size
```

## Migration System
```
assets/migrations/
├── upgrade.sql      Version upgrade scripts (v1 → v16)
└── downgrade.sql    Version downgrade scripts

Flow: SqliteService._onUpgrade() → MigrationService.migrate()
  1. PRAGMA user_version check
  2. Create snapshot backup
  3. Execute SQL scripts
  4. Verify table structure
  5. Cleanup old snapshots
```

## Encryption Architecture
```
Key Storage:
  flutter_secure_storage
    ├── db_cipher_key_{uid}     SQLCipher DB password (256-bit hex)
    ├── e2ee_private_key        E2EE RSA private key
    ├── e2ee_public_key         E2EE RSA public key
    ├── e2ee_device_id          Device identifier
    ├── e2ee_key_id             Key version identifier
    └── e2ee_shard_{id}         Shamir recovery shards

DB Encryption:
  New DB → openDatabase(path, password: key)
  Existing plaintext → sqlcipher_export() + ATTACH → atomic replace
  Backup → {path}.pre_encrypt.bak (auto-cleanup after 7 days)
```

## ID System
- **TSID** (Time-Sorted ID): BIGINT, used for all entity IDs
- **conv_key**: `c2c:{min_uid}:{max_uid}` or `c2g:{gid}`
- **conv_seq**: Per-conversation monotonic sequence for sync

<!-- Generated: 2026-04-10 | Files scanned: 71 (services) + 32 (APIs) | Token estimate: ~850 -->

# Service & API Architecture

## Service Layer (lib/service/, 71 files)

### Core Services
```
WebSocket Pipeline:
  websocket.dart           → Connection management, auto-reconnect
  websocket_events.dart    → Event type definitions
  websocket_message_queue.dart → Persistent outbound queue
  ack_manager.dart         → Delivery/read confirmation

Message Processing:
  message.dart             → Core send/receive/dispatch
  message_providers.dart   → Riverpod providers for msg state
  message_offline.dart     → Offline message pull & sync
  message_retry.dart       → Failed message retry (exponential backoff)
  message_webrtc.dart      → WebRTC signaling messages
  message_type_normalizer.dart → Type normalization layer

Database:
  sqlite.dart              → SQLCipher DB (v16), singleton, CRUD, tx, cache
  cached_sqlite_service.dart → Query result caching
  migration_service.dart   → Version migration (upgrade.sql / downgrade.sql)
  db_encryption_key_service.dart → Per-user 256-bit cipher key management

Storage:
  storage.dart             → SharedPreferences (non-sensitive)
  storage_secure.dart      → FlutterSecureStorage (tokens, keys)
  secure_key_service.dart  → AES key management
  secure_token_storage_service.dart → Auth token storage
```

### E2EE Services
```
  e2ee_service.dart        → E2EE lifecycle management
  e2ee_crypto_service.dart → RSA-OAEP-256 + AES-256-GCM
  e2ee_key_service.dart    → Key generation, rotation
  e2ee_transfer_service.dart → Device-to-device key transfer
  shamir_secret_sharing.dart → Social key recovery (k-of-n)
  e2ee_settings.dart       → Per-conversation E2EE config
```

### Support Services
```
  network_monitor.dart     → connectivity_plus state tracking
  notification.dart        → flutter_local_notifications
  push_notification_service.dart → FCM push
  voice_playback_service.dart → just_audio playback (Riverpod Notifier)
  assets.dart              → Resource URL auth (viewUrl with signed tokens)
  app_logger.dart          → Structured logging
  sentry_service.dart      → Error tracking
  backup_service.dart      → DB backup/restore
  event_bus.dart           → Cross-service event dispatch
```

## API Layer (lib/store/api/, 32 files)

All API clients use Dio HTTP/2. Pattern: `XxxApi` class → `HttpClientFactory`.

```
Auth & User:
  user_api          → login, register, profile CRUD
  passport_api      → auth token management

Messaging:
  message_api       → message history, search, delete
  conversation_api  → conversation list, unread counts
  sync_api          → incremental sync (conv_seq cursors)
  mention_api       → @mention operations

Social:
  contact_api       → friend add/remove/block
  social_api        → social graph operations
  search_api        → global search
  fts_api           → full-text search

Groups:
  group_api         → group CRUD
  group_member_api  → member management
  group_album_api   → shared albums
  group_file_api    → shared files
  group_schedule_api → group events
  group_task_api    → group tasks
  group_vote_api    → group polls

Channels:
  channel_api       → channel CRUD, subscribe

E2EE:
  e2ee_api          → key exchange, device registration
  e2ee_plus_api     → social recovery, compliance

Misc:
  attachment_api    → file upload/download
  feedback_api      → user feedback
  notification_api  → push notification config
  qrcode_api        → QR code generation
  app_upgrade_api   → version check
```

## WebSocket Message Format (v2.0)
```json
{
  "id": "msg_tsid",
  "type": "C2C|C2G|C2S|S2C",
  "from": "sender_tsid",
  "to": "receiver_tsid",
  "msg_type": "text|image|video|audio|file|location|e2ee",
  "payload": "...",
  "e2ee": { "e2ee": true, "e2ee_ver": 1, ... },
  "created_at": 1768957192053
}
```

## Service Init Order
```
1. StorageService.init()
2. UserRepoLocal.onInit()
3. NtpHelper.getOffset()
4. DeviceExt.did
5. HttpClient
6. NetworkMonitorService
7. VoicePlaybackService
8. WebSocket services (MessageService → WebSocketService)
```

# 服务层 (Service Layer)

[根目录](../../CLAUDE.md) > [lib](../) > **service**

## 服务清单

| 服务文件 | 职责 | 关键说明 |
|---------|------|---------|
| `event_bus.dart` | 事件总线（服务间解耦） | AppEventBus.fire() |
| `websocket.dart` | WebSocket 连接管理 | 自动重连、心跳保活 |
| `message.dart` | 消息核心服务 | C2C/C2G/C2S/S2C |
| `message_actions.dart` | 消息操作处理 | 撤回、阅后即焚 |
| `message_s2c.dart` | 服务端→客户端消息 | - |
| `message_offline.dart` | 离线消息拉取/批量插入 | - |
| `message_retry.dart` | 消息重试（指数退避） | 3次上限 |
| `message_webrtc.dart` | WebRTC 信令处理 | - |
| `message_manage_service.dart` | 消息管理 | - |
| `websocket_message_queue.dart` | WS 消息队列 | PersistentMessageQueue |
| `sqlite.dart` | SQLite（v9, WAL, 64MB缓存） | synchronized并发控制 |
| `cached_sqlite_service.dart` | SQLite 查询缓存 | - |
| `migration_service.dart` | 数据库迁移（含快照备份） | upgrade/downgrade.sql |
| `storage.dart` | 键值对存储 | shared_preferences |
| `storage_secure.dart` | 安全存储 | flutter_secure_storage |
| `secure_token_storage_service.dart` | Token 存储 | - |
| `encrypter.dart` | AES 加密解密 | pointycastle |
| `rsa.dart` | RSA 加密 | pointycastle |
| `ack_manager.dart` | ACK 确认管理（含超时重试） | - |
| `network_monitor.dart` | 网络状态监控 | connectivity_plus |
| `notification.dart` | 本地通知 | flutter_local_notifications |
| `backup_service.dart` | 数据备份 | archive, path |
| `assets.dart` | 资源管理 | - |
| `app_logger.dart` | 应用日志 | logger |
| `voice_playback_service.dart` | 语音播放（Riverpod Notifier） | just_audio |

## 初始化顺序（AppInitializer.initialize）

```
1. StorageService.init()
2. UserRepoLocal.onInit()
3. NtpHelper.getOffset()
4. DeviceExt.did
5. HttpClient
6. NetworkMonitorService
7. VoicePlaybackService（voicePlaybackServiceProvider，无需手动init）
8. WS服务群：BottomNavigationLogic → PersistentMessageQueue → ConversationLogic
            → AckManager → MessageService → MessageActions → MessageWebrtc
            → MessageOfflineService → MessageRetry → WebSocketService
```

## 核心 API

### WebSocketService
```dart
WebSocketService ws = WebSocketService.to;
Rx<SocketStatus> status;
await ws.openSocket(from: 'manual');
await ws.closeSocket();
ws.send(msg);

enum SocketStatus { disconnected, connecting, connected, error }
```

### MessageService
```dart
MessageService msgService = MessageService.to;
await msgService.send(MessageModel message);
// 接收消息通过事件总线：eventBus.on<TypeMessage>().listen((msg) { ... });
```

### SqliteService
```dart
SqliteService db = SqliteService.to;
List<Map> data = await db.query('table');
await db.insert('table', {'key': 'value'});
await db.update('table', data, where: 'id=?', whereArgs: [1]);
await db.delete('table', where: 'id=?', whereArgs: [1]);
await db.transaction((txn) async { /* 批量操作 */ });
```

### StorageService / SecureStorageService
```dart
await StorageService.to.setString('key', 'value');
await StorageService.to.setBool('key', true);
await StorageService.to.setInt('key', 123);
String? v = StorageService.to.getString('key');
await StorageService.to.remove('key');

await SecureStorageService.to.setString('token', 'secret');
String? token = await SecureStorageService.to.getString('token');
```

### EncrypterService / RSAService
```dart
String enc = EncrypterService.aesEncrypt(plaintext, key, iv);
String dec = EncrypterService.aesDecrypt(encrypted, key, iv);
String hash = EncrypterService.md5(input);

await RSAService.generateKeyPair();
String enc = RSAService.encryptByPublicKey(plaintext);
String dec = RSAService.decryptByPrivateKey(encrypted);
```

### MigrationService
```dart
// MigrationResult: { bool success, int fromVersion, int toVersion, String? error }
await MigrationService.to.migrate(db: db, fromVersion: 1, toVersion: 2, isUpgrade: true);
await MigrationService.to.backupDatabase(snapshotName: 'backup_v1');
await MigrationService.to.cleanupOldSnapshots(maxAge: Duration(days: 7));
```

### VoicePlaybackService（Riverpod）
```dart
final state = ref.watch(voicePlaybackServiceProvider);
// state: isPlaying, currentPosition, currentDuration, messageId
await ref.read(voicePlaybackServiceProvider.notifier).play(path: 'audio.mp3', messageId: 'msg123');
```

## WebSocket API v2.0 消息格式

### C2C/C2G 字段规范
| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | String | 消息ID |
| `type` | String | C2C / C2G |
| `from` | String | 发送者TSID |
| `to` | **String** | ⚠️ 接收者TSID，不是 `to_id` |
| `msg_type` | String | text/image/…（v2.0保留原始类型） |
| `e2ee` | **Map** | ⚠️ E2EE元数据，必须是Map不能json.encode |
| `payload` | String\|Map | 消息内容（加密时为base64密文） |
| `created_at` | int | 毫秒时间戳 |

### 常见错误
- `{badkey,<<"to">>}` → 误发 `to_id`，改为 `to`
- e2ee变成JSON字符串 → 误用 `json.encode(e2eeMap)`，直接传 Map

### E2EE 字段结构（e2ee 字段为 Map）
```dart
'e2ee': {
  'e2ee': true, 'e2ee_ver': 1, 'e2ee_suite': 'RSA-OAEP-256+AES-256-GCM',
  'iv': '<base64>', 'ct': '<base64>',
  'recipients': [{'did': '...', 'kid': '...', 'ek': '<base64>'}],
  'sig': '<base64>'
}
// payload = 'base64(iv).base64(ciphertext)'
// v2.0: 不再用 msg_type='e2ee'，通过 e2ee 字段存在判断是否加密
```

## 外部依赖
| 包 | 版本 | 用途 |
|----|------|------|
| sqflite | ^2.4.2 | SQLite |
| shared_preferences | ^2.5.4 | 键值存储 |
| flutter_secure_storage | ^10.0.0 | 安全存储 |
| web_socket_channel | ^3.0.3 | WebSocket |
| dio | ^5.9.0 | HTTP |
| connectivity_plus | ^7.0.0 | 网络监控 |
| synchronized | ^3.4.0 | 并发控制 |
| pointycastle | ^4.0.0 | 加密 |
| logger | ^2.6.2 | 日志 |

**相关文档**：[数据层](../store/CLAUDE.md) · [页面层](../page/CLAUDE.md) · [配置](../config/CLAUDE.md)

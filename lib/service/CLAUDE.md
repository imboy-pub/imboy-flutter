# 服务层 (Service Layer)

[根目录](../../CLAUDE.md) > [lib](../) > **service**

## 服务清单

| 服务文件 | 职责 | 关键说明 |
|---------|------|---------|
| `event_bus.dart` | 事件总线（服务间解耦） | AppEventBus.fire() |
| `websocket.dart` | WebSocket 连接管理 | 自动重连、心跳保活；**不做出站确认簿记**（原机制A已删，确认/重发归 `message_retry.dart`） |
| `message.dart` + `message_notifications.dart` | 消息核心服务 | C2C/C2G/C2S/S2C；通知沿用入站消息最初的账号与会话代次 |
| `message_actions.dart` | 消息操作处理 | 撤回、阅后即焚 |
| `message_s2c.dart` | 服务端→客户端消息 | - |
| `message_offline.dart` | 离线消息拉取/批量插入 | - |
| `message_retry.dart` | **出站消息确认状态机（唯一）**：5s 节拍按 `RetryPolicy` 退避重投，DB status 为真值 | 4次上限；单一清除入口 `RemoveFromRetryQueueRequestedEvent`（SERVER_ACK / action-ACK 均汇聚） |
| `retry_policy.dart` | 客户端重试策略单一真值源 | 发消息 [3,5,10,20]s；ACK confirm [3,5,10,15]s |
| `message_webrtc.dart` | WebRTC 信令处理 | 信令不入重试状态机（防 SDP 重放 glare） |
| `websocket_message_queue.dart` | WS 离线队列 | 仅兜底**未被** MessageRetry 跟踪的报文（B×D 去重见 `shouldEnqueueOffline`） |
| `sqlite.dart` | SQLite（v9, WAL, 64MB缓存） | synchronized并发控制 |
| `sqlite_lifecycle.dart` | SQLite 会话与句柄生命周期（`sqlite.dart` part） | 初始化绑定账号/环境/会话代次；关闭失败保留句柄供重试；关闭排空初始化 |
| `sqlite_account_data.dart` | SQLite 账号数据库关闭与删除（`sqlite.dart` part） | 清理读取密钥前排空数据库/初始化锁，删密钥前关闭选中旧句柄；回收 sidecar、旧恢复文件及账号 `.db.restore.*` 目录；Web 使用初始化后的工厂 |
| `sqlcipher_database.dart` | 独立 SQLCipher 打开及只读探测 | 校验原生加密能力和真实数据库页；探测不执行业务回调，不复用其他密码的句柄 |
| `cached_sqlite_service.dart` | SQLite 查询缓存 | - |
| `migration_service.dart` | 数据库迁移执行（事务内、失败回滚） | 从 manifest 构造脚本；快照/恢复在事务外（见下） |
| `migration_manifest.dart` + `migrations/` | **迁移唯一真源**（类型化边：SQL/reversible/dataLoss/affectedObjects） | .sql 与 embedded 常量均为生成物（tool/generate_sqlite_migrations.dart --check 守护） |
| `database_snapshot_service.dart` | 事务外一致性快照（VACUUM INTO、原子落位、env+uid 隔离、恢复） | 恢复需先关全部连接 |
| `database_migration_orchestrator.dart` | 迁移协调器（预检 fail-closed → 快照 → 迁移后验证+meta） | sqlite.dart 打开前/三版本回调接线 |
| `schema_fingerprint.dart` / `schema_contract.dart` | schema 指纹（SHA-256）、golden contract、关键 invariant、_imboy_schema_meta、application_id | 启动/迁移后错配检测 |
| `storage.dart` | 键值对存储 | shared_preferences |
| `storage_secure.dart` | 安全存储 | flutter_secure_storage |
| `secure_token_storage_service.dart` | Token 存储 | - |
| `login_account_history_service.dart` | 成功登录账号的本机身份与历史 | 按环境、服务端、UID 关联账号别名；去重与归属检查；数据清理成功后才移除历史，写入失败保留重试日志 |
| `account_local_task_registry.dart` + `account_local_files.dart` | 账号任务与临时文件归属 | 按 env + endpoint + UID 登记完整任务；清理先取消并等待任务收尾，再进入会话写队列；临时文件使用账号目录 |
| `account_preferences.dart` + `account_draft_store.dart` + `pending_chat_actions.dart` | 账号偏好、草稿与待发送动作 | 原会话失效后拒绝延迟写入；清理等待原生偏好写入落盘；草稿沿用 UID/会话键，队列按发送者清除 |
| `account_local_data_service.dart` + `account_local_data_ownership.dart` | 清除历史账号在本机的数据 / Local account data removal | 先检验归属；按 env + endpoint + UID 清 DB/快照/草稿/录音/秘密/缓存与任务；无法归属的旧数据阻止清理，保留其他账号及设备配置；历史仅成功后移除 |
| `account_media_cache_store.dart` + `account_media_cache_web.dart` | 媒体缓存归属 / Media cache ownership | 索引先于缓存字节写入；账号与公共设备资源独立；原生文件及 Web IndexedDB 均检查旧无主数据，删除失败保留索引可重试 |
| `olm_session_service.dart` + `olm_session_cleanup.dart` | Olm 会话及本机状态清理 | cleanup part 分别处理已删除账号的内存句柄和原有完整 Olm 清理，避免重新打开已删除数据库 |
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

**相关文档**：[数据层](../store/CLAUDE.md) · [页面层](../page/CLAUDE.md)

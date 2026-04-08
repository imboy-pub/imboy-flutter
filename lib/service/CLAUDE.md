# 服务层 (Service Layer) 文档

[根目录](../../CLAUDE.md) > [lib](../) > **service**

> 最后更新：2026-01-05 14:12:27 CST

---

## 变更记录 (Changelog)

### 2026-01-21
- **新增 WebSocket API v2.0 文档**：详细说明与服务端对接的消息格式
- **字段类型说明**：
  - `to` 字段：String 类型（TSID），对应服务端 `<<"to">>` (binary)
  - `to_id` 字段：int 类型，这是数据库字段，WebSocket API 中不使用
- **E2EE 修复说明**：`e2ee` 字段必须是 Map 类型，不能是 JSON 字符串

### 2026-01-05
- 初始化服务层文档
- 完成模块结构分析

---

## 模块职责

服务层（`lib/service/`）是应用的核心业务逻辑层，负责管理 WebSocket 连接、消息处理、数据库操作、存储等关键服务。

### 核心职责
- WebSocket 实时通讯管理
- 消息发送、接收、重试、离线处理
- SQLite 数据库连接和操作
- 本地存储管理（普通存储和安全存储）
- 加密服务
- WebRTC 信令处理
- 通知服务
- 数据迁移和备份

---

## 模块结构

### 核心服务列表

| 服务文件 | 职责描述 | 依赖 |
|---------|---------|------|
| `event_bus.dart` | 事件总线服务（服务间解耦通信） | event_bus, get |
| `websocket.dart` | WebSocket 连接管理 | MessageService, NetworkMonitorService |
| `message.dart` | 消息核心服务 | WebSocketService, MessageRepo |
| `message_actions.dart` | 消息操作处理 | MessageService |
| `message_s2c.dart` | 服务端到客户端消息 | MessageService |
| `message_offline.dart` | 离线消息处理 | MessageService |
| `message_retry.dart` | 消息重试机制 | MessageService |
| `message_webrtc.dart` | WebRTC 消息处理 | MessageService |
| `message_manage_service.dart` | 消息管理服务 | MessageService |
| `websocket_message_queue.dart` | WebSocket 消息队列 | PersistentMessageQueue |
| `sqlite.dart` | SQLite 数据库服务 | sqflite, synchronized |
| `cached_sqlite_service.dart` | SQLite 查询缓存 | SqliteService |
| `migration_service.dart` | 数据库迁移服务 | SqliteService |
| `storage.dart` | 本地存储服务 | shared_preferences |
| `storage_secure.dart` | 安全存储服务 | flutter_secure_storage |
| `secure_key_service.dart` | 安全密钥服务 | storage_secure |
| `secure_token_storage_service.dart` | Token 存储 | storage_secure |
| `encrypter.dart` | 加密解密服务 | pointycastle |
| `rsa.dart` | RSA 加密服务 | pointycastle |
| `ack_manager.dart` | ACK 确认管理 | WebSocketService |
| `network_monitor.dart` | 网络状态监控 | connectivity_plus |
| `notification.dart` | 通知服务 | flutter_local_notifications |
| `backup_service.dart` | 数据备份服务 | archive, path |
| `assets.dart` | 资源管理服务 | -
| `app_logger.dart` | 应用日志服务 | logger |
| `voice_playback_service.dart` | 语音播放服务（Riverpod StateNotifier） | just_audio |

---

## 入口与启动

### 服务初始化流程
服务初始化在 `lib/config/init.dart` 的 `AppInitializer.initialize()` 中进行：

```dart
// 初始化顺序
1. StorageService.init()              // 存储服务
2. UserRepoLocal.onInit()              // 用户仓库
3. NtpHelper.getOffset()               // NTP 时间
4. DeviceExt.did                       // 设备信息
5. HttpClient                          // HTTP 客户端
6. NetworkMonitorService               // 网络监控
7. VoicePlaybackService                // 语音播放（使用 voicePlaybackServiceProvider，无需手动初始化）
8. WebSocket 相关服务                   // WebSocket 服务群
```

### WebSocket 服务初始化
```dart
// 1. BottomNavigationLogic - 底部导航
// 2. PersistentMessageQueue - 消息队列
// 3. ConversationLogic - 会话逻辑
// 4. AckManager - ACK 管理器
// 5. MessageService - 消息服务
// 6. MessageActions - 消息操作
// 7. MessageWebrtc - WebRTC 消息
// 8. MessageOfflineService - 离线消息
// 9. MessageRetry - 消息重试
// 10. WebSocketService - WebSocket 连接
```

---

## 对外接口

### WebSocketService
```dart
// 获取服务实例
WebSocketService ws = WebSocketService.to;

// 连接状态
Rx<SocketStatus> status

// 连接/断开
await ws.openSocket(from: 'manual');
await ws.closeSocket();

// 发送消息
ws.send(msg);
```

### MessageService
```dart
// 获取服务实例
MessageService msgService = MessageService.to;

// 发送消息
await msgService.send(MessageModel message);

// 接收消息（通过事件总线）
eventBus.on<TypeMessage>().listen((msg) {
  // 处理消息
});
```

### SqliteService
```dart
// 获取服务实例
SqliteService db = SqliteService.to;

// 查询
List<Map> data = await db.query('table');

// 插入
await db.insert('table', {'key': 'value'});

// 更新
await db.update('table', {'key': 'new'}, where: 'id = ?', whereArgs: [1]);

// 删除
await db.delete('table', where: 'id = ?', whereArgs: [1]);

// 事务
await db.transaction((txn) async {
  // 批量操作
});
```

### StorageService
```dart
// 字符串存储
await StorageService.to.setString('key', 'value');
String? value = StorageService.to.getString('key');

// 布尔存储
await StorageService.to.setBool('key', true);
bool? value = StorageService.to.getBool('key');

// 整数存储
await StorageService.to.setInt('key', 123);
int? value = StorageService.to.getInt('key');

// 删除
await StorageService.to.remove('key');
```

### MigrationService
```dart
// 获取服务实例
MigrationService migration = MigrationService.to;

// 数据迁移
final result = await migration.migrate(
  db: database,
  fromVersion: 1,
  toVersion: 2,
  isUpgrade: true,
);

// 备份数据库
await migration.backupDatabase(snapshotName: 'backup_v1');

// 清理旧备份
final cleaned = await migration.cleanupOldSnapshots(
  maxAge: Duration(days: 7),
);
```

---

## 关键依赖与配置

### 外部依赖
- `sqflite: ^2.4.2` - SQLite 数据库
- `shared_preferences: ^2.5.4` - 键值对存储
- `flutter_secure_storage: ^10.0.0` - 安全存储
- `web_socket_channel: ^3.0.3` - WebSocket
- `dio: ^5.9.0` - HTTP 客户端
- `connectivity_plus: ^7.0.0` - 网络状态
- `synchronized: ^3.4.0` - 并发控制
- `pointycastle: ^4.0.0` - 加密库
- `logger: ^2.6.2` - 日志库

### 内部依赖
- `lib/store/` - 数据层
- `lib/component/` - 组件层

---

## 数据模型

### SocketStatus 枚举
```dart
enum SocketStatus {
  disconnected,  // 未连接
  connecting,    // 连接中
  connected,     // 已连接
  error,         // 错误
}
```

### MigrationResult
```dart
class MigrationResult {
  final bool success;
  final int fromVersion;
  final int toVersion;
  final String? error;
}
```

---

## 测试与质量

### 服务测试
- 使用 `Mock` 类进行单元测试
- 测试文件位于 `test/` 目录

### 质量标准
- 所有服务使用单例模式
- 支持并发控制和事务
- 完善的错误处理和日志记录

---

## 核心服务详解

### WebSocketService
WebSocket 连接管理服务，负责与服务端建立长连接。

**核心功能**：
- 自动重连机制
- 心跳保活
- 消息队列
- 离线消息拉取

**使用示例**：
```dart
// 监听连接状态
WebSocketService.to.status.listen((status) {
  print('WebSocket status: $status');
});

// 发送消息
WebSocketService.to.send(json.encode({
  'type': 'C2C',
  'payload': {'text': 'Hello'},
}));
```

### MessageService
消息核心服务，负责消息的发送、接收和处理。

**核心功能**：
- 消息发送（C2C、C2G、C2S、S2C）
- 消息接收和解析
- 消息状态更新
- 消息撤回
- 阅后即焚

**消息类型**：
- `C2C` - 客户端到客户端
- `C2G` - 客户端到群组
- `C2S` - 客户端到服务端
- `S2C` - 服务端到客户端

### VoicePlaybackService
语音播放服务，使用 Riverpod StateNotifier 管理音频播放状态。

**核心功能**：
- 播放本地音频文件
- 播放控制（播放、暂停、恢复、停止）
- 播放进度跟踪
- 播放完成回调
- 自动连播支持

**架构设计**：
- 使用 Riverpod Notifier 管理播放状态
- 状态包含：音频路径、消息ID、播放状态、暂停状态、播放位置、音频时长
- 支持响应式 UI 更新

**使用示例**：
```dart
// 在 ConsumerWidget 中监听播放状态
class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playbackState = ref.watch(voicePlaybackServiceProvider);

    return Column(
      children: [
        Text('播放状态: ${playbackState.isPlaying ? "播放中" : "未播放"}'),
        Text('进度: ${playbackState.currentPosition}/${playbackState.currentDuration}'),
        ElevatedButton(
          onPressed: () {
            ref.read(voicePlaybackServiceProvider.notifier).play(
              path: 'audio.mp3',
              messageId: 'msg123',
            );
          },
          child: Text('播放'),
        ),
      ],
    );
  }
}

// 在 Notifier 中使用
class ChatNotifier extends StateNotifier<ChatState> {
  ChatNotifier(this.ref) : super(ChatState());

  final Ref ref;

  Future<void> playVoiceMessage({
    required String voiceUrlOrPath,
    required String messageId,
    required int duration,
  }) async {
    await ref.read(voicePlaybackServiceProvider.notifier).play(
      path: voiceUrlOrPath,
      messageId: messageId,
      durationMs: duration,
    );
  }
}
```

### SqliteService
SQLite 数据库服务，提供统一的数据库操作接口。

**核心功能**：
- 数据库连接管理
- CRUD 操作封装
- 事务支持
- 并发控制
- 查询缓存

**数据库配置**：
- 版本：v9
- 模式：WAL（Write-Ahead Logging）
- 缓存大小：64MB

### MessageOfflineService
离线消息处理服务。

**核心功能**：
- 拉取离线消息
- 批量插入消息
- 会话列表同步
- 未读数计算

### AckManager
ACK 确认管理器。

**核心功能**：
- 消息送达确认
- 消息已读确认
- ACK 超时重试

### MessageRetry
消息重试服务。

**核心功能**：
- 失败消息自动重试
- 重试次数限制
- 指数退避策略

---

## 数据库迁移

### 迁移脚本
- 升级脚本：`assets/migrations/upgrade.sql`
- 降级脚本：`assets/migrations/downgrade.sql`

### 迁移流程
1. 检测版本差异
2. 创建数据库快照备份
3. 执行迁移脚本
4. 验证迁移结果
5. 清理旧备份

### 迁移示例
```dart
// 自动迁移（在 onUpgrade 回调中）
await MigrationService.to.migrate(
  db: db,
  fromVersion: oldVsn,
  toVersion: newVsn,
  isUpgrade: true,
);
```

---

## 加密服务

### EncrypterService
加密解密服务，提供 AES 加密。

```dart
// AES 加密
String encrypted = EncrypterService.aesEncrypt(
  plaintext,
  key,
  iv,
);

// AES 解密
String decrypted = EncrypterService.aesDecrypt(
  encrypted,
  key,
  iv,
);

// MD5 哈希
String hash = EncrypterService.md5(input);
```

### RSAService
RSA 加密服务。

```dart
// 生成密钥对
await RSAService.generateKeyPair();

// 公钥加密
String encrypted = RSAService.encryptByPublicKey(plaintext);

// 私钥解密
String decrypted = RSAService.decryptByPrivateKey(encrypted);
```

---

## 存储服务

### StorageService
普通键值对存储，基于 `shared_preferences`。

```dart
// 字符串
await StorageService.to.setString('key', 'value');

// 布尔
await StorageService.to.setBool('key', true);

// 整数
await StorageService.to.setInt('key', 123);

// 获取
String? value = StorageService.to.getString('key');
```

### SecureStorageService
安全存储服务，基于 `flutter_secure_storage`。

```dart
// 存储敏感信息
await SecureStorageService.to.setString('token', 'secret_token');

// 获取
String? token = await SecureStorageService.to.getString('token');
```

---

## 常见问题 (FAQ)

### Q: WebSocket 断线后如何重连？
A: `WebSocketService` 内置自动重连机制，断线后会自动尝试重连。

### Q: 消息发送失败如何处理？
A: 使用 `MessageRetry` 服务，失败消息会自动重试。

### Q: 数据库迁移失败如何恢复？
A: `MigrationService` 会自动创建备份，迁移失败可以恢复。

### Q: 如何查看服务日志？
A: 使用 `AppLogger` 或 `logger` 全局实例，日志会输出到控制台。

### Q: 如何备份数据库？
A: 使用 `MigrationService.to.backupDatabase()` 或 `BackupService`。

---

## 相关文件清单

### 核心服务
- `lib/service/websocket.dart` - WebSocket 服务
- `lib/service/message.dart` - 消息核心服务
- `lib/service/message_actions.dart` - 消息操作
- `lib/service/message_offline.dart` - 离线消息
- `lib/service/message_retry.dart` - 消息重试
- `lib/service/message_webrtc.dart` - WebRTC 消息
- `lib/service/sqlite.dart` - 数据库服务
- `lib/service/storage.dart` - 存储服务

### 辅助服务
- `lib/service/ack_manager.dart` - ACK 管理
- `lib/service/network_monitor.dart` - 网络监控
- `lib/service/encrypter.dart` - 加密服务
- `lib/service/migration_service.dart` - 迁移服务
- `lib/service/backup_service.dart` - 备份服务
- `lib/service/notification.dart` - 通知服务

---

## WebSocket API v2.0 消息格式

### C2C 消息格式（与服务端对接）

客户端发送给服务端的 WebSocket 消息必须遵循以下格式：

```dart
// WebSocket API v2.0 - C2C 消息格式
{
  'id': 'msg123',                    // String: 消息ID
  'type': 'C2C',                   // String: 消息类型
  'from': '1838294017982464',       // String: 发送者ID (TSID)
  'to': '1838294017982465',         // String: 接收者ID (TSID) ⚠️ 必须是 "to" 不是 "to_id"
  'msg_type': 'text',              // String: 消息类型 (text/image/file/e2ee等)
  'action': '',                    // String: 动作类型 (可选，通常为空)
  'e2ee': {},                      // Map: E2EE元数据 (可选, 加密消息时必须有，必须是 Map 不是 JSON 字符串)
  'payload': '{...}',              // String|Map: 消息内容（加密时为 base64 密文字符串）
  'created_at': 1768957192053,      // int: 创建时间戳(毫秒)
}
```

### 关键字段说明

| 字段 | 类型 | 说明 | 服务端对应 |
|------|------|------|-----------|
| `to` | **String** | 接收者ID (如 `"1838294017982465"`) | `<<"to">>` (binary) |
| `to_id` | **int** | ❌ 不要使用！这是数据库字段 | 服务端解码后的 `ToId` (integer) |
| `from` | String | 发送者ID (TSID) | `<<"from">>` |
| `e2ee` | **Map** | E2EE 元数据，必须是 Map 不能是 JSON 字符串 | `<<"e2ee">>` (map) |
| `payload` | String|Map | 消息内容 | `<<"payload">>` |

### 服务端字段类型映射

| Dart 类型 | Erlang 类型 | 说明 |
|-----------|-------------|------|
| `String` | `binary()` | 字符串在 Erlang 中是 binary 类型 |
| `int` | `integer()` | 整数在 Erlang 中是 integer 类型 |
| `Map` | `map()` | Map 在 Erlang 中是 map 类型 |

**重要**：
- 客户端发送 `to` (String) → 服务端接收为 `<<"to">>` (binary)
- 服务端直接将 `To` 转换为整数 → 得到 `ToId` (integer)
- 数据库存储的是 `to_id` (integer)

### E2EE 加密消息格式

当消息需要端到端加密时（通过 `e2ee` 字段存在判断）：

```dart
// WebSocket API v2.0: msg_type 保留原始内容类型，e2ee 字段独立存在
'msg_type': 'text',  // 保留原始消息类型（text, image, video 等）
'e2ee': {  // Map 类型，不能是 JSON 字符串
  'e2ee': true,
  'e2ee_ver': 1,
  'e2ee_suite': 'RSA-OAEP-256+AES-256-GCM',
  'iv': 'base64_encoded_iv',
  'ct': 'base64_encoded_ciphertext',
  'recipients': [
    {
      'did': 'device-id',
      'kid': 'device-id',
      'ek': 'base64_encoded_encrypted_key'
    }
  ],
  'sig': 'base64_signature'
}

// payload 是密文字符串：base64(iv) + '.' + base64(ciphertext)
'payload': 'ODdcmdLuZ7v9enKf./mSJ0ivbNR9y7LFzc3dmsE/2Mq9SGL8YWZ0az+...'
```

**重要变更**（v2.0 架构）：
- ❌ **不再**使用 `msg_type = 'e2ee'` 来标识加密消息
- ✅ **保留**原始消息的 `msg_type`（text, image, video 等）
- ✅ **通过** `e2ee` 字段是否存在判断是否为加密消息

### 常见错误

#### 错误1: {badkey,<<"to">>}

**服务端错误**：
```
{json_message_error, error, {badkey,<<"to">>}, ...}
```

**原因**: 客户端发送了 `to_id` 而不是 `to`

**解决方案**:
```dart
// ❌ 错误
{'to_id': 'gdwqa5'}

// ✅ 正确
{'to': '1838294017982465'}
```

#### 错误2: e2ee 字段是 JSON 字符串

**服务端接收到的**：
```erlang
<<"e2ee">> => <<"{\"e2ee\":true,...}">>  % JSON 字符串 ❌
```

**期望应该是**：
```erlang
<<"e2ee">> => #{<<"e2ee">> => true, ...}  % Map ✅
```

**原因**: 客户端使用了 `json.encode(e2eeMap)`

**解决方案**:
```dart
// ❌ 错误：e2ee 变成 JSON 字符串
'e2ee': json.encode(e2eeMap)

// ✅ 正确：直接发送 Map
'e2ee': e2eeMap  // Dart WebSocket 库会自动编码为 Erlang Map
```

### 发送消息示例

```dart
// 在 chat_provider.dart 中
Map<String, dynamic> msg = {
  'id': obj.id,
  'type': obj.type,  // 'C2C' 或 'C2G'
  'from': obj.fromId,
  'to': obj.toId,  // ⚠️ 注意：是 'to' 不是 'to_id'
  'msg_type': msgType,
  'action': action,
  'e2ee': e2ee,  // Map 类型，不要 json.encode()
  'payload': finalPayload,
  'created_at': obj.createdAt,
};

// 通过 WebSocket 发送
AppEventBus.fire(
  WebSocketMessageSendRequestEvent(
    message: json.encode(msg),  // 整个消息编码为 JSON 字符串
    messageId: msg['id'],
  ),
);
```

---

**相关文档**
- [数据层文档](../store/CLAUDE.md)
- [页面层文档](../page/CLAUDE.md)
- [配置文档](../config/CLAUDE.md)

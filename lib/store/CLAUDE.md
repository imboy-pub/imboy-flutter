# 数据层 (Store Layer)

[根目录](../../CLAUDE.md) > [lib](../) > **store**

## 目录结构

| 子模块 | 职责 | 数量（2026-09-30 实测） |
|-------|------|------|
| `model/` | 数据模型（toJson/fromJson） | 34 |
| `repository/` | 本地数据仓库（SQLite） | 20 |
| `api/` | 远程 HTTP API 客户端 | 45 |

## 模型清单（model/）

| 模型文件 | 关键字段 |
|---------|---------|
| `message_model.dart` | id, type(C2C/C2G/C2S/S2C), fromId, toId, payload, createdAt, status, conversationUk3, topicId, isAuthor |
| `conversation_model.dart` | id, peerId, avatar, title, subtitle, type, msgType, lastMsgId, lastTime, unreadNum, payload, isShow |
| `user_model.dart` | userId, nickname, avatar, region, sign, gender, createdAt |
| `contact_model.dart` | id, uid, nickname, avatar, remark, isDeleted, isBlocklist, createdAt |
| `group_model.dart` | id, title, avatar, introduction, memberCount, ownerId, createdAt |
| `group_member_model.dart` | - |
| `new_friend_model.dart` | - |
| `user_tag_model.dart` | - |
| `denylist_model.dart` | - |
| `user_device_model.dart` | - |
| `user_collect_model.dart` | - |
| `feedback_model.dart` | - |
| `channel_model.dart` | - |
| `channel_message_model.dart` | - |
| `channel_comment_model.dart` | - |
| `channel_order_model.dart` | - |
| `channel_stats_model.dart` | - |
| `channel_subscription_model.dart` | - |
| `live_room_model.dart` | - |
| `moment_notify_model.dart` | - |
| `people_model.dart` | - |
| `project_model.dart` / `project_w2_model.dart` | - |
| `red_packet_model.dart` | - |
| `workspace_model.dart` | - |
| `webrtc_signaling_model.dart` | - |
| `app_version_model.dart` | - |
| `feedback_reply_model.dart` | - |

辅助/列定义文件：`message_columns.dart`、`group_member_columns.dart`、`moment_notify_columns.dart`、`model_parse_utils.dart`、`entity_image.dart`、`entity_video.dart`。

## Repository 清单（repository/）

| Repository | 关键方法 |
|-----------|---------|
| `user_repo_local.dart` | currentUid, currentUser, setting, accessToken, isLoggedIn, updateUser, updateSetting |
| `message_repo_sqlite.dart` | insert, update, find, pageForConversation, page(kwd) |
| `conversation_repo_sqlite.dart` | insert, updateById, findById, findByPeerId, page, delete, deleteByPeerId |
| `contact_repo_sqlite.dart` | insert, updateById, findById, findByUid, all |
| `group_repo_sqlite.dart` | insert, updateById, findById, findByGroupId, pageByUser |
| `group_member_repo_sqlite.dart` | - |
| `user_tag_repo_sqlite.dart` | - |
| `new_friend_repo_sqlite.dart` | - |
| `user_device_repo_sqlite.dart` | - |
| `user_denylist_repo_sqlite.dart` | - |
| `user_collect_repo_sqlite.dart` | - |
| `channel_repo_sqlite.dart` | - |
| `channel_message_repo_sqlite.dart` | - |
| `channel_message_outbox_repo.dart` | - |
| `channel_publish_outbox_repo.dart` | - |
| `mention_frequency_repo.dart` | - |
| `message_fts_repo.dart` | - |
| `moment_notify_repo_sqlite.dart` | - |

辅助文件：`message_repo_types.dart`（类型定义）、`user_repo_provider.dart`。

## API 清单（api/）

| Api 文件 | 关键方法 |
|---------|---------|
| `user_api.dart` | refreshAccessTokenApi, changeEmail, changePassword, userSearch |
| `contact_api.dart` | listFriend, syncByUid, changeRemark, deleteContact |
| `group_api.dart` | page, detail, groupAdd, groupEdit |
| `msg_api.dart` | history(chatType, peerId, afterSeq, limit) — conv_seq游标分页 |
| `conversation_api.dart` | - |
| `group_member_api.dart` | - |
| `denylist_api.dart` | - |
| `user_tag_api.dart` | - |
| `feedback_api.dart` | - |
| `location_api.dart` | - |
| `user_device_api.dart` | - |
| `user_collect_api.dart` | - |
| `app_version_api.dart` | - |
| `attachment_api.dart` | - |
| `e2ee_api.dart` | - |
| `e2ee_backup_api.dart` | - |
| `olm_api.dart` | - |
| `channel_api.dart` | - |
| `channel_order_api.dart` | - |
| `moment_api.dart` | - |
| `mention_api.dart` | - |
| `fts_api.dart` | - |
| `wallet_api.dart` | - |
| `billing_api.dart` | - |
| `workspace_api.dart` | - |
| `project_api.dart` | - |
| `project_channel_api.dart` | - |
| `project_member_api.dart` | - |
| `project_milestone_api.dart` | - |
| `live_room_api.dart` | - |
| `rtc_room_api.dart` | - |
| `push_api.dart` | - |
| `report_api.dart` | - |
| `appeal_api.dart` | - |
| `agent_api.dart` | - |
| `agent_task_api.dart` | - |
| `group_album_api.dart` | - |
| `group_category_api.dart` | - |
| `group_discovery_api.dart` | - |
| `group_file_api.dart` | - |
| `group_schedule_api.dart` | - |
| `group_tag_api.dart` | - |
| `group_task_api.dart` | - |
| `group_vote_api.dart` | - |
| `app_upgrade_log_api.dart` | - |

## 核心 API 签名

### UserRepoLocal
```dart
UserRepoLocal repo = UserRepoLocal.to;
String currentUid = repo.currentUid;
UserModel? currentUser = repo.currentUser;
String? accessToken = await repo.accessToken;
bool isLoggedIn = repo.isLoggedIn;
await repo.updateUser(userModel);
await repo.updateSetting(newSetting);
```

### MessageRepo
```dart
// 表名常量: c2cTable='message', c2gTable='group_message', c2sTable='c2s_message', s2cTable='s2c_message'
MessageRepo msgRepo = MessageRepo(tableName: 'message');
await msgRepo.insert(message);
await msgRepo.update(data);
MessageModel? msg = await msgRepo.find(messageId);
List<MessageModel> msgs = await msgRepo.pageForConversation(uk3, nextAutoId, size);
List<MessageModel> results = await msgRepo.page(page: 1, size: 20, kwd: 'kw', conversationUk3: uk3);
```

### ConversationRepo
```dart
ConversationRepo convRepo = ConversationRepo();
int id = await convRepo.insert(conversation);
await convRepo.updateById(id, data);
ConversationModel? conv = await convRepo.findByPeerId(type, peerId);
List<ConversationModel> list = await convRepo.page(page: 1, size: 20);
await convRepo.deleteByPeerId(type, peerId);
```

### MsgApi（需后端 msg_archive_enabled=true）
```dart
MsgApi api = MsgApi();
Map<String, dynamic>? result = await api.history(
  chatType: 'c2c',    // 'c2c' | 'c2g'
  peerId: encodedUid,
  afterSeq: 0,        // 上次 next_seq，0=从头
  limit: 50,          // 最大 100
);
// result: { "messages":[...], "next_seq":42, "has_more":true, "conv_key":"c2c:1:2" }
// ChatNotifier 封装了 loadHistory() / resetHistoryCursor()
// 状态跟踪：ChatState.lastHistorySeq / ChatState.historyHasMore
```

### IMBoyHttpResponse（统一响应）
```dart
class IMBoyHttpResponse {
  final bool ok;
  final int code;
  final String? msg;
  final dynamic payload;
  bool get success => ok && code == 200;
}
```

## Repository 设计模式
```dart
class ExampleRepo {
  final SqliteService _db = SqliteService.to;
  final String tableName = 'example';
  Future<int> insert(ExampleModel model) async { ... }
  Future<List<ExampleModel>> page({int page, int size}) async { ... }
  Future<ExampleModel?> find(String id) async { ... }
  Future<int> delete(String id) async { ... }
}
```

## 外部依赖
`sqflite_sqlcipher ^3.4.0`（替代 sqflite，配 `sqflite_common_ffi`） · `dio ^5.11.1`

**内部依赖**：`lib/service/sqlite.dart` · `lib/component/http/http_client.dart` · `lib/config/init.dart`

**相关文档**：[服务层](../service/CLAUDE.md) · [页面层](../page/CLAUDE.md) · [组件层](../component/CLAUDE.md)

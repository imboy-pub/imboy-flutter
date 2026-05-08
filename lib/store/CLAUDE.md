# 数据层 (Store Layer)

[根目录](../../CLAUDE.md) > [lib](../) > **store**

## 目录结构

| 子模块 | 职责 | 数量 |
|-------|------|------|
| `model/` | 数据模型（toJson/fromJson） | 18+ |
| `repository/` | 本地数据仓库（SQLite） | 11+ |
| `api/` | 远程 HTTP API 客户端 | 15+ |

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

## API 清单（api/）

| Api 文件 | 关键方法 |
|---------|---------|
| `user_api.dart` | refreshAccessTokenApi, changeEmail, changePassword, userSearch |
| `contact_api.dart` | listFriend, syncByUid, changeRemark, deleteContact |
| `group_api.dart` | page, detail, groupAdd, groupEdit |
| `msg_api.dart` | history(chatType, peerId, afterSeq, limit) — conv_seq游标分页 |
| `auth_api.dart` | - |
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
`sqflite ^2.4.2` · `dio ^5.9.0` · `get ^5.0.0`

**内部依赖**：`lib/service/sqlite.dart` · `lib/component/http/http_client.dart` · `lib/config/init.dart`

**相关文档**：[服务层](../service/CLAUDE.md) · [页面层](../page/CLAUDE.md) · [组件层](../component/CLAUDE.md)

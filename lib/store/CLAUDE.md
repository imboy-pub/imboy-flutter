# 数据层 (Store Layer) 文档

[根目录](../../CLAUDE.md) > [lib](../) > **store**

> 最后更新：2026-01-05 14:12:27 CST

---

## 变更记录 (Changelog)

### 2026-01-05
- 初始化数据层文档
- 完成模块结构分析

---

## 模块职责

数据层（`lib/store/`）负责应用的数据管理，包括数据模型定义、数据仓库（Repository）、API 提供者（Provider）三部分。

### 核心职责
- 数据模型（Model）定义
- 本地数据存储和查询（Repository）
- 远程 API 调用（Provider）
- 数据缓存和同步

---

## 模块结构

### 主要子模块

| 子模块 | 职责描述 | 文件数量 |
|-------|---------|---------|
| `model/` | 数据模型定义 | 18+ 个模型 |
| `repository/` | 数据仓库（SQLite） | 11+ 个仓库 |
| `provider/` | API 提供者（HTTP） | 13+ 个提供者 |

---

## 入口与启动

### Repository 导入示例
```dart
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
```

### Provider 导入示例
```dart
import 'package:imboy/store/provider/user_provider.dart';
import 'package:imboy/store/provider/contact_provider.dart';
import 'package:imboy/store/provider/group_provider.dart';
```

---

## 对外接口

### Repository 接口

#### UserRepoLocal（用户仓库）
```dart
// 获取实例
UserRepoLocal userRepo = UserRepoLocal.to;

// 当前用户信息
String currentUid = userRepo.currentUid;
UserModel? currentUser = userRepo.currentUser;
UserSetting setting = userRepo.setting;

// Token 管理
String? accessToken = await userRepo.accessToken;
String? refreshToken = await userRepo.refreshToken;

// 登录状态
bool isLoggedIn = userRepo.isLoggedIn;

// 用户操作
await userRepo.updateUser(userModel);
await userRepo.updateSetting(newSetting);
```

#### MessageRepo（消息仓库）
```dart
// 创建实例
MessageRepo msgRepo = MessageRepo(tableName: 'message');

// 插入消息
await msgRepo.insert(message);

// 更新消息
await msgRepo.update(data);

// 分页查询
List<MessageModel> messages = await msgRepo.pageForConversation(
  uk3,
  nextAutoId,
  size,
);

// 搜索消息
List<MessageModel> results = await msgRepo.page(
  page: 1,
  size: 20,
  kwd: 'keyword',
  conversationUk3: uk3,
);

// 查找单条消息
MessageModel? msg = await msgRepo.find(messageId);
```

#### ConversationRepo（会话仓库）
```dart
// 创建实例
ConversationRepo convRepo = ConversationRepo();

// 插入会话
int id = await convRepo.insert(conversation);

// 更新会话
await convRepo.updateById(id, data);

// 查找会话
ConversationModel? conv = await convRepo.findById(id);
ConversationModel? conv = await convRepo.findByPeerId(type, peerId);

// 分页查询
List<ConversationModel> list = await convRepo.page(
  page: 1,
  size: 20,
);

// 删除会话
await convRepo.delete(id);
await convRepo.deleteByPeerId(type, peerId);
```

#### ContactRepo（联系人仓库）
```dart
// 创建实例
ContactRepo contactRepo = ContactRepo();

// 插入联系人
int id = await contactRepo.insert(contact);

// 更新联系人
await contactRepo.updateById(id, data);

// 查找联系人
ContactModel? contact = await contactRepo.findById(id);
ContactModel? contact = await contactRepo.findByUid(uid);

// 获取所有联系人
List<ContactModel> contacts = await contactRepo.all();
```

#### GroupRepo（群组仓库）
```dart
// 创建实例
GroupRepo groupRepo = GroupRepo();

// 插入群组
int id = await groupRepo.insert(group);

// 更新群组
await groupRepo.updateById(id, data);

// 查找群组
GroupModel? group = await groupRepo.findById(id);
GroupModel? group = await groupRepo.findByGroupId(groupId);

// 获取用户的群组列表
List<GroupModel> groups = await groupRepo.pageByUser(uid);
```

### Provider 接口

#### UserProvider（用户 API）
```dart
// 创建实例
UserProvider provider = UserProvider();

// 登录
IMBoyHttpResponse response = await provider.loginApi(
  username,
  password,
);

// 注册
IMBoyHttpResponse response = await provider.signUpApi(data);

// 刷新 Token
IMBoyHttpResponse response = await provider.refreshAccessTokenApi(
  refreshToken,
);

// 获取用户信息
IMBoyHttpResponse response = await provider.userInfoApi(userId);
```

#### ContactProvider（联系人 API）
```dart
// 创建实例
ContactProvider provider = ContactProvider();

// 搜索用户
IMBoyHttpResponse response = await provider.searchUserApi(keyword);

// 添加好友
IMBoyHttpResponse response = await provider.addFriendApi(userId);

// 删除好友
IMBoyHttpResponse response = await provider.deleteFriendApi(userId);

// 获取好友列表
IMBoyHttpResponse response = await provider.contactListApi();
```

#### GroupProvider（群组 API）
```dart
// 创建实例
GroupProvider provider = GroupProvider();

// 创建群组
IMBoyHttpResponse response = await provider.createGroupApi(data);

// 加入群组
IMBoyHttpResponse response = await provider.joinGroupApi(groupId);

// 退出群组
IMBoyHttpResponse response = await provider.leaveGroupApi(groupId);

// 获取群组成员
IMBoyHttpResponse response = await provider.groupMembersApi(groupId);
```

---

## 关键依赖与配置

### 外部依赖
- `sqflite: ^2.4.2` - SQLite 数据库
- `dio: ^5.9.0` - HTTP 客户端
- `get: ^5.0.0` - 状态管理

### 内部依赖
- `lib/service/sqlite.dart` - 数据库服务
- `lib/component/http/http_client.dart` - HTTP 客户端
- `lib/config/init.dart` - 全局配置

---

## 数据模型

### 核心数据模型

#### MessageModel（消息模型）
```dart
class MessageModel {
  final String id;              // 消息 ID
  final String type;            // 消息类型 (C2C, C2G, C2S, S2C)
  final String fromId;          // 发送者 ID
  final String toId;            // 接收者 ID
  final Map<String, dynamic> payload;  // 消息负载
  final int createdAt;          // 创建时间
  final int isAuthor;           // 是否为发送者
  final int status;             // 消息状态
  final String conversationUk3; // 会话 UK3
  final int topicId;            // 话题 ID

  // toJson, fromJson 等序列化方法
}
```

#### ConversationModel（会话模型）
```dart
class ConversationModel {
  final int id;                  // 自增 ID
  final String peerId;           // 对方 ID
  final String avatar;           // 头像
  final String title;            // 标题
  final String subtitle;         // 副标题（最后消息预览）
  final String type;             // 类型 (C2C, C2G)
  final String msgType;          // 最后消息类型
  final String lastMsgId;        // 最后消息 ID
  final int lastTime;            // 最后消息时间
  final int unreadNum;           // 未读数
  final Map<String, dynamic> payload;  // 扩展数据
  final int isShow;              // 是否显示

  // toJson, fromJson, uk3 getter 等方法
}
```

#### UserModel（用户模型）
```dart
class UserModel {
  final String userId;           // 用户 ID
  final String nickname;         // 昵称
  final String avatar;           // 头像
  final String? region;          // 地区
  final String? sign;            // 签名
  final int gender;              // 性别
  final int createdAt;           // 注册时间

  // toJson, fromJson 等方法
}
```

#### ContactModel（联系人模型）
```dart
class ContactModel {
  final int id;                  // 自增 ID
  final String uid;              // 用户 ID
  final String nickname;         // 昵称
  final String avatar;           // 头像
  final String? remark;          // 备注
  final int isDeleted;           // 是否删除
  final int isBlocklist;         // 是否在黑名单
  final int createdAt;           // 添加时间

  // toJson, fromJson 等方法
}
```

#### GroupModel（群组模型）
```dart
class GroupModel {
  final String id;               // 群组 ID
  final String title;            // 群名称
  final String? avatar;          // 群头像
  final String? introduction;    // 群简介
  final int memberCount;         // 成员数
  final String ownerId;          // 群主 ID
  final int createdAt;           // 创建时间

  // toJson, fromJson 等方法
}
```

---

## 测试与质量

### 数据层测试
- 模型序列化测试
- Repository CRUD 测试
- Provider API Mock 测试

### 质量标准
- 所有模型支持 `toJson`/`fromJson`
- Repository 使用事务保证数据一致性
- Provider 统一错误处理

---

## Repository 设计模式

### 基础结构
```dart
class ExampleRepo {
  final SqliteService _db = SqliteService.to;
  final String tableName = 'example';

  // CRUD 操作
  Future<int> insert(ExampleModel model) async { }
  Future<int> update(Map<String, dynamic> data) async { }
  Future<List<ExampleModel>> page({page, size}) async { }
  Future<ExampleModel?> find(String id) async { }
  Future<int> delete(String id) async { }
}
```

### 表字段常量
```dart
class MessageRepo {
  static const c2cTable = 'message';
  static const c2gTable = 'group_message';
  static const c2sTable = 'c2s_message';
  static const s2cTable = 's2c_message';

  static const id = 'id';
  static const type = 'type';
  static const from = 'from_id';
  static const to = 'to_id';
  // ...
}
```

---

## Provider 设计模式

### 基础结构
```dart
class ExampleProvider {
  // API 方法
  Future<IMBoyHttpResponse> exampleApi(
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await HttpClient.client.post(
        '/api/example',
        data: data,
      );
      return response;
    } catch (e) {
      return IMBoyHttpResponse.error(e.toString());
    }
  }
}
```

### 统一响应处理
```dart
class IMBoyHttpResponse {
  final bool ok;           // 是否成功
  final int code;          // 状态码
  final String? msg;       // 消息
  final dynamic payload;   // 数据负载

  // 判断成功
  bool get success => ok && code == 200;
}
```

---

## 常见问题 (FAQ)

### Q: 如何添加新的数据模型？
A: 在 `lib/store/model/` 下创建新模型类，实现 `toJson`/`fromJson` 方法。

### Q: 如何创建新的 Repository？
A: 在 `lib/store/repository/` 下创建新的仓库类，继承基础 CRUD 模式。

### Q: 如何调用新的 API？
A: 在 `lib/store/provider/` 下创建新的 Provider 类，使用 `HttpClient` 发送请求。

### Q: 如何处理数据库迁移？
A: 在 `lib/service/migration_service.dart` 中添加迁移逻辑。

---

## 相关文件清单

### 数据模型（Model）
- `lib/store/model/message_model.dart` - 消息模型
- `lib/store/model/conversation_model.dart` - 会话模型
- `lib/store/model/user_model.dart` - 用户模型
- `lib/store/model/contact_model.dart` - 联系人模型
- `lib/store/model/group_model.dart` - 群组模型
- `lib/store/model/group_member_model.dart` - 群成员模型
- `lib/store/model/new_friend_model.dart` - 新朋友模型
- `lib/store/model/user_tag_model.dart` - 用户标签模型
- `lib/store/model/denylist_model.dart` - 黑名单模型
- `lib/store/model/user_device_model.dart` - 用户设备模型
- `lib/store/model/user_collect_model.dart` - 收藏模型
- `lib/store/model/feedback_model.dart` - 反馈模型

### 数据仓库（Repository）
- `lib/store/repository/user_repo_local.dart` - 用户仓库
- `lib/store/repository/message_repo_sqlite.dart` - 消息仓库
- `lib/store/repository/conversation_repo_sqlite.dart` - 会话仓库
- `lib/store/repository/contact_repo_sqlite.dart` - 联系人仓库
- `lib/store/repository/group_repo_sqlite.dart` - 群组仓库
- `lib/store/repository/group_member_repo_sqlite.dart` - 群成员仓库
- `lib/store/repository/user_tag_repo_sqlite.dart` - 用户标签仓库
- `lib/store/repository/new_friend_repo_sqlite.dart` - 新朋友仓库
- `lib/store/repository/user_device_repo_sqlite.dart` - 用户设备仓库
- `lib/store/repository/user_denylist_repo_sqlite.dart` - 黑名单仓库
- `lib/store/repository/user_collect_repo_sqlite.dart` - 收藏仓库

### API 提供者（Provider）
- `lib/store/provider/user_provider.dart` - 用户 API
- `lib/store/provider/contact_provider.dart` - 联系人 API
- `lib/store/provider/group_provider.dart` - 群组 API
- `lib/store/provider/group_member_provider.dart` - 群成员 API
- `lib/store/provider/auth_provider.dart` - 认证 API
- `lib/store/provider/denylist_provider.dart` - 黑名单 API
- `lib/store/provider/user_tag_provider.dart` - 用户标签 API
- `lib/store/provider/feedback_provider.dart` - 反馈 API
- `lib/store/provider/location_provider.dart` - 位置 API
- `lib/store/provider/user_device_provider.dart` - 用户设备 API
- `lib/store/provider/user_collect_provider.dart` - 收藏 API
- `lib/store/provider/app_version_provider.dart` - 应用版本 API
- `lib/store/provider/attachment_provider.dart` - 附件 API

---

**相关文档**
- [服务层文档](../service/CLAUDE.md)
- [页面层文档](../page/CLAUDE.md)
- [组件层文档](../component/CLAUDE.md)

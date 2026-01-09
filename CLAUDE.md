# ImBoy App - 架构文档

> 本文档由 init-architect 自动生成和维护
> 最后更新：2026-01-01 12:00:00 CST

---

## 变更记录 (Changelog)

### 2026-01-01
- 完善架构文档，更新技术栈信息
- 补充数据库架构和消息系统详细信息
- 更新国际化和主题系统说明
- 增加常见问题解答

### 2026-01-05
- 初始化架构文档
- 完成模块结构分析和文档生成
- 创建 Mermaid 架构图和模块索引

---

## 项目愿景

ImBoy 是一个基于 Flutter 开发的跨平台即时通讯（IM）应用，提供完整的聊天、群组、联系人管理等功能。项目采用现代化的架构设计，支持多端部署（iOS、Android、macOS）。

### 核心特性
- 实时消息通讯（C2C、C2G、S2C）
- 群组管理和面对面建群
- 联系人和好友管理
- 用户标签和分类
- WebRTC 音视频通话
- 多媒体消息（文本、图片、视频、音频、位置、文件）
- 本地数据库持久化（SQLite）
- 主题系统（亮色/暗色模式）
- 国际化支持

---

## 架构总览

### 技术栈
- **前端框架**：Flutter (Dart 3.8+)
- **状态管理**：GetX 5.0
- **本地数据库**：SQLite (sqflite 2.4+)
- **网络请求**：Dio 5.9
- **实时通讯**：WebSocket + WebRTC
- **依赖注入**：GetX 依赖注入系统

### 设计模式
- **架构模式**：MVVM + Repository 模式
- **路由管理**：GetX 路由
- **数据持久化**：Repository + SQLite
- **消息队列**：持久化队列 + 事件总线

---

## 模块结构图

```mermaid
graph TD
    Root["(根) ImBoy App"] --> lib["lib/"]
    lib --> page["page/ - 页面层"]
    lib --> component["component/ - 组件层"]
    lib --> service["service/ - 服务层"]
    lib --> store["store/ - 数据层"]
    lib --> theme["theme/ - 主题系统"]
    lib --> config["config/ - 配置"]
    lib --> utils["utils/ - 工具类"]

    page --> chat["chat/ - 聊天模块"]
    page --> contact["contact/ - 联系人模块"]
    page --> group["group/ - 群组模块"]
    page --> mine["mine/ - 我的模块"]
    page --> conversation["conversation/ - 会话列表"]
    page --> passport["passport/ - 登录注册"]
    page --> personal_info["personal_info/ - 个人信息"]

    component --> ui["ui/ - 通用UI组件"]
    component --> chat_comp["chat/ - 聊天组件"]
    component --> helper["helper/ - 辅助工具"]
    component --> http["http/ - 网络请求"]

    service --> websocket["websocket.dart - WebSocket服务"]
    service --> message["message*.dart - 消息服务"]
    service --> sqlite["sqlite.dart - 数据库服务"]
    service --> storage["storage*.dart - 存储服务"]

    store --> repository["repository/ - 数据仓库"]
    store --> provider["provider/ - API提供者"]
    store --> model["model/ - 数据模型"]

    click page "./lib/page/CLAUDE.md" "查看页面层文档"
    click component "./lib/component/CLAUDE.md" "查看组件层文档"
    click service "./lib/service/CLAUDE.md" "查看服务层文档"
    click store "./lib/store/CLAUDE.md" "查看数据层文档"
    click theme "./lib/theme/CLAUDE.md" "查看主题系统文档"

    Root --> assets["assets/ - 资源文件"]
    Root --> test["test/ - 测试文件"]
    Root --> plugin["plugin/ - 插件源码"]
</mermaid>

---

## 模块索引

| 模块路径 | 职责描述 | 文档链接 |
|---------|---------|---------|
| `lib/page/` | 所有页面视图和路由 | [查看详情](./lib/page/CLAUDE.md) |
| `lib/component/` | 可复用组件和工具类 | [查看详情](./lib/component/CLAUDE.md) |
| `lib/service/` | 核心业务服务（WebSocket、消息、数据库） | [查看详情](./lib/service/CLAUDE.md) |
| `lib/store/` | 数据层（Repository、Provider、Model） | [查看详情](./lib/store/CLAUDE.md) |
| `lib/theme/` | 主题管理和样式系统 | [查看详情](./lib/theme/CLAUDE.md) |
| `lib/config/` | 应用配置和初始化 | - |
| `lib/utils/` | 通用工具类和辅助函数 | - |

---

## 运行与开发

### 环境要求
- Flutter SDK 3.8.0+
- Dart SDK 3.8.0+
- Xcode（iOS 开发）或 Android Studio（Android 开发）

### 常用命令

```bash
# 获取依赖
flutter pub get

# 运行开发版本
flutter run

# 构建生产版本
flutter build apk
flutter build ios

# 运行测试
flutter test

# 代码生成
flutter pub run build_runner build
```

### 环境配置
- 开发环境：`lib/config/env_dev.dart`
- 生产环境：`lib/config/env_pro.dart`
- 本地环境：`lib/config/env_local.dart`

通过 `main.dart` 中的 `env` 参数切换环境。

---

## 测试策略

### 测试目录结构
- `test/` - 单元测试和集成测试
- `test/async_test.dart` - 异步测试
- `test/hidden_phone_test.dart` - 手机号隐藏测试
- `test/is_phone_test.dart` - 手机号验证测试

### 测试工具
- `flutter_test` - Flutter 官方测试框架
- `build_runner` - 代码生成工具

---

## 编码规范

### GetX 架构规范
每个功能模块遵循 GetX 的四层架构：
- **View**（`*_view.dart`）- UI 视图层
- **Logic**（`*_logic.dart`）- 业务逻辑层
- **State**（`*_state.dart`）- 状态管理层
- **Binding**（`*_binding.dart`）- 依赖注入层

### 文件命名规范
- 页面文件：`<module>_<name>_view.dart`
- 逻辑文件：`<module>_<name>_logic.dart`
- 状态文件：`<module>_<name>_state.dart`
- 绑定文件：`<module>_<name>_binding.dart`

### 时间处理规范
**重要**：项目中所有获取时间点、格式化时间、计算时间差等操作，**必须统一使用 `DateTimeHelper` 工具类**，禁止直接使用 `DateTime.now()` 或其他时间处理方式。

**原因**：
- 统一时间处理逻辑，避免时区问题
- 便于维护和修改时间显示格式
- 支持国际化时间格式
- 确保时间显示的一致性

**正确示例**：
```dart
// ✅ 使用 DateTimeHelper
String timeStr = DateTimeHelper.lastTimeFmt(timestamp);
String fullTime = DateTimeHelper.fmt(timestamp);
```

**错误示例**：
```dart
// ❌ 直接使用 DateTime
String timeStr = DateTime.now().toString();
String timeStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
```

**DateTimeHelper 常用方法**：
- `lastTimeFmt(timestamp)` - 格式化为"刚刚"、"5分钟前"等相对时间
- `fmt(timestamp)` - 标准时间格式化
- `getTimestamp()` - 获取当前时间戳
- 其他方法请参考 `lib/component/helper/func.dart` 中的 `DateTimeHelper` 类

### 代码风格
- 遵循 [Flutter 官方代码规范](https://dart.dev/guides/language/effective-dart)
- 使用 `flutter_lints` 进行代码检查
- 建议使用 VS Code 或 Android Studio 配合 Flutter 插件开发

---

## AI 使用指引

### 适合 AI 辅助的任务
1. **新增页面/功能**：基于现有模式创建新的页面模块
2. **UI 组件开发**：参考 `lib/component/ui/` 下的通用组件
3. **数据模型扩展**：在 `lib/store/model/` 添加新的数据模型
4. **API 集成**：在 `lib/store/provider/` 添加新的 API 接口
5. **消息类型扩展**：参考 `lib/component/chat/` 添加新的消息类型

### 关键上下文文件
在执行 AI 辅助开发时，建议优先提供以下文件：
- `lib/config/init.dart` - 应用初始化流程
- `lib/config/routes.dart` - 路由配置
- `lib/page/pages.dart` - 页面注册
- `lib/service/sqlite.dart` - 数据库服务
- `lib/service/websocket.dart` - WebSocket 服务
- `lib/store/repository/message_repo_sqlite.dart` - 消息数据仓库示例

### 典型开发流程
1. 在 `lib/page/<module>/` 创建页面（View、Logic、State、Binding）
2. 在 `lib/store/model/` 创建数据模型
3. 在 `lib/store/repository/` 创建数据仓库
4. 在 `lib/store/provider/` 创建 API 提供者
5. 在 `lib/page/pages.dart` 注册路由
6. 在对应的 Logic 中集成业务逻辑

---

## 依赖管理

### 核心依赖
- `get: ^5.0.0-release-candidate-9.3.2` - 状态管理和路由
- `sqflite: ^2.4.2` - SQLite 数据库
- `dio: ^5.9.0` - HTTP 网络请求
- `web_socket_channel: ^3.0.3` - WebSocket 通讯
- `flutter_webrtc: ^1.2.1` - WebRTC 音视频

### 自定义插件
项目使用多个自定义插件，位于 `plugin/` 目录：
- `flutter_chat_ui` - 自定义聊天 UI 组件
- `cross_cache` - 跨平台缓存
- `amap_flutter_map_plus` - 高德地图
- 其他第三方定制插件

查看 `pubspec.yaml` 获取完整依赖列表。

---

## 数据库架构

### SQLite 数据库
- 数据库版本：v9
- 数据库名称：`{env}_{uid}.db`
- 支持事务、并发控制、查询缓存
- 自动迁移和降级支持

### 主要数据表
- `message` - C2C 消息
- `group_message` - C2G 群组消息
- `c2s_message` - C2S 客户端到服务端消息
- `s2c_message` - S2C 服务端到客户端消息
- `conversation` - 会话列表
- `contact` - 联系人
- `group_*` - 群组相关表
- `user_*` - 用户相关表

### 数据库操作模式
- 所有数据库操作通过 `SqliteService` 单例进行
- 使用事务保证数据一致性
- 支持批量操作和并发控制
- 实现了查询缓存机制以提高性能

### 迁移策略
- 使用 `MigrationService` 进行自动迁移
- 每次版本升级都创建数据库快照备份
- 支持升级和降级操作
- 迁移失败时可回滚到备份版本

---

## 消息系统

### 消息类型
- `C2C` - 客户端到客户端消息
- `C2G` - 客户端到群组消息
- `C2S` - 客户端到服务端消息
- `S2C` - 服务端到客户端消息

### 消息流程
1. **发送**：客户端 → WebSocket → 服务端
2. **接收**：服务端 → WebSocket → 客户端
3. **存储**：本地 SQLite 数据库
4. **展示**：消息列表渲染

### 消息状态
- 待发送
- 已发送
- 已送达
- 已读
- 撤回

### 消息可靠性保障
- **消息确认**：通过 ACK 机制确保消息送达
- **消息重试**：失败消息自动重试发送
- **离线消息**：应用恢复时自动拉取离线消息
- **消息去重**：防止重复消息显示

---

## 主题系统

### 主题管理器
- `lib/theme/theme_manager.dart` - 主题管理核心
- 支持亮色/暗色模式切换
- 支持动态字体缩放
- 支持动态颜色（Material 3）

### 主题配置
- `lib/theme/default/theme.dart` - 主题配置
- `lib/theme/default/app_colors.dart` - 颜色定义
- `lib/theme/default/font_types.dart` - 字体类型

### 字体管理
- 支持多种字体大小选项
- 遵循无障碍标准
- 可根据系统设置自动调整

---

## 国际化

### 支持语言
- 简体中文 (zh_CN)
- 繁体中文 (zh_Hant)
- 英语 (en_US)
- 德语 (de_DE)
- 法语 (fr_FR)
- 意大利语 (it_IT)
- 日语 (ja_JP)
- 韩语 (ko_KR)
- 俄语 (ru_RU)
- 阿拉伯语 (ar_SA)

### 翻译文件
- `assets/locales/` - JSON 格式翻译文件
- `lib/component/locales/locales.g.dart` - 生成的翻译代码

---

## 常见问题 (FAQ)

### Q: 如何添加新的消息类型？
A: 在 `lib/component/chat/` 下创建新的消息 Builder，参考 `message_image_builder.dart` 等文件。

### Q: 如何修改主题颜色？
A: 编辑 `lib/theme/default/app_colors.dart` 中的颜色定义。

### Q: 数据库迁移如何处理？
A: 使用 `lib/service/migration_service.dart` 中的 `MigrationService` 进行自动迁移。

### Q: WebSocket 连接失败如何排查？
A: 检查 `lib/service/websocket.dart` 和 `lib/service/network_monitor.dart` 的日志输出。

### Q: 如何处理消息撤回？
A: 使用 `MessageActions` 服务中的撤回功能，系统会自动更新消息状态并通知相关界面。

### Q: 如何添加新的聊天消息类型？
A:
1. 在 `lib/component/chat/enum.dart` 中添加消息类型枚举
2. 创建对应的 `Message*Builder` 组件
3. 在消息处理逻辑中添加相应的处理分支

### Q: 如何实现消息加密？
A:
1. 使用 `lib/service/encrypter.dart` 中的加密服务
2. 在发送消息前对消息内容进行加密
3. 在接收消息时进行解密处理

---

## 相关资源

- [Flutter 官方文档](https://flutter.dev/docs)
- [GetX 文档](https://github.com/jonataslaw/getx)
- [SQLite 文档](https://www.sqlite.org/docs.html)
- 项目 Wiki：待补充

---

**文档维护者**：init-architect agent
**项目版本**：0.7.0
**最后更新**：2026-01-01
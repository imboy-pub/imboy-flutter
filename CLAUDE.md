# ImBoy App - 架构文档

> 本文档由 init-architect 自动生成和维护
> 最后更新：2026-01-19 12:00:00 CST

---

## 变更记录 (Changelog)

### 2026-01-19
- **数据层命名重构**：`store/provider/` 重命名为 `store/api/`
- 统一 API 客户端命名：`*_provider.dart` → `*_api.dart`，`*Provider` → `*Api`
- 解决与 Riverpod 的 `Provider` 类型命名冲突
- 更新模块架构图和文档

### 2026-01-16
- **统一文件命名规范**：
  - 新页面 UI 组件使用 `*_page.dart` 后缀
  - 状态管理使用 `*_provider.dart` 后缀
  - 添加完整的命名规范文档和代码模板
  - 明确旧架构到新架构的迁移规则

### 2026-01-15
- 更新主题颜色：主色调从绿色 #059669 更改为科技蓝 #2474E5
- 同步更新 UI/UX 设计规范文档
- 更新颜色系统中的所有相关定义（主色、浅色、深色、容器色）
- **解决 Provider 命名冲突**：为旧 `provider` 包添加别名 `get_provider`，与 Riverpod 的 `Provider` 区分

### 2026-01-13
- 更新国际化方案说明：项目使用 slang 作为多语言解决方案
- 添加 slang 使用方式和配置说明
- 新增国际化相关 FAQ

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
- **状态管理**：
  - **主力架构**：**Riverpod**（最新版本，已完成80%迁移）
- **路由管理**：**go_router**（主力）
- **本地数据库**：SQLite (sqflite 2.4+)
- **网络请求**：Dio 5.9
- **实时通讯**：WebSocket + WebRTC

### 设计模式
- **架构模式**：MVVM + Repository 模式
- **路由管理**：**go_router
- **数据持久化**：Repository + SQLite
- **消息队列**：持久化队列 + 事件总线

### 迁移状态（2026-01-16 22:10）
- ✅ **服务层**：100% 迁移到 Riverpod
- ✅ **会话模块**：100% 迁移到 Riverpod
- ✅ **联系人模块**：100% 迁移到 Riverpod
- ✅ **个人信息模块**：100% 迁移到 Riverpod
- ✅ **群组模块**：100% 迁移到 Riverpod
- ✅ **登录注册模块**：100% 迁移到 Riverpod
- ✅ **我的模块**：95% 迁移到 Riverpod (user_collect已完成)
- ✅ **聊天模块**：100% 迁移到 Riverpod ⭐
- ✅ **GetX依赖**：0个Dart文件使用GetX
- ✅ **编译状态**：0 errors, 0 warnings (chat模块)

**迁移完成时间**：2026-01-16 22:10 CST
**详细报告**：`lib/page/chat/chat/CHAT_MODULE_GETX_REMOVAL_COMPLETE_REPORT.md`

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
    store --> api["api/ - HTTP API客户端"]
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
| `lib/store/` | 数据层（Repository、Api、Model） | [查看详情](./lib/store/CLAUDE.md) |
| `lib/theme/` | 主题管理和样式系统 | [查看详情](./lib/theme/CLAUDE.md) |
| `lib/config/` | 应用配置和初始化 | - |
| `lib/utils/` | 通用工具类和辅助函数 | - |

### 设计文档
| 文档 | 描述 | 链接 |
|------|------|------|
| UI/UX 设计规范 | 完整的设计系统文档（颜色、间距、组件等） | [查看](./doc/UI_UX_Design_Spec.md) |

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
- `test/service/storage_service_test.dart` - 存储服务测试
- `test/service/event_bus/` - 事件总线测试
- `test/theme_migration_test.dart` - 主题迁移测试

### 测试原则
- **框架无关**：测试代码不依赖特定状态管理框架
- **Widget 测试**：使用 `ProviderScope` 包裹测试组件
- **单元测试**：直接测试业务逻辑，不依赖 UI 层
- **集成测试**：测试完整的用户流程

### 测试工具
- `flutter_test` - Flutter 官方测试框架
- `build_runner` - 代码生成工具
- `mockito` - Mock 框架（如需要）

---

## 国际化

### 多语言方案
项目使用 **slang** 作为国际化解决方案（版本: ^4.11.2）

### 支持语言
- 简体中文 (zh_CN) - 默认语言
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
- `lib/i18n/*.i18n.yaml` - YAML 格式翻译文件
  - `zh-CN.i18n.yaml` - 简体中文（主文件，包含所有翻译键）
  - `en-US.i18n.yaml` - 英语
  - 其他语言文件...
- `lib/i18n/strings.g.dart` - 自动生成的翻译入口文件
- `lib/i18n/strings_*.g.dart` - 各语言自动生成的翻译代码

### 使用方式
```dart
// 在代码中使用翻译
import 'package:imboy/i18n/strings.g.dart';

// 获取翻译字符串
String title = t.home.title; // 访问嵌套键
String message = t.errors.networkError;

// 切换语言
LocaleSettings.setLocale(AppLocale.enUs);

// 获取当前语言
AppLocale currentLocale = LocaleSettings.currentLocale;
```

### 添加新翻译
1. 在 `lib/i18n/zh-CN.i18n.yaml` 添加新的翻译键
2. 运行 `dart run slang` 生成翻译代码
3. 在其他语言文件中提供对应翻译

### 配置文件
- `build.yaml` - slang 构建配置
- `pubspec.yaml` - slang 依赖配置

### 优势
- **类型安全**: 编译时检查翻译键是否存在
- **自动代码生成**: 无需手动维护映射关系
- **支持嵌套**: 支持多层嵌套的翻译结构
- **缺失翻译检测**: 自动检测缺失的翻译
- **轻量高效**: 采用懒加载和代码分割，减小包体积

---

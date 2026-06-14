# IMBoy Flutter App

[![Flutter](https://img.shields.io/badge/Flutter-3.41.x-blue.svg)](https://flutter.dev/)
[![License](https://img.shields.io/badge/License-木兰宽松许可证v2-green.svg)](https://gitee.com/imboy-pub/imboy-flutter/blob/main/LICENSE)

IMBoy 是一个基于 Flutter 的即时通讯客户端，当前仓库包含聊天、联系人、群组、频道、朋友圈、收藏、Tag、通知与端到端加密等相关实现。

## Related Decisions / 相关 ADR

- [2026-03-15-feature-module-boundaries](doc/adr/2026-03-15-feature-module-boundaries.md)

## Related Docs / 相关文档

- [Flutter Module Map](doc/module_map.md)

## Migration Status / 迁移状态（2026-03-29 — 闭环）

> Workspace Modular + Plugin Architecture 迁移已全部完成（Task 0-17）。

- Stable public entries: `lib/modules/messaging/public.dart`, `lib/modules/moment_social/public.dart`, `lib/modules/channel_content/public.dart`, `lib/modules/group_collab/public.dart`, `lib/modules/identity/public.dart`, `lib/modules/social_graph/public.dart`, `lib/modules/security_privacy/public.dart`, `lib/modules/ops_governance/public.dart`.
- Messaging upper layers have converged on `MessagingFacade` via `lib/modules/messaging/public.dart`; `lib/service/message.dart` and `lib/service/message_actions.dart` remain internal legacy implementations behind the module facade.
- Route and page-barrel entry points now converge on module public entries for `moment_social`, `channel_content`, `group_collab`, `social_graph`, `security_privacy`, and `ops_governance`.
- Production extension points: `lib/plugins/contracts/message_type_plugin.dart`, `lib/plugins/registry/message_type_registry.dart`, `lib/plugins/builtin/register_builtin_plugins.dart`.
- Boundary gate: `tool/check_module_boundaries.dart` + `analysis_options.yaml`.
- Regression: `flutter analyze` 0 issues, 1072 tests passed / 7 skipped / 0 failed.

## 项目概览

- Flutter 3.41.x 客户端工程
- 支持单聊、群聊、会话管理、消息提醒、频道、收藏、Tag、朋友圈等业务线
- 实时链路基于 WebSocket，音视频能力基于 WebRTC
- 本地持久化使用 SQLite，状态管理以 Riverpod 为主

## 功能概览

### V1.0 MVP 核心功能
- ✅ 用户注册登录与认证
- ✅ 实时消息收发（文本、图片、语音、视频）
- ✅ 好友管理与联系人同步
- ✅ 群组聊天与管理
- ✅ 音视频通话（WebRTC）
- ✅ 消息推送与通知
- ✅ 多媒体文件管理
- ✅ 主题切换与个性化设置

### 后续增强项
- 🔄 群公告与管理功能
- 🔄 消息免打扰设置
- 🔄 个性化聊天背景
- 🔄 朋友圈功能
- 🔄 高级推送系统

## 📸 应用截图

<table>
    <td width="32%">
        <img alt="聊天界面" src="https://a.imboy.pub/img/20225/25_21/ca73910gph0gio9q2pg0.png?s=open&a=4e2498d2673bf43d&v=1687988290&width=600" width="100%"/>
    </td>
    <td width="32%">
        <img alt="联系人" src="https://a.imboy.pub/img/20225/25_21/ca73cl0gph0gio9q2pp0.png?s=open&a=1ffbf5e386ad0272&v=1687988290&width=600" width="100%"/>
    </td>
    <td width="32%">
        <img alt="设置页面" src="https://a.imboy.pub/img/20225/25_22/ca73d6ogph0gio9q2psg.png?s=open&a=b2a2bd2380208f87&v=1687988290&width=600" width="100%"/>
    </td>
</table>

## 🚀 快速开始

### 环境要求

- Flutter 3.41.x（CI 当前固定为 3.41.0）
- Dart 3.8.0+（推荐 Dart 3.11.x）
- iOS 12.0+ / Android API 21+
- Xcode 14+ (iOS开发)
- Android Studio / VS Code

### 安装步骤

1. **克隆项目**
```bash
git clone https://gitee.com/imboy-pub/imboy-flutter.git imboyapp
cd imboyapp
```

2. **环境配置**

```bash
# 复制环境配置文件
cp ./example.env ./.env.dev
cp ./example.env ./.env.pro

# 常用运行环境
flutter run --target lib/main.dart --dart-define=APP_ENV=local_office
flutter run --target lib/main.dart --dart-define=APP_ENV=local_home
flutter run --target lib/main.dart --dart-define=APP_ENV=dev
flutter run --target lib/main.dart --dart-define=APP_ENV=pro


```



3. **安装依赖**


```bash
flutter pub get

# 生成代码
dart run build_runner build --verbose
dart run build_runner build --delete-conflicting-outputs
```

4. **插件配置**
```bash
# 仓库内已包含 plugin 目录
# 如果本地插件依赖异常，可进入对应目录自行检查或更新
```

envied 项目使用 envied + build_runner。运行：

```bash
flutter pub run build_runner build
```

如果只想重新生成 env 相关文件（跳过其他），可以加 --delete-conflicting-outputs：
```bash
flutter pub run build_runner build --delete-conflicting-outputs

```

如需重新生成启动图：

```bash
dart run flutter_native_splash:create
```

5. **运行应用**
```bash
flutter run --target lib/main.dart --dart-define=APP_ENV=local_home
```

## 🏗️ 项目架构

### 技术栈
- **前端框架**：Flutter 3.41.x / Dart 3.8.0+
- **状态管理**：Riverpod
- **路由管理**：go_router
- **本地数据库**：SQLite (sqflite)
- **网络请求**：Dio
- **实时通讯**：WebSocket + WebRTC

### 架构状态
当前工程以 Riverpod 为主，部分复杂模块仍保留历史实现形态。

当前边界以代码目录和实际实现为准，不再依赖仓库内的迁移过程文档。

### 目录结构

```
lib/
├── page/                   # 页面层
│   ├── chat/               # 聊天相关页面
│   ├── channel/            # 频道页面
│   ├── contact/            # 联系人页面
│   ├── conversation/       # 会话页面
│   ├── group/              # 群组页面
│   ├── mine/               # 我的页面
│   ├── moment/             # 朋友圈页面
│   ├── passport/           # 登录注册页面
│   └── ...
├── component/              # 通用组件
│   ├── extension/          # 扩展方法
│   ├── helper/             # 工具方法
│   ├── http/               # HTTP 客户端
│   ├── ui/                 # UI 组件
│   ├── widget/             # 自定义组件
│   └── webrtc/             # 音视频相关组件
├── features/               # 新能力域实验/拆分目录
├── i18n/                   # Slang 生成的国际化代码
├── service/                # 服务层
│   ├── message.dart        # 消息服务
│   ├── websocket.dart      # WebSocket 服务
│   └── storage.dart        # 存储服务
├── store/                  # 状态管理与仓储
│   ├── api/
│   ├── model/
│   └── repository/
├── theme/                  # 主题系统
├── config/                 # 配置中心
└── utils/                  # 通用工具
```

### 架构设计原则

- **分层架构**：清晰的分层结构，职责分离
- **状态管理**：使用 Riverpod 进行状态管理
- **路由管理**：使用 go_router 进行声明式路由
- **响应式编程**：基于 Stream 和 Provider 的响应式架构
- **模块化设计**：高内聚、低耦合的模块设计
- **测试驱动**：完善的单元测试和集成测试

## UI/UX Minimal Rules

为减少维护成本，UI/UX 不再维护独立大文档，统一使用以下最小约束：

- **Design Token 单一来源**：颜色、间距、圆角、阴影、动效统一定义在 `lib/theme/default/`。
- **颜色与可读性**：优先使用 `AppColors` 语义色，不在业务页面硬编码十六进制颜色；正文文本需满足基本对比度可读性。
- **间距与圆角**：优先使用 `AppSpacing` 和 `AppRadius` 常量，列表/卡片避免自由值。
- **触控与交互**：可点击区域建议不小于 `44x44`，关键状态变化使用统一时长与曲线（`app_duration.dart` / `app_curves.dart`）。
- **响应式与安全区**：页面需适配窄屏与横屏，底部操作区必须处理安全区（Safe Area）。
- **国际化与文本伸缩**：文案必须走 i18n，避免固定宽度截断；字体缩放后布局不能破坏核心交互。

主题相关实现入口：
- `lib/theme/default/theme.dart`
- `lib/theme/default/config/component_theme_manager.dart`
- `lib/theme/theme_manager.dart`

## ChatPage Mixin Rules

聊天页采用 Mixin 分层，避免单文件持续膨胀。规则精简如下：

- **单一职责**：每个 Mixin 只覆盖一个能力域（如初始化、事件订阅、消息交互、滚动处理）。
- **依赖显式化**：通过抽象 getter/方法声明依赖，不在 Mixin 内隐式耦合页面私有状态。
- **最小依赖**：只声明该 Mixin 必需依赖，避免把 `ref/context/widget` 全量透传。
- **边界清晰**：页面状态编排留在 `chat_page.dart`，可复用行为放入 `lib/page/chat/chat/mixin/`。

## 开发与构建

### 常用命令

```bash
dart run tool/check_module_boundaries.dart
flutter analyze
flutter test
flutter test integration_test/
flutter build apk --release
flutter build appbundle --release
flutter build ios --release
```

## Architecture Gates / 架构门禁

- Flutter 模块边界检查：`dart run tool/check_module_boundaries.dart`
- 静态分析：`flutter analyze`
- 约束规则：域外代码只能通过 `lib/modules/<domain>/public.dart` 使用模块能力，不能直接导入模块内部文件

### 平台说明

- iOS 依赖异常时，优先进入 `ios/` 执行 `pod install`。
- Android 打包配置以 `android/app/build.gradle` 为准。
- Google Play 发版前可参考：
  - `scripts/build_play_aab.sh`
  - `scripts/check_play_release.sh`

## 多语言支持

项目当前使用 **Slang**，翻译源文件和生成文件目录如下：

```text
assets/i18n/
lib/i18n/
```

生成翻译代码：

```bash
dart run slang
```

翻译审计入口见：

```text
assets/i18n/README.md
assets/i18n/i18n_audit.rb
```

## 已知问题

- "查找聊天记录"列表定位到具体聊天记录的跳转问题
- 视频上传优化（文件大小压缩）
- 红米 A5 手机拍摄视频问题

详细说明见 [FAQ文档](./doc/FAQ.md)。

## 许可证与链接

- 许可证：[木兰宽松许可证, 第2版](https://gitee.com/imboy-pub/imboy-flutter/blob/main/LICENSE)
- 项目主页：[Gitee](https://gitee.com/imboy-pub/imboy-flutter)
- 问题反馈：[Issues](https://gitee.com/imboy-pub/imboy-flutter/issues)

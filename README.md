# IMBoy - 现代化即时通讯应用

[![Flutter](https://img.shields.io/badge/Flutter-3.0+-blue.svg)](https://flutter.dev/)
[![License](https://img.shields.io/badge/License-木兰宽松许可证v2-green.svg)](https://gitee.com/imboy-pub/imboy-flutter/blob/main/LICENSE)
[![Quality](https://img.shields.io/badge/Code%20Quality-A+-brightgreen.svg)](#代码质量)

IMBoy 是一个基于 Flutter 开发的现代化即时通讯应用，采用先进的架构设计和开发流程，致力于提供优秀的用户体验和开发体验。

## ✨ 项目特色

- 🚀 **高性能架构**：优化的应用启动时间（<3秒）和流畅的用户体验
- 🎨 **Material 3 设计**：现代化的UI设计，支持动态主题和深色模式
- 🔧 **智能开发工具**：集成AI协作提示词模板，提升开发效率
- 📊 **代码质量保障**：完整的质量监控和自动化测试体系
- 🌐 **多语言支持**：国际化支持，轻松扩展多语言
- 🔒 **安全可靠**：端到端加密，保障用户隐私安全

## 📱 功能概览

### V1.0 MVP 核心功能
- ✅ 用户注册登录与认证
- ✅ 实时消息收发（文本、图片、语音、视频）
- ✅ 好友管理与联系人同步
- ✅ 群组聊天与管理
- ✅ 音视频通话（WebRTC）
- ✅ 消息推送与通知
- ✅ 多媒体文件管理
- ✅ 主题切换与个性化设置

### V2.0 增强功能
- 🔄 群公告与管理功能
- 🔄 消息免打扰设置
- 🔄 个性化聊天背景
- 🔄 朋友圈功能
- 🔄 高级推送系统

## 📸 应用截图

更多截图请查看 [应用界面展示](./doc/appui.md)

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

- Flutter 3.0+
- Dart 3.0+
- iOS 12.0+ / Android API 21+
- Xcode 14+ (iOS开发)
- Android Studio / VS Code

### 安装步骤

1. **克隆项目**
```bash
git clone https://gitee.com/imboy-pub/imboy-flutter.git imboy
cd imboy
```

2. **环境配置**

```bash
# 复制环境配置文件
cp ./example.env ./.env.dev
cp ./example.env ./.env.pro

# 复制主入口文件
cp example_main.dart main.dart


#命令行运行

## 办公室本地环境
flutter run --dart-define=APP_ENV=local_office

## 其他环境
flutter run --dart-define=APP_ENV=dev
flutter run --dart-define=APP_ENV=pro
flutter run --dart-define=APP_ENV=local_home

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
# 安装聊天UI插件
mkdir -p plugin && cd plugin/
git clone https://gitee.com/imboy-tripartite-deps/flutter_chat_ui.git
cd flutter_chat_ui && git fetch origin leeyi && git checkout -f leeyi
```


deps flutter_native_splash
```
dart run flutter_native_splash:create
```

5. **运行应用**
```bash
flutter run
```

## 🏗️ 项目架构

### 技术栈
- **前端框架**：Flutter 3.0+ / Dart 3.0+
- **状态管理**：Riverpod（主力）+ GetX（兼容）
- **路由管理**：go_router（主力）+ GetX（兼容）
- **本地数据库**：SQLite (sqflite)
- **网络请求**：Dio
- **实时通讯**：WebSocket + WebRTC

### 架构迁移状态（2026-01-16）
项目已完成 GetX 到 Riverpod 的大规模迁移：
- ✅ **服务层**：完全移除 GetX 依赖
- ✅ **会话/联系人/个人信息/群组/登录注册模块**：100% 迁移到 Riverpod
- 🔄 **我的模块**：70% 迁移完成
- ⏳ **聊天模块**：保留 GetX（复杂模块）

> 详细迁移报告请查看项目文档中的 `MIGRATION*.md` 文件

### 目录结构

```
lib/
├── page/                    # 页面层
│   ├── single/             # 单页面组件
│   ├── chat/               # 聊天相关页面
│   ├── contact/            # 联系人页面
│   ├── quality/            # 质量管理页面
│   └── ...
├── component/              # 通用组件
│   ├── extension/          # 扩展方法
│   ├── helper/             # 工具方法
│   ├── http/               # HTTP客户端
│   ├── ui/                 # UI组件
│   └── widget/             # 自定义组件
├── core/                   # 核心模块
│   ├── quality/            # 代码质量管理
│   ├── architecture/       # 架构优化
│   └── refactoring/        # 重构助手
├── service/                # 服务层
│   ├── message.dart        # 消息服务
│   ├── websocket.dart      # WebSocket服务
│   └── storage.dart        # 存储服务
├── store/                  # 状态管理
│   ├── model/              # 数据模型
│   ├── repository/         # 数据仓库
│   └── provider/           # 状态提供者
├── theme/                  # 主题系统
│   ├── cache/              # 主题缓存
│   ├── validation/         # 主题验证
│   └── theme_manager.dart  # 主题管理器
└── config/                 # 配置中心
    ├── env.dart            # 环境配置
    └── init.dart           # 初始化配置
```

### 架构设计原则

- **分层架构**：清晰的分层结构，职责分离
- **状态管理**：使用 Riverpod 进行状态管理（主力），保留 GetX 兼容
- **路由管理**：使用 go_router 进行声明式路由（主力），保留 GetX 路由兼容
- **响应式编程**：基于 Stream 和 Provider 的响应式架构
- **模块化设计**：高内聚、低耦合的模块设计
- **测试驱动**：完善的单元测试和集成测试

## 🔧 开发指南

### 性能优化

#### 启动性能
- 应用启动时间优化至3秒以内
- 分阶段初始化：关键路径 → 并行组件 → 延迟服务
- 字体预加载解决汉字乱码问题

#### 运行时性能
- 内存优化和泄漏检测
- UI渲染性能监控
- 网络请求优化
- 数据库查询优化

### 测试策略

#### 单元测试
```bash
flutter test
```

#### 集成测试
```bash
flutter test integration_test/
```

#### 性能测试
```bash
flutter drive --target=test_driver/perf_test.dart
```

## 🌐 多语言支持

### 配置多语言

1. 安装Get CLI工具：
```bash
flutter pub global activate get_cli
export PATH="$PATH":"$HOME/.pub-cache/bin"
```

2. 生成本地化文件：
```bash
get generate locales assets/locales on lib/component/locales
```

3. 在应用中使用：
```dart
return GetMaterialApp(
  locale: Get.deviceLocale,
  translations: AppTranslations(),
);
现在app的 配置多语言 显示有问题了，不知道啥原因
```

## 📊 功能完成度

当前项目功能实现情况：
- ✅ 已完成：144个功能
- 🔄 待完成：54个功能

详细功能列表请查看 [功能树文档](./doc/feature_tree.md)

## 🔍 已知问题与解决方案

### 当前已知问题
- "查找聊天记录"列表定位到具体聊天记录的跳转问题
- 视频上传优化（文件大小压缩）
- 红米A5手机拍摄视频兼容性问题

### 解决方案
详细的问题解决方案请参考 [FAQ文档](./doc/FAQ.md)

## 🛠️ 开发工具

### 推荐工具
- **IDE**：VS Code / Android Studio
- **调试**：Flutter DevTools
- **性能分析**：fps_monitor
- **代码质量**：dart_code_metrics
- **版本控制**：Git + GitLens

### 分析工具
```bash
# 代码分析
flutter analyze

# 性能分析
flutter run --profile

# 内存分析
flutter run --debug --enable-software-rendering
```

## 📦 依赖管理

### 核心依赖
- `flutter_riverpod`: 状态管理（主力）
- `go_router`: 路由管理（主力）
- `get`: 状态管理和路由（兼容模式，逐步迁移中）
- `flutter_chat_ui`: 聊天界面组件
- `webrtc_interface`: 音视频通话
- `sqflite`: 本地数据库
- `dio`: 网络请求

### 开发依赖
- `build_runner`: 代码生成
- `freezed`: 数据类生成
- `flutter_lints`: 代码规范检查

### 平台特定配置

#### iOS配置
```bash
cd ios
arch -x86_64 pod install
arch -x86_64 pod update

cd ios && rm -rf Podfile.lock pods .symlink Runner.xcworkspace && pod install --repo-update && flutter clean && flutter pub get && pod update && cd ..
```

#### Android配置
确保 `android/app/build.gradle` 中的配置正确。

## 🚀 部署指南

### 构建发布版本

#### Android
```bash
flutter build apk --release
flutter build appbundle --release
```

#### iOS
```bash
flutter build ios --release
```

### 版本管理

项目遵循 [语义化版本控制规范](https://semver.org/lang/zh-CN/)：
- 主版本号：不兼容的API修改
- 次版本号：向下兼容的功能性新增
- 修订号：向下兼容的问题修正

## 🤝 贡献指南

### 开发流程
1. Fork 项目到个人仓库
2. 创建功能分支：`git checkout -b feature/amazing-feature`
3. 提交更改：`git commit -m 'Add amazing feature'`
4. 推送分支：`git push origin feature/amazing-feature`
5. 创建 Pull Request

### 代码审查
所有代码提交都需要通过代码审查，审查清单包括：
- 功能实现正确性
- 代码质量和规范
- 性能影响评估
- 安全性检查
- 测试覆盖率

详细的代码审查清单请参考 [代码审查文档](./doc/code_review_checklist.md)

## 📄 许可证

因为我是中国人，所以选择了[木兰宽松许可证, 第2版](https://gitee.com/imboy-pub/imboy-flutter/blob/main/LICENSE)

所有依赖的flutter包大部分是"MIT License" 和 "Apache-2.0 License"

## 📞 联系我们

- 项目主页：[Gitee](https://gitee.com/imboy-pub/imboy-flutter)
- 问题反馈：[Issues](https://gitee.com/imboy-pub/imboy-flutter/issues)
- 讨论交流：[Discussions](https://gitee.com/imboy-pub/imboy-flutter/discussions)

## 🙏 致谢

感谢所有为IMBoy项目做出贡献的开发者和用户！

---

**IMBoy** - 让沟通更简单，让开发更高效！

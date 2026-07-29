> [imboy.pub 根目录](../CLAUDE.md) > **imboyapp（Flutter 移动端）**

# ImBoy App - 架构文档 / Architecture Document

> 最后更新 / Last updated：2026-07-25 CST | Flutter 客户端

---

## 文档双语规则 (MANDATORY)

> 见根级 [CLAUDE.md](../CLAUDE.md#双语文档规则--bilingual-documentation-rule-mandatory)

---

## 必读设计规范

**所有 UI 代码必须先阅读 [`./DESIGN.md`](./DESIGN.md)（第 13 章 For Coding Agents）。**

| 约束 | 规则 |
|------|------|
| 品牌蓝 | `#2474E5` (`AppColors.primary`) — Logo、Tab 选中、主按钮、发送气泡 |
| iOS 蓝 | `#007AFF` (`AppColors.iosBlue`) — 链接、Nav 文字按钮、取消按钮 |
| 破坏性操作 | 必须用 `iosRed` (`#FF3B30`) |
| 最小触达区 | ≥ 44×44pt |
| 页面水平 padding | 16pt |
| 聊天气泡圆角 | 20pt；发送用 `brand`，接收用 `surface` |
| 禁止硬编码 | 颜色/间距/字号必须通过 `AppColors` / `AppSpacing` / `FontSizeType` Token |
| 暗色模式 | 查 DESIGN.md §10.2 浅→暗映射表 |

---

## 技术栈

| 层级 | 技术 |
|------|------|
| 框架 | Flutter / Dart 3.8+ |
| 状态管理 | Riverpod（100% 迁移完成，0 GetX） |
| 路由 | go_router |
| 本地数据库 | SQLite (sqflite 2.4+)，当前 schema v24 |
| 网络 | Dio 5.9 |
| 实时通讯 | WebSocket + WebRTC |
| 国际化 | slang ^4.11.2，默认语言 zh-CN |
| 架构模式 | MVVM + Repository |

---

## 目录结构

```
lib/
├── page/          # 页面层（路由页面）→ lib/page/CLAUDE.md
├── component/     # 可复用组件层   → lib/component/CLAUDE.md
├── service/       # 核心业务服务   → lib/service/CLAUDE.md
├── store/         # 数据层 (Repo/Api/Model) → lib/store/CLAUDE.md
├── theme/         # 主题系统       → lib/theme/CLAUDE.md
├── app_core/      # 应用核心（feature_flags / routing）
├── plugins/       # 插件体系（builtin / contracts / registry）
├── modules/       # DDD 功能模块（messaging / social_graph / group_collab 等）
├── config/        # 配置与路由
├── utils/         # 工具类
└── i18n/          # slang 生成物（*.g.dart），勿手动修改
assets/i18n/       # 国际化源文件 <locale>/<namespace>.i18n.yaml（先改这里）
assets/migrations/ # SQLite 迁移脚本
test/              # 单元/集成测试
plugin/            # 插件源码（勿动 plugin/r_upgrade）
scripts/           # 构建/测试脚本
```

**保留区（禁止修改）**：`ios/*`、`macos/*`、`plugin/r_upgrade`

---

## 架构规则

### 资源 URL 授权（CRITICAL）

所有附件 URL（图片/视频/音频/文件）必须经 `AssetsService.viewUrl` 重新授权（有效期 3600s）。

| 正确用法 | 说明 |
|---------|------|
| `cachedImageProvider(url, w: 400)` | 内部已调用 `AssetsService.viewUrl` |
| `dynamicAvatar(url)` | 调用 `cachedImageProvider` |
| `Avatar` 组件 | 已内置，无需额外处理 |
| `IMBoyCacheManager().getSingleFile(url)` | 内部自动重授权 |

**禁止直接使用**：`Image.network(url)`、`CachedNetworkImage(url)`、`Dio().get(url)`

### MessageModel.id 类型

`MessageModel.id` 为 `String`（Xid base32hex），非 `int`。禁止用 `int.tryParse`。

### SQLite 版本

当前 `_dbVersion = 24`（以 `lib/service/sqlite.dart` 为准）。历史：v21 修复 `moment_notify` dedup 索引（`COALESCE(comment_id, '')`）。

---

## 常用命令

> 基础命令见 [README.md](./README.md)。发布专用命令：

```bash
flutter pub run build_runner build  # 生成代码（Provider、JSON 序列化等）
flutter build apk                   # Android 发布构建
flutter build ios                   # iOS 发布构建
```

### 环境配置

| 环境 | 配置文件 |
|------|---------|
| dev | `lib/config/env_dev.dart` |
| pro | `lib/config/env_pro.dart` |
| local | `lib/config/env_local.dart` |

### 开发规则

- **Android 调试必须使用真机**，禁止用模拟器做功能验证。
- 后端代码位于 `../imboy/`（Erlang/OTP 28+）。

---

## 国际化

```
assets/i18n/              ← 权威源文件目录（slang input_directory）
├── zh-CN/               ← 基准语言（base_locale）
│   ├── common.i18n.yaml
│   ├── chat.i18n.yaml
│   ├── group.i18n.yaml
│   └── ...（每个 namespace 一个文件）
├── en-US/
├── zh-Hant/
└── ...（共 10 个语言）
lib/i18n/                ← 生成物目录（slang output_directory），勿手动修改
```

新增翻译：在 `assets/i18n/zh-CN/<namespace>.i18n.yaml` 添加键 → `dart run slang` → 同步其他语言文件。

---

## 模块索引

### 传统层

| 模块路径 | 职责 | 文档 |
|---------|------|------|
| `lib/page/` | 所有页面视图和路由 | [page/CLAUDE.md](./lib/page/CLAUDE.md) |
| `lib/component/` | 可复用组件和工具类 | [component/CLAUDE.md](./lib/component/CLAUDE.md) |
| `lib/service/` | WebSocket、消息、数据库服务 | [service/CLAUDE.md](./lib/service/CLAUDE.md) |
| `lib/store/` | Repository、Api、Model | [store/CLAUDE.md](./lib/store/CLAUDE.md) |
| `lib/theme/` | 主题管理和样式系统 | [theme/CLAUDE.md](./lib/theme/CLAUDE.md) |

### 应用核心

| 模块路径 | 职责 |
|---------|------|
| `lib/app_core/feature_flags/` | 功能开关（Feature Flag）管理 |
| `lib/app_core/routing/` | 路由配置与守卫 |

### 插件体系

| 模块路径 | 职责 |
|---------|------|
| `lib/plugins/builtin/` | 内置插件实现 |
| `lib/plugins/contracts/` | 插件接口契约 |
| `lib/plugins/registry/` | 插件注册表 |

### DDD 功能模块（lib/modules/）

| 模块路径 | 职责 | 文档 |
|---------|------|------|
| `lib/modules/messaging/` | 消息（充血领域 + 四层架构） | [messaging/CLAUDE.md](./lib/modules/messaging/CLAUDE.md) |
| `lib/modules/social_graph/` | 好友关系与社交图谱 | — |
| `lib/modules/group_collab/` | 群组协作（任务/投票/日程） | — |
| `lib/modules/channel_content/` | 频道内容订阅 | — |
| `lib/modules/moment_social/` | 朋友圈与动态 | — |
| `lib/modules/identity/` | 身份认证与账户 | — |
| `lib/modules/security_privacy/` | 安全与隐私（E2EE/DND） | — |
| `lib/modules/ops_governance/` | 运营治理（举报/审核） | — |

---

## 测试原则

- Widget 测试用 `ProviderScope` 包裹组件。
- 单元测试直接测业务逻辑，不依赖 UI 层。
- 纯函数契约测试 + SQLite ffi in-memory 测试优先。
- 基线：`dart analyze lib` 应保持 **零 issues**（error / warning / info）。**以实跑为准**，勿凭本文档断言——基线会随新代码漂移。

---

## 自动化 E2E 测试

> 详见 [integration_test/README.md](./integration_test/README.md)

### 方案定位（2026-07-29 决策）

| 方案 | 工具 | 定位 | 状态 |
|------|------|------|------|
| **integration_test** | Flutter 官方 | 底座，进程内、`Key` 可直接用 | ✅ 现役 |
| **Patrol** | LeanCode | 主 E2E 框架，补原生权限/通知/WebView | 📋 待接入（Android 优先） |
| **mobile-mcp** | Claude Code MCP | 探索验证、故障复现、AI 辅助 | ✅ 可用（Android） |
| ~~Maestro YAML~~ | — | — | ❌ 已删除，见下 |

**为什么删 Maestro**：Flutter 的 `Key()` **不接入 accessibility bridge**，Maestro 在 Flutter 上
只能看见 `Semantics(identifier:)`（[官方文档](https://docs.maestro.dev/get-started/supported-platform/flutter)）。
本仓有 83 个字面量 `Key('...')`、**0 个 `Semantics(identifier:)`**，那 51 个 flow 用 `id: xxx` 匹配
`Key('xxx')` 从设计上就永远找不到元素——不是坏了，是从来没工作过。要复活得给全项目补一套无障碍标识体系。

**注1 — iOS 受阻**：`ios/Runner.xcodeproj` 的 `SUPPORTED_PLATFORMS = iphoneos`（仅真机），
模拟器不在目标列表；`ios/*` 是保留区禁止修改。
这同样卡住 Patrol 的 iOS 接入——Patrol 需要新建 `ios/RunnerUITests/`、改 `ios/Podfile` 与
`ios/Runner.xcodeproj/project.pbxproj`。**Android 侧不受影响**（只需 `android/app/src/androidTest/`
+ `android/app/build.gradle`），所以先落地 Android。

### 推荐流程（方案 C，真机）

```bash
cd imboyapp

# 1. 冒烟门控（快，合并前必跑）
flutter test integration_test/smoke/smoke_test.dart \
  -d 00008140-000E30561E32801C \
  --dart-define=APP_ENV=pro \
  --dart-define=TEST_PHONE=+86手机号 \
  --dart-define=TEST_PASSWORD=密码

# 2. 全量 UI 流程
flutter test integration_test/all_tests.dart \
  -d 00008140-000E30561E32801C \
  --dart-define=APP_ENV=pro \
  --dart-define=TEST_PHONE=+86手机号 \
  --dart-define=TEST_PASSWORD=密码
```

### macOS 桌面（无需真机）

同一套 integration_test，`-d macos` 即可；macOS 上需显式传 `API_BASE_URL`：

```bash
flutter test integration_test/smoke/smoke_test.dart -d macos \
  --dart-define=APP_ENV=pro \
  --dart-define=API_BASE_URL=https://pro.imboy.pub \
  --dart-define=TEST_PHONE=账号 \
  --dart-define=TEST_PASSWORD=密码
```

> 实测（2026-07-29）：macOS 冒烟 31s 通过。Keychain `-34018 entitlement` 报错是 macOS 桌面固有，不影响断言。

### Patrol 接入路线（待执行）

Patrol 是 integration_test 的**超集**——现有 24 个测试文件与 83 个 `Key` 可直接沿用，
额外获得原生权限弹窗、通知、WebView、生物识别的操作能力。

1. 加 `patrol` 依赖 + `android/app/src/androidTest/.../MainActivityTest.java` + `android/app/build.gradle`
2. 迁 smoke 用例，验证华为 EMUI 权限弹窗可被处理
3. 可选接 [`patrol_mcp`](https://pub.dev/packages/patrol_mcp)：让 AI 驱动 Patrol 会话，产物仍是可提交、可重放的 Dart 测试
4. iOS 待 `ios/*` 保留区解禁后再接

**分工原则**：AI（mobile-mcp / patrol_mcp）负责探索、生成、诊断；
**发版门禁只认可提交、可重复执行的 Dart 测试**——agent 的概率性操作不作为唯一回归依据。

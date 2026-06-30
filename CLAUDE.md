> [imboy.pub 根目录](../CLAUDE.md) > **imboyapp（Flutter 移动端）**

# ImBoy App - 架构文档 / Architecture Document

> 最后更新 / Last updated：2026-06-13 CST | Flutter 客户端

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
| 本地数据库 | SQLite (sqflite 2.4+)，当前 schema v21 |
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

当前 `_dbVersion = 21`；v21 migration 修复 `moment_notify` dedup 索引（`COALESCE(comment_id, '')`）。

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
- 当前基线（2026-06-22）：`dart analyze lib` **No issues found!**（零 error / 零 warning / 零 info）。历史轨迹：353 →（2026-06-11）约 60 →（2026-06-22）0。本轮清理：删除 2 个孤儿页（`e2ee_dev_test_page.dart` / `web_conversation_page.dart`，均零实例化死代码）+ 修复 8 项残留告警（mine_routes `dynamic→String` 显式转换 ×4、withdraw_page `if` 补花括号 ×2、chat_provider 冗余 import、e2ee_shard_message_handler 未用 import）。**仍以 `dart analyze lib` 实跑为准**，勿凭此条断言——基线会随新代码漂移。

---

## 自动化 E2E 测试

> 详见 [maestro/README.md](./maestro/README.md) 和 [integration_test/README.md](./integration_test/README.md)

### 三条可用路径

| 方案 | 工具 | 目标 | 当前状态 |
|------|------|------|---------|
| **A — mobile-mcp** | Claude Code MCP 工具 | iOS 模拟器 | ⚠️ 受阻（见注1） |
| **B — Maestro YAML** | Maestro CLI | macOS Desktop | ✅ 可用 |
| **C — flutter test** | Flutter integration_test | 真机（iPhone 16e） | ✅ 推荐 |

**注1 — iOS 模拟器受阻原因**：`ios/Runner.xcodeproj` 的 `SUPPORTED_PLATFORMS = iphoneos`（仅真机），
模拟器不在目标列表。`ios/*` 是保留区禁止修改。
Maestro 真机受阻原因：driver bundle ID `dev.mobile.maestro-driver-ios` 被 mobile.dev 公司占用，
需 Maestro Cloud 才能在任意 Team 下使用。

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

### macOS + Maestro（方案 B，无需真机）

```bash
cd imboyapp
# 后台启动 macOS app
flutter run -d macos --dart-define=APP_ENV=pro &

# 等 app 启动后运行 Maestro flow
maestro test maestro/01_login.yaml \
  -e APP_ID=pub.imboy.macos \
  -e PHONE=+86手机号 \
  -e PASSWORD=密码
```

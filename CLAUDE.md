> [imboy.pub 根目录](../CLAUDE.md) > **imboyapp（Flutter 移动端）**

# ImBoy App - 架构文档 / Architecture Document

> 最后更新 / Last updated：2026-05-08 CST | Flutter 客户端

---

## 文档双语规则 (MANDATORY)

- 面向用户/贡献者文档必须同时提供**简体中文 + English**。
- 简体中文为权威版本，英文在同一 PR 内同步跟进。
- 代码块、命令、配置原样保留，不翻译。
- AI 代理默认双语输出；commit 前缀 `docs(bilingual):`。
- 例外（仅中文）：`.claude/plan/*`、`.claude/memory/*`、内部会议纪要。

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
├── config/        # 配置与路由
├── utils/         # 工具类
└── i18n/          # slang 翻译文件 (*.i18n.yaml)
assets/migrations/ # SQLite 迁移脚本
test/              # 单元/集成测试
plugin/            # 插件源码（勿动 plugin/r_upgrade）
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

```bash
flutter pub get
flutter run
flutter test
dart run slang                      # 生成 i18n 代码
flutter pub run build_runner build
flutter build apk / flutter build ios
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
lib/i18n/
├── zh-CN.i18n.yaml   # 权威主文件（先改这里）
├── en-US.i18n.yaml
└── strings.g.dart    # 自动生成，勿手动修改
```

新增翻译：在 `zh-CN.i18n.yaml` 添加键 → `dart run slang` → 同步其他语言文件。

---

## 模块索引

| 模块路径 | 职责 | 文档 |
|---------|------|------|
| `lib/page/` | 所有页面视图和路由 | [page/CLAUDE.md](./lib/page/CLAUDE.md) |
| `lib/component/` | 可复用组件和工具类 | [component/CLAUDE.md](./lib/component/CLAUDE.md) |
| `lib/service/` | WebSocket、消息、数据库服务 | [service/CLAUDE.md](./lib/service/CLAUDE.md) |
| `lib/store/` | Repository、Api、Model | [store/CLAUDE.md](./lib/store/CLAUDE.md) |
| `lib/theme/` | 主题管理和样式系统 | [theme/CLAUDE.md](./lib/theme/CLAUDE.md) |

---

## 测试原则

- Widget 测试用 `ProviderScope` 包裹组件。
- 单元测试直接测业务逻辑，不依赖 UI 层。
- 纯函数契约测试 + SQLite ffi in-memory 测试优先。
- 当前基线：全量回归绿（`flutter analyze` 零警告）。

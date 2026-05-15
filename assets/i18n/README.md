# Slang 国际化说明

本目录存放 Slang 翻译源文件和辅助审计脚本。生成后的 Dart 文件位于 `lib/i18n/`，不要手动修改生成产物。

## 当前目录结构 (Namespaces 模式)

项目已开启命名空间支持，每个语言对应一个文件夹，内部按模块拆分 YAML 文件。

```text
assets/i18n/
├── zh-CN/                # 简体中文模块
│   ├── common.i18n.yaml  # 通用 (按钮、提示、时间)
│   ├── chat.i18n.yaml    # 聊天消息、状态
│   ├── account.i18n.yaml # 登录、注册、个人资料
│   ├── contact.i18n.yaml # 好友、标签、黑名单
│   ├── group.i18n.yaml   # 群组管理、公告
│   ├── discovery.i18n.yaml # 朋友圈、附近的人、频道
│   ├── error.i18n.yaml   # 网络、权限错误
│   └── main.i18n.yaml    # 其他未分类词条
├── en-US/                # 英文模块 (结构同上)
├── ...                   # 其他 8 种语言文件夹
├── i18n_audit.rb
└── README.md
```

生成结果位于：

```text
lib/i18n/strings.g.dart
lib/i18n/strings_*.g.dart
```

## 配置入口

- Slang 核心配置：`slang.yaml` (已开启 `namespaces: true`)
- Slang 依赖：`pubspec.yaml`
- 生成代码输出目录：`lib/i18n/`

## 常用命令

### 1. 生成翻译代码

在 `imboyapp` 根目录执行：

```bash
dart run slang
```

### 2. 审计翻译文件

在项目根目录执行：

```bash
ruby assets/i18n/i18n_audit.rb summary
```

## 使用约定

- **新增词条**：请根据逻辑归类到对应的命名空间 YAML 中。
- **命名空间**：`slang` 会根据文件名生成属性。例如 `common.i18n.yaml` 中的键通过 `t.common.xxx` 访问。
- **链接引用**：跨文件引用请使用绝对路径，格式为 `@:namespace.key`。例如 `@:common.buttonCancel`。
- **新增语言**：创建对应的文件夹（如 `fr-FR`），并按模块补齐 `.i18n.yaml` 文件。

## 代码入口

项目中建议通过 `BuildContext` 扩展或直接使用全局 `t`：

```dart
import 'package:imboy/i18n/strings.g.dart';
```

常见用法：

```dart
// 1. 通过 context 访问 (推荐，支持响应式)
final t = context.t; 
String text = t.common.cancel;

// 2. 全局访问
String text = t.chat.send;

// 3. 动态切换语言
await LocaleSettings.setLocale(AppLocale.enUs);
```

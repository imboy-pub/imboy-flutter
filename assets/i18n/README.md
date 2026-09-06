# Slang 国际化说明

本目录存放 Slang 翻译源文件和辅助审计脚本。生成后的 Dart 文件位于 `lib/i18n/`，不要手动修改生成产物。

## 当前目录结构（Namespaces 模式）

项目已开启命名空间支持，每个语言对应一个文件夹，内部按模块拆分 YAML 文件，
当前共 **10 个 locale × 28 个 namespace**（以 `zh-CN/` 实际文件为准）：

```text
assets/i18n/
├── zh-CN/                # 简体中文（基准语言 base_locale）
│   ├── common.i18n.yaml  # 通用（按钮、提示、时间）
│   ├── chat.i18n.yaml    # 聊天消息、状态、禁言
│   ├── account.i18n.yaml # 账号安全、设备、支付宝模拟器
│   ├── contact.i18n.yaml # 好友、标签、黑名单
│   ├── group*.i18n.yaml  # 群组管理/公告/任务/投票/日程/发现（6 个文件）
│   ├── discovery.i18n.yaml / momentNotify.i18n.yaml / momentFriendPicker.i18n.yaml
│   ├── channel.i18n.yaml # 频道（订阅、管理、发布）
│   ├── workspace.i18n.yaml / agentTask.i18n.yaml
│   ├── billing / complaint / complaintReason / passport / splash / welcome
│   ├── error.i18n.yaml   # 网络、权限错误
│   └── main.i18n.yaml    # 其他未分类词条（访问无前缀：t.main.xxx → t.xxx）
├── en-US/                # 英语（语义桥接层）
├── zh-Hant/ ja-JP/ ko-KR/ de-DE/ fr-FR/ it-IT/ ru-RU/ ar-SA/
├── i18n_audit.rb         # 审计器（见下）
├── i18n_audit_test.rb    # 审计器回归测试（13 用例）
├── i18n_key_prune.rb     # P4 键删除执行机（verify/apply --approve/selftest）
└── README.md
```

生成结果位于：

```text
lib/i18n/strings.g.dart
lib/i18n/strings_*.g.dart
```

## 配置入口

- Slang 核心配置：`slang.yaml`（已开启 `namespaces: true`，fallback 到 base_locale）
- Slang 依赖：`pubspec.yaml`
- 生成代码输出目录：`lib/i18n/`

## 常用命令

### 1. 生成翻译代码

在 `imboyapp` 根目录执行：

```bash
dart run slang
```

### 2. 审计翻译文件（新增键后的日常门）

```bash
ruby assets/i18n/i18n_audit.rb check          # 结构门（含英文残留门）
I18N_AUDIT_STRICT=1 ruby assets/i18n/i18n_audit.rb check   # 完整发布门
ruby assets/i18n/i18n_audit.rb summary        # 各 locale 统计矩阵
ruby assets/i18n/i18n_audit_test.rb           # 审计器回归（13 用例）
```

`check` 判结构失败的类别：重复键 / 空值 / null / 非字符串叶子 / YAML 语法 /
placeholder 不一致 / 非法 alias / 真性 extra / 未登记 locale /
**非拉丁 locale 英文残留**（值与 en-US 逐字节相同且不在 PINNED/品牌/技术豁免清单
——Round-3 实证 36 键 × 8 locale 曾以此形态潜伏）。strict 追加 missing / used_missing /
动态访问风险门。详见 `ruby assets/i18n/i18n_audit.rb help`。

## 使用约定

- **新增词条**：请根据逻辑归类到对应的命名空间 YAML 中；`main.i18n.yaml` 中的键
  通过无前缀形式访问（`t.xxx`），其余文件按文件名生成属性（`t.common.xxx`）。
- **新语言同步铁律**：新增键必须 10 locale 同步补齐，且**禁止把 en-US 值直接拷贝
  到非拉丁 locale 作为占位**（审计门会红）。
- **角色词 PINNED**：`Owner / Member / Guest / Admin` 及品牌词 `Alipay / WeChat`
  等按术语治理决议保留拉丁原文，勿在个别语言单独本地化。
- **链接引用**：跨文件引用请使用绝对路径，格式为 `@:namespace.key`。
- **产品术语**：翻译前先查 `I18N_TERMINOLOGY.md`（10 语言术语矩阵与裁决记录）；
  高风险文案的母语审核走 `I18N_NATIVE_REVIEW_<locale>.md` ×8。
- **删除键**：必须先过 `i18n_audit.rb unused` 候选 + 人工确认，再经
  `i18n_key_prune.rb`（verify → apply --approve），禁止手工删。

## 代码入口

项目中建议通过 `BuildContext` 扩展或直接使用全局 `t`：

```dart
import 'package:imboy/i18n/strings.g.dart';

// 1. 通过 context 访问（推荐，支持响应式）
final t = context.t;
String text = t.common.cancel;

// 2. 全局访问
String text = t.chat.send;

// 3. 动态切换语言
await LocaleSettings.setLocale(AppLocale.enUs);
```

# Slang 国际化说明

本目录存放 Slang 翻译源文件和辅助审计脚本。生成后的 Dart 文件位于 `lib/i18n/`，不要手动修改生成产物。

## 当前目录结构

```text
assets/i18n/
├── ar-SA.i18n.yaml
├── de-DE.i18n.yaml
├── en-US.i18n.yaml
├── fr-FR.i18n.yaml
├── it-IT.i18n.yaml
├── ja-JP.i18n.yaml
├── ko-KR.i18n.yaml
├── ru-RU.i18n.yaml
├── zh-CN.i18n.yaml
├── zh-Hant.i18n.yaml
├── i18n_audit.rb
└── README.md
```

生成结果位于：

```text
lib/i18n/strings.g.dart
lib/i18n/strings_*.g.dart
```

## 配置入口

- Slang 依赖：`pubspec.yaml`
- Slang 构建配置：`build.yaml`
- 生成代码输出目录：`lib/i18n/`

## 常用命令

### 1. 生成翻译代码

在 `imboyapp` 根目录执行：

```bash
dart run slang
```

### 2. 审计翻译文件

在 `assets/i18n/` 目录执行：

```bash
ruby i18n_audit.rb summary
ruby i18n_audit.rb aliases
ruby i18n_audit.rb unexpected-scripts
```

也可以在项目根目录执行：

```bash
ruby assets/i18n/i18n_audit.rb summary
```

## 使用约定

- 新增语言时，先补 `.i18n.yaml` 源文件，再运行 `dart run slang`。
- 生成文件以 `lib/i18n/strings.g.dart` 为统一入口，不直接改 `strings_*.g.dart`。
- 占位符、键名层级和基础语言文件保持一致，避免生成阶段出现缺失或类型漂移。
- 提交前建议至少跑一次 `summary` 和 `unexpected-scripts` 审计。

## 代码入口

项目中统一通过下面入口使用翻译：

```dart
import 'package:imboy/i18n/strings.g.dart';
```

常见用法：

```dart
await LocaleSettings.setLocale(AppLocale.zhCn);
final locale = LocaleSettings.currentLocale;
final text = t.some.path;
```

# Slang 国际化配置示例

> 本目录用于存放 Slang 翻译文件
> 配合 `script/migrate_translation_calls.dart` 使用

---

## 目录结构

```
lib/i18n/
├── en.i18n.yaml        # 英文翻译
├── zh_CN.i18n.yaml     # 简体中文翻译
├── zh_Hant.i18n.yaml   # 繁体中文翻译
└── strings.g.dart      # 自动生成的文件（不要修改）
```

---

## 快速开始

### 1. 检查 build.yaml 配置

在项目根目录的 `build.yaml` 中确保有：

```yaml
targets:
  $default:
    builders:
      slang:
        options:
          base_locale: zh_CN  # 基础语言
          input_directory: lib/i18n
          output_directory: lib/i18n
          output_localization_file: strings.g.dart
          output_class_name: AppStrings
          enum_name: AppLocale
          typedefs:
            AppLocale: String
```

### 2. 创建翻译文件

参考本目录下的 `.i18n.yaml` 示例文件。

### 3. 生成翻译代码

```bash
dart run slang
```

### 4. 在代码中使用

```dart
import 'package:imboy/i18n/strings.g.dart';

// 简单翻译
Text(AppStrings.current.hello)

// 带参数的翻译
Text(AppStrings.current.welcome(name: 'John'))

// 切换语言
AppLocale.current = AppLocale.zh_CN;
```

---

## 从 GetX 迁移

### 迁移前（GetX）

```dart
import 'package:get/get.dart';

Text('hello'.tr)
Text('welcome'.trParams({'name': 'John'}))
```

### 迁移后（Slang）

```dart
import 'package:imboy/i18n/strings.g.dart';

Text(AppStrings.current.hello)
Text(AppStrings.current.welcome(name: 'John'))
```

---

## 翻译文件格式示例

### en.i18n.yaml

```yaml
hello: Hello
welcome: Welcome {name}
setting:
  title: Settings
  accountSecurity: Account Security
  languageSetting: Language
```

### zh_CN.i18n.yaml

```yaml
hello: 你好
welcome: 欢迎 {name}
setting:
  title: 设置
  accountSecurity: 账户安全
  languageSetting: 语言设置
```

---

## 常见问题

### Q: 如何处理复数形式？

A: 使用 Slang 的复数支持：

```yaml
count:
  zero: 没有项目
  one: 1 个项目
  other: {n} 个项目
```

### Q: 如何处理动态键？

A: 使用 `AppLocale.current.string(key)`：

```dart
String dynamicKey = 'someKey';
final translation = AppLocale.current.string(dynamicKey);
```

### Q: 如何在数据模型中使用？

A: 需要导入并在 getter 中使用：

```dart
import 'package:imboy/i18n/strings.g.dart';

class UserModel {
  String get genderTitle {
    if (gender == 1) {
      return AppStrings.current.male;
    }
    return AppStrings.current.unknown;
  }
}
```

---

## 更多资源

- [Slang 官方文档](https://pub.dev/packages/slang)
- [Slang GitHub](https://github.com/slang-i18n/slang)
- [迁移脚本](../../script/migrate_translation_calls.dart)
- [迁移报告](../../script/migration_report.md)

# IMBoy 维护工具脚本 / Tooling Scripts

此目录包含用于维护 IMBoy 项目的实用脚本，重点在于 i18n（国际化）系统的优化和代码库重构。
This directory contains utility scripts for maintaining the IMBoy project, focusing on i18n optimization and codebase refactoring.

## i18n 优化工具 / i18n Optimization Tools

这些工具旨在将项目从单体翻译文件迁移到基于 `slang` 命名空间的模块化结构。
These tools were created to transition the project from monolithic translation files to a modular, namespaced structure using `slang`.

### 1. `split_i18n.dart` (翻译拆分工具 / Translation Splitting)

**用途 / Purpose:**
将平铺的 `.i18n.yaml` 文件按逻辑模块（如 `common`, `chat`, `account`）拆分为多个文件。
Splits flat `.i18n.yaml` files into multiple modular files based on logical namespaces.

*   **用法 / Usage:**
    ```bash
    dart tool/split_i18n.dart
    ```
*   **工作原理 / How it works:**
    *   读取 `assets/i18n/` 下的所有 YAML 文件。 / Reads all YAML files in `assets/i18n/`.
    *   使用脚本顶部定义的 `keyToNamespace` 映射表对键进行分类。 / Uses the `keyToNamespace` map defined in the script to categorize keys.
    *   自动处理 YAML 内部链接（例如将 `@:buttonCancel` 更新为 `@:common.buttonCancel`）。 / Automatically handles inner YAML links.
*   **自定义 / Customization:**
    如果你想创建新的命名空间或更改分类规则，请修改脚本内的 `keyToNamespace` 映射表。
    Edit the `keyToNamespace` map inside the script if you want to create new namespaces or change categorization.

### 2. `refactor_i18n_calls.dart` (代码重构工具 / Code Refactoring)

**用途 / Purpose:**
自动更新 `lib/` 目录下的 Dart 代码，使其使用新的命名空间访问器（例如将 `t.cancel` 更改为 `t.common.cancel`）。
Automatically updates Dart code across `lib/` to use the new namespaced accessors.

*   **用法 / Usage:**
    ```bash
    dart tool/refactor_i18n_calls.dart
    ```
*   **工作原理 / How it works:**
    1.  扫描 `assets/i18n/zh-CN/` 以动态构建键与命名空间的映射表。 / Scans `assets/i18n/zh-CN/` to build a key-to-namespace map.
    2.  使用正则表达式在 Dart 文件中查找翻译访问器。 / Uses regular expressions to find translation accessors.
    3.  **安全性 / Safety:** 实现了一个黑名单（`cancel`, `clear`, `dispose` 等），防止误伤代码中名为 `t` 的本地变量（如 `Timer t`）。 / Implements a blacklist to prevent accidentally renaming methods on local variables like `Timer t`.

---

## 未来调整结构的 SOP / Standard Operating Procedure (SOP) for Future Restructuring

如果你将来需要再次大规模调整翻译键的结构，请遵循以下流程：
If you ever need to heavily reorganize your translation keys again, follow this workflow:

1.  **修改规则 / Modify Rules:** 更新 `tool/split_i18n.dart` 中的 `keyToNamespace` 映射。 / Update the mapping in `tool/split_i18n.dart`.
2.  **拆分文件 / Split Files:** 运行 `dart tool/split_i18n.dart`。 / Run `dart tool/split_i18n.dart`.
3.  **重新生成代码 / Regenerate Code:** 运行 `dart run slang`（此时项目会出现分析错误）。 / Run `dart run slang` (analysis errors will appear).
4.  **修复代码 / Refactor Code:** 运行 `dart tool/refactor_i18n_calls.dart` 来修复访问器。 / Run `dart tool/refactor_i18n_calls.dart`.
5.  **验证 / Verify:** 运行 `dart analyze lib/` 并手动修复脚本遗漏的极端情况。 / Run `dart analyze lib/` and manually fix edge cases.

import 'dart:io';

/// golden 基线不入库的交付边界守卫。
///
/// 基线惯例：test/ 零跟踪 PNG（.gitignore `test/**/goldens/`，
/// CLAUDE.md 交付边界 + 用户确认 2026-10-17），基线由本地
/// `flutter test --update-goldens` 生成后仅存开发机。CI / 全新检出
/// 没有基线文件，此时相关用例 skip——`matchesGoldenFile` 对缺失文件
/// 会直接判失败，把「无基线可比较」误报成渲染回归。
///
/// [repoRelativePath] 传仓库根相对路径（flutter test 的工作目录是包根）。
bool goldenBaselineExists(String repoRelativePath) =>
    File(repoRelativePath).existsSync();

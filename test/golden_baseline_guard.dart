import 'dart:io';

import 'package:flutter_test/flutter_test.dart' show autoUpdateGoldenFiles;

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

/// 一个 testWidgets 内循环比对整组基线时的 skip 判定（取反后传给 `skip:`）。
///
/// `flutter test --update-goldens` 时恒为就绪——否则「没有基线 → 跳过 →
/// 永远生成不出基线」。CI 上恒为未就绪：像素比对只对生成基线的那台机器
/// 成立，runner 的 Flutter/字体栅格与开发机不同（run 39399556106：p1 已
/// 入库基线在 CI 上 "Pixel test failed"），比对结果不是渲染回归信号。
/// 其余情况任一基线缺失即视为未就绪，整组跳过。
bool goldenBaselinesReady(Iterable<String> repoRelativePaths) {
  if (autoUpdateGoldenFiles) return true;
  if (Platform.environment['CI'] == 'true') return false;
  return repoRelativePaths.every(goldenBaselineExists);
}

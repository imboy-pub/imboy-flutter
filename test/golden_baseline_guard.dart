import 'dart:io';

import 'package:flutter_test/flutter_test.dart' show autoUpdateGoldenFiles;

/// Golden 基线由维护者在固定 Flutter/engine/字体环境显式生成，保持本地
/// 交付边界；执行治理入口会核验基线与字体哈希后设置 required 标记。
/// 缺基线是环境阻塞，不是像素回归通过，也不能靠 CI 环境直接跳过。
bool get _goldenRequired =>
    Platform.environment['IMBOY_GOLDEN_REQUIRED'] == 'true';

/// [repoRelativePath] 是仓库根相对路径（flutter test 的工作目录是包根）。
bool goldenBaselineExists(String repoRelativePath) {
  final exists = File(repoRelativePath).existsSync();
  if (!exists && _goldenRequired) {
    throw StateError('ENV_MISSING: GOLDEN_BASELINE_MISSING:$repoRelativePath');
  }
  return exists;
}

/// 显式基线维护仍支持 --update-goldens。受治理的回归执行禁止更新基线，
/// 防止把新生成的图片当作已验证的像素回归证据。
bool goldenBaselinesReady(Iterable<String> repoRelativePaths) {
  if (autoUpdateGoldenFiles) {
    if (_goldenRequired) {
      throw StateError('GOLDEN_BASELINE_UPDATE_FORBIDDEN_DURING_REGRESSION');
    }
    return true;
  }
  return repoRelativePaths.every(goldenBaselineExists);
}

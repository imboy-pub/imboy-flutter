import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// GL-26：AppLogger 是 lib/ 内唯一允许构造 Logger 的出口。
///
/// 旧的三个私有 Logger 已统一迁移；不再要求它们继续存在。
/// 禁止在豁免文件之外构造实例，连同 Logger().e(...) 直接调用一起覆盖，
/// 避免绕过 LogRedactor 与 ErrorReportEvent。合成正反例证明检测器有效，
/// AppLogger 的真实构造则保留为非空的生产锚点。
void main() {
  // AppLogger 定义文件：唯一合法的 Logger 消费出口。
  const exemptFiles = <String>{'lib/service/app_logger.dart'};

  final loggerConstructorPattern = RegExp(
    r'\bLogger\s*(?:\.\s*[A-Za-z_]\w*\s*)?\(',
  );

  Iterable<File> libDartFiles() =>
      Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .where((f) => !exemptFiles.contains(f.path));

  test('Logger 构造检测器识别正例并排除普通日志调用', () {
    for (final source in [
      'var logger = Logger();',
      'static final Logger renamed = Logger(printer: printer);',
      "Logger().e('synthetic');",
      'final log = logging.Logger();',
      'final log = Logger.named();',
    ]) {
      expect(loggerConstructorPattern.hasMatch(source), isTrue, reason: source);
    }
    for (final source in [
      "AppLogger.error('synthetic');",
      "_getLogger().w('synthetic');",
      'Logger? cached;',
      'final log = CustomLogger();',
    ]) {
      expect(
        loggerConstructorPattern.hasMatch(source),
        isFalse,
        reason: source,
      );
    }
  });

  test('lib/ 内只有 AppLogger 可以构造 Logger（GL-26 守护）', () {
    final violations = [
      for (final file in libDartFiles())
        if (loggerConstructorPattern.hasMatch(file.readAsStringSync()))
          file.path,
    ];
    expect(
      violations,
      isEmpty,
      reason:
          '发现 AppLogger 之外的 Logger 构造，日志必须经统一脱敏出口（GL-26）：\n'
          '${violations.join('\n')}',
    );
  });

  test('AppLogger 仍是 lib/ 内 Logger 实例化的唯一豁免出口（接线契约锁）', () {
    // 若 AppLogger 定义文件被移动/重命名，上面的 exemptFiles 将失效，
    // 本测试通过"app_logger.dart 仍存在且持有 Logger 构造"锁住该契约。
    final appLoggerFile = File('lib/service/app_logger.dart');
    expect(
      appLoggerFile.existsSync(),
      isTrue,
      reason:
          'lib/service/app_logger.dart 不存在：豁免清单失效，请更新'
          '本守护测试的 exemptFiles',
    );
    expect(
      loggerConstructorPattern.hasMatch(appLoggerFile.readAsStringSync()),
      isTrue,
      reason: 'app_logger.dart 不再持有 Logger 实例化（出口重构？）',
    );
  });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// GL-26（C05-fix）守护：lib/ 内不得存在绕过 [AppLogger] 的
/// logger 包实例 `.e` / `.f` / `.w` 直接调用。
///
/// 背景（W1-review C05 observation）：C05 把 LogRedactor 接线到
/// `AppLogger.error/fatal` 出口（message+error 双脱敏 + ErrorReportEvent
/// 携带脱敏值），但基线存在 20 处直接 `logger.e/_logger.e/_msgLogger.e`
/// （及 `.w`）调用——迁移 SQL、token 刷新异常等只走本地 console，不经
/// 脱敏。本守护锁定"error/fatal/warning 级别单一出口"：
///
/// 1. 动态收集 lib/ 内全部 `xxx = Logger(` 实例化目标的变量名
///    （新增 Logger 实例自动纳入守护，无需改测试）；
/// 2. 断言这些变量名在 lib/ 内没有任何 `.e(`/`.f(`/`.w(` 调用；
/// 3. 硬锚点：已知实例（logger / _logger / _msgLogger）必须仍被收集到
///    ——防止收集正则失配导致空集恒真（与 C05 注册表对账测试的
///    "表→源码无死条目"同思想）。
///
/// 排除 `lib/service/app_logger.dart`：它是唯一合法出口，内部
/// `_getLogger().e(...)` 传入的是已脱敏值。
///
/// `.i` / `.d` 级别不在本守护范围（AppLogger.info/debug 仅 debug 模式
/// 输出、非 ErrorReportEvent 来源；Logger 实例保留供这些级别使用）。
void main() {
  // AppLogger 定义文件：唯一合法的 Logger 消费出口。
  const exemptFiles = <String>{'lib/service/app_logger.dart'};

  /// 赋值目标为 Logger 构造的变量名，如：
  /// `var logger = Logger()` / `static final Logger _logger = Logger()` /
  /// `final _msgLogger = Logger(printer: ...)`
  final loggerInstancePattern = RegExp(r'\b([A-Za-z_]\w*)\s*=\s*Logger\s*\(');

  Iterable<File> libDartFiles() =>
      Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .where((f) => !exemptFiles.contains(f.path));

  test('lib/ 内不存在 logger 包实例的 .e/.f/.w 直接调用（GL-26 守护）', () {
    // 层1：动态收集全部 Logger 实例变量名。
    final instanceNames = <String>{};
    for (final file in libDartFiles()) {
      final source = file.readAsStringSync();
      for (final match in loggerInstancePattern.allMatches(source)) {
        instanceNames.add(match.group(1)!);
      }
    }

    // 层3（硬锚点）：已知基线实例必须仍被收集到，否则收集层失效。
    expect(
      instanceNames,
      containsAll(<String>['logger', '_logger', '_msgLogger']),
      reason:
          'Logger 实例收集正则失配（实例已重命名或删除？请同步更新'
          '本守护测试的锚点清单）',
    );

    // 层2：任何被收集的实例名都不得有 .e/.f/.w 直调。
    final violations = <String>[];
    for (final file in libDartFiles()) {
      final source = file.readAsStringSync();
      for (final name in instanceNames) {
        final callPattern = RegExp(
          '\\b${RegExp.escape(name)}'
          r'\s*\.\s*(?:e|f|w)\s*\(',
        );
        if (callPattern.hasMatch(source)) {
          violations.add(
            '${file.path}: $name.(e|f|w) 直调（绕过 AppLogger '
            '→ 绕过 LogRedactor 脱敏与 ErrorReportEvent）',
          );
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          '发现绕过 AppLogger 的错误/警告级日志直调，请改用 '
          'AppLogger.error/fatal/warning（GL-26）：\n'
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
      appLoggerFile.readAsStringSync(),
      contains('Logger('),
      reason: 'app_logger.dart 不再持有 Logger 实例化（出口重构？）',
    );
  });
}

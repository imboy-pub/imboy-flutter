import 'package:sentry_flutter/sentry_flutter.dart';

class SentryService {
  /// Sentry DSN - 需要人工配置
  /// 从 Sentry 项目设置获取: https://sentry.io/settings/
  static const String _dsn = '';  // TODO: 配置 Sentry DSN

  static bool get isEnabled => _dsn.isNotEmpty;

  static Future<void> init() async {
    if (!isEnabled) return;
    // 初始化在 main.dart 中通过 SentryFlutter.init 完成
  }

  static Future<void> captureException(
    dynamic exception, {
    dynamic stackTrace,
    String? hint,
  }) async {
    if (!isEnabled) return;
    await Sentry.captureException(exception, stackTrace: stackTrace);
  }
}

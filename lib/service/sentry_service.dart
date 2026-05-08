import 'package:sentry_flutter/sentry_flutter.dart';

class SentryService {
  /// Sentry DSN - 通过 --dart-define=SENTRY_DSN=https://... 在构建时注入
  /// 从 Sentry 项目设置获取: https://sentry.io/settings/
  /// 构建示例: flutter build apk --dart-define=SENTRY_DSN=https://xxx@sentry.io/yyy
  static const String _dsn = String.fromEnvironment(
    'SENTRY_DSN',
    defaultValue: '',
  );

  static String get dsn => _dsn;
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

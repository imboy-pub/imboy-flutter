import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'config/init.dart';
import 'page/error/init_error_page.dart';
import 'run.dart';
import 'service/sentry_service.dart';

/// 通过 --dart-define=APP_ENV=xxx 指定运行环境
/// 可用环境: pro, dev, local_home, local_office
/// 默认环境: pro
const String appEnv = String.fromEnvironment('APP_ENV', defaultValue: 'pro');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await bootstrap();
}

/// 完整启动链：init →（release 且开启时）Sentry 包裹 → run。
///
/// #95：init 失败不再永久白屏——渲染 [InitErrorPage]，用户点「重试」
/// 重新进入本函数（AppInitializer._initialized 仅在成功后置位，可重入）。
Future<void> bootstrap() async {
  try {
    await AppInitializer.initialize(env: appEnv, signKeyVsn: '1');
  } catch (e) {
    runApp(InitErrorPage(error: e, onRetry: bootstrap));
    return;
  }

  if (!kDebugMode && SentryService.isEnabled) {
    await SentryFlutter.init(
      (options) {
        options.dsn = SentryService.dsn;
        options.tracesSampleRate = 0.2;
        options.environment = appEnv;
      },
      appRunner: () async {
        await run();
      },
    );
  } else {
    await run();
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'config/init.dart';
import 'run.dart';
import 'service/sentry_service.dart';

/// 通过 --dart-define=APP_ENV=xxx 指定运行环境
/// 可用环境: pro, dev, local_home, local_office
/// 默认环境: pro
const String appEnv = String.fromEnvironment('APP_ENV', defaultValue: 'pro');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await AppInitializer.initialize(env: appEnv, signKeyVsn: '1');
  } catch (e) {
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

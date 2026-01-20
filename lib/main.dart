import 'package:flutter/material.dart';
//import 'package:sentry_flutter/sentry_flutter.dart';

//import 'package:imboy/config/const.dart';

import 'config/init.dart';
import 'run.dart';

/// 通过 --dart-define=APP_ENV=xxx 指定运行环境
/// 可用环境: pro, dev, local_home, local_office
/// 默认环境: pro
const String appEnv = String.fromEnvironment('APP_ENV', defaultValue: 'pro');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await AppInitializer.initialize(env: appEnv, signKeyVsn: '1');
    run();
  } catch (e, s) {
    // logger.e("Application initialization failed", error: e);
    debugPrint("Application initialization failed: $e, $s");
  }
  // var v = SignKeyFFI.signKey("input");
  // debugPrint("signKey $v ;");
  // await initJPush();
  // if (kDebugMode) {
  // run();
  // } else {
  //   await SentryFlutter.init(
  //     (options) {
  //       options.dsn = SENTRY_DSN;
  //     },
  //     appRunner: () async {
  //       run();
  //     },
  //   );
  // }
}

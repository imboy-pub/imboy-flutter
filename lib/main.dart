import 'package:flutter/material.dart';
//import 'package:sentry_flutter/sentry_flutter.dart';

//import 'package:imboy/config/const.dart';

import 'config/init.dart';
import 'run.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await AppInitializer.initialize(
      env: 'pro',  // 默认环境
      signKeyVsn: '1',
    );
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

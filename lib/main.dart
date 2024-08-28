import 'package:flutter/material.dart';
//import 'package:sentry_flutter/sentry_flutter.dart';

//import 'package:imboy/config/const.dart';

import 'config/init.dart';
import 'run.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await init(env: 'pro', signKeyVsn: '1');

  // var v = SignKeyFFI.signKey("input");
  // debugPrint("signKey $v ;");
  // await initJPush();
  // if (kDebugMode) {
  run();
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

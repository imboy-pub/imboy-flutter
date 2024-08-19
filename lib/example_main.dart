//import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
//import 'package:sentry_flutter/sentry_flutter.dart';

//import 'package:imboy/config/const.dart';

import 'config/init.dart';
import 'run.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // solidifiedKey 不能为空的
  await init(
    env: 'dev',
    signKeyVsn: '1',
    solidifiedKey: '',
    iv: '',
  );

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

//import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
//import 'package:sentry_flutter/sentry_flutter.dart';

//import 'package:imboy/config/const.dart';

import 'config/init.dart';
import 'run.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env"); //
  await init();
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

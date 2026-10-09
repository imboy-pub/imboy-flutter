import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/main.dart' as app;

/// Call inside testWidgets so the saved handlers belong to its test binding.
Future<void> launchOwnedUi(WidgetTester tester) async {
  final frameworkHandler = FlutterError.onError;
  final platformHandler = PlatformDispatcher.instance.onError;
  try {
    await app.bootstrap();
  } finally {
    FlutterError.onError = frameworkHandler;
    PlatformDispatcher.instance.onError = platformHandler;
  }
  await tester.pump();
}

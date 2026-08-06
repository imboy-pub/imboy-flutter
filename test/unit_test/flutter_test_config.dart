import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(pathProviderChannel, (methodCall) async {
        switch (methodCall.method) {
          case 'getTemporaryDirectory':
          case 'getApplicationDocumentsDirectory':
          case 'getApplicationSupportDirectory':
          case 'getLibraryDirectory':
          case 'getExternalStorageDirectory':
          case 'getExternalCacheDirectories':
          case 'getDownloadsDirectory':
          case 'getDatabasesPath':
            return Directory.systemTemp.path;
          default:
            return Directory.systemTemp.path;
        }
      });

  SharedPreferences.setMockInitialValues(<String, Object>{});
  await StorageService.init();

  try {
    await testMain();
  } finally {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
  }
}

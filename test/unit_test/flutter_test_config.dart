import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'smoke/smoke_test_harness.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 全局禁网：unit_test 下任何套件都不应打真实网络（含页面 initState 的
  // 隐式探测请求——e2ee_backup_import_page 的 _probeCloudBackup 曾因这里
  // 未安装 HttpOverrides 而真实打到生产 pro.imboy.pub）。返回空 200，
  // 解析失败由各调用方按「探测失败静默」口径吞掉。smoke 套件 setUpAll
  // 重复安装同实现，幂等无害。
  installSmokeHttpOverrides();

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

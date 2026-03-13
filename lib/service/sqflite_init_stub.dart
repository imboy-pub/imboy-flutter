/// SQLite 数据库工厂初始化 - 非 Web 平台存根
///
/// 用于 iOS、Android、macOS、Windows、Linux 等平台
library;

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// 初始化 SQLite 数据库工厂
/// 非 Web 平台使用 sqflite_common_ffi（桌面端）
/// 移动端不需要 FFI，sqflite 包自带实现
void initSqfliteFactory() {
  if (kIsWeb) {
    throw UnsupportedError('initSqfliteFactory_stub 不应在 Web 平台调用');
  }

  // Android/iOS 使用 sqflite 原生实现，不应切换到 ffi factory。
  if (Platform.isAndroid || Platform.isIOS) {
    return;
  }

  // 桌面平台需要 FFI 初始化。
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
}

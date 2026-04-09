/// SQLite 数据库工厂初始化 - 非 Web 平台存根
///
/// 用于 iOS、Android、macOS、Windows、Linux 等平台
/// SQLCipher 加密支持：
/// - iOS/Android/macOS：通过 sqflite_sqlcipher 原生支持
/// - Windows/Linux：通过 sqflite_common_ffi（当前不加密，未来可接入 SQLite3MultipleCiphers）
library;

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite_common/sqflite.dart' as common show databaseFactory;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;
import 'package:sqflite_sqlcipher/sqflite.dart';

/// 初始化 SQLite 数据库工厂
/// 非 Web 平台使用 sqflite_common_ffi（桌面端）
/// 移动端不需要 FFI，sqflite_sqlcipher 包自带实现
void initSqfliteFactory() {
  if (kIsWeb) {
    throw UnsupportedError('initSqfliteFactory_stub 不应在 Web 平台调用');
  }

  // Android/iOS/macOS 使用 sqflite_sqlcipher 原生实现，不需要切换工厂。
  if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
    return;
  }

  // Windows/Linux 桌面平台需要 FFI 初始化。
  ffi.sqfliteFfiInit();
  common.databaseFactory = ffi.databaseFactoryFfi;
}

/// 当前平台是否支持数据库加密
///
/// - iOS/Android/macOS：支持（sqflite_sqlcipher）
/// - Windows/Linux：暂不支持（需要 SQLite3MultipleCiphers，Phase 2+）
/// - Web：不支持
bool get isEncryptionSupported {
  if (kIsWeb) return false;
  return Platform.isAndroid || Platform.isIOS || Platform.isMacOS;
}

/// 打开加密数据库
///
/// 在支持加密的平台上，使用 sqflite_sqlcipher 的 password 参数。
/// 在不支持加密的平台上，忽略 password 参数打开明文数据库。
///
/// [path] 数据库文件路径
/// [password] 加密密钥（仅在 isEncryptionSupported 为 true 时生效）
/// [version] 数据库版本号
/// [onConfigure] 配置回调
/// [onCreate] 创建回调
/// [onUpgrade] 升级回调
/// [onDowngrade] 降级回调
/// [onOpen] 打开回调
Future<Database> openEncryptedDatabase(
  String path, {
  String? password,
  int? version,
  OnDatabaseConfigureFn? onConfigure,
  OnDatabaseCreateFn? onCreate,
  OnDatabaseVersionChangeFn? onUpgrade,
  OnDatabaseVersionChangeFn? onDowngrade,
  OnDatabaseOpenFn? onOpen,
}) async {
  final effectivePassword = isEncryptionSupported ? password : null;

  return await openDatabase(
    path,
    password: effectivePassword,
    version: version,
    onConfigure: onConfigure,
    onCreate: onCreate,
    onUpgrade: onUpgrade,
    onDowngrade: onDowngrade,
    onOpen: onOpen,
  );
}

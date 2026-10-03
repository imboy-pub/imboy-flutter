import 'dart:math';

import 'package:imboy/service/storage_secure.dart';

/// 数据库加密密钥管理服务
///
/// 专门管理 SQLCipher 数据库的加密密钥。
/// 每个用户独立密钥（数据库文件本身已按 uid 隔离）。
///
/// 设计决策：
/// - 密钥不轮换（数据库密钥轮换需要重新加密整个数据库，代价极高）
/// - 密钥为 32 字节随机数的 hex 编码（SQLCipher 推荐格式）
/// - 通过 flutter_secure_storage 持久化。实际保护级别（C05 核查，
///   与 StorageSecureService 配置一致，不得虚标）：
///   - iOS：Keychain，kSecAttrAccessibleAfterFirstUnlockThisDevice
///     （ThisDeviceOnly：不随 iCloud 备份迁移到新设备）
///   - Android：默认实现 = Android Keystore 生成/保管的 AES 密钥加密
///     后写入 SharedPreferences（**未启用** EncryptedSharedPreferences，
///     亦未声明 StrongBox/Secure Enclave 等硬件不可导出属性——密钥
///     保护上限是 OS Keystore 软件隔离 + 沙箱）
///   - fail-closed：secure storage 读取/写入抛异常时本服务向上抛，
///     SqliteService 不会拿到空密码降级打开明文库
class DbEncryptionKeyService {
  DbEncryptionKeyService._();

  /// 存储 key 前缀，按用户 uid 隔离
  static String _storageKey(String uid) => 'db_cipher_key_$uid';

  /// 获取或创建数据库加密密钥
  ///
  /// 如果密钥不存在，生成一个 256-bit 随机密钥并持久化到安全存储。
  /// 如果密钥已存在，直接返回。
  static Future<String> getOrCreateKey(String uid) async {
    final key = _storageKey(uid);
    final existing = await StorageSecureService.to.read(key: key);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    final newKey = _generateKey();
    await StorageSecureService.to.write(key: key, value: newKey);
    return newKey;
  }

  /// 检查指定用户是否已有加密密钥
  static Future<bool> hasKey(String uid) async {
    final existing = await StorageSecureService.to.read(key: _storageKey(uid));
    return existing != null && existing.isNotEmpty;
  }

  /// 删除密钥（仅用于调试或账号注销）
  ///
  /// 警告：删除密钥后将无法打开对应的加密数据库！
  static Future<void> deleteKey(String uid) async {
    await StorageSecureService.to.delete(key: _storageKey(uid));
  }

  /// 生成 256-bit 随机密钥
  ///
  /// 输出格式：hex 编码的 64 字符字符串
  /// SQLCipher 支持多种密钥格式，hex 格式兼容性最好且可读性强。
  static String _generateKey() {
    final rand = Random.secure();
    final bytes = List<int>.generate(32, (_) => rand.nextInt(256));
    // 使用 hex 编码（SQLCipher 原生支持 "x'...' " 格式）
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 安全存储服务 - 基于 FlutterSecureStorage
/// Secure storage service based on FlutterSecureStorage
///
/// 职责：
/// - 提供安全的键值对存储（数据加密存储）
/// - 适用于存储敏感信息（如 Token、密钥等）
/// - 支持多平台（iOS Keychain、Android Keystore）
///
/// 使用方式：
/// ```dart
/// // 写入
/// await StorageSecureService.to.write(
///   key: 'token',
///   value: 'secret_token',
/// );
///
/// // 读取
/// String? token = await StorageSecureService.to.read(key: 'token');
///
/// // 删除
/// await StorageSecureService.to.delete(key: 'token');
/// ```
///
/// 迁移说明：
/// - 使用标准 Dart 单例模式
/// - 提供 `.to` 静态访问方式（与项目其他服务保持一致）
/// - 保留 factory 构造函数以向后兼容
class StorageSecureService {
  // 单例实例
  static final StorageSecureService _instance =
      StorageSecureService._internal();

  // FlutterSecureStorage 实例
  final FlutterSecureStorage _self = const FlutterSecureStorage();

  /// 获取单例实例（推荐使用）
  /// Get singleton instance (recommended)
  static StorageSecureService get to => _instance;

  /// Factory 构造函数（向后兼容）
  /// Factory constructor (for backward compatibility)
  factory StorageSecureService() {
    return _instance;
  }

  /// 私有构造函数
  /// Private constructor
  StorageSecureService._internal();

  /// Encrypts and saves the [key] with the given [value].
  ///
  /// If the key was already in the storage, its associated value is changed.
  /// If the value is null, deletes associated value for the given [key].
  /// [key] shouldn't be null.
  /// [value] required value
  /// [iOptions] optional iOS options
  /// [aOptions] optional Android options
  /// [lOptions] optional Linux options
  /// [webOptions] optional web options
  /// [mOptions] optional MacOs options
  /// [wOptions] optional Windows options
  /// Can throw a [PlatformException].
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return _self.write(
      key: key,
      value: value,
      iOptions: iOptions,
      aOptions: aOptions,
      lOptions: lOptions,
      webOptions: webOptions,
      mOptions: mOptions,
      wOptions: wOptions,
    );
  }

  /// Decrypts and returns the value for the given [key] or null if [key] is not in the storage.
  ///
  /// [key] shouldn't be null.
  /// [iOptions] optional iOS options
  /// [aOptions] optional Android options
  /// [lOptions] optional Linux options
  /// [webOptions] optional web options
  /// [mOptions] optional MacOs options
  /// [wOptions] optional Windows options
  /// Can throw a [PlatformException].
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) => _self.read(
    key: key,
    iOptions: iOptions,
    aOptions: aOptions,
    lOptions: lOptions,
    webOptions: webOptions,
    mOptions: mOptions,
    wOptions: wOptions,
  );

  /// Deletes associated value for the given [key].
  ///
  /// If the given [key] does not exist, nothing will happen.
  ///
  /// [key] shouldn't be null.
  /// [iOptions] optional iOS options
  /// [aOptions] optional Android options
  /// [lOptions] optional Linux options
  /// [webOptions] optional web options
  /// [mOptions] optional MacOs options
  /// [wOptions] optional Windows options
  /// Can throw a [PlatformException].
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) => _self.delete(
    key: key,
    iOptions: iOptions,
    aOptions: aOptions,
    lOptions: lOptions,
    webOptions: webOptions,
    mOptions: mOptions,
    wOptions: wOptions,
  );
}

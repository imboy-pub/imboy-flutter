/// RSA 加密服务 - Web 平台存根
///
/// 用于非 Web 平台（iOS、Android、macOS 等）
/// 避免导入 package:web 导致的编译错误
library;

/// Web 存储存根类
///
/// 在非 Web 平台返回空实现，避免编译错误
class WebStorageStub {
  /// 获取本地存储项
  String? getItem(String key) => null;

  /// 设置本地存储项
  void setItem(String key, String value) {}

  /// 移除本地存储项
  void removeItem(String key) {}

  /// 清空本地存储
  void clear() {}
}

/// Web 窗口存根类
///
/// 在非 Web 平台返回空实现
class WebWindowStub {
  final WebStorageStub _localStorage = WebStorageStub();

  /// 获取 localStorage
  WebStorageStub get localStorage => _localStorage;
}

/// Web 窗口实例
///
/// 在非 Web 平台使用存根
WebWindowStub get webWindow => WebWindowStub();

/// RSA 加密 - Web 平台存根
///
/// 在非 Web 平台（iOS、Android、macOS 等）
/// 此函数不应该被调用（调用者应检查 kIsWeb）
Future<String> rsaEncryptWeb(String plaintext, String pubKeyPem) async {
  throw UnsupportedError(
    'rsaEncryptWeb 只能在 Web 平台使用。非 Web 平台应使用 rsaEncryptWithPointyCastle。',
  );
}

/// RSA 密钥对生成 - Web 平台存根
///
/// 在非 Web 平台（iOS、Android、macOS 等）
/// 此函数不应该被调用（调用者应检查 kIsWeb）
Future<Map<String, String>> generateRSAKeyPairWeb() async {
  throw UnsupportedError(
    'generateRSAKeyPairWeb 只能在 Web 平台使用。非 Web 平台应使用 E2EEKeyService。',
  );
}

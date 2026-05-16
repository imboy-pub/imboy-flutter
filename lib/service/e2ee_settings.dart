/// E2EE（端到端加密）设置服务
///
/// 管理E2EE功能的开关和配置
library;

import 'package:imboy/service/storage.dart';

/// E2EE设置服务
///
/// 提供E2EE功能的开关管理和相关配置
class E2EESettings {
  // 存储键常量
  static const String _keyEnabled = 'e2ee_enabled';
  static const String _keyNotifyOnFailed = 'e2ee_notify_on_failed';

  /// E2EE 功能是否启用
  ///
  /// 永远返回 false（**强制关闭** E2EE）。
  /// 原因：开发环境多次 build/重装客户端会导致本地 Keychain 里的 RSA 私钥与
  /// 服务端 user_device 表中的公钥 / 对端缓存的公钥不匹配，加密消息对端无法
  /// 解密、只看到 `🔒 [加密消息无法解密]`。当后端 policy 为 plaintext /
  /// optional 时，强制关闭本地 E2EE 让消息走明文路径，保证对端能正确显示文本。
  /// 后端 policy 若强制加密 (EncryptionModeService.requiresEncryption)，
  /// 仍会按策略走 e2ee 路径（policy 优先于本地开关）。
  static bool isEnabled() {
    // 旧版本会读取 storage 中 _keyEnabled，但 storage 持久化的 true 值会让
    // 已安装客户端在策略 = optional 时仍走加密路径并失败。统一返回 false，
    // 让 e2ee 完全由后端 policy 控制，避免客户端 storage 漂移。
    return false;
  }

  /// 设置E2EE功能开关
  ///
  /// [enabled] true=启用E2EE，false=关闭E2EE
  static Future<void> setEnabled(bool enabled) {
    return StorageService.to.setBool(_keyEnabled, enabled);
  }

  /// 是否在E2EE失败时通知用户
  ///
  /// 默认返回 true（默认通知用户）
  static bool shouldNotifyOnFailed() {
    return StorageService.to.getBool(_keyNotifyOnFailed) ?? true;
  }

  /// 设置E2EE失败时是否通知用户
  ///
  /// [notify] true=通知用户，false=不通知
  static Future<void> setNotifyOnFailed(bool notify) {
    return StorageService.to.setBool(_keyNotifyOnFailed, notify);
  }

  /// 重置所有E2EE设置为默认值
  ///
  /// 仅用于测试或调试
  static Future<void> resetToDefaults() async {
    await StorageService.to.remove(_keyEnabled);
    await StorageService.to.remove(_keyNotifyOnFailed);
  }
}

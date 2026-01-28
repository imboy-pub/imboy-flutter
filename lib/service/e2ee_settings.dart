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

  /// E2EE功能是否启用
  ///
  /// 默认返回 true（默认启用E2EE）
  /// 用户可以在设置中关闭
  static bool isEnabled() {
    return StorageService.to.getBool(_keyEnabled) ?? true;
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

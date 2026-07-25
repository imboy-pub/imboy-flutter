/// E2EE（端到端加密）设置服务
///
/// 加密决策由后端 imboy_policy 的 e2ee_mode capability 全权接管，
/// 客户端 EncryptionModeService 镜像该 policy。本类仅保留：
/// - isEnabled(): 兜底返回 false（policy=plaintext 时走明文）
/// - shouldNotifyOnFailed() / setNotifyOnFailed(): E2EE 失败通知偏好
library;

import 'package:imboy/service/storage.dart';

/// E2EE设置服务
class E2EESettings {
  static const String _keyNotifyOnFailed = 'e2ee_notify_on_failed';

  /// E2EE 功能是否启用——永远返回 false。
  //
  // ponytail: 本地开关已废弃，加密由后端 policy 接管。
  // 历史根因：开发环境多次 build/重装导致本地 Keychain 的 RSA 私钥与服务端
  // user_device 表公钥 / 对端缓存公钥漂移，加密消息对端无法解密、只看到
  // `🔒 [加密消息无法解密]`。统一返回 false，让 e2ee 完全由后端 policy 控制。
  // 后端 policy 强制加密 (EncryptionModeService.requiresEncryption) 时，
  // 出站路径 policy 优先、本类不参与决策（见 e2ee_service.dart:130）。
  // 上限：客户端完全失去自主加密能力——policy=plaintext 的部署下，用户即便
  // 想加密也只能发明文，且 UI 无从表达"我要加密"。
  // 升级触发：后端 policy 提供 per-user / per-conversation 的 opt-in 位（即
  // 同一部署内允许用户自选加密）时，本方法改为读该位而非恒 false；届时必须
  // 先解决上面的历史根因——本地 Keychain 私钥与服务端 user_device 公钥漂移的
  // 检测与自动重注册，否则会退回"对端只看到 🔒 无法解密"的老问题。
  static bool isEnabled() => false;

  /// 是否在E2EE失败时通知用户（默认 true）
  static bool shouldNotifyOnFailed() {
    return StorageService.to.getBool(_keyNotifyOnFailed) ?? true;
  }

  /// 设置E2EE失败时是否通知用户
  static Future<void> setNotifyOnFailed(bool notify) {
    return StorageService.to.setBool(_keyNotifyOnFailed, notify);
  }
}

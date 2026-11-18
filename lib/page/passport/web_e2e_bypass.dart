/// Web E2E debug 测试旁路配置（无副作用的 sealed 决策）。
///
/// 仅 debug 构建允许用合成 token/uid 注入测试会话。profile/release 编译时
/// 强制禁用，即使误传 WEB_E2E_TOKEN / WEB_E2E_UID 也不能启动旁路。
/// 默认空值只是未配置，不是交付安全证明；正式产物仍须核查无旁路凭据，
/// 普通 Human 扫码授权须独立验收。
///
/// 仅用于隔离 debug 测试：
/// ```bash
/// flutter run -d chrome --debug \
///   --dart-define=WEB_E2E_TOKEN=<synthetic-token> \
///   --dart-define=WEB_E2E_UID=<synthetic-user-id>
/// ```
///
/// 本模块不发请求、不持久化、不导航；副作用仍由 WebLoginPage 复用现有
/// loginAfterQr 会话提交边界。不得把 debug 旁路结果当普通登录验收。
library;

import 'package:flutter/foundation.dart' show kDebugMode;

/// 旁路配置的密封变体（穷尽两个分支）
sealed class WebE2eBypassConfig {
  const WebE2eBypassConfig();
}

/// 交付构建或未配置旁路时，走普通 QR 扫码登录。
final class BypassDisabled extends WebE2eBypassConfig {
  const BypassDisabled();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is BypassDisabled;

  @override
  int get hashCode => 0;

  @override
  String toString() => 'BypassDisabled()';
}

/// 测试路径：直接以 token + uid 注入登录态
final class BypassEnabled extends WebE2eBypassConfig {
  /// Bearer token（写入 SecureTokenStorageService）
  final String token;

  /// 用户 ID（写入 StorageService.currentUid）
  final String uid;

  const BypassEnabled({required this.token, required this.uid});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BypassEnabled && other.token == token && other.uid == uid;

  @override
  int get hashCode => Object.hash(token, uid);

  @override
  String toString() => 'BypassEnabled(token: <redacted>)';
}

/// 解析旁路配置。
///
/// [token] / [uid] 通常来自 `String.fromEnvironment('WEB_E2E_TOKEN')` /
/// `String.fromEnvironment('WEB_E2E_UID')`。
///
/// 实际编译模式不是 debug 或任一凭据为空时，返回 [BypassDisabled]。
/// [debugBuild] 允许测试进一步收紧为禁用，不能覆盖实际构建模式开启旁路。
WebE2eBypassConfig parseE2eBypassConfig({
  required String token,
  required String uid,
  bool debugBuild = kDebugMode,
}) {
  if (!kDebugMode ||
      !debugBuild ||
      token.trim().isEmpty ||
      uid.trim().isEmpty) {
    return const BypassDisabled();
  }
  return BypassEnabled(token: token, uid: uid);
}

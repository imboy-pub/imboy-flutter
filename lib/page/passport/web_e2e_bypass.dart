/// Step 2 — Web E2E 测试旁路配置（纯函数 + sealed 决策）
///
/// 目的：让 Chrome 自动化测试（chromedriver / Playwright）跳过 QR 扫码登录，
/// 直接注入登录态。生产构建因 `String.fromEnvironment` 默认值为 ''，自动走
/// BypassDisabled 分支，**生产代码零运行时开销 + 零安全风险**。
///
/// 启用方式（仅测试 / CI）：
/// ```bash
/// flutter run -d chrome \
///   --dart-define=WEB_E2E_TOKEN=<jwt-or-bearer-token> \
///   --dart-define=WEB_E2E_UID=<user-id>
/// ```
///
/// 安全约束：
/// - token 或 uid 任一为空（含空白字符）→ 旁路禁用
/// - 不在本模块做任何副作用（saveToken / setCurrentUid / 路由跳转）
///   —— 副作用由 web_login_page.dart 的 initState 在 switch BypassEnabled 时
///   显式执行，便于审计和 grep
/// - 无网络调用、无持久化 → 纯函数，零外部依赖
library;

/// 旁路配置的密封变体（穷尽两个分支）
sealed class WebE2eBypassConfig {
  const WebE2eBypassConfig();
}

/// 默认（生产）路径：走 QR 扫码登录
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
  String toString() => 'BypassEnabled(uid: $uid, token: <$token-len>)';
}

/// 解析旁路配置。
///
/// [token] / [uid] 通常来自 `String.fromEnvironment('WEB_E2E_TOKEN')` /
/// `String.fromEnvironment('WEB_E2E_UID')`。
///
/// 任一参数为空（trim 后）即返回 [BypassDisabled]，避免误开旁路（例如 dart-define
/// 拼写错误传入 `=` 后空字符串）。
WebE2eBypassConfig parseE2eBypassConfig({
  required String token,
  required String uid,
}) {
  if (token.trim().isEmpty || uid.trim().isEmpty) {
    return const BypassDisabled();
  }
  return BypassEnabled(token: token, uid: uid);
}

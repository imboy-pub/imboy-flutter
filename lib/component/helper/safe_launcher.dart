import 'package:url_launcher/url_launcher.dart';

/// 安全调用 launchUrl 的封装，执行 scheme 白名单验证。
///
/// 允许的 scheme：http, https, mailto, tel, sms
/// 以及系统设置跳转使用的 x-apple.systempreferences（Apple 官方拼写为点号）
/// 等系统 scheme。
///
/// 任何不在白名单中的 scheme（如 ftp://, javascript://, file:// 等）
/// 将被拒绝，防止恶意 URL 通过消息/频道内容诱导用户打开危险链接。
class SafeLauncher {
  /// 默认允许的 scheme 白名单
  static const Set<String> _allowedSchemes = {
    'http',
    'https',
    'mailto',
    'tel',
    'sms',
    'x-apple.systempreferences',
    'app-settings',
  };

  /// 检查 scheme 是否在白名单中
  static bool isSchemeAllowed(String scheme) {
    return _allowedSchemes.contains(scheme.toLowerCase());
  }

  /// 安全打开 URL：先检查 scheme 白名单，再调用 canLaunchUrl + launchUrl。
  ///
  /// [uri] 要打开的 URI
  /// [mode] launch 模式，默认 externalApplication
  /// [onBlocked] scheme 被拒绝时的回调，默认 null 时不额外处理
  /// 返回 true 表示成功打开，false 表示被拒绝或无法打开。
  static Future<bool> safeLaunchUrl(
    Uri uri, {
    LaunchMode mode = LaunchMode.externalApplication,
    void Function(String scheme)? onBlocked,
  }) async {
    if (!isSchemeAllowed(uri.scheme)) {
      onBlocked?.call(uri.scheme);
      return false;
    }
    if (!await canLaunchUrl(uri)) {
      return false;
    }
    return await launchUrl(uri, mode: mode);
  }

  /// 安全打开 URL 字符串版本
  static Future<bool> safeLaunchUrlString(
    String urlString, {
    LaunchMode mode = LaunchMode.externalApplication,
    void Function(String scheme)? onBlocked,
  }) async {
    final uri = Uri.tryParse(urlString);
    if (uri == null) return false;
    return safeLaunchUrl(uri, mode: mode, onBlocked: onBlocked);
  }
}

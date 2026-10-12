import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:imboy/app_core/routing/organization_invite_link.dart';
import 'package:flutter/cupertino.dart';
import 'package:imboy/component/web_view.dart';
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

  /// 网页只在应用内打开；系统协议使用对应的系统能力。
  ///
  /// [uri] 要打开的 URI
  /// [context] 网页导航需要有效的页面上下文。
  /// [mode] 仅影响系统协议；网页始终使用应用内 WebView。
  /// [onBlocked] scheme 被拒绝时的回调，默认 null 时不额外处理
  /// 网页返回 true 表示导航已发起，不等待页面关闭。
  static Future<bool> safeLaunchUrl(
    Uri uri, {
    BuildContext? context,
    bool allowOaDevicePermissions = false,
    LaunchMode mode = LaunchMode.externalApplication,
    void Function(String scheme)? onBlocked,
  }) async {
    final invite = organizationInviteLocation(uri.toString());
    if (invite != null) {
      if (context == null || !context.mounted) return false;
      final router = GoRouter.maybeOf(context);
      if (router == null) return false;
      unawaited(router.push<void>(invite));
      return true;
    }
    if (!isSchemeAllowed(uri.scheme)) {
      onBlocked?.call(uri.scheme);
      return false;
    }
    if (uri.scheme.toLowerCase() == 'http' ||
        uri.scheme.toLowerCase() == 'https') {
      if (uri.host.isEmpty || context == null || !context.mounted) return false;
      final navigator = Navigator.maybeOf(context);
      if (navigator == null) return false;
      unawaited(
        navigator.push<void>(
          CupertinoPageRoute<void>(
            builder: (_) => WebViewPage(
              uri.toString(),
              uri.host,
              allowOaDevicePermissions: allowOaDevicePermissions,
            ),
          ),
        ),
      );
      return true;
    }
    if (!await canLaunchUrl(uri)) {
      return false;
    }
    return await launchUrl(uri, mode: mode);
  }

  /// 安全打开 URL 字符串版本
  static Future<bool> safeLaunchUrlString(
    String urlString, {
    BuildContext? context,
    bool allowOaDevicePermissions = false,
    LaunchMode mode = LaunchMode.externalApplication,
    void Function(String scheme)? onBlocked,
  }) async {
    final uri = Uri.tryParse(urlString);
    if (uri == null) return false;
    return safeLaunchUrl(
      uri,
      context: context,
      allowOaDevicePermissions: allowOaDevicePermissions,
      mode: mode,
      onBlocked: onBlocked,
    );
  }
}

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

/// Android `imboy://` 深链 → Flutter 路由桥接（MC-AC-22 / AC05 直接路由）。
///
/// 数据来源：Android `MainActivity` 对 `ACTION_VIEW` 中 `imboy` scheme 的
/// 分流，经 `imboy/deep_link` MethodChannel 传递（冷启动 pull / 热启动 push）。
/// 登录态与功能门守卫不在此重复实现——统一交给 [GoRouter.redirect]：
/// 未登录时 redirect 会拦截并把目标记为 pendingLocation。
class DeepLinkRouterBridge {
  DeepLinkRouterBridge._();

  static const _channel = MethodChannel('imboy/deep_link');

  /// 冷启动：消费初始深链（App 由外部 VIEW intent 拉起）。
  static Future<void> consumeInitialLink(GoRouter router) async {
    if (!Platform.isAndroid) return;
    try {
      final link = await _channel.invokeMethod<String>('getInitialLink');
      if (link != null && link.isNotEmpty) {
        await _navigate(router, link);
      }
    } on MissingPluginException {
      // 原生侧未注册（旧构建/非 Android 壳）：no-op。
    } on Object catch (e) {
      _debugLog('consumeInitialLink: $e');
    }
  }

  /// 热启动：监听 native 推送的深链（App 已在前台时收到 VIEW intent）。
  static void watchIncomingLinks(GoRouter router) {
    if (!Platform.isAndroid) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onDeepLink') {
        final link = call.arguments;
        if (link is String && link.isNotEmpty) {
          await _navigate(router, link);
        }
      }
      return null;
    });
  }

  /// `imboy://imboy.pub/web_shell?tab=chat&id=xxx` → `/web_shell?tab=chat&id=xxx`
  ///
  /// 仅接受 `/` 开头的相对路径（host 部分丢弃），拒绝 `//`（协议相对）
  /// 与非路径形态，避免把外部输入直接当绝对 URL 导航。
  static Future<void> _navigate(GoRouter router, String link) async {
    Uri? uri;
    try {
      uri = Uri.parse(link);
    } on FormatException {
      _debugLog('invalid deep link: $link');
      return;
    }
    if (uri.scheme != 'imboy') {
      _debugLog('unsupported scheme: ${uri.scheme}');
      return;
    }
    final path = uri.path;
    if (!path.startsWith('/') || path.startsWith('//')) {
      _debugLog('unsupported path: $path');
      return;
    }
    final location = uri.hasQuery ? '$path?${uri.query}' : path;
    _debugLog('navigating to $location');
    // push 而非 go：深链内容页要叠在当前栈上（GlassBackButton 依赖
    // Navigator.canPop；go 重置整栈会让深链页成根路由，页内无返回键）。
    // push 抛错（匹配/守卫失败）时回退 go 保持重定向语义。
    try {
      await router.push(location);
    } on Object catch (e) {
      _debugLog('push failed ($e), falling back to go');
      router.go(location);
    }
  }

  static void _debugLog(String message) {
    if (kDebugMode) {
      debugPrint('[DeepLinkBridge] $message');
    }
  }
}

import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:imboy/component/helper/func.dart' show iPrint;
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/page/chat/chat/chat_page.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_colors.dart';

/// `imboyJSBridge` 的双向消息协议。
///
/// H5 → 原生：`imboyJSBridge.postMessage(JSON.stringify({id?, type, data?}))`
/// 原生 → H5：页面 `window` 上派发 `imboyBridgeMessage` MessageEvent，
/// `event.data = {id?, type, ok, data?, error?}`。
///
/// 方法白名单制：通道挂在所有 `imboy.pub` 页面上（通道名公开可知），
/// 因此每个新方法都必须先单独评审再添加（企业 OA 计划 §3.3 的约束）。
/// 当前方法：
/// - `ping` / `echo`：无副作用，供 OA 联调页（test_oa.html 等）验证通道；
/// - `openChat`：H5 传 `{to: '<纯数字 uid>'}`，原生打开与该用户的聊天页，
///   由用户亲手输入发送——不代发、不透传内容，无消息面副作用。
/// 未知方法回 `unsupported` 错误回执，便于 H5 侧联调定位；
/// 坏 JSON 无法构造回执，静默忽略。
class ImboyJsBridge {
  ImboyJsBridge({required this.onOpenChat});

  /// `openChat` 的导航动作（WebViewPage 注入）；返回 true = 已发起导航。
  final Future<bool> Function(String peerId) onOpenChat;

  /// C2C peerId 形态：纯数字 uid（EntityId 数字字符串）。
  static final RegExp _peerIdPattern = RegExp(r'^\d{1,18}$');

  /// 处理一条 H5 → 原生消息，返回应回推给页面的 JavaScript 语句；
  /// 无需回推（坏 JSON）时返回 null。
  Future<String?> handle(String raw) async {
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return null;
    }
    if (decoded is! Map<String, dynamic>) return null;
    if (decoded['type'] == 'openChat') {
      return _handleOpenChat(decoded);
    }
    return buildReply(raw);
  }

  Future<String?> _handleOpenChat(Map<String, dynamic> decoded) async {
    final payload = _basePayload(decoded, decoded['type']);
    final data = decoded['data'];
    final String to = data is Map<String, dynamic>
        ? (data['to']?.toString() ?? '')
        : '';
    if (!_peerIdPattern.hasMatch(to)) {
      payload['error'] = 'invalid_to';
      return _replyJs(payload);
    }
    try {
      final opened = await onOpenChat(to);
      payload
        ..['ok'] = opened
        ..['data'] = {'to': to};
      if (!opened) payload['error'] = 'not_mounted';
    } catch (e) {
      payload['error'] = 'navigate_failed';
      iPrint('[ImboyJsBridge] openChat navigate failed: ${e.runtimeType}');
    }
    return _replyJs(payload);
  }

  /// 处理同步协议方法（ping/echo/未知），返回回推 JS；坏 JSON 返回 null。
  /// 公开保留：纯函数便于单测，异步分发入口 [handle] 对非 openChat 消息
  /// 委托到这里。
  static String? buildReply(String raw) {
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return null;
    }
    if (decoded is! Map<String, dynamic>) return null;
    final type = decoded['type'] is String ? decoded['type'] : '';
    final payload = _basePayload(decoded, type);
    switch (type) {
      case 'ping':
        payload
          ..['ok'] = true
          ..['data'] = {
            'pong': true,
            'ts': DateTime.now().millisecondsSinceEpoch,
          };
      case 'echo':
        payload
          ..['ok'] = true
          ..['data'] = decoded['data'];
      default:
        payload['error'] = 'unsupported';
    }
    return _replyJs(payload);
  }

  static Map<String, dynamic> _basePayload(
    Map<String, dynamic> decoded,
    Object? type,
  ) {
    return <String, dynamic>{
      if (decoded['id'] != null) 'id': decoded['id'],
      'type': type is String ? type : '',
      'ok': false,
    };
  }

  static String _replyJs(Map<String, dynamic> payload) {
    return "window.dispatchEvent(new MessageEvent('imboyBridgeMessage', "
        '{data: ${jsonEncode(payload)}}));';
  }
}

class WebViewPage extends StatefulWidget {
  final String url;
  final String title;
  final void Function(String url)? errorCallback;
  final bool allowOaDevicePermissions;

  const WebViewPage(
    this.url,
    this.title, {
    super.key,
    this.errorCallback,
    this.allowOaDevicePermissions = false,
  });

  @override
  State<StatefulWidget> createState() => WebViewPageState();
}

class WebViewPageState extends State<WebViewPage> {
  /// H5 桥（openChat 导航动作由本 State 提供 context）。
  late final ImboyJsBridge _bridge = ImboyJsBridge(onOpenChat: _openNativeChat);

  /// controller/title 归 State 持有：上层 rebuild 会向路由页传入新的
  /// widget 实例，若可变状态挂 widget 上，新实例字段为空会导致 build
  /// 期空断言崩溃（openChat 打开聊天 → 未读徽标更新 → 触发过一次）。
  WebViewController? _controller;
  late String title = widget.title;

  /// 仅允许的 URL scheme。
  ///
  /// 这里刻意**不做域名白名单**：扫码后打开第三方链接是正常功能
  /// （`scanner_result_page` 先展示文本、用户显式点「在浏览器打开」才进来），
  /// 域名白名单会直接废掉它。真正的提权面是 scheme：
  ///   - `file:` + unrestricted JS = 读应用私有目录再外传
  ///   - `javascript:` = 在当前页上下文执行任意脚本
  ///   - `intent:` / `content:` = 跨应用组件调用
  /// 而 `isUrl()`（`helper/func.dart:61`）放行 ftp/rtsp/mms，且其 scheme 组是
  /// 可选的（`://evil` 也能匹配），指望调用方过滤不成立 —— 守卫放在这里，
  /// 两个调用点一并覆盖。
  static const Set<String> allowedSchemes = {'http', 'https'};

  /// 允许挂 JS 通道的域名后缀（自家 H5）
  static const List<String> jsBridgeHostSuffixes = ['imboy.pub'];

  static bool isSchemeAllowed(String url) {
    final Uri? uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) return false;
    return allowedSchemes.contains(uri.scheme.toLowerCase());
  }

  static bool isJsBridgeHost(String url) {
    final Uri? uri = Uri.tryParse(url);
    if (uri == null || !allowedSchemes.contains(uri.scheme.toLowerCase())) {
      return false;
    }
    final String host = uri.host.toLowerCase();
    return jsBridgeHostSuffixes.any((s) => host == s || host.endsWith('.$s'));
  }

  /// 只有明确的 OA 入口可申请设备能力；不将子域或跳转页面扩展为可信源。
  static bool allowsOaDevicePermissions({
    required bool enabled,
    required String initialUrl,
    required String? currentUrl,
    String? requestOrigin,
  }) {
    bool trusted(String? value) {
      final uri = value == null ? null : Uri.tryParse(value);
      return uri != null &&
          uri.scheme == 'https' &&
          uri.host == 'imboy.pub' &&
          uri.port == 443 &&
          uri.userInfo.isEmpty;
    }

    return enabled &&
        trusted(initialUrl) &&
        trusted(currentUrl) &&
        (requestOrigin == null || trusted(requestOrigin));
  }

  @override
  void initState() {
    super.initState();

    _controller =
        WebViewController(
            onPermissionRequest: (request) =>
                unawaited(_handleDeviceRequest(request)),
          )
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          // 注意：JavaScriptMode.unrestricted 是 JS bridge（javascriptChannel）
          // 正常工作的必要条件。第三方 HTTP(S) 页面同样在应用内显示，
          // 但不会获得自家 H5 桥接能力；桥消息另按当前 origin 复核权限。
          ..setNavigationDelegate(
            NavigationDelegate(
              onProgress: (int progress) {
                if (title.isEmpty) {
                  AppLoading.showProgress(
                    progress / 100,
                    status: t.common.webpageLoading,
                  );
                }
                // debugPrint('> WebView is loading (progress : $progress%)');
              },
              onPageStarted: (String url) {
                if (widget.url.contains("weixin.qq.com/r/") ||
                    widget.url.contains("weixin.qq.com/x/")) {
                  widget.errorCallback?.call(widget.url);
                }
              },
              onPageFinished: (String url) {
                AppLoading.dismiss();
                if (title.isEmpty && _controller != null) {
                  _controller!.getTitle().then((fetched) {
                    // getTitle 异步返回时页面可能已 dispose（加载中返回）。
                    if (!mounted) return;
                    if (fetched != null && fetched.isNotEmpty) {
                      setState(() {
                        title = fetched;
                      });
                    }
                  });
                }
              },
              onWebResourceError: (WebResourceError error) {
                AppLoading.dismiss();
                final msg = "\n${widget.url}\n\nerror: \n${error.description}";
                widget.errorCallback?.call(msg);
              },
              onNavigationRequest: (NavigationRequest request) {
                // 原为一段被注释掉的判断，且逻辑是反的（拦自家域名、放行其余）。
                // 页内跳转同样必须过 scheme 闸：首屏是 https，但页面可以把用户
                // 导航到 file:/javascript:/intent: 完成提权。
                if (!isSchemeAllowed(request.url)) {
                  return NavigationDecision.prevent;
                }
                return NavigationDecision.navigate;
              },
            ),
          );

    // JS 通道只挂给自家 H5：通道名 imboyJSBridge 是公开可知的，任意第三方
    // 页面都能往里发消息。方法白名单见 ImboyJsBridge 类注释；第三方站点
    // 不在本通道挂载域内（isJsBridgeHost 只放行 imboy.pub 后缀）。
    if (isJsBridgeHost(widget.url)) {
      _controller!.addJavaScriptChannel(
        'imboyJSBridge', // 与h5 端的一致 不然收不到消息
        onMessageReceived: (JavaScriptMessage message) {
          unawaited(_handleBridgeMessage(message.message));
        },
      );
    }

    // 首屏加载不一定经过 onNavigationRequest（各平台实现不一致），单独把闸。
    if (isSchemeAllowed(widget.url)) {
      unawaited(_loadInitialUrl());
    } else {
      AppLoading.dismiss();
      widget.errorCallback?.call(widget.url);
    }

    // H5 设备能力（定位/相机）授权接线。iOS 的 WKWebView 无回调时默认
    // prompt 系统权限弹窗（Info.plist 描述已备）。macOS 使用 WKWebView，
    // 不走 Android 的平台回调；不向任意网页增添敏感桥方法。
    final platform = _controller!.platform;
    if (platform is AndroidWebViewController) {
      unawaited(_wireAndroidDevicePermissions(platform));
    }

    // setBackgroundColor is not supported on macOS
    if (defaultTargetPlatform != TargetPlatform.macOS) {
      _controller!.setBackgroundColor(AppColors.transparent);
    }
  }

  Future<void> _loadInitialUrl() async {
    // 自家 H5（OA 应用）改版需即时生效：打开前清 HTTP 缓存，避免 WebView
    // 对无 Cache-Control 响应的启发式缓存滞留旧页面；第三方页面（扫码
    // 浏览）保持缓存不清理。
    if (isJsBridgeHost(widget.url)) {
      await _controller!.clearCache();
    }
    await _controller!.loadRequest(Uri.parse(widget.url));
  }

  /// 桥消息入口：分发并异步回推。
  ///
  /// 通道按初始 URL 挂载，且 WebView 内跨导航常驻——imboy.pub 页面把
  /// 用户带到第三方站点后，对方页面仍能向通道发消息。这里按当前页 URL
  /// 复核域名，非 imboy.pub 一律静默丢弃（fail-closed）；取 URL 或回推
  /// 失败（导航中、已销毁）同样安全丢弃。
  Future<void> _handleBridgeMessage(String raw) async {
    try {
      final String? current = await _controller?.currentUrl();
      if (current == null || !isJsBridgeHost(current)) return;
      final String? reply = await _bridge.handle(raw);
      if (reply == null) return;
      await _controller?.runJavaScript(reply);
    } catch (_) {}
  }

  /// `openChat` 桥动作：打开与该用户的原生聊天页，由用户亲手输入发送。
  /// peerTitle/avatar 传空——ChatPage 内部自行解析 peer 信息。
  /// 回执语义是「已发起导航」：push 后立即返回，不等聊天页关闭——
  /// 否则 H5 侧的回执超时（5s）必先到期。
  Future<bool> _openNativeChat(String peerId) async {
    if (!mounted) return false;
    unawaited(
      Navigator.of(context).push(
        CupertinoPageRoute<dynamic>(
          builder: (_) => ChatPage(
            peerId: peerId,
            type: 'C2C',
            peerTitle: '',
            peerAvatar: '',
            peerSign: '',
          ),
        ),
      ),
    );
    return true;
  }

  /// Android WebView 的定位与相机授权（如 test_oa.html 的 Web 标准定位/
  /// getUserMedia）。普通浏览拒绝设备能力；明确 OA 入口复验当前来源，
  /// 仅相机和定位走系统权限流程，其他资源拒绝。
  Future<void> _wireAndroidDevicePermissions(
    AndroidWebViewController controller,
  ) async {
    await controller.setGeolocationEnabled(true);
    await controller.setGeolocationPermissionsPromptCallbacks(
      onShowPrompt: (request) async {
        if (!await _allowsDeviceRequest(request.origin)) {
          return const GeolocationPermissionsResponse(
            allow: false,
            retain: false,
          );
        }
        final status = await Permission.locationWhenInUse.request();
        return GeolocationPermissionsResponse(
          allow: status.isGranted && await _allowsDeviceRequest(request.origin),
          retain: false,
        );
      },
    );
  }

  Future<bool> _allowsDeviceRequest([String? requestOrigin]) async {
    if (!mounted || !widget.allowOaDevicePermissions) return false;
    try {
      final current = await _controller?.currentUrl();
      return mounted &&
          allowsOaDevicePermissions(
            enabled: widget.allowOaDevicePermissions,
            initialUrl: widget.url,
            currentUrl: current,
            requestOrigin: requestOrigin,
          );
    } catch (_) {
      return false;
    }
  }

  Future<void> _handleDeviceRequest(WebViewPermissionRequest request) async {
    if (request.types.length == 1 &&
        request.types.contains(WebViewPermissionResourceType.camera) &&
        await _allowsDeviceRequest()) {
      final status = await Permission.camera.request();
      if (status.isGranted && await _allowsDeviceRequest()) {
        await request.grant();
        return;
      }
    }
    await request.deny();
  }

  @override
  void dispose() {
    AppLoading.dismiss();
    // 通道现在是按域名条件注册的，移除也必须同条件，否则移除未注册的通道
    if (isJsBridgeHost(widget.url)) {
      _controller!.removeJavaScriptChannel('imboyJSBridge');
    }
    // dispose 不能 await：捕获异步错误，避免污染 zone。
    unawaited(_controller!.clearLocalStorage().catchError((Object _) {}));
    _controller = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    PlatformWebViewWidgetCreationParams params =
        PlatformWebViewWidgetCreationParams(controller: _controller!.platform);
    if (_controller!.platform is AndroidWebViewController) {
      params =
          AndroidWebViewWidgetCreationParams.fromPlatformWebViewWidgetCreationParams(
            params,
            displayWithHybridComposition: true,
          );
    }
    return Scaffold(
      appBar: GlassAppBar(
        titleWidget: Text(
          title,
          // style: AppStyle.navAppBarTitleStyle,
        ),
        automaticallyImplyLeading: true,
      ),
      body: WebViewWidget.fromPlatformCreationParams(params: params),
    );
  }
}

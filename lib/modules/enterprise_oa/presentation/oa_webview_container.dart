/// OA WebView 真实容器（EPGZ-06 W3 / plan §7.2）。
///
/// 把 webview_flutter 挂到 W1 预留的 ready 态槽位：
/// - **exact-origin 导航策略**：`NavigationDelegate.onNavigationRequest` →
///   W1 的 [ExactOriginNavigationHandler]；deny → prevent，域名跳转 →
///   [OaTabStatus.originMismatch]；
/// - **稳定 UI 状态全覆盖**：主帧加载失败 → error（可重试）；主帧 HTTP
///   401 → oaUnauthorized（ready 态；loading 态按 W1 冻结语义不允许直达，
///   回退 error）；页面加载完成 → ready；
/// - **安全边界**：不注入 IMBoy JWT / Application secret（无自定义
///   header/cookie）、不挂 JS bridge（无 addJavaScriptChannel）。
///   JavaScriptMode.unrestricted 仅为 OA H5 业务页自身可用——无通道注册，
///   页面无法与 Flutter 通信（区别于 lib/component/web_view.dart 的
///   imboyJSBridge 机制，OA Tab 不复用之）。
///
/// 事件→状态机的裁决集中在 [OaWebViewEventHandlers]（可脱离 WebView
/// 直测）；本 widget 只做 NavigationDelegate 接线。
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:imboy/component/helper/func.dart' show iPrint;

import 'package:imboy/modules/enterprise_oa/domain/oa_tab_state.dart';
import 'package:imboy/modules/enterprise_oa/domain/oa_webview_policy.dart';

/// WebView 事件 → 状态机裁决（纯逻辑，测试直驱）。
///
/// 非不可变：[_firstLoadSignalled] 是一次性信号哨兵。
class OaWebViewEventHandlers {
  OaWebViewEventHandlers({
    required this.machine,
    required this.navigationHandler,
    this.onFirstPageLoaded,
  });

  final OaTabStateMachine machine;

  /// exact-origin 导航策略（通常 ExactOriginNavigationHandler(config origin)）。
  final OaNavigationHandler navigationHandler;

  /// 首次页面加载完成（SSO 兑换成功代理信号；协调器借此停 60s 倒计时）。
  final VoidCallback? onFirstPageLoaded;

  bool _firstLoadSignalled = false;

  /// onNavigationRequest 裁决。
  NavigationDecision decideNavigation(String url) {
    final OaNavigationAction action = navigationHandler.onNavigationRequested(
      url,
    );
    switch (action) {
      case OaNavigationAction.proceed:
        return NavigationDecision.navigate;
      case OaNavigationAction.cancelAsMismatch:
        if (navigationHandler is ExactOriginNavigationHandler) {
          machine.markOriginMismatch(
            attemptedUrl: url,
            allowedOrigin: (navigationHandler as ExactOriginNavigationHandler)
                .allowedOrigin,
          );
        } else {
          // 自定义 handler 无 origin 事实可记，仅置态。
          machine.markOriginMismatch(attemptedUrl: url, allowedOrigin: '');
        }
        return NavigationDecision.prevent;
      case OaNavigationAction.cancel:
        return NavigationDecision.prevent;
    }
  }

  /// onPageFinished：loading → ready（首次另发 [onFirstPageLoaded]）。
  void onPageFinished(String url) {
    final bool becameReady = machine.markReady();
    if (becameReady || !_firstLoadSignalled) {
      _firstLoadSignalled = true;
      onFirstPageLoaded?.call();
    }
  }

  /// 主帧资源加载失败（网络/SSL/超时等）→ error（仅 loading 态可进入；
  /// ready 态页内导航失败由 WebView 自身错误页呈现，状态机 fail-closed）。
  void onMainFrameLoadFailed() {
    machine.markError();
  }

  /// 主帧 HTTP 错误响应：401 → oaUnauthorized（W1 冻结语义仅 ready 可入，
  /// loading 态回退 error）；其余状态码不动状态机（OA 页面自处理）。
  void onMainFrameHttpStatus(int statusCode) {
    if (statusCode != 401) return;
    if (!machine.markOaUnauthorized()) {
      machine.markError();
    }
  }
}

/// 真实 WebView 挂载 widget（OA Tab ready 态槽位实现）。
class OaWebViewContainer extends StatefulWidget {
  const OaWebViewContainer({
    super.key,
    required this.initialUrl,
    required this.machine,
    required this.allowedOrigin,
    this.onFirstPageLoaded,
    this.onStateChanged,
  });

  /// 首次加载 URL（`redirect_uri?code=…&state=…`）。
  final String initialUrl;

  final OaTabStateMachine machine;

  /// 唯一允许的 exact HTTPS origin（BrandConfig.oaOrigin）。
  final String allowedOrigin;

  final VoidCallback? onFirstPageLoaded;

  /// 任意状态机迁移后的通知（协调器 setState/停倒计时）。
  final VoidCallback? onStateChanged;

  @override
  State<OaWebViewContainer> createState() => _OaWebViewContainerState();
}

class _OaWebViewContainerState extends State<OaWebViewContainer> {
  late final OaWebViewEventHandlers _handlers;
  late final WebViewController _controller;
  static Future<void> _sessionBarrier = Future.value();
  static _OaWebViewContainerState? _active;
  bool _retired = true;

  bool get _acceptEvents => mounted && !_retired && identical(_active, this);

  @override
  void initState() {
    super.initState();
    _handlers = OaWebViewEventHandlers(
      machine: widget.machine,
      navigationHandler: ExactOriginNavigationHandler(
        allowedOrigin: widget.allowedOrigin,
      ),
      onFirstPageLoaded: widget.onFirstPageLoaded,
    );
    _controller = WebViewController();
    unawaited(_prepare());
  }

  NavigationDelegate _navigationDelegate() => NavigationDelegate(
    onNavigationRequest: (NavigationRequest request) {
      if (_retired && request.url == 'about:blank') {
        return NavigationDecision.navigate;
      }
      if (!_acceptEvents) return NavigationDecision.prevent;
      final NavigationDecision decision = _handlers.decideNavigation(
        request.url,
      );
      _notifyStateChanged();
      return decision;
    },
    onPageFinished: (String url) {
      if (!_acceptEvents) return;
      _handlers.onPageFinished(url);
      _notifyStateChanged();
    },
    onWebResourceError: (WebResourceError error) {
      if (!_acceptEvents) return;
      // 仅主帧失败视为页面加载失败；子资源（图片/脚本）失败
      // 不推翻页面状态。
      if (error.isForMainFrame ?? false) {
        _handlers.onMainFrameLoadFailed();
        _notifyStateChanged();
      }
    },
    onHttpError: (HttpResponseError error) {
      if (!_acceptEvents) return;
      // webview_flutter 的 onHttpError 在 Android 仅主帧触发；
      // iOS 经 WKWebView 导航响应同样以主帧为主。非 401 状态码
      // 不动状态机（OA 页面自行处理）。
      _handlers.onMainFrameHttpStatus(error.response?.statusCode ?? 0);
      _notifyStateChanged();
    },
  );

  static Future<void> _enqueueSession(Future<void> Function() action) {
    final next = _sessionBarrier.then((_) => action());
    _sessionBarrier = next.catchError((Object error) {
      iPrint('[OaWebView] session cleanup failed: ${error.runtimeType}');
    });
    return next;
  }

  Future<void> _clearSession() async {
    // ponytail: plugin clears the shared WebView store; use native profiles when available.
    await WebViewCookieManager().clearCookies();
    await _controller.clearLocalStorage();
    await _controller.clearCache();
  }

  Future<void> _quiesce() async {
    _retired = true;
    await _controller.runJavaScript('window.stop();');
    await _controller.loadRequest(Uri.parse('about:blank'));
  }

  Future<void> _prepare() async {
    try {
      if (!evaluateOrigin(widget.allowedOrigin, widget.initialUrl).isAllow) {
        throw StateError('Invalid OA origin');
      }
      await _controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      await _controller.setNavigationDelegate(_navigationDelegate());
      await _enqueueSession(() async {
        if (!mounted) return;
        final previous = _active;
        if (previous != null && !identical(previous, this)) {
          await previous._quiesce();
        }
        await _clearSession();
        if (!mounted) return;
        _active = this;
        _retired = false;
        await _controller.loadRequest(Uri.parse(widget.initialUrl));
      });
    } on Object catch (error) {
      if (!mounted) return;
      _handlers.onMainFrameLoadFailed();
      _notifyStateChanged();
      iPrint('[OaWebView] prepare failed: ${error.runtimeType}');
    }
  }

  /// 状态迁移后通知协调器。
  void _notifyStateChanged() {
    if (!mounted) return;
    widget.onStateChanged?.call();
  }

  @override
  void dispose() {
    _retired = true;
    unawaited(
      _enqueueSession(() async {
        if (!identical(_active, this)) return;
        await _quiesce();
        await _clearSession();
        _active = null;
      }).catchError((Object error) {
        iPrint('[OaWebView] dispose cleanup failed: ${error.runtimeType}');
      }),
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WebViewWidget(controller: _controller);
  }
}

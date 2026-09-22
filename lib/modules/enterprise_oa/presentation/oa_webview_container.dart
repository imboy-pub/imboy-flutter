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

import 'package:flutter/widgets.dart';
import 'package:webview_flutter/webview_flutter.dart';

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
    _controller = WebViewController()
      // 见库文档：unrestricted 仅为 OA H5 页自身可用；无 JS 通道注册，
      // 页面与 Flutter 之间不存在任何 bridge 面。
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            final NavigationDecision decision = _handlers.decideNavigation(
              request.url,
            );
            _notifyStateChanged();
            return decision;
          },
          onPageFinished: (String url) {
            _handlers.onPageFinished(url);
            _notifyStateChanged();
          },
          onWebResourceError: (WebResourceError error) {
            // 仅主帧失败视为页面加载失败；子资源（图片/脚本）失败
            // 不推翻页面状态。
            if (error.isForMainFrame ?? false) {
              _handlers.onMainFrameLoadFailed();
              _notifyStateChanged();
            }
          },
          onHttpError: (HttpResponseError error) {
            // webview_flutter 的 onHttpError 在 Android 仅主帧触发；
            // iOS 经 WKWebView 导航响应同样以主帧为主。非 401 状态码
            // 不动状态机（OA 页面自行处理）。
            _handlers.onMainFrameHttpStatus(error.response?.statusCode ?? 0);
            _notifyStateChanged();
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.initialUrl));
  }

  /// 状态迁移后通知协调器。
  void _notifyStateChanged() {
    widget.onStateChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    return WebViewWidget(controller: _controller);
  }
}

import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_colors.dart';

// ignore: must_be_immutable
class WebViewPage extends StatefulWidget {
  final String url;
  String title;
  WebViewController? _controller;
  final void Function(String url)? errorCallback;

  WebViewPage(this.url, this.title, {super.key, this.errorCallback});

  @override
  State<StatefulWidget> createState() => WebViewPageState();
}

class WebViewPageState extends State<WebViewPage> {
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
    if (uri == null) return false;
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

  @override
  void initState() {
    super.initState();

    widget._controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            if (widget.title.isEmpty) {
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
              widget.errorCallback!(widget.url);
            }
          },
          onPageFinished: (String url) {
            AppLoading.dismiss();
            if (widget.title.isEmpty && widget._controller != null) {
              widget._controller!.getTitle().then((title) {
                if (title != null) {
                  setState(() {
                    widget.title = title;
                  });
                }
              });
            }
          },
          onWebResourceError: (WebResourceError error) {
            AppLoading.dismiss();
            if (widget.errorCallback != null) {
              String msg = "\n${widget.url}\n\nerror: \n${error.description}";
              widget.errorCallback!(msg);
            }
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
    // 页面都能往里发消息。当前 onMessageReceived 是空实现，但通道一旦挂上，
    // 日后给它加逻辑的人不会想到它同时暴露给了扫码打开的任意站点。
    if (isJsBridgeHost(widget.url)) {
      widget._controller!.addJavaScriptChannel(
        'imboyJSBridge', // 与h5 端的一致 不然收不到消息
        onMessageReceived: (JavaScriptMessage message) {},
      );
    }

    // 首屏加载不一定经过 onNavigationRequest（各平台实现不一致），单独把闸。
    if (isSchemeAllowed(widget.url)) {
      widget._controller!.loadRequest(Uri.parse(widget.url));
    } else {
      AppLoading.dismiss();
      widget.errorCallback?.call(widget.url);
    }

    // setBackgroundColor is not supported on macOS
    if (defaultTargetPlatform != TargetPlatform.macOS) {
      widget._controller!.setBackgroundColor(AppColors.transparent);
    }
  }

  @override
  void dispose() {
    AppLoading.dismiss();
    // 通道现在是按域名条件注册的，移除也必须同条件，否则移除未注册的通道
    if (isJsBridgeHost(widget.url)) {
      widget._controller!.removeJavaScriptChannel('imboyJSBridge');
    }
    widget._controller!.clearLocalStorage();
    widget._controller = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GlassAppBar(
        titleWidget: Text(
          widget.title,
          // style: AppStyle.navAppBarTitleStyle,
        ),
        automaticallyImplyLeading: true,
      ),
      body: WebViewWidget(controller: widget._controller!),
    );
  }
}

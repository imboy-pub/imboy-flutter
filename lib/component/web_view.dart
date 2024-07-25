import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/config/theme.dart';
import 'package:webview_flutter/webview_flutter.dart';

// ignore: must_be_immutable
class WebViewPage extends StatefulWidget {
  final String url;
  String title;
  WebViewController? _controller;
  final void Function(String url)? errorCallback;

  WebViewPage(
    this.url,
    this.title, {
    super.key,
    this.errorCallback,
  });

  @override
  State<StatefulWidget> createState() => WebViewPageState();
}

class WebViewPageState extends State<WebViewPage> {
  @override
  void initState() {
    super.initState();

    widget._controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            if (widget.title.isEmpty) {
              EasyLoading.showProgress(
                progress / 100,
                status: 'webpage_loading'.tr,
              );
            }
            // debugPrint('> WebView is loading (progress : $progress%)');
          },
          onPageStarted: (String url) {
            debugPrint("> on onPageStarted $url");
            if (widget.url.contains("weixin.qq.com/r/") ||
                widget.url.contains("weixin.qq.com/x/")) {
              widget.errorCallback!(widget.url);
            }
          },
          onPageFinished: (String url) {
            EasyLoading.dismiss();
            if (widget.title.isEmpty && widget._controller != null) {
              widget._controller!.getTitle().then((title) {
                debugPrint('> getTitle onPageFinished $title end');
                if (title != null) {
                  setState(() {
                    widget.title = title;
                  });
                }
              });
            }
          },
          onWebResourceError: (WebResourceError error) {
            EasyLoading.dismiss();
            if (widget.errorCallback != null) {
              String msg = "\n${widget.url}\n\nerror: \n${error.description}";
              widget.errorCallback!(msg);
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            // if (request.url.startsWith('https://www.imboy.pub/')) {
            //   return NavigationDecision.prevent;
            // }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..addJavaScriptChannel('imboyJSBridge', // 与h5 端的一致 不然收不到消息
          onMessageReceived: (JavaScriptMessage message) {})
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  void dispose() {
    EasyLoading.dismiss();
    widget._controller!.removeJavaScriptChannel('imboyJSBridge');
    widget._controller!.clearLocalStorage();
    widget._controller = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: NavAppBar(
        titleWidget: Text(
          widget.title,
          style: AppStyle.navAppBarTitleStyle,
        ),
        automaticallyImplyLeading: true,
      ),
      body: WebViewWidget(controller: widget._controller!),
    );
  }
}

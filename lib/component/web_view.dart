import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:webview_flutter/webview_flutter.dart';

class WebViewPage extends StatefulWidget {
  final String url;
  String title;

  final void Function(String url)? errorCallback;

  late WebViewController _controller;

  WebViewPage(
    this.url,
    this.title, {
    this.errorCallback,
  });

  @override
  State<StatefulWidget> createState() => WebViewPageState();
}

class WebViewPageState extends State<WebViewPage> {
  // final Completer<WebViewController> _controller =
  //     Completer<WebViewController>();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PageAppBar(
        titleWiew: Text(widget.title),
      ),
      body: Builder(builder: (BuildContext context) {
        return WebView(
          initialUrl: widget.url,
          allowsInlineMediaPlayback: false,
          javascriptMode: JavascriptMode.unrestricted,
          javascriptChannels: <JavascriptChannel>[
            jsBridge(context),
          ].toSet(),
          onWebViewCreated: (WebViewController webViewController) {
            // _controller.complete(webViewController);
            widget._controller = webViewController;
          },
          onPageStarted: (url) {
            debugPrint(">>> on onPageStarted ${url}");
            if (widget.url.contains("weixin.qq.com/r/") ||
                widget.url.contains("weixin.qq.com/x/")) {
              widget.errorCallback!(widget.url);
            } else {
              EasyLoading.showToast("加载中...".tr);
            }
          },
          onWebResourceError: (WebResourceError error) {
            print('onWebResourceError ' + error.description);
            if (widget.errorCallback != null) {
              String msg = widget.url + "; error: " + error.description;
              widget.errorCallback!(msg);
            }
          },
          navigationDelegate: (NavigationRequest request) {
            print('allowing navigation to $request');
            return NavigationDecision.prevent;
          },
          onPageFinished: (String url) async {
            await widget._controller
                .runJavascriptReturningResult("document.title")
                .then((result) {
              result = result.trim();
              result = result
                  .replaceFirst("\"", "")
                  .replaceRange(result.length - 2, result.length - 1, "");
              // debugPrint(">>> on onPageFinished result  ${result.trim()}");
              setState(() {
                widget.title = result;
              });
            });
          },
        );
      }),
    );
  }

  JavascriptChannel jsBridge(BuildContext context) {
    return JavascriptChannel(
      name: 'jsbridge', // 与h5 端的一致 不然收不到消息
      onMessageReceived: (JavascriptMessage message) {
        Scaffold.of(context).showSnackBar(
          SnackBar(content: Text(message.message)),
        );
      },
    );
  }
}

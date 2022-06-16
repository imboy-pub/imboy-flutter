import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:webview_flutter/webview_flutter.dart';

class WebViewPage extends StatefulWidget {
  final String url;
  final String title;

  WebViewPage(this.url, this.title);

  @override
  State<StatefulWidget> createState() => WebViewPageState();
}

class WebViewPageState extends State<WebViewPage> {
  final Completer<WebViewController> _controller =
      Completer<WebViewController>();

  Widget body() {
    return Builder(builder: (BuildContext context) {
      return WebView(
        initialUrl: widget.url,
        allowsInlineMediaPlayback: true,
        javascriptMode: JavascriptMode.unrestricted,
        onWebViewCreated: (WebViewController webViewController) {
          _controller.complete(webViewController);
        },
        onPageStarted: (url) {
          // Get.snackbar('', '加载中...');
        },
        javascriptChannels: <JavascriptChannel>[
          _toasterJavascriptChannel(context),
        ].toSet(),
        navigationDelegate: (NavigationRequest request) {
          if (request.url.startsWith('http')) {
            return NavigationDecision.prevent;
          }
          print('allowing navigation to $request');
          return NavigationDecision.navigate;
        },
        onPageFinished: (String url) {
          print('Page finished loading: $url');
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PageAppBar(
        title: '${widget.title}',
      ),
      body: body(),
    );
  }

  JavascriptChannel _toasterJavascriptChannel(BuildContext context) {
    return JavascriptChannel(
      name: 'Toaster',
      onMessageReceived: (JavascriptMessage message) {
        Scaffold.of(context).showSnackBar(
          SnackBar(content: Text(message.message)),
        );
      },
    );
  }
}

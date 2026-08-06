import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/web_view.dart';

/// WebView scheme 闸 + JS 通道域名收敛
///
/// 背景：`onNavigationRequest` 原来无条件 `navigate`（唯一的判断被注释掉，
/// 且逻辑是反的——拦自家域名放行其余）；`imboyJSBridge` 通道无条件注册，
/// 扫码打开的任意第三方页面都能往里发消息。
///
/// 这里锁定的是"不该放行什么"，而不是"只放行自家域名"——扫码打开第三方
/// http/https 链接是正常功能，域名白名单会废掉它。
void main() {
  group('isSchemeAllowed', () {
    test('放行 http / https', () {
      expect(WebViewPageState.isSchemeAllowed('https://example.com/a'), isTrue);
      expect(WebViewPageState.isSchemeAllowed('http://example.com/a'), isTrue);
      // 第三方域名同样放行：这是扫码打开外链的正常路径
      expect(WebViewPageState.isSchemeAllowed('https://evil.test/x'), isTrue);
    });

    test('拦截提权类 scheme', () {
      // file: + unrestricted JS = 读应用私有目录再外传
      expect(
        WebViewPageState.isSchemeAllowed('file:///data/data/pub.imboy/x'),
        isFalse,
      );
      expect(WebViewPageState.isSchemeAllowed('javascript:alert(1)'), isFalse);
      expect(WebViewPageState.isSchemeAllowed('data:text/html,<b>x'), isFalse);
      expect(
        WebViewPageState.isSchemeAllowed('intent://x#Intent;end'),
        isFalse,
      );
      expect(WebViewPageState.isSchemeAllowed('content://media/x'), isFalse);
    });

    test('拦截 isUrl() 会放行但 WebView 不该开的 scheme', () {
      // helper/func.dart:61 的正则放行 ftp/rtsp/mms，且 scheme 组可选
      expect(WebViewPageState.isSchemeAllowed('ftp://h/x'), isFalse);
      expect(WebViewPageState.isSchemeAllowed('rtsp://h/x'), isFalse);
      expect(WebViewPageState.isSchemeAllowed('mms://h/x'), isFalse);
      expect(WebViewPageState.isSchemeAllowed('://evil'), isFalse);
      expect(WebViewPageState.isSchemeAllowed(''), isFalse);
    });
  });

  group('isJsBridgeHost', () {
    test('自家域名及其子域可挂通道', () {
      expect(WebViewPageState.isJsBridgeHost('https://imboy.pub/h5'), isTrue);
      expect(
        WebViewPageState.isJsBridgeHost('https://pro.imboy.pub/h5'),
        isTrue,
      );
    });

    test('第三方域名不得挂通道', () {
      expect(WebViewPageState.isJsBridgeHost('https://evil.test/x'), isFalse);
      // 后缀拼接绕过：imboy.pub.evil.test 不是子域
      expect(
        WebViewPageState.isJsBridgeHost('https://imboy.pub.evil.test/x'),
        isFalse,
      );
      // 前缀粘连绕过：notimboy.pub 不是子域
      expect(
        WebViewPageState.isJsBridgeHost('https://notimboy.pub/x'),
        isFalse,
      );
    });

    test('非 http/https 一律不挂通道', () {
      expect(WebViewPageState.isJsBridgeHost('file://imboy.pub/x'), isFalse);
    });
  });
}

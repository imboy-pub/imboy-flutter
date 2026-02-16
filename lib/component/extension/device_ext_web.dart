/// 设备信息扩展 - Web 平台实现
///
/// 仅在 Web 平台编译和使用
library;

import 'package:web/web.dart' as web;

/// Web 浏览器 API 包装器
///
/// 封装 web 包的 window.navigator 和 window.screen API
class WebBrowserStub {
  final web.Window _window;

  WebBrowserStub(this._window);

  /// 获取 user agent
  String get userAgent => _window.navigator.userAgent;

  /// 获取屏幕宽度
  int get screenWidth => _window.screen.width.toInt();

  /// 获取屏幕高度
  int get screenHeight => _window.screen.height.toInt();

  /// 获取语言
  String get language => _window.navigator.language;

  /// 获取平台
  String get platform => _window.navigator.platform;

  /// 获取供应商
  String get vendor => _window.navigator.vendor;

  /// Cookie 是否启用
  bool get cookieEnabled => _window.navigator.cookieEnabled;

  /// 是否在线
  bool get onLine => _window.navigator.onLine;

  /// 获取本地存储项
  String? getItem(String key) {
    try {
      return _window.localStorage.getItem(key);
    } catch (e) {
      return null;
    }
  }

  /// 设置本地存储项
  void setItem(String key, String value) {
    try {
      _window.localStorage.setItem(key, value);
    } catch (e) {
      // 忽略存储错误
    }
  }
}

/// Web 浏览器实例
///
/// 返回真正的浏览器 API 包装器
WebBrowserStub get webBrowser => WebBrowserStub(web.window);

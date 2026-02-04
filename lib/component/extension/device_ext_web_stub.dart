/// 设备信息扩展 - Web 平台存根
///
/// 用于非 Web 平台和测试环境
/// 提供与 Web 浏览器 API 兼容的接口
library;

/// Web 浏览器 API 存根类
///
/// 在非 Web 平台返回默认值，避免编译错误
class WebBrowserStub {
  /// 获取 user agent
  String get userAgent => 'Stub Browser';

  /// 获取屏幕宽度
  int get screenWidth => 1920;

  /// 获取屏幕高度
  int get screenHeight => 1080;

  /// 获取语言
  String get language => 'en';

  /// 获取平台
  String get platform => 'Unknown';

  /// 获取供应商
  String get vendor => 'Unknown';

  /// Cookie 是否启用
  bool get cookieEnabled => false;

  /// 是否在线
  bool get onLine => true;

  /// 获取本地存储项
  String? getItem(String key) => null;

  /// 设置本地存储项
  void setItem(String key, String value) {}
}

/// Web 浏览器实例
///
/// 在 Web 平台由 device_ext_web.dart 提供
/// 在非 Web 平台使用存根
WebBrowserStub get webBrowser => WebBrowserStub();

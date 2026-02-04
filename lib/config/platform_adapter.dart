/// 平台适配器
///
/// 提供统一的平台判断接口，屏蔽各平台差异
library;

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'dart:io';

/// 平台适配器
///
/// 提供统一的平台判断接口，屏蔽 Web、移动端、桌面端差异
class PlatformAdapter {
  /// 当前是否为 Web 平台
  static bool get isWeb => kIsWeb;

  /// 当前是否为移动平台（iOS/Android）
  static bool get isMobile => !kIsWeb && (Platform.isIOS || Platform.isAndroid);

  /// 当前是否为桌面平台（macOS/Windows/Linux）
  static bool get isDesktop =>
      !kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux);

  /// 当前是否为 iOS
  static bool get isIOS => !kIsWeb && Platform.isIOS;

  /// 当前是否为 Android
  static bool get isAndroid => !kIsWeb && Platform.isAndroid;

  /// 当前是否为 macOS
  static bool get isMacOS => !kIsWeb && Platform.isMacOS;

  /// 当前是否为 Windows
  static bool get isWindows => !kIsWeb && Platform.isWindows;

  /// 当前是否为 Linux
  static bool get isLinux => !kIsWeb && Platform.isLinux;

  /// 根据平台选择值
  ///
  /// 示例：
  /// ```dart
  /// final path = PlatformAdapter.choose(
  ///   web: '/web/path',
  ///   mobile: '/mobile/path',
  ///   desktop: '/desktop/path',
  /// );
  /// ```
  static T choose<T>({required T web, required T mobile, T? desktop}) {
    if (isWeb) return web;
    if (isDesktop && desktop != null) return desktop;
    return mobile;
  }

  /// 获取平台名称（用于日志和调试）
  static String get platformName {
    if (isWeb) return 'Web';
    if (isIOS) return 'iOS';
    if (isAndroid) return 'Android';
    if (isMacOS) return 'macOS';
    if (isWindows) return 'Windows';
    if (isLinux) return 'Linux';
    return 'Unknown';
  }

  /// 调试输出当前平台信息
  static void debugPrintInfo() {
    debugPrint('📱 Platform: ${PlatformAdapter.platformName}');
    debugPrint('   - isWeb: $isWeb');
    debugPrint('   - isMobile: $isMobile');
    debugPrint('   - isDesktop: $isDesktop');
  }
}

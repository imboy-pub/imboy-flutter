import 'package:flutter/cupertino.dart';

/// 统一的路由工具类
///
/// 提供便捷的路由导航方法，自动应用手势返回支持
class RouteHelper {
  /// 使用手势返回导航到新页面
  ///
  /// 自动为 iOS 和 Android 提供一致的手势返回体验
  static Future<T?> pushWithGesture<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool fullscreenDialog = false,
  }) {
    return Navigator.push(
      context,
      CupertinoPageRoute(builder: builder, fullscreenDialog: fullscreenDialog),
    );
  }

  /// 使用手势返回替换当前页面
  static Future<T?> replaceWithGesture<T>({
    required BuildContext context,
    required WidgetBuilder builder,
  }) {
    return Navigator.pushReplacement(
      context,
      CupertinoPageRoute(builder: builder),
    );
  }

  /// 使用手势返回并清除栈
  static Future<T?> pushAndClearWithGesture<T>({
    required BuildContext context,
    required WidgetBuilder builder,
  }) {
    return Navigator.pushAndRemoveUntil(
      context,
      CupertinoPageRoute(builder: builder),
      (route) => false,
    );
  }
}

/// 自定义支持手势返回的页面路由
///
/// 使用 Cupertino 风格的滑动过渡，支持 iOS/Android 的右滑返回手势
class GesturePageRoute<T> extends CupertinoPageRoute<T> {
  GesturePageRoute({
    required super.builder,
    super.title,
    super.fullscreenDialog = false,
    super.allowSnapshotting = true,
  });
}

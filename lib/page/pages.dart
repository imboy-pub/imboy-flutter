// ✅ 路由系统已完全迁移到 go_router
// 所有路由配置已迁移到 lib/config/router/app_router.dart
// 此文件现在仅保留路由历史记录和观察者功能

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// 路由历史记录和观察者
///
/// 此类保留了路由历史记录功能，用于路由追踪和调试
/// 路由导航已迁移到 go_router，请使用 GoRouter 进行页面跳转
class AppPages {
  /// 路由观察者 - 用于追踪页面跳转历史
  static final RouteObserver<Route> observer = RouteObservers();

  /// 路由跳转历史记录
  static final List<String> history = [];
}

/// 路由观察者
///
/// 监听路由生命周期事件，记录页面跳转历史
/// 与 go_router 配合使用，提供路由追踪功能
class RouteObservers<R extends Route<dynamic>> extends RouteObserver<R> {
  /// 页面push
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    final name = route.settings.name ?? '';
    if (name.isNotEmpty) {
      AppPages.history.add(name);
    }
    debugPrint('> on didPush ${AppPages.history}');
  }

  /// 页面pop
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    AppPages.history.remove(route.settings.name);
    debugPrint('> on didPop ${AppPages.history}');
  }

  /// 页面替换
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute != null) {
      final index = AppPages.history.indexWhere(
        (element) => element == oldRoute?.settings.name,
      );
      final name = newRoute.settings.name ?? '';
      if (name.isNotEmpty) {
        if (index > 0) {
          AppPages.history[index] = name;
        } else {
          AppPages.history.add(name);
        }
      }
    }
    debugPrint('> on didReplace ${AppPages.history}');
  }

  /// 页面移除
  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    AppPages.history.remove(route.settings.name);
    debugPrint('> on didRemove ${AppPages.history}');
  }

  /// 用户手势开始
  @override
  void didStartUserGesture(
    Route<dynamic> route,
    Route<dynamic>? previousRoute,
  ) {
    debugPrint('> on didStartUserGesture ${AppPages.history}');
    super.didStartUserGesture(route, previousRoute);
  }

  /// 用户手势结束
  @override
  void didStopUserGesture() {
    debugPrint('> on didStopUserGesture ${AppPages.history}');
    super.didStopUserGesture();
  }
}

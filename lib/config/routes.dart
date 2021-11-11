import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:imboy/page/pages.dart';

class AppRoutes {
  static const INITIAL = '/';
  static const SIGN_IN = '/sign_in';
  static const SIGN_UP = '/sign_up';
  static const NotFound = '/not_found';

  static const Mine = '/mine';
  static const Contact = '/contact';
  static const ContactDetail = '/contact_detail';
  static const Conversation = "/conversation";
}

class RouteObservers<R extends Route<dynamic>> extends RouteObserver<R> {
  /// 页面push
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    var name = route.settings.name ?? '';
    if (name.isNotEmpty) {
      AppPages.history.add(name);
    }
    debugPrint('>>>>> on didPush ${AppPages.history}');
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    AppPages.history.remove(route.settings.name);
    debugPrint('>>>>> on didPop ${AppPages.history}');
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute != null) {
      var index = AppPages.history.indexWhere((element) {
        return element == oldRoute?.settings.name;
      });
      var name = newRoute.settings.name ?? '';
      if (name.isNotEmpty) {
        if (index > 0) {
          AppPages.history[index] = name;
        } else {
          AppPages.history.add(name);
        }
      }
    }
    debugPrint('>>>>> on didReplace ${AppPages.history}');
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    AppPages.history.remove(route.settings.name);
    print('didRemove');
    debugPrint('>>>>> on didRemove ${AppPages.history}');
  }

  @override
  void didStartUserGesture(
    Route<dynamic> route,
    Route<dynamic>? previousRoute,
  ) {
    debugPrint('>>>>> on didStartUserGesture ${AppPages.history}');
    super.didStartUserGesture(route, previousRoute);
  }

  @override
  void didStopUserGesture() {
    debugPrint('>>>>> on didStopUserGesture ${AppPages.history}');
    super.didStopUserGesture();
  }
}

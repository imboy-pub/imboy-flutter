import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/config/routes.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

/// 检查是否登录
class RouteAuthMiddleware extends GetMiddleware {
  // priority 数字小优先级高
  @override
  // ignore: overridden_fields
  int? priority = 0;

  RouteAuthMiddleware({required this.priority});

  @override
  RouteSettings? redirect(String? route) {
    bool isLogin = UserRepoLocal.to.isLogin;
    if (isLogin ||
        route == AppRoutes.SIGN_IN ||
        route == AppRoutes.SIGN_UP ||
        route == AppRoutes.INITIAL) {
      return null;
    } else {
      Future.delayed(
        const Duration(seconds: 1),
        () => Get.snackbar("提示", "登录过期,请重新登录"),
      );
      return const RouteSettings(name: AppRoutes.SIGN_IN);
    }
  }
}

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/page/bottom_navigation/bottom_navigation_view.dart';
import 'package:imboy/page/login/login_view.dart';
// import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  await GetStorage.init();

  // Get.putAsync<SharedPreferences>(() async {
  //   final sp = await SharedPreferences.getInstance();
  //   return sp;
  // });
  runApp(IMBoyApp());
}

class IMBoyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    GetStorage box = GetStorage();
    // print("box.hasData(Keys.tokenKey) ");
    // print(box.hasData(Keys.tokenKey));
    return GetMaterialApp(
      // 底部导航组件
      home: box.hasData(Keys.tokenKey) ? BottomNavigationPage() : LoginPage(),
      // 要读取系统语言
      locale: ui.window.locale,
      navigatorKey: Get.key,
      navigatorObservers: [GetObserver()],
      // initialRoute: RouteConfig.main,
      // getPages: RouteConfig.getPages,
      enableLog: true,
      defaultTransition: Transition.fade,
      opaqueRoute: Get.isOpaqueRouteDefault,
      popGesture: Get.isPopGestureEnable,
    );
  }
}

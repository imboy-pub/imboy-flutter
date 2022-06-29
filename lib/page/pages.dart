import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:imboy/config/routes.dart';
import 'package:imboy/middleware/router_auth.dart';
import 'package:imboy/page/passport/passport_view.dart';

import 'contact/contact_binding.dart';
import 'contact/contact_view.dart';
import 'mine/mine_binding.dart';
import 'mine/mine_view.dart';
import 'welcome/welcome_binding.dart';
import 'welcome/welcome_view.dart';

class AppPages {
  static const INITIAL = AppRoutes.INITIAL;
  static final RouteObserver<Route> observer = RouteObservers();
  static List<String> history = [];

  static final List<GetPage> routes = [
    // 免登陆
    GetPage(
      name: AppRoutes.INITIAL,
      page: () => WelcomePage(),
      binding: WelcomeBinding(),
      middlewares: const [
        // RouteWelcomeMiddleware(priority: 1),
      ],
    ),
    GetPage(
      name: AppRoutes.SIGN_IN,
      page: () => PassportPage(),
    ),
    // GetPage(
    //   name: AppRoutes.SIGN_UP,
    //   page: () => SignUpPage(),
    //   binding: SignUpBinding(),
    // ),

    // 需要登录
    GetPage(
      name: AppRoutes.Mine,
      page: () => MinePage(),
      binding: MineBinding(),
      middlewares: [
        RouteAuthMiddleware(priority: 1),
      ],
    ),
    GetPage(
      name: AppRoutes.Contact,
      page: () => ContactPage(),
      binding: ContactBinding(),
      middlewares: [
        RouteAuthMiddleware(priority: 1),
      ],
    ),
  ];

// static final unknownRoute = GetPage(
//   name: AppRoutes.NotFound,
//   page: () => NotfoundView(),
// );

}

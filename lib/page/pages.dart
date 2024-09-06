import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:imboy/config/routes.dart';
import 'package:imboy/middleware/router_auth.dart';

import 'contact/contact/contact_view.dart';
import 'mine/mine/mine_binding.dart';
import 'mine/mine/mine_view.dart';
import 'passport/login_view.dart';
import 'passport/welcome_view.dart';

class AppPages {
  static const INITIAL = AppRoutes.INITIAL;
  static final RouteObserver<Route> observer = RouteObservers();
  static List<String> history = [];

  static final List<GetPage> routes = [
    // 免登陆
    GetPage(
      name: AppRoutes.INITIAL,
      page: () => const WelcomePage(),
      // binding: WelcomeBinding(),
      middlewares: const [
        // RouteWelcomeMiddleware(priority: 1),
      ],
    ),
    GetPage(
      name: AppRoutes.SIGN_IN,
      page: () => const LoginPage(),
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

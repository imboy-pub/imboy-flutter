import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:imboy/config/routes.dart';
import 'package:imboy/middleware/router_auth.dart';

import 'chat/setting/chat_setting_binding.dart';
import 'chat/setting/chat_setting_view.dart';
import 'contact/contact/contact_view.dart';
import 'group/announcement/group_announcement_binding.dart';
import 'group/announcement/group_announcement_view.dart';
import 'mine/mine/mine_binding.dart';
import 'mine/mine/mine_view.dart';
import 'passport/login_view.dart';
import 'passport/welcome_view.dart';

class AppPages {
  static final RouteObserver<Route> observer = RouteObservers();
  static List<String> history = [];

  static final List<GetPage> routes = [
    // 免登陆
    GetPage(
      name: AppRoutes.initial,
      page: () => const WelcomePage(),
      // binding: WelcomeBinding(),
      middlewares: const [
        // RouteWelcomeMiddleware(priority: 1),
      ],
    ),
    GetPage(
      name: AppRoutes.signIn,
      page: () => const LoginPage(),
    ),
    // GetPage(
    //   name: AppRoutes.SIGN_UP,
    //   page: () => SignUpPage(),
    //   binding: SignUpBinding(),
    // ),

    // 需要登录
    GetPage(
      name: AppRoutes.mine,
      page: () => MinePage(),
      binding: MineBinding(),
      middlewares: [
        RouteAuthMiddleware(priority: 1),
      ],
    ),
    GetPage(
      name: AppRoutes.contact,
      page: () => ContactPage(),
      middlewares: [
        RouteAuthMiddleware(priority: 1),
      ],
    ),
    // 群组公告
    GetPage(
      name: AppRoutes.groupAnnouncement,
      page: () => GroupAnnouncementView(),
      binding: GroupAnnouncementBinding(),
      middlewares: [
        RouteAuthMiddleware(priority: 1),
      ],
    ),
    // 聊天设置
    GetPage(
      name: AppRoutes.chatSetting,
      page: () => ChatSettingView(),
      binding: ChatSettingBinding(),
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

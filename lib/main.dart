import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:imboy/component/view/controller.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/helper/log.dart';
import 'package:imboy/page/bottom_navigation/bottom_navigation_view.dart';
import 'package:imboy/page/login/login_view.dart';
import 'package:imboy/page/pages.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

void main() async {
  await init();
  runApp(IMBoyApp());
}

class IMBoyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: Size(375, 812),
      builder: () => RefreshConfiguration(
        headerBuilder: () => ClassicHeader(),
        footerBuilder: () => ClassicFooter(),
        hideFooterWhenNotFull: true,
        headerTriggerDistance: 80,
        maxOverScrollExtent: 100,
        footerTriggerDistance: 150,
        child: GetMaterialApp(
          title: 'IMBoy',
          // 底部导航组件
          home:
              UserRepoLocal.user.isLogin ? BottomNavigationPage() : LoginPage(),
          debugShowCheckedModeBanner: false,
          getPages: AppPages.routes,
          // initialRoute: AppPages.INITIAL,
          // translations: TranslationService(),
          navigatorObservers: [AppPages.observer],
          // localizationsDelegates: [
          //   GlobalMaterialLocalizations.delegate,
          //   GlobalWidgetsLocalizations.delegate,
          //   GlobalCupertinoLocalizations.delegate,
          // ],
          // supportedLocales: ConfigStore.to.languages,
          // locale: ConfigStore.to.locale,
          // fallbackLocale: Locale('en', 'US'),
          defaultTransition: Transition.fade,
          opaqueRoute: Get.isOpaqueRouteDefault,
          popGesture: Get.isPopGestureEnable,
          theme: Get.find<ThemeController>().darkMode == 0
              ? ThemeData.light()
              : ThemeData.dark(),
          enableLog: true,
          logWriterCallback: Logger.write,
        ),
      ),
    );
  }
}

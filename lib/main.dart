import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:imboy/component/helper/log.dart';
import 'package:imboy/component/locales/locales.g.dart';
import 'package:imboy/component/view/controller.dart';
import 'package:imboy/page/bottom_navigation/bottom_navigation_view.dart';
import 'package:imboy/page/pages.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:intl/intl.dart';
import 'package:jiffy/jiffy.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

import 'component/locales/locales.dart';
import 'config/init.dart';
import 'config/theme.dart';
import 'page/passport/passport_view.dart';

void run() async {
  // 要读取系统语言，可以使用window.locale
  String? local = Intl.shortLocale(ui.window.locale.toString());
  debugPrint(">>> on main ${local}");
  // zh_Hans_CN ui.window.locale.toString();
  await Jiffy.locale(local);
  // 强制竖屏 DeviceOrientation.portraitUp
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp])
      .then((_) {
    runApp(IMBoyApp());
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await init();
  run();
  // 暂时不用sentry 2022-04-10
  // await SentryFlutter.init(
  //   (options) => {
  //     options.dsn = SENTRY_DSN,
  //     // To set a uniform sample rate
  //     options.tracesSampleRate = 1.0,
  //     // OR if you prefer, determine traces sample rate based on the sampling context
  //     options.tracesSampler = (samplingContext) {
  //       // return a number between 0 and 1 or null (to fallback to configured value)
  //     },
  //   },
  //   appRunner: () async {
  //     run();
  //   },
  // );
}

class IMBoyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: Size(375, 812),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (_, child) => RefreshConfiguration(
        headerBuilder: () => const ClassicHeader(),
        footerBuilder: () => const ClassicFooter(),
        hideFooterWhenNotFull: true,
        headerTriggerDistance: 80,
        maxOverScrollExtent: 100,
        footerTriggerDistance: 150,
        child: GetMaterialApp(
          title: 'IMBoy',
          // 底部导航组件
          home: UserRepoLocal.to.isLogin
              ? BottomNavigationPage()
              : PassportPage(),
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
          translationsKeys: AppTranslation.translations,

          translations: IMBoyTranslations(), // 你的翻译
          locale: const Locale('zh', 'CN'), // 将会按照此处指定的语言翻译
          fallbackLocale: const Locale('en', 'US'), // 添加一个回调语言选项，以备上面指定的语言翻译不存在
          defaultTransition: Transition.fade,
          opaqueRoute: Get.isOpaqueRouteDefault,
          popGesture: Get.isPopGestureEnable,
          // theme: Get.find<ThemeController>().darkMode == 0
          //     ? ThemeData.light()
          //     : ThemeData.dark(),
          builder: EasyLoading.init(),
          theme: ThemeData(
            brightness: Get.find<ThemeController>().darkMode == 0
                ? Brightness.light
                : Brightness.dark,
            primarySwatch: createMaterialColor(const Color(0xFF223344)),
          ),
          enableLog: true,
          logWriterCallback: Logger.write,
        ),
      ),
    );
  }
}

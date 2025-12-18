import 'package:feedback/feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:imboy/component/helper/func.dart';
import 'package:imboy/page/passport/welcome_view.dart';

// ignore: depend_on_referenced_packages
import 'package:jiffy/jiffy.dart';

import 'package:imboy/component/helper/log.dart';
import 'package:imboy/component/locales/locales.g.dart';

import 'package:imboy/page/bottom_navigation/bottom_navigation_view.dart';
import 'package:imboy/page/pages.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/theme/theme_manager.dart';

import 'component/locales/locales.dart';
import 'config/init.dart';

void run() async {
  await Jiffy.setLocale(jiffyLocal(sysLang('jiffy')));
  Provider.debugCheckInvalidValueType = null; // ⛔ 忽略 Provider 的类型安全检查

  // 强制竖屏 DeviceOrientation.portraitUp
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]).then((
    _,
  ) {
    runApp(
      BetterFeedback(mode: FeedbackMode.navigate, child: const IMBoyApp()),
    );
    // runApp(const IMBoyApp());
  });
}

class IMBoyApp extends StatefulWidget {
  const IMBoyApp({super.key});

  @override
  State<IMBoyApp> createState() => IMBoyAppState();
}

class IMBoyAppState extends State<IMBoyApp> {
  // 监听字体大小变化
  RxString currentFontSize = 'normal'.obs;

  @override
  void initState() {
    super.initState();

    // 初始化字体大小设置
    currentFontSize.value = UserRepoLocal.to.setting.fontSize;

    // 监听 ThemeManager 的主题设置变化
    // 使用 GetBuilder 或直接监听 ThemeManager 的更新
    ThemeManager.instance.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });

    initialization();
  }

  void initialization() async {
    /// HACK: 启动页关闭
    await Future.delayed(const Duration(seconds: 2));
    FlutterNativeSplash.remove();
  }

  @override
  Widget build(BuildContext context) {
    String lang = jiffyLocal(sysLang(''));
    List<String> code = lang.split('_');
    if (lang == 'ru') {
      code.add('RU');
    }
    return Directionality(
      // 为子树提供文本方向信息。它告诉应用中的其他widget应该按照从左到右（LTR）还是从右到左（RTL）的顺序来排列内容。
      textDirection: TextDirection.ltr,
      child: ScreenUtilInit(
        designSize: const Size(375, 812),
        minTextAdapt: true,
        splitScreenMode: true,
        // fix https://github.com/flutter/flutter/issues/126585
        useInheritedMediaQuery: true,
        builder: (_, child) => GetMaterialApp(
          navigatorKey: navigatorKey,
          title: appName,
          // 底部导航组件
          home: UserRepoLocal.to.currentUid.isNotEmpty
              ? BottomNavigationPage()
              : const WelcomePage(),
          debugShowCheckedModeBanner: false,
          // getPages: AppPages.routes,
          // initialRoute: AppPages.INITIAL,
          navigatorObservers: [AppPages.observer],
          
          // 配置本地化代理
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          
          // 配置支持的语言环境
          supportedLocales: const [
            Locale('zh', 'CN'), // 简体中文
            Locale('zh', 'TW'), // 繁体中文
            Locale('en', 'US'), // 美式英语
            Locale('en', 'GB'), // 英式英语
            Locale('ru', 'RU'), // 俄语
          ],
          
          // 配置 GetX 翻译
          translationsKeys: AppTranslation.translations,
          translations: IMBoyTranslations(),
          
          // 翻译将在该语言环境中显示
          locale: Locale(code[0], code[1]),
          // 如果选择了无效的语言环境，则指定备用语言环境。
          fallbackLocale: const Locale('en', 'US'),
          // 添加一个回调语言选项，以备上面指定的语言翻译不存在
          defaultTransition: Transition.fade,
          // opaqueRoute: Get.isOpaqueRouteDefault,
          // popGesture: Get.isPopGestureEnable,
          builder: EasyLoading.init(),
          theme: ThemeManager.instance.lightTheme,
          darkTheme: ThemeManager.instance.darkTheme,
          // themeMode: ThemeMode.system, // 跟随系统主题
          // 配置 本地存储 主题类型
          themeMode: getLocalProfileAboutThemeModel(),
          enableLog: true,
          logWriterCallback: Logger.write,
        ),
      ),
    );
  }
}

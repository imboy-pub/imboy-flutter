import 'dart:io';

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

import 'package:imboy/component/helper/log.dart';

// slang 国际化
import 'package:imboy/i18n/strings.g.dart';

import 'package:imboy/page/bottom_navigation/bottom_navigation_view.dart';
import 'package:imboy/page/pages.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/theme/theme_manager.dart';

import 'config/init.dart';

void run() async {
  // Jiffy 已移除，使用 intl 包的内置语言支持
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

  /// 初始化 slang locale
  void _initLocale() {
    // 尝试从用户设置中获取语言偏好
    // 如果没有设置，则使用设备语言
    try {
      // 获取设备语言
      final deviceLocale = AppLocaleUtils.findDeviceLocale();

      // 这里可以从本地存储中读取用户保存的语言设置
      // String savedLanguage = UserRepoLocal.to.setting.language;
      // if (savedLanguage.isNotEmpty) {
      //   LocaleSettings.setLocaleRaw(savedLanguage);
      // } else {
      //   LocaleSettings.setLocale(deviceLocale);
      // }

      // 目前使用设备语言作为默认语言
      LocaleSettings.setLocale(deviceLocale);
    } catch (e) {
      // 如果获取设备语言失败，使用默认的简体中文
      LocaleSettings.setLocale(AppLocale.zhCn);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 在第一帧渲染完成后移除启动画面
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FlutterNativeSplash.remove();

      // macOS平台：发送通知关闭启动窗口
      if (Platform.isMacOS) {
        const platform = MethodChannel('imboy.app/splash');
        platform.invokeMethod('closeSplash');
      }
    });

    // 初始化 slang locale，从系统语言或用户设置中获取
    _initLocale();

    return Directionality(
      // 为子树提供文本方向信息。它告诉应用中的其他widget应该按照从左到右（LTR）还是从右到左（RTL）的顺序来排列内容。
      textDirection: TextDirection.ltr,
      child: ScreenUtilInit(
        designSize: const Size(375, 812),
        minTextAdapt: true,
        splitScreenMode: true,
        // fix https://github.com/flutter/flutter/issues/126585
        useInheritedMediaQuery: true,
        builder: (_, child) => TranslationProvider(
          // slang TranslationProvider，用于在运行时切换语言
          child: GetMaterialApp(
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

            // 配置支持的语言环境 - 使用 slang 生成的支持语言列表
            supportedLocales: AppLocaleUtils.supportedLocales,

            // 使用 slang 的当前 locale
            locale: LocaleSettings.currentLocale.flutterLocale,

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
      ),
    );
  }
}

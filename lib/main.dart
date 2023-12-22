import 'dart:io';

import 'package:drag_ball/drag_ball.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/feedback_builder.dart';

// ignore: depend_on_referenced_packages
import 'package:jiffy/jiffy.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:feedback/feedback.dart';
import 'package:niku/namespace.dart' as n;

import 'package:imboy/component/controller.dart';
import 'package:imboy/component/helper/log.dart';
import 'package:imboy/component/locales/locales.g.dart';
import 'package:imboy/component/ui/common.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/page/bottom_navigation/bottom_navigation_view.dart';
import 'package:imboy/page/pages.dart';
import 'package:imboy/store/provider/attachment_provider.dart';
import 'package:imboy/store/provider/feedback_provider.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import 'component/locales/locales.dart';
import 'config/init.dart';
import 'config/theme.dart';
import 'page/passport/passport_view.dart';

void run() async {
  await Jiffy.setLocale(sysLang('jiffy'));
  // 强制竖屏 DeviceOrientation.portraitUp
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp])
      .then((_) {
    runApp(
      BetterFeedback(
        theme: FeedbackThemeData(
          background: Colors.grey,
          feedbackSheetColor: Colors.grey[50]!,
          drawColors: [
            Colors.red,
            Colors.orange,
            Colors.yellow,
            Colors.green,
            Colors.cyan,
            Colors.blue,
            Colors.purple,
          ],
        ),
        feedbackBuilder: (context, onSubmit, scrollController) =>
            IMBoyFeedbackForm(
          onSubmit: onSubmit,
          scrollController: scrollController,
        ),
        child: const IMBoyApp(),
      ),
    );
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await init();
  // await initJPush();
  if (kDebugMode) {
    run();
  } else {
    await SentryFlutter.init(
      (options) {
        options.dsn = SENTRY_DSN;
      },
      appRunner: () async {
        run();
      },
    );
  }
}

class IMBoyApp extends StatelessWidget {
  const IMBoyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Dragball(
        icon: const DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primaryElement,
          ),
          child: Padding(
            padding: EdgeInsets.all(3),
            child: Icon(
              Icons.navigate_before_rounded,
              size: 24,
              color: Colors.white,
            ),
          ),
        ),
        ball: SizedBox(
          width: 96,
          height: 30,
          child: n.Row(
              [const Space(width: 18), Text('反馈建议'.tr), const Space(width: 18)])
            ..backgroundColor = AppColors.ChatInputBackgroundColor
            // 垂直居中
            ..mainAxisAlignment = MainAxisAlignment.spaceBetween,
        ),
        initialPosition: const DragballPosition.defaultPosition(),
        onTap: () {
          BetterFeedback.of(context).show((UserFeedback feedback) async {
            iPrint(
                "BetterFeedback show extra ${feedback.extra.toString()} isLogin ${UserRepoLocal.to.isLogin}");
            // Uint8List feedbackScreenshot = feedback.screenshot
            // if (UserRepoLocal.to.isLogin == false) {
            //   EasyLoading.showError("需要登录才能提交反馈建议".tr);
            //   return;
            // }
            if (feedback.text.isEmpty) {
              EasyLoading.showError("反馈内容不能为空".tr);
              return;
            }
            Uint8List result;
            if (Platform.isAndroid || Platform.isIOS) {
              // 压缩上传图片
              result = await FlutterImageCompress.compressWithList(
                feedback.screenshot,
                minHeight: Get.height.toInt(),
                minWidth: Get.width.toInt(),
                quality: 60,
                // rotate: 90,
              );
            } else {
              result = feedback.screenshot;
            }
            await AttachmentProvider.uploadBytes("feedback", result, (
              Map<String, dynamic> resp,
              String uri,
            ) async {
              FeedbackProvider p = FeedbackProvider();
              var type = feedback.extra?['feedback_type'] ?? '';
              var rating = feedback.extra?['rating'] ?? '';

              Map<String, dynamic> data = {
                'title': '',
                'rating': rating,
                'type': type.toString().split('.').last.replaceAll('_', ' '),
                'description': feedback.text,
                'screenshot': [uri],
              };
              bool res = await p.add(data);
              if (res) {
                EasyLoading.showSuccess('操作成功'.tr);
              } else {
                EasyLoading.showError('操作失败'.tr);
              }
            }, (Error error) {
              debugPrint("> on upload ${error.toString()}");
            }, process: false);
          });
        },
        onPositionChanged: (DragballPosition position) {
          // debugPrint(position.toString());
        },
        child: ScreenUtilInit(
          designSize: const Size(375, 812),
          minTextAdapt: true,
          splitScreenMode: true,
          // fix https://github.com/flutter/flutter/issues/126585
          useInheritedMediaQuery: true,
          builder: (_, child) => GetMaterialApp(
            navigatorKey: navigatorKey,
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

            translations: IMBoyTranslations(),
            // 你的翻译
            locale: const Locale('zh', 'CN'),
            // 将会按照此处指定的语言翻译
            fallbackLocale: const Locale('en', 'US'),
            // 添加一个回调语言选项，以备上面指定的语言翻译不存在
            defaultTransition: Transition.fade,
            opaqueRoute: Get.isOpaqueRouteDefault,
            popGesture: Get.isPopGestureEnable,
            // theme: Get.find<ThemeController>().darkMode == 0
            //     ? ThemeData.light()
            //     : ThemeData.dark(),
            builder: EasyLoading.init(),
            theme: ThemeData(
              platform: TargetPlatform.iOS,
              brightness: Get.find<ThemeController>().darkMode == 0
                  ? Brightness.light
                  : Brightness.dark,
              primarySwatch: createMaterialColor(const Color(0xFF223344)),
              useMaterial3: true,
              // 设置为 true 影响到 其他样式，例如我的页面的样式
              colorScheme: ColorScheme.fromSeed(
                seedColor: AppColors.primaryElement,
                primary: AppColors.primaryElement,
                primaryContainer: AppColors.primaryElement,
                // ···
                brightness: Get.find<ThemeController>().darkMode == 0
                    ? Brightness.light
                    : Brightness.dark,
              ),
            ),
            enableLog: true,
            logWriterCallback: Logger.write,
          ),
        ));
  }
}

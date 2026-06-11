import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/config/const.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/app_logger.dart';

// slang 国际化
import 'package:imboy/i18n/strings.g.dart';

import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/theme/providers/theme_provider.dart';
import 'package:imboy/theme/theme_manager.dart';

import 'config/init.dart';
import 'config/router/app_router.dart';
import 'service/message.dart';

/// 应用级共享 ProviderContainer
/// MessageService 和 Widget 树共用，保证状态同步
final appProviderContainer = ProviderContainer();

/// 应用初始化标志（防止重复初始化）
bool _localeInitialized = false;
bool _fontSizeInitialized = false;
const String appEnv = String.fromEnvironment('APP_ENV', defaultValue: 'pro');

/// `flutter run --target lib/run.dart` requires a top-level `main` entrypoint.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await AppInitializer.initialize(env: appEnv, signKeyVsn: '1');
    await run();
  } catch (e) {
  }
}

Future<void> run() async {
  // === 全局错误捕获 ===
  // 捕获 Flutter 框架内部错误（Widget build、layout、paint 等）
  FlutterError.onError = (FlutterErrorDetails details) {
    AppLogger.fatal(
      'FlutterError: ${details.exceptionAsString()}',
      details.exception,
      details.stack,
    );
    // 保留默认行为（debug 模式打印到控制台）
    FlutterError.presentError(details);
  };

  // 捕获 Dart 异步未处理异常（Future 中未被 catch 的错误）
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    AppLogger.fatal('PlatformDispatcher uncaught error: $error', error, stack);
    // 返回 true 表示已处理，不再传播
    return true;
  };

  // Web 平台不支持屏幕方向设置
  if (!kIsWeb) {
    // 强制竖屏 DeviceOrientation.portraitUp
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  // 注入共享 ProviderContainer 到 MessageService，确保与 UI 状态同步
  MessageService.setProviderContainer(appProviderContainer);
  // 注入共享 ProviderContainer 到 ThemeManager，确保主题状态与 UI 同步
  ThemeManager.instance.setProviderContainer(appProviderContainer);

  // Flutter 3.22+ 多视图模式兼容
  // 使用 UncontrolledProviderScope 共享同一个 ProviderContainer
  final app = UncontrolledProviderScope(
    container: appProviderContainer,
    child: const IMBoyApp(),
  );

  if (kIsWeb) {
    // Web 平台：使用 runWidget 支持多视图模式
    // 从 PlatformDispatcher 获取默认视图
    final view = PlatformDispatcher.instance.views.first;
    runWidget(View(view: view, child: app));
  } else {
    // 非 Web 平台：继续使用 runApp
    runApp(app);
  }
}

class IMBoyApp extends ConsumerStatefulWidget {
  const IMBoyApp({super.key});

  @override
  ConsumerState<IMBoyApp> createState() => _IMBoyAppState();
}

class _IMBoyAppState extends ConsumerState<IMBoyApp> {
  /// 当前语言环境（用于触发重建）
  AppLocale _currentLocale = LocaleSettings.currentLocale;
  late final GoRouter _router;
  StreamSubscription<AppLocale>? _localeSubscription;

  @override
  void initState() {
    super.initState();
    _router = ref.read(goRouterProvider);
    // 监听语言变化
    _localeSubscription = LocaleSettings.getLocaleStream().listen((locale) {
      if (mounted && _currentLocale != locale) {
        setState(() {
          _currentLocale = locale;
        });
      }
    });
  }

  @override
  void dispose() {
    _localeSubscription?.cancel();
    super.dispose();
  }

  /// 初始化 slang locale
  Future<void> _initLocale() async {
    if (_localeInitialized) return;

    try {
      // 优先从本地存储读取用户上次选择的语言
      final savedLocaleName = StorageService.to.getString(
        Keys.currentLanguageCode,
      );

      if (savedLocaleName.isNotEmpty) {
        // 通过枚举名称查找 AppLocale（如 'zhCn' -> AppLocale.zhCn）
        final savedLocale = AppLocale.values.firstWhere(
          (locale) => locale.name == savedLocaleName,
          orElse: () => AppLocale.zhCn,
        );
        // 使用异步方法设置语言
        await LocaleSettings.setLocale(savedLocale);
      } else {
        // 没有保存的语言，使用默认的简体中文
        await LocaleSettings.setLocale(AppLocale.zhCn);
      }
      _localeInitialized = true;
    } catch (e) {
      // 如果获取失败，使用默认的简体中文
      await LocaleSettings.setLocale(AppLocale.zhCn);
      _localeInitialized = true;
    }
  }

  /// 初始化字体大小设置
  void _initFontSize(WidgetRef ref) {
    if (_fontSizeInitialized) return;

    try {
      // 从用户设置中读取字体大小
      final fontSizeValue = UserRepoLocal.to.setting.fontSize;
      final themeNotifier = ref.read(themeProvider.notifier);
      // 更新字体大小
      themeNotifier.updateFontSize(fontSizeValue);
      _fontSizeInitialized = true;
    } catch (e) {
      _fontSizeInitialized = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    // 初始化语言和字体大小设置（只执行一次）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 移除启动画面
      FlutterNativeSplash.remove();

      // 初始化语言和字体大小
      _initLocale();
      _initFontSize(ref);
    });

    // 监听主题状态
    final themeState = ref.watch(themeProvider);
    final themeMode = ref.watch(themeModeProvider);

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
          child: MaterialApp.router(
            // Flutter 原生配置
            title: appName,
            debugShowCheckedModeBanner: false,

            // go_router 配置
            routerConfig: _router,

            // 配置本地化代理
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],

            // 配置支持的语言环境 - 使用 slang 生成的支持语言列表
            supportedLocales: AppLocaleUtils.supportedLocales,

            // 使用当前语言环境（响应式更新）
            locale: _currentLocale.flutterLocale,

            builder: EasyLoading.init(),
            // 使用 Riverpod 主题系统（字体大小变化时会自动重建）
            theme: themeState.isDarkMode
                ? ref.read(themeProvider.notifier).darkTheme
                : ref.read(themeProvider.notifier).lightTheme,
            darkTheme: ref.read(themeProvider.notifier).darkTheme,
            // 使用 Riverpod themeMode provider
            themeMode: themeMode,
          ),
        ),
      ),
    );
  }
}

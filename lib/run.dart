import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderFlex;
import 'package:flutter/services.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/capabilities/capability_locator.dart';
import 'package:imboy/capabilities/adapters/wechat_assets_picker_adapter.dart';
import 'package:imboy/capabilities/contracts/media_picker_capability.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/page/error/init_error_page.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/app_logger.dart';

// slang 国际化
import 'package:imboy/i18n/strings.g.dart';

import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/page/passport/passport_notifier.dart';
import 'package:imboy/theme/providers/theme_provider.dart';
import 'package:imboy/theme/theme_manager.dart';

import 'config/init.dart';
import 'config/router/app_router.dart';
import 'service/incoming_backup_handler.dart';
import 'service/message.dart';

/// 应用级共享 ProviderContainer
/// MessageService 和 Widget 树共用，保证状态同步
final appProviderContainer = ProviderContainer();

/// VM 注入登录辅助（仅调试用）：通过 appProviderContainer 调用真实 loginUser
/// 返回 null=成功，否则错误字符串
Future<String?> debugVmLogin(
  String accountType,
  String account,
  String password,
) async {
  debugPrint('🔍 debugVmLogin START');
  // passportProvider 是 autoDispose，用 listen 保持存活
  final sub = appProviderContainer.listen(passportProvider, (_, _) {});
  try {
    final result = await appProviderContainer
        .read(passportProvider.notifier)
        .loginUser(accountType, account, password);
    debugPrint('🔍 debugVmLogin RESULT: $result');
    debugVmLoginResult = result ?? 'SUCCESS_NULL';
    return result;
  } catch (e, s) {
    debugPrint('🔍 debugVmLogin THREW: $e\n$s');
    debugVmLoginResult = 'THREW: $e';
    return e.toString();
  } finally {
    sub.close();
  }
}

/// 调试用：存储最后一次 debugVmLogin 的结果
String debugVmLoginResult = '';

/// 应用初始化标志（防止重复初始化）
bool _localeInitialized = false;
bool _fontSizeInitialized = false;
const String appEnv = String.fromEnvironment('APP_ENV', defaultValue: 'pro');

/// `flutter run --target lib/run.dart` requires a top-level `main` entrypoint.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await bootstrapFromRun();
}

/// run.dart 入口的完整启动链（与 main.dart 的 bootstrap 同构）。
///
/// #95：init 失败渲染 [InitErrorPage] 兜底页替代静默白屏，
/// 重试重新走完整链（AppInitializer._initialized 仅成功后置位，可重入）。
Future<void> bootstrapFromRun() async {
  try {
    await AppInitializer.initialize(env: appEnv, signKeyVsn: '1');
    await run();
  } catch (e) {
    debugPrint('[run] run error: $e');
    runApp(InitErrorPage(error: e, onRetry: bootstrapFromRun));
  }
}

Future<void> run() async {
  // === 全局错误捕获 ===
  // TODO(overflow-probe): 临时定位 RenderFlex(137×22) 溢出组件，定位后删除
  bool overflowProbed = false;
  void probeOverflow() {
    if (overflowProbed) return;
    overflowProbed = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final hits = <String>[];
      void walk(Element el) {
        if (el is RenderObjectElement) {
          final ro = el.renderObject;
          if (ro is RenderFlex &&
              (ro.size.width - 137).abs() < 3 &&
              (ro.size.height - 22).abs() < 3) {
            final chain = <String>[];
            el.visitAncestorElements((a) {
              chain.add(a.widget.runtimeType.toString());
              return chain.length < 10;
            });
            hits.add(
              '${el.widget.runtimeType} @depth=${el.depth} '
              '<- ${chain.join(' < ')}',
            );
          }
        }
        el.visitChildren(walk);
      }

      WidgetsBinding.instance.rootElement?.visitChildren(walk);
      debugPrint(
        '🐛 [overflow-probe] '
        '${hits.isEmpty ? "未匹配（约束已变）" : hits.join(' | ')}',
      );
    });
  }

  // 捕获 Flutter 框架内部错误（Widget build、layout、paint 等）
  FlutterError.onError = (FlutterErrorDetails details) {
    AppLogger.fatal(
      'FlutterError: ${details.exceptionAsString()}',
      details.exception,
      details.stack,
    );
    // 保留默认行为（debug 模式打印到控制台）
    FlutterError.presentError(details);
    // TODO(overflow-probe): 溢出时触发一次定位，定位后删除
    final msg = details.exceptionAsString();
    if (msg.contains('RenderFlex') && details.toString().contains('overflow')) {
      probeOverflow();
    }
  };

  // 捕获 Dart 异步未处理异常（Future 中未被 catch 的错误）
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    // ponytail: audio_waveforms 2.0.1 的 PlayerController.dispose() 内部
    // fire-and-forget 触发 stopWaveformExtraction()；Android（尤华为 OMX）
    // 上 codec 已被 just_audio 释放后再 stop() 会异步抛 IllegalStateException。
    // 该 Future 在库内未 await，调用点 try/catch 接不住，属无害 teardown 竞态，
    // 按签名吞掉以免污染 AppLogger.fatal。
    final s = error.toString();
    if (s.contains('WaveformExtractor.stop') &&
        s.contains('IllegalStateException')) {
      return true;
    }
    AppLogger.fatal('PlatformDispatcher uncaught error: $error', error, stack);
    // 返回 true 表示已处理，不再传播
    return true;
  };

  // Web 平台不支持屏幕方向设置
  if (!kIsWeb) {
    // 强制竖屏 DeviceOrientation.portraitUp
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  // 注册能力契约层适配器
  CapabilityLocator.I.register<MediaPickerCapability>(
    const WechatAssetsPickerAdapter(),
  );

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
  StreamSubscription<String>? _incomingBackupSub;

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
    // 热启动：App 已在前台时收到外部 App 打开/分享的 E2EE 备份文件，
    // 直接跳导入页。用全局 navigatorKey 避免 Riverpod ref 生命周期问题。
    _incomingBackupSub = IncomingBackupHandler.watchIncomingFiles().listen(
      (path) {
        final ctx = navigatorKey.currentContext;
        // navigatorKey 是全局 key（config/init.dart），生命周期长于任何 widget；
        // 非 null 即可安全导航。linter 无法识别这点，故显式忽略。
        if (ctx != null) {
          // ignore: use_build_context_synchronously
          ctx.go('/e2ee_backup_import', extra: {'initialFilePath': path});
        }
      },
      onError: (Object e) {
        // 非备份文件的分享会被 stream 内部 handleError 吞掉；
        // 走到这里的都是意外异常，调试时打印即可。
        if (kDebugMode) {
          debugPrint('[IMBoyApp] incoming backup stream error: $e');
        }
      },
    );
  }

  @override
  void dispose() {
    _localeSubscription?.cancel();
    _incomingBackupSub?.cancel();
    super.dispose();
  }

  /// 初始化 slang locale
  Future<void> _initLocale() async {
    if (_localeInitialized) return;
    // 进入即置位：addPostFrameCallback 每次 build 都会触发本方法，
    // 若等 await 完成后才置位，首个 await 挂起期间的重入会并发执行
    // setPluralResolver，撞上 slang lazy 加载同一 locale 的竞态 NPE。
    _localeInitialized = true;

    await _registerPluralResolvers();

    try {
      // 优先从本地存储读取用户上次选择的语言
      final savedLocaleName = StorageService.to.getString(
        Keys.currentLanguageCode,
      );

      if (Keys.isFollowSystemLanguage(savedLocaleName)) {
        // 跟随系统（显式选的，或从未设置过的新装）。必须先判这一支 ——
        // 哨兵值不是枚举名，落到下面的 firstWhere 会被 orElse 兜成简体中文，
        // 用户选的「跟随系统」一重启就失效。
        // slang 匹配不到设备语言时自己回落 base_locale，不需要再兜一层。
        await LocaleSettings.useDeviceLocale();
      } else {
        // 通过枚举名称查找 AppLocale（如 'zhCn' -> AppLocale.zhCn）
        final savedLocale = AppLocale.values.firstWhere(
          (locale) => locale.name == savedLocaleName,
          orElse: () => AppLocale.zhCn,
        );
        // 使用异步方法设置语言
        await LocaleSettings.setLocale(savedLocale);
      }
    } catch (e) {
      // 如果获取失败，使用默认的简体中文
      await LocaleSettings.setLocale(AppLocale.zhCn);
    }
  }

  /// 为 slang 内置表里没有的语言注册 cardinal resolver。
  ///
  /// 相对时间三个 key（timeDaysAgo / timeHoursAgo / timeMinutesAgo）改成 plural
  /// 后，slang 会对每种语言查 resolver；zh / ja / ko / ar / ru 不在内置表里，
  /// 每次渲染都会打一条
  /// `Resolver for <lang = zh> not specified! ... A fallback is used now.`
  ///
  /// 这几种语言在本项目里只提供 `other` 一档（无单复数变化，或复数规则复杂
  /// 待母语者补），恒返回 other 即为正确行为 —— 显式注册只为消除噪音日志，
  /// 不改变任何输出。ru / ar 将来补齐 few/many 时，把对应 resolver 换成
  /// 真实规则即可。
  Future<void> _registerPluralResolvers() async {
    for (final lang in const ['zh', 'ja', 'ko', 'ar', 'ru']) {
      await LocaleSettings.setPluralResolver(
        language: lang,
        cardinalResolver: (n, {zero, one, two, few, many, other}) =>
            other ?? one ?? n.toString(),
        ordinalResolver: (n, {zero, one, two, few, many, other}) =>
            other ?? one ?? n.toString(),
      );
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

            builder: AppLoading.init(),
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

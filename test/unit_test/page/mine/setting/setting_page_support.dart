// SettingPage 设置页共享 fixture（拆分自 setting_page_test.dart，
// ratchet <800 行约束）：FakeLogoutSessions 与 pump/gesture/font helpers。
// 本文件不含用例。

import 'package:flutter/foundation.dart' show debugPrintSynchronously;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:imboy/page/mine/dark_model/dark_model_page.dart';
import 'package:imboy/page/mine/font_size/font_size_page.dart';
import 'package:imboy/theme/providers/theme_provider.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';

import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/init.dart' as init;
import 'package:imboy/config/routes.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/organization/presentation/organization_routes.dart';
import 'package:imboy/page/mine/setting/setting_page.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/auth_session_scope.dart';
import 'package:imboy/page/web_shell/web_shell_route.dart';

class FakeLogoutSessions extends ChangeNotifier implements AuthSessionReader {
  @override
  bool get transitionFailed => false;
  @override
  AuthSessionScope current = (
    uid: 'synthetic',
    generation: 0,
    transitioning: false,
  );
  @override
  bool isCurrent(AuthSessionScope captured) => current == captured;
  void transition() {
    current = (
      uid: current.uid,
      generation: current.generation,
      transitioning: true,
    );
    notifyListeners();
  }
}

/// SettingPage widget test (843 行核心入口)
///
/// 覆盖：
///   - InsetGrouped 背景 (surfaceGrouped)
///   - AppBar title "设置"
///   - 通用 / 隐私与安全 等 section header 渲染
///   - 关键设置项 cell：账号安全 / 语言 / 深色模式 / 字体大小
///   - 跳转契约：tap 设置项触发 context.push 到对应路由
///
/// 测试策略：直接 ProviderScope（themeProvider/themeModeProvider/userRepoProvider/
/// allowSearchProvider 默认 build 在测试中可用，flutter_test_config.dart 已 mock
/// path_provider + StorageService）。每个测试末尾 unmountSettingPage 清理 Riverpod scheduler。
GoRouter _stubRouter({
  FakeLogoutSessions? shellSessions,
  bool webMode = false,
  bool realPreferencePages = false,
  Future<String> Function()? readWebDeviceId,
  Future<bool> Function(String, void Function())? revokeWebDevice,
  Future<bool> Function(int?)? quitLocal,
  bool Function(int)? isLoggedOutAfter,
}) {
  Widget stub(String label) => Scaffold(body: Center(child: Text(label)));
  return GoRouter(
    initialLocation: '/setting',
    routes: [
      GoRoute(
        path: '/setting',
        builder: (_, state) {
          final page = SettingPage(
            webMode: webMode,
            readWebDeviceId: readWebDeviceId,
            revokeWebDevice: revokeWebDevice,
            quitLocal: quitLocal,
            isLoggedOutAfter: isLoggedOutAfter,
          );
          return shellSessions == null
              ? page
              : WebShellRoute(
                  uri: state.uri,
                  sessionReader: shellSessions,
                  child: page,
                );
        },
      ),
      GoRoute(
        path: kOrganizationPickerPath,
        builder: (_, _) => stub('organization picker stub'),
      ),
      // 设置页内多个跳转目标
      GoRoute(
        path: '/account_security',
        builder: (_, _) => stub('account_security stub'),
      ),
      GoRoute(path: '/language', builder: (_, _) => stub('language stub')),
      GoRoute(
        path: '/terms_of_service',
        builder: (_, _) => stub('terms_of_service stub'),
      ),
      GoRoute(
        path: '/logout_account',
        builder: (_, _) => stub('logout_account stub'),
      ),
      GoRoute(
        path: '/dark_model',
        builder: (_, _) => realPreferencePages
            ? const DarkModelPage()
            : stub('dark_model stub'),
      ),
      // 并集修复：main 的字体导航用例（默认 harness）直接点按 tile 并断言真实
      // FontSizePage（Slider/GlassBackButton），而车道用例只在 realPreferencePages
      // 真实偏好 harness 里点按。/font_size 恒挂真实页面对两者均成立；
      // /dark_model 仍按 realPreferencePages 条件式（stub 导航用例依赖 stub）。
      GoRoute(path: '/font_size', builder: (_, _) => const FontSizePage()),
      GoRoute(
        path: '/bottom_navigation',
        builder: (_, _) => stub('bottom_navigation stub'),
      ),
      GoRoute(
        path: AppRoutes.signIn,
        builder: (_, _) => stub('signed out stub'),
      ),
      GoRoute(
        path: '/welcome',
        builder: (_, _) => stub('native signed out stub'),
      ),
    ],
  );
}

Future<void> pumpSettingPage(
  WidgetTester tester, {
  double width = 390,
  double scale = 1,
  Brightness brightness = Brightness.light,
  bool webMode = false,
  FakeLogoutSessions? shellSessions,
  Future<String> Function()? readWebDeviceId,
  Future<bool> Function(String, void Function())? revokeWebDevice,
  Future<bool> Function(int?)? quitLocal,
  bool Function(int)? isLoggedOutAfter,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = Size(
    width,
    1200,
  ); // 大画布让 SingleChildScrollView 内容尽量可见
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
  });

  await tester.pumpWidget(
    ProviderScope(
      child: TranslationProvider(
        child: MaterialApp.router(
          routerConfig: _stubRouter(
            shellSessions: shellSessions,
            webMode: webMode,
            readWebDeviceId: readWebDeviceId,
            revokeWebDevice: revokeWebDevice,
            quitLocal: quitLocal,
            isLoggedOutAfter: isLoggedOutAfter,
          ),
          theme: ThemeData(brightness: brightness),
          builder: (context, child) => EasyLoading.init()(
            context,
            MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> unmountSettingPage(WidgetTester tester) async {
  await EasyLoading.dismiss(animation: false);
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
}

Future<(ProviderContainer, GoRouter)> realPreferenceContext(
  WidgetTester tester,
  double width,
) async {
  late SharedPreferences prefs;
  late Map<String, Object?> saved;
  late Map<String, dynamic> user;
  final originalFont = init.currentFontSize.value;
  ProviderContainer? scope;
  GoRouter? routes;
  var captured = false;
  addTearDown(() async {
    await unmountSettingPage(tester);
    routes?.dispose();
    ThemeManager.instance.dispose();
    scope?.dispose();
    if (!captured) return;
    await tester.runAsync(() async {
      for (final entry in saved.entries) {
        final value = entry.value;
        if (value == null) {
          await prefs.remove(entry.key);
        } else if (value is bool) {
          await prefs.setBool(entry.key, value);
        } else {
          await prefs.setString(entry.key, value as String);
        }
      }
      await StorageService.setMap(Keys.currentUser, user);
      init.currentFontSize.value = originalFont;
    });
  });
  await tester.runAsync(() async {
    // Construct session/Theme write chains in the real zone, before UI gestures.
    expect(UserRepoLocal.to.isAuthTransitioning, isFalse);
    await Future<void>.value();
    prefs = await SharedPreferences.getInstance();
    saved = {
      for (final key in [
        'theme_is_dark_mode',
        'theme_follow_system',
        'theme_font_size',
        'theme_use_dynamic_color',
      ])
        key: prefs.get(key),
    };
    user = Map<String, dynamic>.from(StorageService.getMap(Keys.currentUser));
    captured = true;
    await prefs.setBool('theme_is_dark_mode', false);
    await prefs.setBool('theme_follow_system', false);
    await prefs.setString('theme_font_size', 'normal');
    await StorageService.setMap(Keys.currentUser, {
      ...user,
      'setting': {...?(user['setting'] as Map?), 'font_size': 'normal'},
    });
    scope = ProviderContainer();
    scope!.listen(themeProvider, (_, _) {});
    await scope!.read(themeProvider.notifier).loadThemePreference();
    ThemeManager.instance.setProviderContainer(scope!);
  });
  final container = scope!;
  final router = routes = _stubRouter(webMode: true, realPreferencePages: true);
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 640);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: TranslationProvider(
        child: Consumer(
          builder: (_, ref, _) {
            ref.watch(themeProvider);
            final theme = ref.read(themeProvider.notifier);
            return MaterialApp.router(
              routerConfig: router,
              theme: theme.lightTheme,
              darkTheme: theme.darkTheme,
              themeMode: ref.watch(themeModeProvider),
              builder: EasyLoading.init(),
            );
          },
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (container, router);
}

Future<void> preferenceGesture(
  WidgetTester tester,
  ProviderContainer scope,
  Future<void> Function() gesture,
) async {
  await tester.runAsync(() async {
    debugPrintSynchronously('SETTINGS_RETURN gesture.begin');
    await gesture();
    debugPrintSynchronously('SETTINGS_RETURN gesture.end');
    // Existing no-publish serial barrier; no synthetic setting or fake save.
    await scope
        .read(themeProvider.notifier)
        .restoreAccountFontSize('', isCurrent: () => false);
    debugPrintSynchronously('SETTINGS_RETURN save.barrier.end');
  });
  // EasyLoading4 queues dismiss behind show, whose presentation awaits a frame.
  // Advance the real host before awaiting its nonanimated dismissal operation.
  await tester.pumpAndSettle();
  debugPrintSynchronously('SETTINGS_RETURN presentation.end');
  await tester.runAsync(() => EasyLoading.dismiss(animation: false));
  debugPrintSynchronously('SETTINGS_RETURN dismiss.end');
  await tester.pumpAndSettle();
}

Future<void> chooseRealFont(
  WidgetTester tester,
  ProviderContainer scope,
  FontSizeOption value,
) async {
  final slider = find.byType(Slider);
  final rect = tester.getRect(slider);
  final fraction =
      FontSizeOption.values.indexOf(value) / (FontSizeOption.values.length - 1);
  final point = Offset(
    rect.left +
        AppSpacing.xLarge +
        (rect.width - AppSpacing.xLarge * 2) * fraction,
    rect.center.dy,
  );
  await preferenceGesture(tester, scope, () => tester.tapAt(point));
  expect(scope.read(themeProvider).fontSizeOption, value);
  expect(UserRepoLocal.to.setting.fontSize, value.value);
  expect(scope.read(fontSizeProvider).currentOption, value);
}

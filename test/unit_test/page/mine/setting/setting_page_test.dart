import 'package:imboy/service/explicit_web_logout.dart';

import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrintSynchronously;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:imboy/page/mine/dark_model/dark_model_page.dart';
import 'package:imboy/page/mine/font_size/font_size_page.dart';
import 'package:imboy/theme/providers/theme_provider.dart';
import 'package:imboy/theme/default/app_sizes.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:imboy/component/ui/common_bar.dart' show GlassBackButton;
import 'package:imboy/component/ui/ios_settings_ui.dart' show ImBoySettingsTile;
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:imboy/theme/default/theme.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';

import 'package:imboy/component/extension/imboy_cache_manager.dart';
import 'package:imboy/component/ui/resource_page_layout.dart';
import 'package:imboy/component/ui/detail_settings_tile.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/config/init.dart' show appVsn;
import 'package:imboy/config/init.dart' as init;
import 'package:imboy/config/routes.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/organization/presentation/organization_routes.dart';
import 'package:imboy/page/mine/setting/setting_page.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/service/auth_session_scope.dart';
import 'package:imboy/page/web_shell/web_shell_route.dart';

class _LogoutSessions extends ChangeNotifier implements AuthSessionReader {
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
/// path_provider + StorageService）。每个测试末尾 _unmount 清理 Riverpod scheduler。
GoRouter _stubRouter({
  _LogoutSessions? shellSessions,
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

Future<void> _pumpSetting(
  WidgetTester tester, {
  double width = 390,
  double scale = 1,
  Brightness brightness = Brightness.light,
  bool webMode = false,
  _LogoutSessions? shellSessions,
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

Future<void> _unmount(WidgetTester tester) async {
  await EasyLoading.dismiss(animation: false);
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
}

Future<(ProviderContainer, GoRouter)> _realPreferenceContext(
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
    await _unmount(tester);
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

Future<void> _preferenceGesture(
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

Future<void> _chooseRealFont(
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
  await _preferenceGesture(tester, scope, () => tester.tapAt(point));
  expect(scope.read(themeProvider).fontSizeOption, value);
  expect(UserRepoLocal.to.setting.fontSize, value.value);
  expect(scope.read(fontSizeProvider).currentOption, value);
}

void main() {
  setUpAll(() async {
    Env.uploadKey = 'test_dummy_upload_key';
    Env.uploadScene = 'test_scene';
    IMBoyCacheManager.debugLogEnabled = false;
    // 注入 currentUid 让 userRepoProvider 工作
    await StorageService.to.setString(Keys.currentUid, 'tsid_uid_001');
    await StorageService.setMap(Keys.currentUser, <String, dynamic>{
      'uid': 'tsid_uid_001',
      'account': 'imboy_user',
      'nickname': 'Tester',
      'avatar': '',
      'email': '',
      'gender': 0,
      'sign': '',
      'region': '',
      'createdAt': 0,
    });
  });

  tearDownAll(() async {
    IMBoyCacheManager.debugLogEnabled = true;
    await StorageService.to.remove(Keys.currentUid);
    await StorageService.to.remove(Keys.currentUser);
  });

  group('real settings return context', () {
    for (final width in [390.0, 1024.0]) {
      for (final font in [false, true]) {
        testWidgets(
          'real ${font ? 'font' : 'theme'} returns to same entry at $width',
          (tester) async {
            final (scope, router) = await _realPreferenceContext(tester, width);
            final page = find.byType(SettingPage);
            final viewport = find.descendant(
              of: page,
              matching: find.byType(CustomScrollView),
            );
            final scrollable = find
                .descendant(of: viewport, matching: find.byType(Scrollable))
                .first;
            final label = font ? t.common.fontSettings : t.main.darkModel;
            final entry = find.descendant(of: page, matching: find.text(label));
            final entryId = font ? 'setting:/font_size' : 'setting:/dark_model';
            await tester.drag(viewport, const Offset(0, -100));
            await tester.pumpAndSettle();
            final beforeState = tester.state(page);
            final beforeElement = tester.element(entry);
            final position = tester.state<ScrollableState>(scrollable).position;
            expect(
              position.pixels,
              greaterThan(0),
              reason: '$entryId must be scrolled',
            );
            final beforeY =
                tester.getTopLeft(entry).dy - tester.getTopLeft(viewport).dy;
            expect(beforeY, greaterThanOrEqualTo(0));
            final beforeFont = tester
                .renderObject<RenderParagraph>(
                  find.descendant(of: entry, matching: find.byType(RichText)),
                )
                .text
                .style!
                .fontSize!;
            await tester.tap(entry);
            await tester.pumpAndSettle();
            expect(router.state.uri.path, font ? '/font_size' : '/dark_model');
            if (font) {
              expect(find.byType(FontSizePage), findsOneWidget);
              await _chooseRealFont(tester, scope, FontSizeOption.huge);
            } else {
              expect(find.byType(DarkModelPage), findsOneWidget);
              final dark = find.descendant(
                of: find.byType(ImBoySettingsTile),
                matching: find.text(t.main.darkModel),
              );
              await _preferenceGesture(tester, scope, () => tester.tap(dark));
              expect(scope.read(themeModeProvider), ThemeMode.dark);
              expect(
                Theme.of(tester.element(find.byType(DarkModelPage))).brightness,
                Brightness.dark,
              );
            }
            await tester.tap(find.byType(GlassBackButton));
            await tester.pumpAndSettle();
            expect(router.state.uri.path, '/setting');
            expect(tester.state(page), same(beforeState));
            expect(tester.element(entry), same(beforeElement));
            expect(position.pixels, greaterThan(0));
            final relativeY =
                tester.getTopLeft(entry).dy - tester.getTopLeft(viewport).dy;
            expect(
              relativeY,
              closeTo(beforeY, font ? AppSizes.touchTarget : 1),
              reason:
                  '$entryId: theme1px/font48px tolerance frozen before execution',
            );
            final bounds = tester.getRect(viewport),
                item = tester.getRect(entry);
            expect(item.top, greaterThanOrEqualTo(bounds.top));
            expect(item.bottom, lessThanOrEqualTo(bounds.bottom));
            if (font) {
              final rendered = tester
                  .renderObject<RenderParagraph>(
                    find.descendant(of: entry, matching: find.byType(RichText)),
                  )
                  .text
                  .style!
                  .fontSize!;
              expect(
                rendered,
                greaterThan(beforeFont),
                reason: 'actual settings font changed',
              );
              await tester.tap(entry);
              await tester.pumpAndSettle();
              await _chooseRealFont(tester, scope, FontSizeOption.normal);
              await tester.tap(find.byType(GlassBackButton));
              await tester.pumpAndSettle();
              expect(tester.state(page), same(beforeState));
              expect(
                tester.getTopLeft(entry).dy - tester.getTopLeft(viewport).dy,
                closeTo(beforeY, 1),
                reason: 'normal geometry returns within1px',
              );
            }
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  });

  group('logout dialog app font and independent system scale', () {
    for (final appFont in [FontSizeOption.normal, FontSizeOption.huge]) {
      for (final systemScale in [1.0, 2.0]) {
        for (final followAppFont in [true, false]) {
          testWidgets('$appFont system=$systemScale appFont=$followAppFont', (
            tester,
          ) async {
            Future<bool?>? result;
            await tester.pumpWidget(
              TranslationProvider(
                child: MaterialApp(
                  theme: AppTheme.getLightThemeFromOption(appFont),
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: TextScaler.linear(systemScale)),
                    child: child!,
                  ),
                  home: Builder(
                    builder: (context) => Scaffold(
                      body: TextButton(
                        onPressed: () {
                          result = confirmExplicitWebLogout(
                            context,
                            followAppFont: followAppFont,
                          );
                        },
                        child: const Text('open logout dialog'),
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.tap(find.text('open logout dialog'));
            await tester.pumpAndSettle();
            final scale = followAppFont ? appFont.scale : 1.0;
            for (final entry in {
              t.account.logOut: 17.0,
              t.account.areYouSureLogOut: 13.0,
              t.common.buttonCancel: followAppFont ? 17.0 : 16.8,
              t.common.buttonConfirm: followAppFont ? 17.0 : 16.8,
            }.entries) {
              final text = find.descendant(
                of: find.byType(CupertinoAlertDialog),
                matching: find.text(entry.key),
              );
              expect(text, findsOneWidget);
              final paragraph = tester.renderObject<RenderParagraph>(
                find.descendant(of: text, matching: find.byType(RichText)),
              );
              expect(
                paragraph.text.style!.fontSize,
                closeTo(entry.value * scale, 0.001),
              );
              expect(
                paragraph.textScaler.scale(entry.value * scale),
                closeTo(entry.value * scale * systemScale, 0.001),
              );
            }
            for (final action in tester.widgetList<CupertinoDialogAction>(
              find.byType(CupertinoDialogAction),
            )) {
              expect(
                action.textStyle?.fontSize,
                followAppFont ? closeTo(17 * scale, 0.001) : isNull,
              );
              expect(action.textStyle?.color, isNull);
              expect(action.textStyle?.fontWeight, isNull);
            }
            // RenderParagraph scaler is observed above; SDK may fit regular
            // actions and uses wrapping in accessibility mode. Never infer
            // final painted size only from the requested system scale.
            for (final action
                in find.byType(CupertinoDialogAction).evaluate()) {
              final bounds = tester.getRect(
                find.byElementPredicate(
                  (element) => identical(element, action),
                ),
              );
              expect(bounds.width, greaterThan(0));
              expect(bounds.height, greaterThan(0));
            }
            await tester.tap(find.text(t.common.buttonCancel));
            await tester.pumpAndSettle();
            expect(await result, isFalse);
            expect(find.byType(CupertinoAlertDialog), findsNothing);
            expect(tester.takeException(), isNull);
            await _unmount(tester);
          });
        }
      }
    }
  });

  group('explicit Web logout revocation', () {
    late String previousDid;
    late String previousUid;
    late Map<String, dynamic> previousUser;
    setUp(() {
      previousDid = init.deviceId;
      previousUid = UserRepoLocal.to.currentUid;
      previousUser = StorageService.getMap(Keys.currentUser);
      init.deviceId = 'web_synthetic_logout';
    });
    tearDown(() async {
      init.deviceId = previousDid;
      await StorageService.to.setString(Keys.currentUid, previousUid);
      await StorageService.setMap(Keys.currentUser, previousUser);
      UserRepoLocal.to.notifyListeners();
    });

    Future<void> open(WidgetTester tester) async {
      await tester.scrollUntilVisible(
        find.text(t.account.logOut),
        220,
        scrollable: find
            .descendant(
              of: find.byType(SettingPage),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.text(t.account.logOut));
      await tester.pumpAndSettle();
    }

    Future<void> confirm(WidgetTester tester) async {
      await tester.tap(find.text(t.common.buttonConfirm));
      await tester.pumpAndSettle();
    }

    testWidgets('cancel sends no request and does not clear local session', (
      tester,
    ) async {
      var requests = 0;
      var quits = 0;
      await _pumpSetting(
        tester,
        webMode: true,
        readWebDeviceId: () async => init.deviceId,
        revokeWebDevice: (_, guard) async {
          guard();
          requests++;
          return true;
        },
        quitLocal: (_) async {
          quits++;
          return true;
        },
      );
      await open(tester);
      await tester.tap(find.text(t.common.buttonCancel));
      await tester.pumpAndSettle();
      expect(requests, 0);
      expect(quits, 0);
      await _unmount(tester);
    });

    testWidgets(
      'success revokes current bound DID before generation-scoped local logout',
      (tester) async {
        final events = <String>[];
        final generation = UserRepoLocal.to.sessionGeneration;
        var completedGeneration = generation;
        int? quitGeneration;
        await _pumpSetting(
          tester,
          webMode: true,
          isLoggedOutAfter: (original) {
            expect(original, generation);
            return completedGeneration == original + 1 &&
                UserRepoLocal.to.currentUid.isEmpty;
          },
          readWebDeviceId: () async => init.deviceId,
          revokeWebDevice: (did, guard) async {
            guard();
            events.add('delete:$did');
            return true;
          },
          quitLocal: (expected) async {
            quitGeneration = expected;
            events.add('quit');
            await StorageService.to.setString(Keys.currentUid, '');
            completedGeneration++;
            return true;
          },
        );
        await open(tester);
        await confirm(tester);
        expect(events, ['delete:web_synthetic_logout', 'quit']);
        expect(quitGeneration, generation);
        expect(find.text('signed out stub'), findsOneWidget);
        await _unmount(tester);
      },
    );

    for (final replaceAccount in [false, true]) {
      testWidgets('shell disposal during cleanup replacement=$replaceAccount', (
        tester,
      ) async {
        final sessions = _LogoutSessions();
        final generation = UserRepoLocal.to.sessionGeneration;
        var completedGeneration = generation;
        final cleanup = Completer<bool>();
        await _pumpSetting(
          tester,
          webMode: true,
          shellSessions: sessions,
          isLoggedOutAfter: (original) {
            expect(original, generation);
            return completedGeneration == original + 1 &&
                UserRepoLocal.to.currentUid.isEmpty;
          },
          readWebDeviceId: () async => init.deviceId,
          revokeWebDevice: (_, guard) async {
            guard();
            return true;
          },
          quitLocal: (_) {
            sessions.transition();
            return cleanup.future;
          },
        );
        await open(tester);
        await tester.tap(find.text(t.common.buttonConfirm));
        await tester.pumpAndSettle();
        expect(find.byType(SettingPage), findsNothing);
        await StorageService.to.setString(
          Keys.currentUid,
          replaceAccount ? 'new_synthetic_owner' : '',
        );
        cleanup.complete(true);
        completedGeneration = generation + (replaceAccount ? 2 : 1);
        await tester.pumpAndSettle();
        expect(
          find.text('signed out stub'),
          replaceAccount ? findsNothing : findsOneWidget,
        );
        if (replaceAccount) {
          expect(UserRepoLocal.to.currentUid, 'new_synthetic_owner');
        }
        await _unmount(tester);
        sessions.dispose();
      });
    }

    for (final throws in [false, true]) {
      testWidgets(
        'delete ${throws ? 'throw' : 'false'} preserves session and permits retry',
        (tester) async {
          var requests = 0;
          var quits = 0;
          await _pumpSetting(
            tester,
            webMode: true,
            readWebDeviceId: () async => init.deviceId,
            revokeWebDevice: (_, guard) async {
              guard();
              requests++;
              if (requests == 1) {
                if (throws) throw StateError('synthetic offline');
                return false;
              }
              return true;
            },
            quitLocal: (_) async {
              quits++;
              return true;
            },
          );
          await open(tester);
          await confirm(tester);
          expect(requests, 1);
          expect(quits, 0);
          expect(UserRepoLocal.to.currentUid, previousUid);
          await EasyLoading.dismiss(animation: false);
          await tester.pumpAndSettle();
          await open(tester);
          await confirm(tester);
          expect(requests, 2);
          expect(quits, 1);
          await _unmount(tester);
        },
      );
    }

    testWidgets('in-flight intent prevents a second revoke or dialog', (
      tester,
    ) async {
      var requests = 0;
      var quits = 0;
      final pending = Completer<bool>();
      await _pumpSetting(
        tester,
        webMode: true,
        readWebDeviceId: () async => init.deviceId,
        revokeWebDevice: (_, guard) {
          guard();
          requests++;
          return pending.future;
        },
        quitLocal: (_) async {
          quits++;
          return true;
        },
      );
      await tester.scrollUntilVisible(find.text(t.account.logOut), 220);
      final row = tester.widget<DetailSettingsTile>(
        find
            .ancestor(
              of: find.text(t.account.logOut),
              matching: find.byType(DetailSettingsTile),
            )
            .first,
      );
      row.onTap!();
      row.onTap!();
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoAlertDialog), findsOneWidget);
      await confirm(tester);
      expect(requests, 1);
      row.onTap!();
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoAlertDialog), findsNothing);
      expect(requests, 1);
      pending.complete(true);
      await tester.pumpAndSettle();
      expect(quits, 1);
      await _unmount(tester);
    });

    testWidgets('late delete cannot clear a replacement account', (
      tester,
    ) async {
      var requests = 0;
      var quits = 0;
      final pending = Completer<bool>();
      await _pumpSetting(
        tester,
        webMode: true,
        readWebDeviceId: () async => init.deviceId,
        revokeWebDevice: (_, guard) {
          guard();
          requests++;
          return pending.future;
        },
        quitLocal: (_) async {
          quits++;
          return true;
        },
      );
      await open(tester);
      await confirm(tester);
      expect(requests, 1);
      await StorageService.to.setString(
        Keys.currentUid,
        'replacement_synthetic_uid',
      );
      UserRepoLocal.to.notifyListeners();
      pending.complete(true);
      await tester.pumpAndSettle();
      expect(quits, 0);
      expect(UserRepoLocal.to.currentUid, 'replacement_synthetic_uid');
      expect(find.text('signed out stub'), findsNothing);
      await _unmount(tester);
    });

    testWidgets(
      'DID mismatch rejects Web logout without revoke or local cleanup',
      (tester) async {
        var requests = 0;
        var quits = 0;
        await _pumpSetting(
          tester,
          webMode: true,
          readWebDeviceId: () async => 'different_synthetic_did',
          revokeWebDevice: (_, _) async {
            requests++;
            return true;
          },
          quitLocal: (_) async {
            quits++;
            return true;
          },
        );
        await open(tester);
        expect(find.byType(CupertinoAlertDialog), findsNothing);
        expect(requests, 0);
        expect(quits, 0);
        await _unmount(tester);
      },
    );

    testWidgets('account replacement during confirmation cancels revocation', (
      tester,
    ) async {
      var requests = 0;
      var quits = 0;
      await _pumpSetting(
        tester,
        webMode: true,
        readWebDeviceId: () async => init.deviceId,
        revokeWebDevice: (_, _) async {
          requests++;
          return true;
        },
        quitLocal: (_) async {
          quits++;
          return true;
        },
      );
      await open(tester);
      await StorageService.to.setString(
        Keys.currentUid,
        'replacement_during_dialog',
      );
      UserRepoLocal.to.notifyListeners();
      await confirm(tester);
      expect(requests, 0);
      expect(quits, 0);
      expect(UserRepoLocal.to.currentUid, 'replacement_during_dialog');
      await _unmount(tester);
    });

    testWidgets(
      'server kick before delete response does not clear twice or report delete success',
      (tester) async {
        var requests = 0;
        var quits = 0;
        final pending = Completer<bool>();
        await _pumpSetting(
          tester,
          webMode: true,
          readWebDeviceId: () async => init.deviceId,
          revokeWebDevice: (_, guard) {
            guard();
            requests++;
            return pending.future;
          },
          quitLocal: (_) async {
            quits++;
            return true;
          },
        );
        await open(tester);
        await confirm(tester);
        expect(requests, 1);
        // Model automatic cleanup independently of the explicit logout callback.
        await StorageService.to.setString(Keys.currentUid, '');
        UserRepoLocal.to.notifyListeners();
        pending.complete(false);
        await tester.pumpAndSettle();
        expect(quits, 0);
        expect(find.text(t.common.logoutFailed), findsNothing);
        expect(find.text('signed out stub'), findsNothing);
        await _unmount(tester);
      },
    );

    testWidgets(
      'Native explicit logout adds no device lookup or revoke request',
      (tester) async {
        var deviceReads = 0;
        var requests = 0;
        int? generation;
        await _pumpSetting(
          tester,
          readWebDeviceId: () async {
            deviceReads++;
            return init.deviceId;
          },
          revokeWebDevice: (_, _) async {
            requests++;
            return true;
          },
          quitLocal: (expected) async {
            generation = expected;
            return true;
          },
        );
        await open(tester);
        await confirm(tester);
        expect(deviceReads, 0);
        expect(requests, 0);
        expect(generation, isNull);
        expect(find.text('native signed out stub'), findsOneWidget);
        await _unmount(tester);
      },
    );
  });

  testWidgets(
    'Web reuses appearance settings but exposes privacy as static data',
    (tester) async {
      await _pumpSetting(tester, webMode: true);
      expect(find.text(t.common.languageSetting), findsOneWidget);
      expect(find.text(t.main.darkModel), findsOneWidget);
      expect(find.text(t.common.fontSettings), findsOneWidget);
      final privacy = tester.widget<DetailSettingsTile>(
        find.byWidgetPredicate(
          (widget) =>
              widget is DetailSettingsTile &&
              widget.title is Text &&
              (widget.title as Text).data == t.common.allowSearchMe,
        ),
      );
      expect(privacy.onTap, isNull);
      expect(privacy.trailing, isNull);
      expect(privacy.value, t.common.unknown);
      expect(find.byType(CupertinoSwitch), findsNothing);
      expect(find.text(t.account.accountSecurity), findsNothing);
      await tester.scrollUntilVisible(find.text(t.account.logOut), 220);
      expect(find.text(t.common.switchEnvironment), findsNothing);
      expect(find.text(t.account.logoutAccount), findsNothing);
      await _unmount(tester);
    },
  );

  test('account privacy overrides stale global settings and follows account changes', () async {
    final previousUser = StorageService.getMap(Keys.currentUser);
    final previousSetting = StorageService.to.getString('setting');
    final container = ProviderContainer();
    await StorageService.to.setString('setting', '{"allow_search":true}');
    await StorageService.setMap(Keys.currentUser, {
      ...previousUser,
      'setting': {'allow_search': 2},
    });
    final subscription = container.listen(allowSearchProvider, (_, _) {});
    try {
      expect(container.read(allowSearchProvider), isFalse);
      await StorageService.setMap(Keys.currentUser, {
        ...previousUser,
        'uid': 'synthetic-other-settings-owner',
        'setting': {'allow_search': 1},
      });
      UserRepoLocal.to.notifyListeners();
      expect(container.read(allowSearchProvider), isTrue);
    } finally {
      subscription.close();
      container.dispose();
      await StorageService.setMap(Keys.currentUser, previousUser);
      if (previousSetting.isEmpty) {
        await StorageService.to.remove('setting');
      } else {
        await StorageService.to.setString('setting', previousSetting);
      }
      UserRepoLocal.to.notifyListeners();
    }
  });

  testWidgets('设置图标保持中性，无彩色实心底', (tester) async {
    await _pumpSetting(tester);
    expect(
      tester.widget<Icon>(find.byIcon(CupertinoIcons.lock_shield)).color,
      AppColors.getTextColor(Brightness.light, isSecondary: true),
    );
    await _unmount(tester);
  });
  for (final brightness in Brightness.values) {
    for (final width in [320.0, 360.0, 390.0]) {
      for (final scale in [1.0, 1.5, 2.0]) {
        testWidgets('设置 $width × $scale $brightness 字体导航返回且末尾可达', (
          tester,
        ) async {
          await _pumpSetting(
            tester,
            width: width,
            scale: scale,
            brightness: brightness,
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final fontSetting = find.text(t.common.fontSettings);
          await tester.ensureVisible(fontSetting);
          expect(fontSetting.hitTestable(), findsOneWidget);
          await tester.tap(find.text(t.common.fontSettings));
          await tester.pumpAndSettle();
          expect(find.byType(FontSizePage), findsOneWidget);
          expect(find.byType(Slider), findsOneWidget);
          expect(find.text(t.main.thisIsTitleText), findsOneWidget);
          final context = tester.element(find.byType(FontSizePage));
          expect(GoRouterState.of(context).uri.path, '/font_size');
          await tester.tap(find.byType(GlassBackButton));
          await tester.pumpAndSettle();
          expect(find.byType(FontSizePage), findsNothing);
          expect(find.byType(SettingPage), findsOneWidget);
          expect(
            find.text(t.common.fontSettings).hitTestable(),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
          await tester.scrollUntilVisible(
            find.text(t.account.logoutAccount),
            220,
          );
          await tester.pumpAndSettle();
          expect(
            find.text(t.account.logoutAccount).hitTestable(),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
          await _unmount(tester);
        });
      }
    }
  }

  group('SettingPage layout', () {
    testWidgets('宽窗口内容列居中，版本信息随大字号移到标题下方', (tester) async {
      final previousVersion = appVsn;
      appVsn = '1.2.3+456';
      addTearDown(() => appVsn = previousVersion);
      await _pumpSetting(tester, width: 1280, scale: 2);

      final scrollRect = tester.getRect(find.byType(CustomScrollView));
      expect(scrollRect.width, ResourcePageLayout.maxWidth);
      expect(scrollRect.center.dx, 640);
      await tester.scrollUntilVisible(find.text(t.common.aboutApp), 220);
      final titleRect = tester.getRect(find.text(t.common.aboutApp));
      final versionRect = tester.getRect(
        find.text('${t.common.version} $appVsn'),
      );
      expect(versionRect.top, greaterThanOrEqualTo(titleRect.bottom));
      expect(versionRect.right, lessThanOrEqualTo(scrollRect.right));
      expect(tester.takeException(), isNull);
      await _unmount(tester);
    });

    testWidgets('Scaffold uses iOS surfaceGrouped background', (tester) async {
      await _pumpSetting(tester);

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(scaffold.backgroundColor, AppColors.lightSurfaceGrouped);
      await _unmount(tester);
    });

    testWidgets('AppBar title 渲染 "设置"', (tester) async {
      await _pumpSetting(tester);
      // i18n zhCn: setting = "设置"
      expect(find.text('设置'), findsAtLeastNWidgets(1));
      await _unmount(tester);
    });

    testWidgets('Section header "通用" 大写渲染', (tester) async {
      await _pumpSetting(tester);
      // _buildSectionHeader 用 toUpperCase()，中文 toUpperCase() 不变 → "通用"
      expect(find.text('通用'), findsOneWidget);
      await _unmount(tester);
    });
  });

  group('SettingPage menu items', () {
    testWidgets('renders 通用 section 5 个菜单项（含企业切换）', (tester) async {
      await _pumpSetting(tester);

      // 4 个 setting items 主标题
      expect(find.text('账号安全'), findsOneWidget);
      expect(find.text('语言设置'), findsOneWidget);
      expect(find.text('深色模式'), findsOneWidget);
      // fontSettings = @:fontSizeSetting 别名 → 解析为 "字体大小设置"
      expect(find.byIcon(CupertinoIcons.textformat), findsOneWidget);
      expect(find.text('切换空间'), findsOneWidget);

      await _unmount(tester);
    });

    testWidgets('帮助、账号检查与退出入口仍完整保留', (tester) async {
      await _pumpSetting(tester);
      for (final label in [
        t.common.helpDocument,
        t.common.updateLog,
        t.main.privacyPolicy,
        t.main.termsOfService,
        t.common.aboutApp,
        t.account.logOut,
        t.organization.experienceUi.accountCheck,
        t.account.logoutAccount,
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      await _unmount(tester);
    });
  });

  group('SettingPage navigation', () {
    testWidgets('模式入口统一进入企业选择页，不再提供旧布局及部署默认值', (tester) async {
      await _pumpSetting(tester);
      expect(find.text('首页布局'), findsNothing);
      expect(find.text('恢复部署默认值'), findsNothing);
      await tester.tap(find.text('切换空间'));
      await tester.pumpAndSettle();
      expect(find.text('organization picker stub'), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('tap "账号安全" → /account_security', (tester) async {
      await _pumpSetting(tester);

      await tester.tap(find.text('账号安全'));
      await tester.pumpAndSettle();
      expect(find.text('account_security stub'), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('tap "语言设置" → /language', (tester) async {
      await _pumpSetting(tester);

      await tester.tap(find.text('语言设置'));
      await tester.pumpAndSettle();
      expect(find.text('language stub'), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('tap "深色模式" → /dark_model', (tester) async {
      await _pumpSetting(tester);

      await tester.tap(find.text('深色模式'));
      await tester.pumpAndSettle();
      expect(find.text('dark_model stub'), findsOneWidget);
      await _unmount(tester);
    });
  });

  test(
    'shared explicit Web action refuses late confirmation after owner change',
    () async {
      final previousUid = UserRepoLocal.to.currentUid;
      final previousDid = init.deviceId;
      await StorageService.to.setString(Keys.currentUid, '900001');
      init.deviceId = 'web_synthetic_action';
      final confirmation = Completer<bool?>();
      var revokes = 0;
      var quits = 0;
      final action = ExplicitWebLogoutAction(
        readWebDeviceId: () async => init.deviceId,
        revokeWebDevice: (_, guard) async {
          guard();
          revokes++;
          return true;
        },
        quitLocal: (_) async {
          quits++;
          return true;
        },
        isLoggedOutAfter: (_) => false,
      );
      try {
        final run = action.run(
          isMounted: () => true,
          confirm: () => confirmation.future,
          onFailure: () {},
        );
        await Future<void>.delayed(Duration.zero);
        await StorageService.to.setString(Keys.currentUid, '900002');
        confirmation.complete(true);
        expect(await run, isFalse);
        expect(revokes, 0);
        expect(quits, 0);
      } finally {
        await StorageService.to.setString(Keys.currentUid, previousUid);
        init.deviceId = previousDid;
      }
    },
  );

  test('shared explicit Web action coalesces repeated entry and revokes before local', () async {
    final previousUid = UserRepoLocal.to.currentUid;
    final previousDid = init.deviceId;
    await StorageService.to.setString(Keys.currentUid, '900001');
    init.deviceId = 'web_synthetic_action';
    final revocation = Completer<bool>();
    final events = <String>[];
    final action = ExplicitWebLogoutAction(
      readWebDeviceId: () async => init.deviceId,
      revokeWebDevice: (_, guard) async {
        guard();
        events.add('revoke');
        return revocation.future;
      },
      quitLocal: (_) async {
        events.add('quit');
        return true;
      },
      isLoggedOutAfter: (_) => true,
    );
    try {
      final run = action.run(
        isMounted: () => true,
        confirm: () async => true,
        onFailure: () {},
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        await action.run(
          isMounted: () => true,
          confirm: () async => true,
          onFailure: () {},
        ),
        isFalse,
      );
      expect(events, ['revoke']);
      revocation.complete(true);
      expect(await run, isTrue);
      expect(events, ['revoke', 'quit']);
    } finally {
      await StorageService.to.setString(Keys.currentUid, previousUid);
      init.deviceId = previousDid;
    }
  });
}
